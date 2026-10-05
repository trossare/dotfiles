import { readFile } from "fs/promises";
import { fromPromise } from "neverthrow";
import path from "path";
import * as v from "valibot";

type WaybarExecReturn = {
  text?: string;
  alt?: string;
  tooltip?: string;
  class?: string;
  percentage?: string;
};

const UsageWindowSchema = v.pipe(
  v.object({
    status: v.picklist(["ok", "rate-limited"]),
    percent: v.number(),
    resetsAt: v.pipe(
      v.string(),
      v.isoTimestamp(),
      v.transform((value) => Temporal.Instant.from(value)),
    ),
  }),
  v.transform((input) => ({
    ...input,
    remaining: 100 - input.percent,
  })),
);

const UsageSchema = v.object({
  usage: v.object({
    rolling: UsageWindowSchema,
    weekly: UsageWindowSchema,
    monthly: UsageWindowSchema,
  }),
});

function formatDate(instant: Temporal.Instant) {
  const time = instant.toZonedDateTimeISO("Europe/Stockholm");
  const pad = (n: number) => String(n).padStart(2, "0");
  const year = time.year;
  const month = pad(time.month);
  const day = pad(time.day);
  const hour = pad(time.hour);
  const minute = pad(time.minute);
  const second = pad(time.second);

  return `${year}-${month}-${day} ${hour}:${minute}:${second}`;
}

function formattedUsageWindow(
  type: string,
  usage: v.InferOutput<typeof UsageWindowSchema>,
) {
  return `${type}: ${usage.remaining}% ${formatDate(usage.resetsAt)}`;
}

async function main(): Promise<WaybarExecReturn> {
  const configHome = process.env.XDG_CONFIG_HOME;

  if (configHome == undefined) {
    throw Error("XDG_CONFIG_HOME not set");
  }

  const keyPath = path.resolve(configHome, "opencode", "opencode_go.txt");
  const key = await readFile(keyPath, "utf8").then((text) =>
    text.replace(/\r?\n$/, ""),
  );
  const usageResponse = await fetch("https://opencode.ai/zen/go/v1/usage", {
    headers: {
      Authorization: `Bearer ${key}`,
    },
  });

  if (!usageResponse.ok) {
    const status = `${usageResponse.status} ${usageResponse.statusText}`;
    throw Error(
      `Failed to get usage: ${status} (${await usageResponse.text()})`,
    );
  }

  const { usage } = v.parse(UsageSchema, await usageResponse.json());

  const minRemaining = Math.min(
    usage.rolling.remaining,
    usage.weekly.remaining,
    usage.monthly.remaining,
  );

  const remainingLabel = (() => {
    if (minRemaining == 0) return "nothing";
    if (minRemaining <= 20) return "low";
    if (minRemaining <= 50) return "medium";
    else return "high";
  })();

  const gauge = "";
  return {
    text: `${gauge}`,
    alt: `${gauge} (${usage.rolling.remaining}% / ${usage.weekly.remaining}% / ${usage.monthly.remaining}%)`,
    class: remainingLabel,
    tooltip: [
      formattedUsageWindow("Rolling", usage.rolling),
      formattedUsageWindow("Weekly", usage.weekly),
      formattedUsageWindow("Monthly", usage.monthly),
    ].join("\n"),
  };
}

if (import.meta.main) {
  const result = await fromPromise(main(), (err) => err);
  if (result.isOk()) {
    console.log(JSON.stringify(result.value));
    // console.log(result.value.tooltip);
  } else console.log(JSON.stringify({ text: "fail" }));
}
