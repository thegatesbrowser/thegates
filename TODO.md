# TODO

## Ticket-0002 rollout (NVIDIA sandbox fix) — remaining work

Context: 2026-07-09, Discord ticket-0002 (user Digit, RTX 4070 Ti, NVIDIA 580 driver, Fedora/Flathub).
Root cause: the renderer's Landlock sandbox never granted `/dev/nvidia*`, so on 580-series drivers
every Vulkan allocation made after lockdown failed as `VK_ERROR_OUT_OF_DEVICE_MEMORY` — 4.3 gates
hung in error spam, the 4.5 renderer SEGV'd (`buffer_map` on a null buffer from the transfer
worker's unchecked staging-buffer create), and glyph uploads silently failed (garbled text).
Full write-up: [[Triaging Gate Errors]] methodology; engine commits below.

### Shipped (Linux box, 2026-07-09)

- **1.0.6** — engine fix. godot `1d5ca317b7` (tg-4.5) / `e63a1a6579` (tg-master) / `8298c8bd47` (tg-4.3):
  - Landlock grants NVIDIA device nodes (Chromium's GPU-sandbox set) + `/proc/driver/nvidia`,
    Flatpak host-font mounts, user font dirs, fontconfig cache.
  - `buffer_map` null-guards its buffer; transfer worker records staging size only on successful
    create (4.3 cherry-pick drops this hunk — no transfer workers in 4.3).
  - Shipped: Linux launcher (app.thegates.io + Flathub PR #108), `linux-4.5.zip` + `linux-4.3.zip`
    server renderers (`.bak-pre-1.0.6` backups on the box).
- **1.0.7** — launcher fix (parent `9949c28`): downloaded renderers are re-extracted when the server
  zip changes (HTTP 200); previously an extracted renderer was never refreshed, so old-version
  renderer updates only reached first-time visitors. Verified against the shipped binary.
  Shipped: Linux launcher (app.thegates.io + Flathub PR #109), Windows zip (fresh pck, old exe).

### Windows machine — run `/publish`

Today's Windows 1.0.7 zip reuses the **old `TheGates.exe`** — it carries the GDScript re-extract fix
but **not** the C++ fixes (they live in the exe and the renderer binaries).

1. Pull parent `main`; godot `tg-4.5` and `tg-4.3` (fix commits above).
2. Rebuild launcher exe (`launcher-release`) and both renderers (`renderer-release`, `tg-4.3`
   checkout for the 4.3 one).
3. Stage with `deployment/stage_renderer.py`, back up then upload `windows-4.{3,5}.zip` to
   `thegates:~/projects/the-gates-backend/staticfiles/builds/renderers/`, upload the launcher zip.
4. Verify served sha via `https://app.thegates.io/api/download_renderer/windows-4.5` and `-4.3`
   (**app.**thegates.io — bare thegates.io serves the website, not the API).

### macOS machine — run `/publish` (renderer-included flow)

A server zip alone does **not** reach current-version mac users — the 4.5 renderer is baked into
the .app, so the launcher must be re-shipped. Version is already **1.0.7**; don't re-bump.

1. Pull parent `main`; godot `tg-4.5` / `tg-master` / `tg-4.3`.
2. `python godot/tools/macos/build_macos.py` (universal launcher + renderer).
3. `python deployment/build_release.py` → uploads `TheGates_MacOS_1.0.7.zip`.
4. Server renderer zips — stage 4.5 **before** building 4.3 (the 4.3 build overwrites the
   universal renderer binary): `stage_renderer.py --platform macos --godot-version 4.5`, then
   `git -C godot checkout tg-4.3 && build_macos.py --renderer-only && git -C godot checkout tg-4.5`,
   then `stage_renderer.py --platform macos --godot-version 4.3`.
5. Back up then scp `macos-4.{3,5}.zip` (`ssh thegates@188.245.188.59` — the bare `thegates`
   alias exists only on the Linux box); verify served sizes.

### Follow-ups

- [ ] Reply on ticket-0002: update to latest (Flathub publishes after the PR merge), no cache
      clearing needed, retry both world.gate and museum_of_all_things. Digit's 4070 Ti is the
      only real NVIDIA verification available — the dev box is AMD and cannot stage the bug.
- [ ] Watch Mixpanel (project `3024833`, event `error`, Linux) for versions ≥1.0.6 — the
      bootup-crash signal should disappear. Mixpanel reports ~UTC+7; server logs are UTC.


## Windows + tg-4.3 sandbox parity pass — SHIPPED 2026-07-18 (merged + pushed)

Context: the shipped Windows binaries were 54 days / a full version-line stale (last real build
2026-05-24, ~v1.0.0). A four-agent audit + a seven-agent verification pass produced the tasks
below. `win32k.sys` lockdown is explicitly OUT OF SCOPE (deferred Tier-3). Sibling-platform docs:
[[macOS Parity TODO]], [[4.3 Renderer Parity]].

Each Windows task, after implementation, must: build (`python tools/build.py launcher` + `renderer`
from `godot/`), pass `python tools/run-sandbox-test.py` (default + `negative-fail-closed` +
`negative-signature`), then its task-specific check. Then commit on `tg-4.5` and cherry-pick to
`tg-master` (mandatory branch-sync rule).

### Windows (tg-4.5 → cherry-pick tg-master)

1. **Secrets leak — filter the renderer's inherited environment.** *(shipped, verified)*
   Enable Chromium's built-in environment filter (shipped but never turned on) + swap Chrome's
   hardcoded allow-list for ours (exact Windows names + `TG_`/`VK_` prefixes). Touches
   `sandbox_win.cpp` (1 line), vendored `target_process.{h,cc}`, README fork-patch note.
   VERIFY: plant a canary secret in the launcher env; boot a gate whose script dumps
   `OS.get_environment(...)` into its writable dir; confirm the canary is ABSENT post-fix and the
   renderer still reaches `[RENDERER-READY]`; confirm negative-mode harness still passes (the `TG_`
   hooks still reach the renderer).

2. **Denial logging — see what the Windows sandbox blocks.** *(shipped, verified)*
   NOT the PolicyDiagnostic API (that reports config, not events). Log at the in-renderer
   interception thunks where a blocked file/registry op is decided and not escalated. New
   `sandbox_deny_log.{h,cpp}`; hook `filesystem_interception.cc` (`ShouldAskBroker`) +
   `registry_interception.cc` (2 sites); delete stray vendored `wprintf` debug lines; README note.
   VERIFY: the always-on boot canaries already hit both paths — run the harness, grep the uploaded
   log for `[SANDBOX-WIN-DENY]` (file + registry lines), confirm dedup (loop → one line) and
   delivery through the not-responding upload path.

3. **Crash logger — compiled + verified on Windows.** *(shipped, verified)*
   Was written but never compiled; now built with an env-gated deliberate-AV test hook, forced a
   crash, confirm `[RENDERER-CRASH] exception=0x...` reaches the uploaded log. KNOWN BOUNDARY: the
   engine's internal `CRASH_NOW` (fast-fail) bypasses this handler by Windows design — only genuine
   faults produce the marker; internal aborts still log their plain fatal message. Document once
   verified.

4. **GPU shader-cache stall — measured, no fix needed.** *(resolved by measurement)*
   The concern was that the AppContainer sandbox denies the driver's cache folder. MEASURED on a
   real boot: the sandboxed renderer attempts zero driver-cache writes and the denial logger catches
   zero cache-path denials — the GPU driver populates its cache *before* lockdown, so the sandbox
   never blocks it. No live problem, no code fix applied; the "measure first" call held. (A cold
   AMD-cache test was blocked because the driver keeps the folder locked; the warm-cache evidence is
   consistent with the pre-lockdown-caching explanation.)

### tg-4.3 (standalone branch — NOT in the tg-4.5 ↔ tg-master sync)

5. **Crash + seccomp-denial logger port.** *(shipped, verified)*
   Was entirely absent. Copy `crash_logger.{h,cpp}` + `signal_safe_log.h` verbatim from `tg-4.5`;
   patch `renderer_lifecycle.cpp` (install hook), `seccomp_policy.cpp` (denial log),
   `thirdparty/libzmq/src/thread.cpp` (SIGSYS unblock — re-apply if libzmq is re-vendored; 4.3 has
   no `CLAUDE.md` to carry that warning, so it lives in [[4.3 Renderer Parity]]).
   VERIFY: build 4.3 renderer; force a crash → `[RENDERER-CRASH]` in the log; (Linux) force a denied
   syscall → `[SECCOMP] denied syscall N` and the process keeps running.

6. **Force-Vulkan safety net + binding-arg name.** *(shipped, verified)*
   4.3's renderer didn't pin Vulkan → a D3D12-requesting gate could break texture sharing (4.3
   binaries have D3D12 compiled in). Port the ~5-line `#ifdef TG_RENDERER rendering_driver="vulkan"`
   block. Plus the cosmetic `create` binding "data" arg name.
   VERIFY: run the 4.3 renderer with `--rendering-driver d3d12`; confirm it ignores it and stays on
   Vulkan.

7. **`llvm-lib` archiver fix.** *(shipped)*
   `configure_msvc` used MSVC `lib.exe`, which fails `LNK1181` on long (260+ char) object paths
   (deep/CI checkouts); now selects `llvm-lib` like `tg-4.5`, without the `.llvm` binary rename.
   See [[4.3 Renderer Parity]].

### Deferred / documented (no code) — see [[4.3 Renderer Parity]]

- 4.3 open-file-limit, XAUTHORITY, Linux shader-cache redirect: already handled by the launcher
  (always built from 4.5) — do NOT port.
- 4.3 Wayland suspend: independently fixed on 4.3 already — do NOT stack the 4.5 override.
- macOS parity (env leak, crash-logger Mac-compile, doc fix): [[macOS Parity TODO]] — after Windows.
- `win32k.sys` lockdown: deferred (Tier-3).

### Shipped + remaining

- DONE (merged + pushed): godot `tg-4.5` (`3a1a5f0479`) mirrored to `tg-master` (`752996ab8c`),
  `tg-4.3` (`758386a516`), parent `main` (`a06c875`, godot bump).
- Pre-existing (not from this pass): the `negative-signature` self-test fails on a no-pin dev build
  (broker-side `verify_binary` force-fail path); confirm on a signed release build.
- [ ] Run the Windows `/publish` (the ticket-0002 rollout section above) to build + upload the
  rebuilt Windows binaries — ships this parity work AND closes the 54-day binary gap.
