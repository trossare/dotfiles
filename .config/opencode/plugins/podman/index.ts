import { execFile, type ChildProcess } from "node:child_process";
import { createHash } from "node:crypto";
import { resolve } from "node:path";
import { Plugin } from "@opencode/plugin";

const OWNER_LABEL = "io.opencode.podman-workspace";
const ROOT_LABEL = "io.opencode.podman-workspace-root";
const IMAGE_KEY_LABEL = "io.opencode.podman-workspace-image-key";
const OUTPUT_LIMIT = 48_000;
const MAX_EXEC_TIMEOUT_SECONDS = 1_800;
const DEFAULT_IMAGE_KEY = "alpine";

const IMAGE_PROFILES = [
  {
    key: "alpine",
    image: "docker.io/library/alpine",
    description: "General-purpose lightweight Linux environment.",
  },
  {
    key: "python",
    image: "docker.io/library/python:latest",
    description: "Python environment.",
  },
  {
    key: "java-jar-analysis",
    image: "localhost/java-jar-analysis:latest",
    description: "JAR analysis environment.",
  },
] as const;

function getImageProfile(key: string) {
  return IMAGE_PROFILES.find((profile) => profile.key === key);
}

function withDefaultTag(reference: string): string {
  const tagSeparator = reference.lastIndexOf(":");
  const pathSeparator = reference.lastIndexOf("/");
  return reference.includes("@") || tagSeparator > pathSeparator
    ? reference
    : `${reference}:latest`;
}

function sameImageReference(left: string | undefined, right: string): boolean {
  return left !== undefined && withDefaultTag(left) === withDefaultTag(right);
}

const imageProfileHelp = IMAGE_PROFILES.map(
  ({ key, image, description }) => `${key}=${image} (${description})`,
).join("; ");

type RunResult = { code: number; stdout: string; stderr: string };
type ContainerInfo = {
  Config?: { Image?: string; Labels?: Record<string, string> };
  State?: { Running?: boolean };
};

function runPodman(
  root: string,
  args: string[],
  signal: AbortSignal,
  timeoutMs = 30_000,
): Promise<RunResult> {
  return new Promise((resolveRun, rejectRun) => {
    let child: ChildProcess | undefined;
    let timedOut = false;
    const abort = () => child?.kill("SIGTERM");
    const timer = setTimeout(() => {
      timedOut = true;
      child?.kill("SIGTERM");
    }, timeoutMs);

    child = execFile(
      "podman",
      args,
      {
        cwd: root,
        encoding: "utf8",
        maxBuffer: 4 * 1024 * 1024,
        windowsHide: true,
      },
      (error, stdout, stderr) => {
        clearTimeout(timer);
        signal.removeEventListener("abort", abort);

        if (signal.aborted) {
          rejectRun(new Error("Podman operation was cancelled"));
          return;
        }
        if (timedOut) {
          resolveRun({
            code: 124,
            stdout: stdout || "",
            stderr: `${stderr || ""}\nPodman command timed out after ${Math.ceil(timeoutMs / 1000)} seconds.`,
          });
          return;
        }

        const exitCode =
          error && typeof error.code === "number" ? error.code : 0;
        if (error && typeof error.code !== "number") {
          rejectRun(error);
          return;
        }
        resolveRun({
          code: exitCode,
          stdout: stdout || "",
          stderr: stderr || "",
        });
      },
    );

    signal.addEventListener("abort", abort, { once: true });
    if (signal.aborted) abort();
  });
}

function clipped(text: string): string {
  return text.length <= OUTPUT_LIMIT
    ? text
    : `${text.slice(0, OUTPUT_LIMIT)}\n...[output truncated]`;
}

export default Plugin.define({
  id: "podman-workspace",

  async setup(ctx) {
    const root = resolve(ctx.location.project.canonical);
    const rootHash = createHash("sha256").update(root).digest("hex");
    const prefix =
      process.env.OPENCODE_PODMAN_CONTAINER_PREFIX || "opencode-ws";
    if (!/^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,30}$/.test(prefix)) {
      throw new Error(
        "OPENCODE_PODMAN_CONTAINER_PREFIX must be a valid short container-name prefix",
      );
    }
    const name = `${prefix}-${rootHash.slice(0, 12)}`;

    const checked = async (
      args: string[],
      signal: AbortSignal,
      timeoutMs?: number,
    ) => {
      const result = await runPodman(root, args, signal, timeoutMs);
      if (result.code !== 0) {
        throw new Error(
          result.stderr.trim() ||
            result.stdout.trim() ||
            `podman exited with code ${result.code}`,
        );
      }
      return result;
    };

    const inspect = async (
      signal: AbortSignal,
    ): Promise<ContainerInfo | undefined> => {
      const exists = await runPodman(
        root,
        ["container", "exists", name],
        signal,
      );
      if (exists.code === 1) return undefined;
      if (exists.code !== 0) {
        throw new Error(
          exists.stderr.trim() || "podman container exists failed",
        );
      }
      const result = await checked(["inspect", name], signal);
      const decoded = JSON.parse(result.stdout);
      const info: ContainerInfo = Array.isArray(decoded) ? decoded[0] : decoded;
      const labels = info?.Config?.Labels || {};
      if (labels[OWNER_LABEL] !== "true" || labels[ROOT_LABEL] !== rootHash) {
        throw new Error(
          `Container ${name} exists but is not owned by this plugin; refusing to modify it`,
        );
      }
      return info;
    };

    const inputNone = {
      type: "object",
      properties: {},
      additionalProperties: false,
    } as const;

    await ctx.tool.transform((editor) => {
      editor.add({
        name: "podman_images",
        description:
          "List the hardcoded image profiles accepted by podman_start. This reports allowed images, not whether they are installed locally.",
        input: inputNone,
        execute: async () => {
          const rows = IMAGE_PROFILES.map(
            ({ key, image, description }) =>
              `- ${key}=${image} (${description})`,
          );
          return {
            content: `Allowed Podman workspace images:\n${rows.join("\n")}`,
          };
        },
      });

      editor.add({
        name: "podman_start",
        description: `Create or start this project's persistent rootless Podman workspace container, mounting the project at /workspace. Choose only a hardcoded image_key (${imageProfileHelp}). The image does not need to appear in podman_images; Podman may pull it if it is missing locally. Arbitrary image references are not accepted. The image must provide /bin/sh and sleep. A container's image cannot be changed in place; remove it before switching images.`,
        input: {
          type: "object",
          properties: {
            image_key: {
              type: "string",
              enum: IMAGE_PROFILES.map((profile) => profile.key),
              description: `Choose one hardcoded key: ${IMAGE_PROFILES.map(({ key, description }) => `${key}: ${description}`).join("; ")}. The image can be pulled if it is not installed locally. Do not pass an image reference. Omit to use the alpine key.`,
            },
          },
          additionalProperties: false,
        },
        execute: async (rawInput, toolContext) => {
          const input = rawInput as { image_key?: string };
          const requestedKey = input.image_key?.trim();
          if (input.image_key !== undefined && !requestedKey) {
            throw new Error("image_key must not be empty");
          }
          const imageKey = requestedKey ?? DEFAULT_IMAGE_KEY;
          const profile = getImageProfile(imageKey);
          if (!profile) {
            throw new Error(
              `Unknown image_key ${JSON.stringify(imageKey)}. Allowed keys: ${IMAGE_PROFILES.map((item) => item.key).join(", ")}`,
            );
          }
          const image = profile.image;
          const selectedKey = profile.key;

          const info = await inspect(toolContext.signal);
          if (info?.State?.Running) {
            const existingKey = info.Config?.Labels?.[IMAGE_KEY_LABEL];
            if (!sameImageReference(info.Config?.Image, image)) {
              throw new Error(
                `Container ${name} already uses image ${info.Config?.Image || "unknown"}${existingKey ? ` (profile ${existingKey})` : ""}; remove it with podman_remove before starting with hardcoded key ${selectedKey}`,
              );
            }
            return {
              content: `Container ${name} is already running; image=${info.Config?.Image || "unknown"}; image_key=${info.Config?.Labels?.[IMAGE_KEY_LABEL] || "legacy/unknown"}; project is mounted at /workspace.`,
            };
          }
          if (info) {
            const existingKey = info.Config?.Labels?.[IMAGE_KEY_LABEL];
            if (!sameImageReference(info.Config?.Image, image)) {
              throw new Error(
                `Container ${name} already uses image ${info.Config?.Image || "unknown"}${existingKey ? ` (profile ${existingKey})` : ""}; remove it with podman_remove before starting with hardcoded key ${selectedKey}`,
              );
            }
            await checked(["start", name], toolContext.signal);
            return {
              content: `Started existing container ${name}; image=${info.Config?.Image || "unknown"}; image_key=${existingKey || "legacy/unknown"}; project is mounted at /workspace.`,
            };
          }

          let volume = `${root}:/workspace:rw`;
          const uid =
            typeof process.getuid === "function" ? process.getuid() : undefined;
          const gid =
            typeof process.getgid === "function" ? process.getgid() : undefined;
          const args = [
            "run",
            "--pull=missing",
            "--detach",
            "--name",
            name,
            "--label",
            `${OWNER_LABEL}=true`,
            "--label",
            `${ROOT_LABEL}=${rootHash}`,
            "--label",
            `${IMAGE_KEY_LABEL}=${selectedKey}`,
            "--userns=keep-id",
          ];
          if (uid !== undefined && gid !== undefined)
            args.push("--user", `${uid}:${gid}`);
          args.push(
            "--security-opt=no-new-privileges",
            "--volume",
            volume,
            "--workdir",
            "/workspace",
            "--entrypoint",
            "/bin/sh",
            image,
            "-lc",
            "while :; do sleep 3600; done",
          );
          await checked(args, toolContext.signal, 1_800_000);
          return {
            content: `Started ${name} using ${image} (image_key=${selectedKey}); ${root} is mounted read/write at /workspace.`,
          };
        },
      });

      editor.add({
        name: "podman_exec",
        description:
          "Run a command inside the running Podman workspace container, with /workspace as the working directory.",
        input: {
          type: "object",
          properties: {
            command: {
              type: "string",
              description: "Command to run inside the container's /bin/sh.",
            },
            timeout_seconds: {
              type: "integer",
              minimum: 1,
              maximum: MAX_EXEC_TIMEOUT_SECONDS,
              default: 120,
            },
          },
          required: ["command"],
          additionalProperties: false,
        },
        execute: async (rawInput, toolContext) => {
          const input = rawInput as {
            command: string;
            timeout_seconds?: number;
          };
          if (!input.command?.trim())
            throw new Error("command must not be empty");
          const timeoutSeconds = input.timeout_seconds ?? 120;
          if (
            !Number.isInteger(timeoutSeconds) ||
            timeoutSeconds < 1 ||
            timeoutSeconds > MAX_EXEC_TIMEOUT_SECONDS
          ) {
            throw new Error(
              `timeout_seconds must be an integer from 1 to ${MAX_EXEC_TIMEOUT_SECONDS}`,
            );
          }
          const info = await inspect(toolContext.signal);
          if (!info?.State?.Running)
            throw new Error(
              "Workspace container is not running; call podman_start first",
            );

          const result = await runPodman(
            root,
            [
              "exec",
              "--workdir",
              "/workspace",
              name,
              "/bin/sh",
              "-lc",
              input.command,
            ],
            toolContext.signal,
            timeoutSeconds * 1000,
          );
          return {
            content: `exit_code=${result.code}\n${clipped(`${result.stdout}${result.stderr}`)}`,
          };
        },
      });

      editor.add({
        name: "podman_status",
        description:
          "Check whether this project's Podman workspace container exists and is running.",
        input: inputNone,
        execute: async (_input, toolContext) => {
          const info = await inspect(toolContext.signal);
          if (!info)
            return {
              content: `No workspace container exists for ${root}; call podman_start first.`,
            };
          const state = info.State?.Running ? "running" : "stopped";
          return {
            content: `Container ${name}: ${state}; image_key=${info.Config?.Labels?.[IMAGE_KEY_LABEL] || "legacy/unknown"}; image=${info.Config?.Image || "unknown"}; project mount=/workspace.`,
          };
        },
      });

      editor.add({
        name: "podman_stop",
        description:
          "Stop this project's container without removing its container-layer state.",
        input: inputNone,
        execute: async (_input, toolContext) => {
          const info = await inspect(toolContext.signal);
          if (!info) return { content: "No workspace container exists." };
          if (!info.State?.Running)
            return { content: `Container ${name} is already stopped.` };
          await checked(["stop", "--time", "10", name], toolContext.signal);
          return { content: `Stopped ${name}; container state is preserved.` };
        },
      });

      editor.add({
        name: "podman_remove",
        description:
          "Remove this project's owned Podman container. This does not delete the host project directory.",
        input: inputNone,
        execute: async (_input, toolContext) => {
          const info = await inspect(toolContext.signal);
          if (!info) return { content: "No workspace container exists." };
          await checked(["rm", "--force", name], toolContext.signal);
          return {
            content: `Removed ${name}; the host project directory was not deleted.`,
          };
        },
      });
    });
  },
});
