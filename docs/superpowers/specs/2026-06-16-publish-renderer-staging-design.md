# Publish pipeline: renderer bundle staging + staleness guard

**Date:** 2026-06-16
**Status:** Design approved, pending spec review → implementation plan

## Problem

The `/publish` pipeline has two unrelated paths for the renderer binary:

1. **Server path** (Step 4): build renderer → zip → `scp` to `…/builds/renderers/` (the download path; 4.3 gates always download, 4.5 falls back here).
2. **Bundle path** (Step 5): `export_project.py` exports the launcher; `compress_builds_*.py` zips `TheGates.x86_64` + `renderer/` into `TheGates_<OS>_<ver>.zip`. **Nothing refreshes `AppBuilds/<OS>/renderer/`.**

For a renderer-side release these paths diverge silently: in 1.0.4, the new renderer reached the server, but the bundle kept the May-25 (buggy) renderer. It was caught only by a manual md5 check. The 1.0.0–1.0.3 releases were launcher-side, so the stale bundle never mattered — which is exactly why the gap went unnoticed.

## Goal

Make it structurally impossible to ship a stale bundled renderer:
- The bundled renderer is always byte-identical to the freshly-built renderer that also goes to the server (one binary, one staging step).
- A renderer-side release that didn't stage the bundle **fails loudly** instead of shipping stale.
- The cross-built Windows/macOS zips on a Linux host (whose renderers can't be rebuilt there) are **skipped + flagged**, not shipped stale.

Non-goal: detecting drift on launcher-only releases (the renderer is untouched and trusted from the last renderer release). No version tags or marker files on the renderer — a renderer's identity is its *content*, not the launcher's app version.

## Design

Three pieces. All renderer-bundle behavior is gated on `RENDERER_RELEASE` (the flag the pipeline already computes in Step 0.3 from the godot diff). **Launcher-only releases (`RENDERER_RELEASE=no`) do none of this** — no staging, no guard, bundle untouched.

### 1. `deployment/stage_renderer.py` (new) — the single staging entrypoint

The only thing that writes a renderer into the app bundle, and it produces the server zip from the same binary so they can't diverge.

```
python deployment/stage_renderer.py --built <path> --godot-version <4.3|4.5> \
    [--platform linux|windows|macos]   # default: current host (platform.system())
    [--app-builds <dir>]               # default: per-OS AppBuilds path (mirror build_release.py)
    [--server-zip-dir <dir>]           # default: godot/bin
```

Behavior:
1. Read `app/resources/renderer_executable.tres` for `current_godot_version` and the per-platform filename pattern (`linux="renderer/Renderer-godot_v%s.x86_64"`, etc.) — single source of truth, no hardcoded names.
2. Sanity-check `--built`: exists, non-trivial size, contains the `RENDERER-START` string (it's actually a renderer).
3. Produce the **server zip** `<server-zip-dir>/<platform>-<godot-version>.zip` containing the renderer entry named `Renderer-godot_v<v>.<ext>`.
4. **If `--godot-version == current_godot_version`** (the only version that's bundled): copy `--built` → `<app-builds>/<OS>/renderer/Renderer-godot_v<v>.<ext>`. Non-current (4.3) is download-only → server zip only.

No marker file is written.

### 2. Compress guard (`compress_builds_{linux,windows,macos}.py` gain `--renderer-release`)

When `--renderer-release` is passed, for each bundle the script is about to zip:
- **Host-platform bundle** (e.g. Linux dir on a Linux host): the bundled renderer must be byte-identical (md5) to the fresh build output (`godot/bin/godot.<host>.template_release.renderer.x86_64`, the current-version build). Mismatch, or build output absent → **FAIL** ("renderer not staged for this release; run stage_renderer.py"). This is the safety net that catches a skipped staging step (the original bug).
- **Non-host-platform bundle** (Windows/macOS dir on a Linux host): **SKIP that zip + print `[STALE-RENDERER] <OS> …` flag** — its renderer can't be built here. `build_release.py` already uploads only zips that exist, so a skipped zip is simply not published.

Without `--renderer-release`: no renderer checks at all (launcher-only release).

### 3. Wiring

- `build_release.py`: add `--renderer-release` (forwarded to the compress script). Pass the build-output path so compress can do the host comparison.
- `publish.md`:
  - **Step 4** (only runs when `RENDERER_RELEASE=yes`): for each built renderer, call `stage_renderer.py` (replaces the manual rename + zip). 4.5 → bundle + server zip; 4.3 → server zip. Then `scp` the server zips (unchanged).
  - **Step 5**: pass `--renderer-release` to `build_release.py` when `RENDERER_RELEASE=yes`.
  - Document the skip-and-build-on-its-own-machine workflow for Windows/macOS renderer-side releases.

## Consequence (accepted)

For a renderer-side release, Windows/macOS are released from their **own machines** (their `/publish` builds renderer + launcher + bundle together), not cross-built on Linux. The Linux `/publish` produces only the Linux zip and flags the rest.

## Scope

- **In:** Linux + Windows bundle layout (`AppBuilds/<OS>/renderer/`). This is the gap that bit, and the host/cross-built case the pipeline runs today.
- **Extension point (not now):** macOS `.app` layout differs (renderer lives in `Contents/Frameworks` per the `macos_framework` pattern). `stage_renderer.py` should drive its placement from the `renderer_executable.tres` pattern; wire the macOS path when a macOS renderer-side release is done on a Mac.

## Testing

No existing deployment test harness, so add a standalone `deployment/test_stage_renderer.py`:
- `stage_renderer.py` against the real 4.5 build → asserts the bundle copy is byte-identical and the server zip contains the correctly-named renderer.
- Guard: passes when bundle == build output; **FAILs** when they differ (simulated stale bundle) or the build output is missing; **SKIPs + flags** a non-host bundle.
- Documented manual end-to-end: stage the real 4.5 renderer, run compress `--renderer-release`, confirm the Linux zip is produced and the Windows zip is skipped + flagged.

## Backfill

None required: launcher-only releases don't check the bundle, and the next renderer-side release stages fresh. No marker to seed.
