---
description: Release a new TheGates version end to end — launcher → app.thegates.io → Flathub — with verification and confirmation gates at each step.
argument-hint: "[version] [one-line changelog]  (both optional; you'll be asked if omitted)"
---

# /publish — TheGates release pipeline

Run the TheGates release **step by step**, autonomously. After EACH step: verify
the actual artifact and print one line `[OK] <step> — <what you confirmed>`.
**STOP only on failed verification** — never to ask permission to continue a green
run. The checkpoints below are *your* verification gates, not prompts for the user:
check the real artifact, and if it's green, proceed. This is the pipeline that
shipped 1.0.2; reproduce it faithfully.

**Starting assumption:** the code fix is already committed on `godot` `tg-4.5`.
`/publish` takes it from there. `$ARGUMENTS` may carry `[version] [changelog]`.

> **On a Mac?** Steps 0–7 are the **Linux release box** (Linux + Windows launchers
> + Flathub) and can't build the macOS app. For the macOS launcher, skip to the
> **macOS release** section near the bottom — a separate, simpler flow.

## Machine layout — Linux release box (matches the deployment scripts' assumptions)
- Parent app + deployment: `/home/nordup/projects/thegates-folder/thegates` (branch `main`)
- Engine submodule: `…/thegates/godot` (dev `tg-4.5`, integration `tg-master`, legacy renderer base `tg-4.3`)
- Build container: `/home/nordup/projects/thegates-folder/thegates-build-containers` → `./run_build_image.sh <profile>` (profiles: `launcher-release`, `renderer-release`; `BUILD_NAME=4.3` for the 4.3 renderer)
- Flathub clone: `/home/nordup/programs/io.itch.nordup.TheGates` (origin = `Nordup` fork; `upstream` = `flathub`)
- Server (renderers): `ssh thegates` → `…/the-gates-backend/staticfiles/builds/renderers/`

## Checkpoint legend
Checkpoints are the agent's own verification gates, **not** user-confirmation
prompts. Verify the real artifact; if it's green, log `[OK] …` and proceed without
asking.
- **[CHECK]** — routine: verify what the step produced, then continue.
- **[CRITICAL CHECK]** — irreversible publish to all users: verify extra carefully
  and state the blast radius in the `[OK]` line, then continue.
- Any failed verification = STOP, show evidence, propose a fix. Do not proceed.
  Stopping is for **red checks only** — never to ask permission to continue a green run.

---

## Step 0 — Pre-flight (no side effects)
1. Confirm the godot fix is committed + pushed on `tg-4.5`. Note if `tg-master` is behind (cherry-pick in Step 3).
2. Resolve **version** (`$1`, else default to a patch bump of `app/project.godot`'s `config/version`) and a **one-line changelog** (`$2`, else ask). The changelog feeds the appdata note + commit messages.
3. **Renderer-change detection.** Diff the godot submodule since the currently-released pin (`git -C godot log` / `diff` against the pin in `main`'s last release commit) over renderer-affecting paths: `modules/the_gates/renderer/`, `modules/the_gates/ipc/`, `#ifdef TG_RENDERER` blocks, `drivers/vulkan/`, `servers/rendering/`. If touched → likely **renderer-side** (`RENDERER_RELEASE=yes`); if only launcher-spawn/app/GDScript code changed (e.g. `renderer_manager.gd`, `build_child_envp`) → `no`. **When ambiguous, ASK:** "Does this change alter behavior inside the gate renderer process?" (The 1.0.2 X11/shader fixes were launcher-side → `no`.)
4. Print the plan: version, changelog, `RENDERER_RELEASE`, platforms (Linux+Windows launcher via the pipeline; macOS unchanged). **[CHECK]** Confirm the plan is internally consistent (version bump is the right delta, `RENDERER_RELEASE` detection sound), then proceed.

## Step 1 — Bump version
Edit `app/project.godot` `config/version` → target version.

## Step 2 — Build the launcher (docker, gcc release)
`cd thegates-build-containers && ./run_build_image.sh launcher-release -j <cpu-2>`
- If it dies on `Permission denied` writing `bin/obj` (root-owned from a prior docker run), clean via the container, then rerun: `docker run --rm --entrypoint rm -v /home/nordup/projects/thegates-folder/thegates/godot:/the-gates tg-build -rf /the-gates/bin/obj`
- **VERIFY:** `scons: done building targets`, and `godot/bin/godot.linuxbsd.template_release.x86_64` contains the fix marker (a string/symbol from the diff) AND `SandboxLinux` symbols AND **zero** `RENDERER-START` markers (confirms it's the launcher, not a renderer). Note: release uses **gcc**; debug uses clang — that split is intentional (`tools/build.py`).

## Step 3 — Source commit (godot pin + version) on main
- Branch-sync the engine per the fork rule: cherry-pick the fix to `tg-master`; if `RENDERER_RELEASE` also cherry-pick to `tg-4.3` (STOP if it doesn't apply cleanly). Push `tg-4.5`, `tg-master` (+ `tg-4.3` if used).
- In the parent: stage **only** `godot` (pin bump) and `app/project.godot`. Two commits, matching convention: `godot: bump submodule for <changelog>` and `app: bump version to <ver>`.
- **[CHECK]** Confirm `main` is a clean fast-forward (ahead-N, behind-0), then `git push origin main`.

## Step 4 — Linux renderers (only if `RENDERER_RELEASE=yes`)
Skip entirely otherwise.
For each renderer you build, stage it with the single entrypoint (it puts the
renderer into the app bundle AND makes its server zip from the same binary):

- **4.5:** `./run_build_image.sh renderer-release` → then
  `python deployment/stage_renderer.py --built godot/bin/godot.linuxbsd.template_release.renderer.x86_64 --godot-version 4.5 --app-builds /media/common/Projects/thegates-folder/AppBuilds --server-zip-dir godot/bin`
  (produces `godot/bin/linux-4.5.zip` AND refreshes `AppBuilds/Linux/renderer/`).
- **4.3:** `git -C godot checkout tg-4.3` (carries the cherry-picked fix) → `BUILD_NAME=4.3 ./run_build_image.sh renderer-release` → then
  `python deployment/stage_renderer.py --built godot/bin/godot.linuxbsd.template_release.renderer.4.3.x86_64 --godot-version 4.3 --app-builds /media/common/Projects/thegates-folder/AppBuilds --server-zip-dir godot/bin`
  (4.3 is download-only → server zip only). Then `git -C godot checkout tg-4.5`.
- **[CRITICAL CHECK]** `unzip -l godot/bin/linux-4.{3,5}.zip` shows the expected `Renderer-godot_v4.{3,5}.x86_64`. Then `scp godot/bin/linux-4.{3,5}.zip thegates:/home/thegates/projects/the-gates-backend/staticfiles/builds/renderers/`.
- **VERIFY:** `/api/download_renderer/linux-4.5` and `…/linux-4.3` (via `thegates.io`) serve the new zips (sha match).
- **FLAG (cannot do from this box):** `macos-4.{3,5}.zip` and `windows-4.{3,5}.zip` need their own machines. Print a checklist for handling them; do not claim they're done.
  The Linux bundle renderer is now refreshed by `stage_renderer.py`; the compress guard will refuse to ship a stale Linux bundle and will skip the cross-built Windows zip. Build the Windows/macOS renderers + launchers on their own machines (their `/publish` runs stage their own bundles).

## Step 5 — Launcher release to app.thegates.io  ⚠ IRREVERSIBLE
- **[CRITICAL CHECK]** This publishes to all users (Linux + Windows auto-update; macOS unchanged). The pipeline also packages a Windows zip reusing the existing `TheGates.exe` + a fresh pck. Confirm the scope is right (version, platforms) and log the blast radius, then run it.
- `python deployment/build_release.py --renderer-release`  (export → compress → upload). The compress step now **verifies** the Linux bundle renderer matches the freshly-built one and **skips the cross-built Windows zip** (stale on a Linux host) — Windows is released from its own machine. Omit `--renderer-release` for launcher-only releases.
- **VERIFY:** `Uploaded TheGates_Linux_<ver>.zip: HTTP 201` AND `==> Done.` (with `--renderer-release` the Windows zip is skipped — no Windows upload; on a launcher-only release you also get `…Windows…: HTTP 201`). Then unzip the published `…Linux_<ver>.zip` from `/media/common/Projects/thegates-folder/AppBuilds/Linux/` and confirm `TheGates.x86_64` has the fix marker and `renderer/Renderer-godot_v4.5.x86_64` is bundled.

## Step 6 — Flathub  ⚠ IRREVERSIBLE on merge
- Confirm `https://thegates.io/downloads/linux-latest` now serves `TheGates_Linux_<ver>.zip` (content-disposition filename + content-length match the uploaded zip). If not, the server hasn't promoted it — STOP.
- In the Flathub clone: sync first — `git fetch upstream && git checkout master && git merge --ff-only upstream/master`. Then `echo y | python create_release.py --release-description "<changelog>"` (downloads linux-latest, sets sha256, bumps manifest `dest-filename` + appdata note, branches `release-<ver>`, commits, pushes to the fork).
- **VERIFY the diff** (`git diff master..release-<ver>`): `dest-filename` → `TheGates_Linux_<ver>.zip`, `sha256` matches `sha256sum` of the uploaded zip, appdata `<release version="<ver>">` added.
- `gh pr create --repo flathub/io.itch.nordup.TheGates --base master --head Nordup:release-<ver> --title "update to <ver> - <changelog>" --body "<what changed>"`
- **Wait for the `builds/x86_64` check** to go green: poll `gh pr checks <#> --repo flathub/io.itch.nordup.TheGates`. (zsh gotcha: do NOT name a shell var `status` — it's read-only.) If it FAILS, STOP and show the build log; do not merge.
- **[CRITICAL CHECK]** Merge publishes to all Flatpak users — proceed only once the `builds/x86_64` check is green. Then `gh pr merge <#> --repo flathub/io.itch.nordup.TheGates --merge` (keep the release branch, matching prior releases).
- **Sync the fork master to flathub:** `git fetch upstream && git checkout master && git merge --ff-only upstream/master && git push origin master`.

## Step 7 — Report
Print a table of what shipped where (Linux launcher, Windows launcher, Flathub; Linux renderers if `RENDERER_RELEASE`), the version, and the sha. Explicitly list what is **NOT** covered this run: macOS launcher (needs a Mac), and mac/win renderers if it was a renderer-side change. Surface every STOP/flag the user must follow up on.

---

## macOS release — run on a Mac (independent of Steps 0–7)

Steps 0–7 run on the Linux box and ship Linux + Windows + Flathub; they **cannot**
build the macOS app. The macOS launcher is a separate, simpler flow you run **on a
Mac** — the "needs a Mac" hand-off Step 7 flags. Same discipline: verify the real
artifact after each step, log `[OK] …`, stop only on a red check.

### Mac machine layout
- Parent + deployment: `/Users/nordup/Projects/thegates-folder/thegates` (branch `main`)
- Builds dir: `/Users/nordup/Projects/thegates-folder/AppBuilds`
- Build: `python godot/tools/macos/build_macos.py` — runs 4 compiles (launcher+renderer × arm64+x86_64), lipos each pair to a universal, bakes launcher → `.app/Contents/MacOS` and renderer → `.app/Contents/Frameworks/Renderer-godot_v<ver>.universal`, and writes the export template `godot/bin/macos.zip`. `--renderer-only` builds just the renderer (for download-only branches like `tg-4.3`).
- **Renderer delivery (the load-bearing fact):** for the **current** godot version the renderer is **bundled** in the app and used as-is; the launcher downloads a renderer only for **non-current** versions (e.g. 4.3). ⇒ a renderer change reaches mac users **only by re-shipping the launcher** with the new renderer baked in — uploading a server zip does nothing for the current version.

### mac-Step 0 — Pre-flight (no side effects)
Pull parent + all three engine branches (`tg-4.5`, `tg-master`, `tg-4.3`); fast-forward the submodule to the pin in `main`. Version comes from `app/project.godot` (already bumped by the Linux release — don't re-bump). Pick scope:
- **Launcher-only** (usual parity ship): no renderer-side engine change since the last mac build → skip mac-Step 1.
- **Renderer-included**: renderer engine code changed and mac users should get it (e.g. new logs/instrumentation). Diff the submodule since the last mac build over `modules/the_gates/renderer/`, `modules/the_gates/ipc/`, `#ifdef TG_RENDERER`, `drivers/`, `servers/rendering/` (ignore `platform/linuxbsd|windows`). If touched → do mac-Step 1 first.

### mac-Step 1 — Build the universal template (renderer-included only)
`python godot/tools/macos/build_macos.py` (background it; launcher compiles are near-instant when no launcher C++ changed — the renderer recompiles the changed files, then 4 relinks + 2 lipos).
- **VERIFY:** `godot/bin/macos.zip` freshly written AND `godot/bin/godot.macos.template_release.renderer.universal` contains a marker string from the diff (e.g. a new log tag) via `grep -c`. Skip entirely for a launcher-only ship.

### mac-Step 2 — Export + upload to app.thegates.io  ⚠ IRREVERSIBLE
- **[CRITICAL CHECK]** Publishes the macOS launcher to all mac users. Log the blast radius, then run.
- `python deployment/build_release.py` (export → compress → upload; the `--renderer-release` flag is a Linux-only no-op here).
- **VERIFY:** `Uploaded TheGates_MacOS_<ver>.zip: HTTP 201` AND `==> Done.`. Then `curl -s -r 0-0 -D - -o /dev/null https://thegates.io/downloads/macos-latest` → `filename="TheGates_MacOS_<ver>.zip"` with a `content-range` total equal to the local zip's byte size.
- **Same-version note:** re-publishing the *same* version with a new bundled renderer won't re-update users already on it (auto-update is version-keyed); it reaches everyone updating from an older version + fresh installs. To force it to current-version users, bump the version.

### mac-Step 3 — Refresh the renderer server zips (renderer-included releases)
The bundled renderer (mac-Step 1) covers the **current** version for fresh launchers, but the server also serves renderers for download: the current version as a fallback when the bundle is missing, and **non-current versions (4.3) that are download-only** — a 4.3 gate on macOS has *no* bundled renderer, so it must come from the server. Keep both in parity with Linux, which refreshes them on every renderer release.

- **Server (from a Mac):** `ssh thegates@188.245.188.59` (user `thegates`; the bare `thegates` alias only exists on the Linux box — from a Mac use the IP host already in `~/.ssh/config`). Renderers live in `~/projects/the-gates-backend/staticfiles/builds/renderers/`, served at `https://thegates.io/api/download_renderer/macos-<ver>`.
- **4.5 (current):** stage from the renderer you just built —
  `python deployment/stage_renderer.py --built godot/bin/godot.macos.template_release.renderer.universal --godot-version 4.5 --platform macos --app-builds /Users/nordup/Projects/thegates-folder/AppBuilds --server-zip-dir godot/bin` → `godot/bin/macos-4.5.zip`.
- **4.3 (download-only):** build it on its branch, then stage —
  `git -C godot checkout tg-4.3 && python godot/tools/macos/build_macos.py --renderer-only && git -C godot checkout tg-4.5`, then
  `python deployment/stage_renderer.py --built godot/bin/Renderer-godot_v4.3.universal --godot-version 4.3 --platform macos --app-builds /Users/nordup/Projects/thegates-folder/AppBuilds --server-zip-dir godot/bin` → `godot/bin/macos-4.3.zip`.
  Stage 4.5 **before** building 4.3 — the 4.3 build overwrites `…renderer.universal`.
- **VERIFY each zip:** `unzip -p godot/bin/macos-<ver>.zip Renderer-godot_v<ver>.universal | grep -ac <marker>` (a new log tag) > 0 and `lipo -info` shows `x86_64 arm64`.
- **Back up, then upload** (mirrors the Linux `.bak-pre-<ver>` convention):
  `ssh thegates@188.245.188.59 'cd ~/projects/the-gates-backend/staticfiles/builds/renderers && cp macos-4.3.zip macos-4.3.zip.bak-pre-<ver>; cp macos-4.5.zip macos-4.5.zip.bak-pre-<ver>'`, then
  `scp godot/bin/macos-4.3.zip godot/bin/macos-4.5.zip thegates@188.245.188.59:~/projects/the-gates-backend/staticfiles/builds/renderers/`.
- **VERIFY served:** `curl -s -r 0-0 -D - -o /dev/null https://thegates.io/api/download_renderer/macos-4.5` (and `…/macos-4.3`) → `content-range` byte total equals the uploaded zip.

## Non-negotiables
- Verify+report every step; STOP only on failed verification, never to ask permission to continue a green run.
- "Done"/"verified" = you checked the real artifact (the HTTP 201, the published zip's contents, the green CI), not that a command exited 0. Several scripts here pipe through `tail`, which masks the real exit code — read the actual output.
- Never `git add -A`; stage intended files only.
- Background long builds and watch for the chromium-sandbox compile + final link; a release build is ~8 min.
