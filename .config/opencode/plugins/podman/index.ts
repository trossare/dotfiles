import { execFile, type ChildProcess } from "node:child_process";
import { createHash } from "node:crypto";
import { resolve } from "node:path";
import { Plugin } from "@opencode/plugin";

const OWNER_LABEL = "io.opencode.podman-workspace";
const ROOT_LABEL = "io.opencode.podman-workspace-root";
const OUTPUT_LIMIT = 48_000;
const MAX_EXEC_TIMEOUT_SECONDS = 1_800;

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
        name: "podman_start",
        description:
          "Create or start this project's persistent rootless Podman workspace container, mounting the project at /workspace.",
        input: inputNone,
        execute: async (_input, toolContext) => {
          const info = await inspect(toolContext.signal);
          if (info?.State?.Running) {
            return {
              content: `Container ${name} is already running; project is mounted at /workspace.`,
            };
          }
          if (info) {
            await checked(["start", name], toolContext.signal);
            return {
              content: `Started existing container ${name}; project is mounted at /workspace.`,
            };
          }

          const image = (
            process.env.OPENCODE_PODMAN_IMAGE ?? "docker.io/library/alpine"
          ).trim();

          if (!image || image.includes("{env:")) {
            throw new Error(
              "Set OPENCODE_PODMAN_IMAGE in the OpenCode server environment before starting the container",
            );
          }

          const selinux =
            process.env.OPENCODE_PODMAN_SELINUX_LABEL?.trim() || "";
          if (selinux !== "" && selinux !== "Z" && selinux !== "z") {
            throw new Error(
              "OPENCODE_PODMAN_SELINUX_LABEL must be empty, Z, or z",
            );
          }

          let volume = `${root}:/workspace:rw`;
          if (selinux) volume += `,${selinux}`;
          const uid =
            typeof process.getuid === "function" ? process.getuid() : undefined;
          const gid =
            typeof process.getgid === "function" ? process.getgid() : undefined;
          const args = [
            "run",
            "--detach",
            "--name",
            name,
            "--label",
            `${OWNER_LABEL}=true`,
            "--label",
            `${ROOT_LABEL}=${rootHash}`,
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
            content: `Started ${name} using ${image}; ${root} is mounted read/write at /workspace.`,
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
            content: `Container ${name}: ${state}; image=${info.Config?.Image || "unknown"}; project mount=/workspace.`,
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
