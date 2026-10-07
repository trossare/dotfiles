---
name: Temp Directory
description: Write task files in one dated, uniquely named /tmp/opencode directory per session.
---

# Temp Directory

Use this skill when the user wants files written to temporary storage.

## Directory naming

Create each task directory directly under `/tmp/opencode` using:

`YYYYMMDD-<slug>`

- `YYYYMMDD` is the current date: four-digit year, two-digit month, two-digit day.
- `<slug>` is a concise, task-relevant label in lowercase, with words separated by hyphens. Use only letters, numbers, and hyphens.
- Example: `20261007-fix-request-timeout`.

The full directory name must be unique under `/tmp/opencode`.
If the natural slug is already in use by another session, make it more specific; if needed, append a numeric suffix such as `-2`.
Do not use a random ID.

## Directory lifecycle

Use one temp directory per OpenCode session, not one per request.

1. Before creating a directory, check the conversation for the temp directory already chosen in this session. If there is one, reuse it.
2. Only for the first temp-dir task in a session, read `/tmp/opencode`, choose an unused task slug, and use `/tmp/opencode/YYYYMMDD-<slug>`.
3. Keep using that directory for all later scratch-file tasks for the same task, which in general means the entire session.
   Do not choose a directory just because it is the newest one under `/tmp/opencode`; it may belong to another session.
4. Don’t modify or delete other task directories.

## Workflow

1. Check the conversation for the temp directory already chosen in this session. If one exists, reuse it; do not choose a new slug.
2. If this session has no directory yet, read `/tmp/opencode`, choose a concise, unused slug, and use `/tmp/opencode/YYYYMMDD-<slug>`.
3. Use the OpenCode `write` or `patch` tool for requested files inside that directory. The first write creates the directory. Do not use shell commands.
4. Read back created files to verify them, then report their full paths.
