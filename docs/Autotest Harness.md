---
tags: [testing, autotest, sandbox, launcher]
---

# Autotest Harness

The project's de-facto integration test runner. Drives the launcher through a scripted gate-open session, then asserts on the resulting renderer log + sandbox diagnostic block. This is what you reach for instead of writing one-off launcher scripts.

Two pieces, one contract:

| Piece | Lives at | Role |
|---|---|---|
| **Driver** | `app/scripts/autotest.gd` | In-app GDScript that parses `--autotest-*` args, opens the gate, schedules re-opens, measures main-thread responsiveness, and self-quits on a thread-based deadline. Prints `[AUTOTEST-*]` tagged lines. |
| **Runner** | `godot/tools/run-sandbox-test.sh` (Linux/macOS) and `godot/tools/run-sandbox-test.ps1` (Windows) | Builds (optional), launches the launcher with `--autotest`, waits, then greps both the launcher log and the renderer's `SANDBOX-DIAG-BEGIN/END` block. Emits `[VERIFY-OK]` or `[VERIFY-FAIL <reason>]` with a numeric exit code. |

The driver is wired into `app/scripts/app.gd::_ready()` via `Autotest.is_enabled()` — when no `--autotest*` arg is on the command line, the harness is dormant and adds zero runtime cost.

## When to reach for it

- You changed anything in `app/scripts/renderer/` (`renderer_manager.gd`, `command_sync.gd`, `input_sync.gd`, `render_result.gd`, `process_checker.gd`).
- You changed anything under `godot/modules/the_gates/` — the sandbox, the IPC primitives, or the external-texture wrapper.
- You changed the gate-cycle code path in `app/scripts/app.gd` or `gate_events.gd` (see [[Gate Cycle]]).
- You bumped the `godot/` submodule and want to confirm the renderer still boots, spawns, and obeys the sandbox.

What it *doesn't* cover: launcher UI behaviour (menus, URL bar, settings), `.gate` download error paths, anything that doesn't terminate in a renderer process being spawned. Those still need manual testing.

## Run it

```bash
# Linux / macOS — full positive verification:
godot/tools/run-sandbox-test.sh

# Same, but rebuild launcher + renderer first:
godot/tools/run-sandbox-test.sh --build

# Multi-cycle: open the gate, then re-open it twice more (3 total spawns):
godot/tools/run-sandbox-test.sh --cycles 2 --cycle-delay 4

# Different gate:
godot/tools/run-sandbox-test.sh --gate-url https://thegates.io/worlds/foo.gate

# Negative: forced lower_token failure, expect renderer aborts pre-READY:
godot/tools/run-sandbox-test.sh --mode negative-fail-closed

# Negative: forced verify_binary failure, expect broker refuses to spawn:
godot/tools/run-sandbox-test.sh --mode negative-signature
```

PowerShell mirror is `godot/tools/run-sandbox-test.ps1` with the same flags, same `[VERIFY-*]` tags, and the same exit codes.

Results land in `${TMPDIR:-/tmp}/thegates-autotest/` (overridable with `--results-dir`): `launcher.log`, `launcher.err`, `renderer.log` (copy of the in-userdata renderer log for this run), `verify.json` (the parsed sandbox diag block), and `broker_policy.json` (if the broker wrote one).

## CLI flags (runner side)

| Flag | Default | Notes |
|---|---|---|
| `--gate-url URL` | `https://thegates.io/worlds/tutorial.gate` | Gate to load. Passed through to the launcher as `--gate-url`. |
| `--timeout SEC` | 25 | Launcher self-quit budget. Wrapped by an outer wait budget of `TIMEOUT + 25 s` before the runner kills `-9`. |
| `--cycles N` | 0 | Extra re-opens after the first gate spawn. `cycles=2` → 3 total spawns. |
| `--cycle-delay SEC` | 5.0 | Wall-clock delay between cycles (after a gate is entered). |
| `--build` | off | Rebuilds via `godot/tools/build.py launcher` and `... renderer` before launching. |
| `--no-sandbox` | off | With `--build`, passes `tg_sandbox=no` for faster iteration. **Do not use for sandbox verification runs** — it builds a no-sandbox renderer. |
| `--launcher-bin PATH` / `--renderer-bin PATH` | dev binary in `godot/bin/` | Override which binary to run. The renderer override is diagnostic; the launcher actually resolves the renderer via `app/resources/renderer_executable.tres`. |
| `--verbose` | off | Passes `--verbose` to the launcher. |
| `--results-dir PATH` | `${TMPDIR}/thegates-autotest` | Where logs + `verify.json` + `broker_policy.json` are dropped. |
| `--mode MODE` | `default` | `default` \| `negative-fail-closed` \| `negative-signature`. |

## CLI flags (driver side, if invoking the launcher directly)

The driver reads these from `OS.get_cmdline_user_args()` (args after `--`), falling back to `OS.get_cmdline_args()`. The runner script always uses the `--` form.

```bash
godot/bin/godot.linuxbsd.editor.dev.x86_64.llvm \
  --path app/ \
  -- \
  --autotest \
  --gate-url https://thegates.io/worlds/tutorial.gate \
  --autotest-timeout 25 \
  --autotest-cycles 2 \
  --autotest-cycle-delay 5.0
```

| Flag | Notes |
|---|---|
| `--autotest` | Bare switch. Sets `enabled=true`. The harness also self-enables if `--gate-url` or `--autotest-timeout` is present. |
| `--gate-url URL` | If non-empty, the harness defers one frame (so autoloads' `_ready` hooks have run) then calls `Navigation.open(url)`. |
| `--autotest-timeout SEC` | Wall-clock deadline. When it fires, prints `[AUTOTEST-TIMEOUT]` + `[AUTOTEST-EXIT] reason=timeout` and calls `get_tree().quit(0)`. |
| `--autotest-cycles N` | Extra re-opens beyond the first gate-enter. After every `gate_entered`, if there's a cycle budget left, schedules an `open_gate_emit(url)` after `--autotest-cycle-delay`. |
| `--autotest-cycle-delay SEC` | Per-cycle re-open delay. Default 5.0. |

## The tagged stdout language

The harness's only "API" to the runner is its stdout. Every line the runner cares about is `[AUTOTEST-<NAME>] <kv-pairs>`:

| Tag | Emitted when | Fields |
|---|---|---|
| `[AUTOTEST-START]` | `Autotest.start()` runs | `args=<dict>`, `ms=<ticks_msec>` |
| `[AUTOTEST-OPEN]` | One-shot, one frame after start | `<gate_url>`, `ms=<ticks_msec>` |
| `[AUTOTEST-GATE-ENTERED]` | Every `GateEvents.gate_entered` signal | `cycle=<1-based>`, `ms=<ticks>`, `since_reopen=<ms or -1>`, `max_tick_gap=<ms>` |
| `[AUTOTEST-CYCLE-SCHEDULED]` | After a gate-enter, if cycles remain | `next_cycle=<N>`, `delay=<sec>`, `url=<url>` |
| `[AUTOTEST-CYCLE-REOPEN]` | Re-open timer fires | `cycle=<N>`, `url=<url>`, `ms=<ticks>` |
| `[AUTOTEST-TIMEOUT]` | Deadline thread elapses | `elapsed=<sec>` |
| `[AUTOTEST-EXIT]` | Last line before `quit(0)` | `reason=timeout` (currently the only reason) |

Treat these as a **stable contract** — the runner script greps for these literal strings to count cycles and decide pass/fail. Don't rename them lightly; if you must, update both runner scripts and `verify.json` consumers in the same commit.

## What the runner verifies (default mode)

Walk-through of the assertions, in order. Each failure has a distinct exit code (see next section).

1. **Launcher exited cleanly inside the wait budget.** Otherwise kill `-9` and fail with `launcher_no_exit`.
2. **A fresh renderer log exists.** Found by `find` on `~/.local/share/godot/app_userdata/TheGates/logs/` with `mtime >= LAUNCH_START_EPOCH`. Fail: `renderer_never_started`.
3. **`[RENDERER-START]` and `[RENDERER-READY]` markers present, in order**, with READY after START. Fail: `renderer_never_started` / `renderer_no_ready`.
4. **A `SANDBOX-DIAG-BEGIN`…`SANDBOX-DIAG-END` block** sits between START and the end of file, with JSON-parseable contents. Parsed body is saved as `verify.json`.
5. **Gate-enter count.** `grep -c [AUTOTEST-GATE-ENTERED]` from the launcher log must equal `cycles + 1`. Fail: `gate_not_entered` / `multi_gate_cycles_missing`.
6. **Main-thread responsiveness.** Every `[AUTOTEST-GATE-ENTERED]` includes `max_tick_gap=<ms>`. If any cycle's max gap exceeds **500 ms**, fail with `main_thread_frozen`. This is the invariant `verify_binary` had to be moved to a worker thread to satisfy — a 6 s SHA-256 hash on the main loop would freeze the renderer-spawn step and trip this check.
7. **`TGExternalTexture` reached** somewhere after `[RENDERER-START]` in the renderer log. Fail: `renderer_no_external_texture`.
8. **No `ERROR:` / `FATAL` / `CRASH` / `Segmentation` lines after `[RENDERER-READY]`.** Anything before READY is loader noise and ignored. Fail: `renderer_errors`.
9. **Per-gate user dir exists and is non-empty.** Path is `~/.local/share/godot/app_userdata/TheGates/gates_storage/<gate-folder>/`. Fail: `per_gate_dir_missing` / `per_gate_dir_empty`.
10. **Sandbox canaries from `verify.json`.**
    - `canaries.canary_user_dir_write` must be `"allowed"` (renderer can write its own per-gate dir).
    - `canaries.canary_sibling_gate_write` must be `"blocked"` (renderer can NOT write into a sibling gate's dir).
    - `canaries.canary_pck_read` must be `"allowed"` or one of the documented `skipped_*` reasons.
    Failures: `canary_user_dir_blocked`, `canary_sibling_gate_allowed`, `canary_pck_read_blocked`.
11. **Optional broker policy cross-check.** If `broker_policy.json` was written next to the renderer log, the integrity target it pinned must match `verify.json`'s `integrity` field, and `token_lockdown` must not be the deprecated `USER_LOCKDOWN` value.

A pass prints a single summary line:

```
[VERIFY-OK] integrity=low renderer_pid=12345 canary_file=allowed canary_user_dir=allowed canary_sibling=blocked canary_pck=allowed per_gate_files=7 broker_xcheck=ok build=release_debug launcher_exit=0
  results=/tmp/thegates-autotest
```

## Exit codes

The runner returns 0 on `[VERIFY-OK]` and a unique non-zero per failure mode:

| Code | Reason |
|---|---|
| 0 | OK |
| 10 | `launcher_bin_missing` / `renderer_bin_missing` |
| 11 / 12 | `build_launcher` / `build_renderer` (when `--build` was passed) |
| 13 | `launcher_no_exit` (process did not terminate within `timeout + 25 s`) |
| 14 | `renderer_never_started` (no log file, or no `[RENDERER-START]`) |
| 15 | `renderer_no_ready` (START seen, READY not) |
| 16 / 17 | `no_diag_block` / `diag_parse_failed` |
| 18 | `gate_not_entered` (no `[AUTOTEST-GATE-ENTERED]` in launcher log) |
| 19 | `renderer_no_external_texture` |
| 20 | `renderer_errors` (any ERROR/FATAL/CRASH/Segmentation after READY) |
| 21 / 22 | `per_gate_dir_empty` / `per_gate_dir_missing` |
| 23 | `canary_user_dir_blocked` (sandbox over-locked: can't write own user://) |
| 24 | `canary_sibling_gate_allowed` (cross-gate isolation broken) |
| 25 | `canary_pck_read_blocked` |
| 26 / 27 / 28 | `broker_policy_parse_failed` / `broker_renderer_integrity_mismatch` / `broker_token_lockdown_regression` |
| 29 | `negative_fail_closed_not_aborted` (renderer reached READY when it shouldn't have) |
| 30 | `negative_signature_renderer_started` (broker spawned a renderer when it shouldn't have) |
| 31 | `multi_gate_cycles_missing` (got fewer `[AUTOTEST-GATE-ENTERED]` than `cycles + 1`) |
| 32 | `main_thread_frozen` (`max_tick_gap` > 500 ms during a gate switch) |

Codes are stable. CI grepping for a specific code (e.g. "did we regress the sibling-gate canary?") is a supported pattern.

## Modes

### `default`
Positive verification. The full assertion walk above.

### `negative-fail-closed`
Sets env `TG_SANDBOX_FORCE_FAIL=1`. The renderer's `Sandbox::lower_token()` is wired to fail-closed when this is set. **Expectation:** `[RENDERER-START]` appears but `[RENDERER-READY]` does not (the renderer aborts before READY). If READY shows up after START → fail with `negative_fail_closed_not_aborted` (code 29). Otherwise pass.

### `negative-signature`
Sets env `TG_SIGNATURE_FORCE_FAIL=1`. The launcher's `Sandbox.verify_binary()` is wired to fail when this is set, so the broker should refuse to spawn at all. **Expectation:** no renderer log file appears with `mtime >= LAUNCH_START_EPOCH`. If a log is found → fail with `negative_signature_renderer_started` (code 30). Otherwise pass.

Both negative modes are useful in CI for confirming the failure paths are still wired up — a positive `default` run alone can't tell you whether the sandbox is doing its job or whether the assertion was just trivially passing.

## Multi-gate cycles + the responsiveness invariant

The `--cycles N` flag is what catches regressions in the gate-cycle teardown path. The expansion is:

```
[AUTOTEST-START]
  └─ [AUTOTEST-OPEN] (one-shot, +1 frame after start)
        └─ ... renderer spawns ...
              └─ [AUTOTEST-GATE-ENTERED] cycle=1 since_reopen=-1
                    └─ if cycles > 0: [AUTOTEST-CYCLE-SCHEDULED] next_cycle=2
                          └─ (cycle_delay seconds elapse)
                                └─ [AUTOTEST-CYCLE-REOPEN] cycle=2
                                      └─ gate_events.open_gate_emit(url)
                                            └─ ... full Gate Cycle teardown + respawn ...
                                                  └─ [AUTOTEST-GATE-ENTERED] cycle=2 since_reopen=<ms>
                                                        └─ if cycles > 1: schedule next
                                                              └─ ...
```

Every time, the driver also samples `Time.get_ticks_msec()` from `node.get_tree().process_frame` to record the **largest gap between frames during that cycle** as `max_tick_gap=<ms>`. A blocking call on the main loop (the classic regression: a synchronous SHA-256 hash inside `verify_binary`) produces a multi-second gap that fails the 500 ms threshold and trips exit code 32.

This is the load-bearing detail: with `--cycles 2` and `--autotest-timeout 35` you exercise the full `clear_current_gate` → `switch_scene` → `RendererManager._exit_tree` → new sandbox → new `spawn_target` → `gate_entered` path twice in one process. See [[Gate Cycle]] for the event sequence the runner is implicitly asserting on.

## Pitfalls

- **`SceneTreeTimer` and child-of-world Timer nodes can't fire the deadline.** `switch_scene` queue_free's the world subtree every cycle; timers anchored to scenes freed mid-tick get their delta accumulator out of phase, and long timers (10 s+) silently miss. The driver uses a **`Thread` that `OS.delay_msec`s and then `call_deferred`s `quit`** for exactly this reason. Any future "fire on wall time across cycles" need follows the same pattern — see the multi-line comment in `Autotest.start()`.
- **`--no-sandbox` builds a no-sandbox renderer.** Combining `--build --no-sandbox` is for fast iteration on non-sandbox code only. **Never** use it for a verification run — every canary check will pass for the wrong reason.
- **The runner's "fresh log" detection is mtime-based.** If your system clock jumps backwards between launch and renderer log write (rare; happens on VMs with NTP drift), the `find -newermt` filter can skip the real log and pick up an older one. Cure: re-run after `sudo hwclock -s` or wait a second.
- **Negative modes flip env vars the sandbox reads at runtime.** They are NOT compile-time switches. Running `negative-fail-closed` against a binary built with `tg_sandbox=no` will *not* fail-closed — there's no sandbox to force-fail. Always build with the default sandbox on for negative-mode runs.
- **The `[AUTOTEST-*]` tags are a stable contract** between driver and runner. Renaming a tag without updating both `run-sandbox-test.sh` and `run-sandbox-test.ps1` silently breaks the runner's grep/awk pipelines — the launcher will look fine but the runner will report `gate_not_entered`.
- **`Autotest.is_enabled()` self-enables on `--gate-url` or `--autotest-timeout` alone.** Convenient (you can drop the bare `--autotest` switch) but means anyone who runs the launcher with `--gate-url` for non-test reasons will unexpectedly trigger the harness and self-quit. Use the bare `--autotest` switch when you mean to.

## Related

- [[Gate Cycle]] — the event sequence the runner is implicitly asserting on (especially the multi-cycle case)
- [[Renderer Process]] — what `[RENDERER-START]` / `[RENDERER-READY]` mean and where `SANDBOX-DIAG-BEGIN/END` is printed
- [[Launcher App]] — where `Autotest.start()` is wired into `app/scripts/app.gd`
- [[Gotchas and Conventions]] — `SceneTreeTimer` / multi-cycle traps and the broader convention list
- [[Build System]] — `tg_sandbox=yes/no` and the `build.py` profiles the runner shells out to
