---
tags: [deployment, release]
---

# Release and Deployment

How a built TheGates reaches users. This is the "how it fits together" reference;
the **step-by-step runbook is the `/publish` command** (`.claude/commands/publish.md`).
See [[Renderer Process]] and [[Gate Format and Lifecycle]] for why renderers ship
the way they do, and [[Build System]] for how the binaries are built.

## Who ships what (per platform, per machine)

There is no single release machine — each OS's artifacts are built (and signed) on
that OS.

| Built on | Ships | How |
|----------|-------|-----|
| Linux box | Linux + Windows launchers, Flathub | `/publish` Steps 0–7 (docker build containers → `build_release.py` → Flathub PR) |
| A Mac | macOS launcher | `/publish` "macOS release" section (`build_macos.py` → `build_release.py`) |
| Each OS | that OS's renderers (4.3 + 4.5) | built on the matching machine, uploaded to the renderer server |

The Windows launcher zip is repackaged on the Linux box (existing `TheGates.exe` + a
fresh `.pck`); the Windows and macOS **renderers** still need their own machines.

## Renderer delivery — bundled vs downloaded (load-bearing)

Decided by `app/scripts/renderer/renderer_executable.gd`:

- The **current** Godot version's renderer ships **with the launcher** — bundled in
  the macOS `.app` (`Contents/Frameworks/Renderer-godot_v<ver>.universal`) or
  alongside the launcher executable on Linux/Windows. The launcher downloads it only
  if the bundled file is missing.
- **Non-current** versions (e.g. an old 4.3 gate) are **download-only** — fetched
  lazily from the renderer server and cached under `user://`.

**Consequence:** a renderer code change reaches *current-version* users **only by
re-shipping the launcher** with the new renderer baked in — uploading a server zip
does nothing for them. Older download-only renderers (4.3) reach users purely via
the server upload. On a renderer-side release, refresh **both** to keep parity.

## Servers and endpoints

The launcher's API base is **`https://app.thegates.io`** (`app/resources/api_settings.tres`,
`remote_url`).

| Purpose | Endpoint |
|---------|----------|
| Upload a build | `POST https://app.thegates.io/api/upload_build` (header `X-API-Key`, key in `deployment/upload_api.key`) |
| Launcher download ("latest") | `https://thegates.io/downloads/<platform>-latest` → serves `TheGates_<OS>_<ver>.zip` |
| Renderer download | `https://app.thegates.io/api/download_renderer/<platform>-<godot_version>` (e.g. `…/macos-4.5`) |
| Renderer files on disk | `ssh thegates@188.245.188.59` (user `thegates`) → `~/projects/the-gates-backend/staticfiles/builds/renderers/` |

> **GOTCHA — `app.thegates.io` ≠ `thegates.io`.** `app.thegates.io` is the Django
> backend (uploads + the `download_renderer` API). `thegates.io` is the marketing
> site/SPA — `https://thegates.io/api/download_renderer/…` returns an HTML page (and
> a misleading `200`), not the file. Verify renderers against **`app.thegates.io`**.
> The one exception is `thegates.io/downloads/<platform>-latest`, which *does* serve
> the launcher zip.
>
> The bare `ssh thegates` host alias exists only on the Linux release box; from a Mac
> the same server is the IP host already in `~/.ssh/config` (`thegates@188.245.188.59`),
> connecting as user `thegates`.

## `deployment/` scripts

| Script | Role |
|--------|------|
| `build_release.py` | Orchestrator: export → compress → upload, per host OS. `--renderer-release` (Linux only) verifies the bundled renderer matches the freshly-built one and skips the cross-built Windows zip. |
| `export_project.py` | Runs the editor binary headless to `--import` then `--export-release` the host platform's preset from `app/export_presets.cfg`. |
| `compress_build_macos.py` · `compress_build_windows.py` · `compress_builds_linux.py` | Per-OS packagers → `TheGates_<OS>_<ver>.zip`. The Linux/Windows ones share `build_zip.py` and carry a renderer-staleness guard. |
| `build_zip.py` | Shared zip mechanics (entry list → versioned zip). |
| `renderer_config.py` | Single source of truth for renderer naming + current Godot version — reads `app/resources/renderer_executable.tres`. Never hardcode renderer filenames. |
| `stage_renderer.py` | From one freshly-built renderer binary, makes the server zip (`<platform>-<ver>.zip`) **and** bundles it into the app build (current version only) so the two can't diverge. |
| `patch_windows_manifest.py` | Re-injects the `RT_MANIFEST` the Godot exporter drops, so the Windows broker can set up AppContainer. |
| `upload_build.py` | Multipart `POST` of a zip to `/api/upload_build`. |

## macOS universal build

`python godot/tools/macos/build_macos.py` runs four compiles (launcher + renderer ×
arm64 + Intel via `tools/build.py`), `lipo`s each pair into a universal binary, bakes
the launcher into the `.app` template's `MacOS/` and the renderer into its
`Frameworks/`, and writes the export template `godot/bin/macos.zip` that
`build_release.py` then exports from. `--renderer-only` builds just the renderer (for
download-only branches like `tg-4.3`), emitting `bin/Renderer-godot_v<ver>.universal`.
See [[Build System]].

## Verifying a release (don't trust exit codes)

"Done" means you checked the real artifact, not that a script exited `0`:

- Upload returned `HTTP 201` and the script printed `==> Done.`
- The launcher: `thegates.io/downloads/<platform>-latest` serves `TheGates_<OS>_<ver>.zip`
  with a byte size matching the uploaded zip.
- A renderer: `app.thegates.io/api/download_renderer/<platform>-<ver>` serves a zip
  whose bytes (sha256) match what you built — and, for a code change, unzip it and
  `grep` the binary for a marker string from the diff.
