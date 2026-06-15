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

## Machine layout (matches the deployment scripts' assumptions)
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
- **4.5:** `./run_build_image.sh renderer-release` → `godot/bin/godot.linuxbsd.template_release.renderer.x86_64` → copy to `Renderer-godot_v4.5.x86_64` → `zip linux-4.5.zip Renderer-godot_v4.5.x86_64`.
- **4.3:** `git -C godot checkout tg-4.3` (carries the cherry-picked fix) → `BUILD_NAME=4.3 ./run_build_image.sh renderer-release` → `Renderer-godot_v4.3.x86_64` → `linux-4.3.zip`. Then `git -C godot checkout tg-4.5`.
- **[CRITICAL CHECK]** before upload: `unzip -l` each zip shows the expected `Renderer-godot_v4.{3,5}.x86_64`, and the `scp` target path is correct. Then upload to `thegates:…/renderers/`.
- Upload: `scp linux-4.{3,5}.zip thegates:/home/thegates/projects/the-gates-backend/staticfiles/builds/renderers/`
- **VERIFY:** `/api/download_renderer/linux-4.5` and `…/linux-4.3` (via `thegates.io`) serve the new zips (sha match).
- **FLAG (cannot do from this box):** `macos-4.{3,5}.zip` and `windows-4.{3,5}.zip` need their own machines. Print a checklist for handling them; do not claim they're done.

## Step 5 — Launcher release to app.thegates.io  ⚠ IRREVERSIBLE
- **[CRITICAL CHECK]** This publishes to all users (Linux + Windows auto-update; macOS unchanged). The pipeline also packages a Windows zip reusing the existing `TheGates.exe` + a fresh pck. Confirm the scope is right (version, platforms) and log the blast radius, then run it.
- `python deployment/build_release.py`  (export → compress → upload)
- **VERIFY:** `Uploaded TheGates_Linux_<ver>.zip: HTTP 201` AND `…Windows…: HTTP 201` AND `==> Done.` Then unzip the published `…Linux_<ver>.zip` from `/media/common/Projects/thegates-folder/AppBuilds/Linux/` and confirm `TheGates.x86_64` has the fix marker and `renderer/Renderer-godot_v4.5.x86_64` is bundled.

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

## Non-negotiables
- Verify+report every step; STOP only on failed verification, never to ask permission to continue a green run.
- "Done"/"verified" = you checked the real artifact (the HTTP 201, the published zip's contents, the green CI), not that a command exited 0. Several scripts here pipe through `tail`, which masks the real exit code — read the actual output.
- Never `git add -A`; stage intended files only.
- Background long builds and watch for the chromium-sandbox compile + final link; a release build is ~8 min.
