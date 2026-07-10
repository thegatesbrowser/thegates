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
- [x] Hard renderer crashes upload no server log — **diagnosed and fixed 2026-07-10** (Linux box,
      unreleased). Detected crashes (dead process) DID upload once per session — event≫log counts
      are just the `logs_sent` latch (~17 bootup-crash sessions ↔ ~18 uploads over 14 days). The
      real loss is the *undetected* class: an alive renderer stuck before first frame (museum
      error-spam, Wayland suspend) fired no `not_responding`, no Mixpanel event, no upload —
      invisible in both datasets (Digit's museum hang). Closed: (1) 30s boot timeout detects
      alive-but-stuck boots; (2) teardown uploads when the renderer died unnoticed or was stuck
      past a 10s grace (`died_unnoticed` / `exited_before_first_frame`); (3) window close flushes
      in-flight uploads (≤3s). Uploads tail-capped at 1 MB (Django's 2.5 MB body limit would
      reject spam logs); header gained `reason` / `uptime_sec` / `first_frame` / `process_running`
      / `log_bytes`. **Expect Mixpanel error counts to RISE post-release** (new "Gate boot timed
      out" events = new visibility, not regression). Regression net:
      `python godot/tools/run-sandbox-test.py crash-upload`. Ships with the next launcher release
      (GDScript only, no engine rebuild). Consider hardening the server too:
      `logs.py` decodes strict UTF-8 (one bad byte → 500, log lost) — write bytes instead.
