---
tags: [debugging, mixpanel, logs, runbook, analytics]
---

# Triaging Gate Errors (Mixpanel → server logs → code)

How to answer "users are hitting errors on version X" end to end: find which errors and how many, pull the real renderer logs, read them against the boot handshake, map to code, and (if you have a Linux box) reproduce. This is the runbook behind the `/triage-errors` command.

The golden rule, learned the hard way: **don't grep logs for error strings and bucket the rest as "ran ok."** Most gate failures have *no error line at all* — a silent death, a hang, a sandbox kill, a compositor suspend. Read each log against what a healthy boot looks like and work out *what worked and what didn't*, line by line.

## The three data sources

1. **Mixpanel** — the `error` event. Tells you *what, how many, who, which version, which OS*. Counts only; no crash detail.
2. **Server-side renderer logs** — the full verbose renderer output, uploaded on every failure. This is where the actual cause lives.
3. **The code** — the boot handshake in [[Renderer Process]] / `renderer_lifecycle.cpp`, the watchdog in `process_checker.gd`. Tells you how to *interpret* where a log stopped.

---

## Step 1 — Mixpanel: what / how many / who

Project: **TheGates, project_id `3024833`** (EU instance — use the `mcp__claude_ai_Mixpanel_EU__*` tools). `Get-Business-Context` may lack scope; just `Get-Projects` and use the id directly.

The event is **`error`**. Useful properties:

| Property | Meaning |
|---|---|
| `app_version` / `app_version_code` | launcher version, e.g. `1.0.3` (code = `major*10000 + minor*100 + patch`) |
| `msg` | the watchdog verdict — `Gate crashed on bootup`, `Gate crashed on heartbeat`, `Gate is not responding` |
| `$os` | `Windows` / `Linux` / `macOS` |
| `$distinct_id` | unique user — use for true scope |
| `mp_country_code`, `$city` | geo |

Build queries with `Run-Query` (report_type `insights`; call `Get-Query-Schema` once for the full `report` shape). Standard cuts:

- **Errors by version** — table, metric `error` total, breakdown `app_version`, last N days.
- **One version by msg** — table, filter `app_version` equals `X`, breakdown `msg`.
- **By OS** — add filter `msg` equals `Gate crashed on bootup`, breakdown `$os`.
- **Timeline / users** — line chart, unit `hour`/`day`, metrics: `error` total **and** `error` unique.

### Two traps that will mislead you

- **Timezone.** Mixpanel reports in the **project tz (~UTC+7**, the owner's tz); the **server and log filenames are UTC**. So Mixpanel "today" ≈ UTC yesterday-evening onward. Anchor with `ssh thegates date -u` and offset before correlating.
- **Retry inflation.** One failed gate emits **many** `error` events (the watchdog re-checks) but uploads **one** log per renderer session. So event counts ≫ log counts, badly on Linux. Use **unique users** for real scope; expect ~N logs for a much larger event count.

---

## Step 2 — Server logs: the actual crash detail

Every `not_responding`/bootup failure POSTs the full renderer log to `https://app.thegates.io/api/send_logs?url=<gate>` (launcher side: `renderer_logger.gd::send_logs`, fired by `gate_events.not_responding`). The Django backend (`the-gates-backend/src/api/logs.py`) writes it on the Hetzner box:

```
ssh thegates       # 188.245.188.59, user root
BASE=/home/thegates/projects/the-gates-backend/staticfiles/logs
# layout: $BASE/<gate-host>/<gate-path>/log__<UTC-YYYY_MM_DD__HH_MM_SS>.txt
```

- One file per renderer session. Filenames are **UTC**.
- Each upload now opens with a header (added 2026-06): `app_version`, `os`, `gate`, `renderer` (filename → 4.3 vs 4.5), `sandboxed`. Use it to confirm the version instead of guessing.
- **Scope to the right day(s).** Drop logs that predate the version under investigation — old logs muddy the categorization. `find "$BASE" -name "log__2026_06_15*.txt"`.

The renderer was given `--verbose` since 1.0.1, which is *why* these logs are rich.

---

## Step 3 — Read logs against the boot handshake

The renderer boot is a long handshake (`godot/modules/the_gates/renderer/renderer_lifecycle.cpp`). A healthy boot prints these markers **in order**:

```
[PHASE] servers_modules_done → display_server_create_start/done → audio_init_*
[RENDERER-START]
[PHASE] command_sync_connected → filehandle_exchanged → input_sync_connected → external_texture_imported
[NETWORK-BROKER] ...
[LOCKDOWN-ATTEMPT] → [RENDERER-LOCKED] → [PHASE] lockdown_done
[RENDERER-READY]
[DEVICE-MEM] used=.. MB (textures=.. buffers=..)
[ITER] 0 frames_drawn=1 ... vram=..MB
[ITER] 1 frames_drawn=2 ...
[ITER] 2 frames_drawn=3 ...        ← drawn>2 → renderer sends "first_frame"
```

**The one fact that explains most failures:** the gate only *starts* when the renderer draws **3 frames** and sends `first_frame` (`frames_drawn > 2`). If the max `frames_drawn` in a log is ≤ 2, the gate never started. So:

- `Gate crashed on bootup` (watchdog `process_checker.gd`, `BOOTUP_CHECK_SEC=3`) = **the renderer process died before `first_frame`**. The watchdog only fires on *process death*, not slowness — a slow-but-alive renderer just makes the user wait.
- `Gate crashed on heartbeat` / `Gate is not responding` = it rendered (sent `first_frame`), then stopped heart-beating (heartbeats only start after `first_frame`).

### Classify every log by *furthest milestone + max frames_drawn + how it ends*

```bash
for f in <logs>; do
  far=exec
  grep -qa display_server_create_done "$f" && far=display_server
  grep -qa '\[RENDERER-START\]' "$f" && far=engage
  grep -qa external_texture_imported "$f" && far=texture_ok
  grep -qa '\[RENDERER-READY\]' "$f" && far=READY
  drawn=$(grep -aoE 'frames_drawn=[0-9]+' "$f" | grep -oE '[0-9]+' | sort -n | tail -1)
  last=$(grep -avE '^[[:space:]]*$' "$f" | tail -1)
  echo "$f far=$far drawn=${drawn:-0} :: $last"
done
```

### Failure-point → cause table

| Symptom in the log | Cause | Status |
|---|---|---|
| 0 lines / ends before `[RENDERER-START]` | died in engine init (display server, Vulkan device, role-less Wayland surface) or instant exec fail | rare; instrument more |
| stops at `waiting for filehandle`, no `filehandle_exchanged` | `recv_filehandle` failed — texture-handle IPC | open |
| reaches engage, no `external_texture_imported` | Vulkan external-memory import failed (suspected Intel/Mesa) | open |
| `[RENDERER-READY]`, `frames_drawn`≤1, `Suspending. Reason: timeout` | invisible Wayland surface gets no frame callbacks → backend suspends → render loop halts (slow boots only) | **fixed** (`can_any_window_draw` → true under `TG_RENDERER`, commit `f8ec136`) |
| `[RENDERER-READY]`, `frames_drawn`=0, device `llvmpipe`, 30s+ to READY | no GPU → CPU software Vulkan, unusably slow | open (recommend fail-fast) |
| `Can't create buffer ... error -2` / `VK_ERROR_OUT_OF_DEVICE_MEMORY`, spins | GPU VRAM exhaustion (heavy gates, esp 4.3 renderer). Check `[DEVICE-MEM]` + `vram=` climb | open |
| `VK_ERROR_OUT_OF_HOST_MEMORY` at swapchain + `Too many open files` | file-descriptor exhaustion | **fixed** 1.0.3 (broker raises `RLIMIT_NOFILE`) |
| `libzmq err.cpp:356`, error `10106` (`WSAEPROVIDERFAILEDINIT`) | Winsock init blocked — Windows network-isolation sandbox | open (Windows) |
| `VK_ERROR_INVALID_SHADER_NV`, `mvk-*` / CAMetalLayer | MoltenVK can't compile shaders to Metal | open (macOS) |

Read the `Using Device #N: ...` line for the GPU model (gives the VRAM ceiling without an API call). `PulseAudio`/`ALSA`/`wayland` = Linux, `WASAPI` = Windows, `mvk-info`/`CAMetalLayer` = macOS — but **don't trust string-matching for platform**; "Suspending. Reason: timeout" is a *Wayland* (Linux) line even if other tokens look Windows.

---

## Step 4 — Map to code

| Concern | File |
|---|---|
| `error` event shape | `app/scripts/api/analytics/analytics_events.gd` (`error()`), emitted via `Debug.logerr` → `Debug.error` → `analytics_sender_error.gd` |
| watchdog (bootup/heartbeat/not-responding) | `app/scripts/renderer/process_checker.gd` — `BOOTUP_CHECK_SEC=3`, fires only on process death |
| renderer spawn + the broker-bypass fallback | `app/scripts/renderer/renderer_manager.gd` (`OS.execute_with_pipe` when `Sandbox.create()` is null — skips isolation **and** the fd-limit fix; logs a warning + tags `sandboxed:false`) |
| log upload | `app/scripts/renderer/renderer_logger.gd` |
| boot handshake, markers, `first_frame` at `drawn>2`, heartbeat | `godot/modules/the_gates/renderer/renderer_lifecycle.cpp` |
| Wayland render-loop gate | `godot/platform/linuxbsd/wayland/display_server_wayland.cpp` (`can_any_window_draw`) + `godot/main/main.cpp` draw gate |
| Linux sandbox (seccomp, lockdown, NOFILE) | `godot/modules/the_gates/sandbox/linux/` |

Background: [[Renderer Process]], [[Two-Process Model]], [[Gate Cycle]], [[External Texture Sharing]].

---

## Step 5 — Reproduce + verify (on a Linux/Wayland dev box)

```bash
cd godot && python tools/build.py renderer       # debug renderer; ~12s incremental
```

- **Build-env trap:** `godot/bin` can be **root-owned** from a `/publish` Docker build → `Permission denied`. Fix: `sudo chown -R "$USER:$USER" godot/bin`. (Root cause fixed: `thegates-build-containers/run_build_image.sh` now runs the container with `--user`.)
- **Compile-check one file without a full build:** pull its command from `compile_commands.json` and run `clang++ ... -fsyntax-only`; add `-DTG_RENDERER` to exercise the renderer-only paths.

Run a gate through the [[Autotest Harness]] (drives the real launcher + renderer, prints the markers):

```bash
godot/bin/godot.linuxbsd.editor.dev.x86_64.llvm --path app/ -- \
  --autotest --gate-url https://thegates.io/worlds/tutorial.gate --autotest-timeout 30
# watch: [AUTOTEST-FIRST-FRAME] (started) vs [AUTOTEST-NOT-RESPONDING] (failed)
# renderer log: ~/.local/share/godot/app_userdata/TheGates/logs/<gate>/log.txt
```

- **Renderer selection is automatic:** a *debug* launcher opening a *current-version (4.5)* gate spawns the local `godot.linuxbsd.template_debug.dev.renderer.x86_64.llvm` and never downloads — so your fresh build is used. A 4.3 gate downloads the 4.3 renderer.
- **Force a cold boot:** `rm -rf ~/.local/share/godot/app_userdata/TheGates/gates_storage/<gate>` (and `~/.cache/mesa_shader_cache` for the driver cache). The Godot shader cache **persists** across runs, so cold = first-visit only (verified: cold 7.4s/77 misses vs warm 3.1s/330 hits).
- **Repro is hardware-bound.** Some bugs need the *failing* hardware: the Wayland suspend only triggers when a slow GPU / software `llvmpipe` stalls the boot >1s (a fast GPU keeps committing frames and never suspends — it can't stage the bug). VRAM exhaustion needs a constrained GPU. If you can't reproduce, **say so** — the real-user logs are the failing case, and "ship the fix and watch the signal disappear" is a valid verification.

---

## Methodology (the part that actually matters)

- **Not binary.** "Error vs no error" is the wrong axis. Understand each case: how far it got, what worked, where it stopped.
- **Don't over-attribute.** A 28k-line log is not a 3-second bootup crash — it ran, then degraded. Match the *symptom* to the *watchdog verdict* via `frames_drawn`, not by eyeballing the last error.
- **Correlate counts.** Events ≠ users ≠ logs (retry inflation). When macOS shows 2 events and you find 2 logs, that 1:1 is signal; a 23-vs-4 Linux split is retries, not 19 missing logs.
- **A shipped fix is not a working fix.** Compare the failure *signature* before vs after the version landed. The 1.0.3 NOFILE fix really did kill the `Too many open files` crash (gone in every post-fix log) — but it *exposed* the next layer (the Wayland suspend). "Fixed one layer, hit the next" is the normal shape.
- **Verify against ground truth.** Real logs, real runs, real `frames_drawn` — never a proxy number on your defaults.

## Related
- [[Renderer Process]] · [[Autotest Harness]] · [[Gotchas and Conventions]] · [[Custom Godot Module]]
