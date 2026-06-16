---
description: Triage gate errors for a given version/timeframe — pull Mixpanel error counts, fetch the matching server-side renderer logs, root-cause against the boot handshake, and report (with fix only if asked).
argument-hint: "[version] [today|yesterday|Nd]  e.g. 1.0.3 yesterday  (both optional; defaults to latest version, last 2 days)"
---

# /triage-errors — find and root-cause gate errors

Investigate why users are hitting errors. **Read [`docs/Triaging Gate Errors.md`](../../docs/Triaging%20Gate%20Errors.md) first** — it has the project ids, paths, the boot handshake, the failure-point table, the timezone/retry traps, and the methodology. This command is the operational sequence; the doc is the wisdom. Default to **investigate + report**; only write code if the user asked for a fix.

`$ARGUMENTS` may carry `[version] [timeframe]`. Resolve:
- **version** = `$1`, else the newest `app_version` seen in Mixpanel (or `app/project.godot` `config/version`).
- **timeframe** = `$2` (`today`/`yesterday`/`Nd`), else last 2 days. Remember Mixpanel reports in ~UTC+7; server logs are UTC — anchor with `ssh thegates date -u` before correlating.

## Phase 1 — Mixpanel (what / how many / who)
Tools: `mcp__claude_ai_Mixpanel_EU__*`, project_id `3024833`, event `error`.
1. Errors by `app_version` over the timeframe — confirm the target version dominates.
2. For the target version: breakdown by `msg`, by `$os`, and total **and** unique-user counts per day/hour.
3. **[CHECK]** State the shape: N events / M unique users, OS split, msg split. Note retry inflation (events ≫ logs).

## Phase 2 — Server logs (the real crash detail)
`ssh thegates`; logs at `the-gates-backend/staticfiles/logs/<gate>/log__<UTC>.txt` (one per renderer session; header carries `app_version`/`os`/`gate`/`renderer`/`sandboxed`).
1. List only the logs in the timeframe (UTC-adjusted): `find "$BASE" -name "log__<UTC-date>*.txt"`. Drop anything older than the version.
2. **Correlate** the log set to Phase-1 counts (macOS/Windows usually map ~1:1; Linux is retry-inflated). If the GPU/OS split matches Mixpanel, you have the right logs.
3. **[CHECK]** Confirm you're reading the right window — verify a couple of logs' header `app_version` matches the target.

## Phase 3 — Read against the boot handshake (NOT error-grep)
For each distinct log, classify by **furthest boot milestone + max `frames_drawn` + how it ends** (script in the doc). Map each to the failure-point table. Key rule: the gate starts only at `frames_drawn>2` (`first_frame`); `Gate crashed on bootup` = process died before that. Separately understand each cohort (Wayland-suspend, llvmpipe, device-mem `-2`, fd-exhaustion, ZMQ 10106, MoltenVK, stuck-in-engage). Don't bucket "no error" as "fine".

## Phase 4 — Map to code
Trace each confirmed cause to its file (table in the doc: `process_checker.gd`, `renderer_manager.gd`, `renderer_lifecycle.cpp`, `display_server_wayland.cpp`, `sandbox/linux/`). State *where* it fails and *why*, with evidence (log line + code line).

## Phase 5 — Report (and reproduce only if it helps)
- Output a **DEBUG REPORT**: symptom, root cause(s) per cohort, evidence, status (fixed/open), and which version introduced/affected it.
- If a Linux/Wayland dev box is available and the bug is reproducible there: build the renderer (`python tools/build.py renderer`; `chown bin` if root-owned), run the [[Autotest Harness]] with a cold cache, and confirm `[AUTOTEST-FIRST-FRAME]` vs `[AUTOTEST-NOT-RESPONDING]`. **Be honest if the hardware can't stage the bug** (fast GPU can't trigger the Wayland suspend; constrained VRAM needed for device-mem).
- If asked to fix: follow the repo's required-reading rules before editing (`docs/GDScript Style Guide` + `Event Architecture` for `app/`; `godot/notes/C++ Style Guide` + `Custom Godot Fork`/`Custom Godot Module` for `godot/`), keep the diff minimal, and verify by build + autotest.

## Non-negotiables
- "Found"/"verified" = checked the real artifact (the log lines, the `frames_drawn`, the autotest marker), not a proxy count.
- Don't be too literal: most failures have no error string. Read the whole boot, line by line.
- Scope the time window tightly; correlate events↔users↔logs; account for the UTC/UTC+7 offset.
- A shipped fix is not a working fix — compare the failure signature before vs after the version landed.
