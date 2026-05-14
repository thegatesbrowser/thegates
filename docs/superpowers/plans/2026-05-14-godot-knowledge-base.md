# Godot fork knowledge base Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a self-contained agent-entry contract (`godot/CLAUDE.md`) and move six fork-specific notes from `thegates/docs/` to `godot/notes/`, while migrating the Obsidian vault root up to `thegates/` so wikilinks span both folders.

**Architecture:** Two-repo (parent + git submodule) docs reorganization. Fork-specific notes travel with the submodule; project-overview and app-side notes stay in parent. Obsidian vault is unified at the parent root so wikilinks resolve across both. Two commits at the end: one in the godot submodule, one in parent thegates. The submodule-pointer bump in parent is left for the user's normal ship process — this plan does NOT bump it.

**Tech Stack:** Markdown, Obsidian (vault), git (submodule), Windows PowerShell + Bash via WSL.

**Spec reference:** `docs/superpowers/specs/2026-05-14-godot-knowledge-base-design.md`

---

### Task 1: Vault root migration

**Files:**
- Copy: `thegates/docs/.obsidian/workspace.json` → `thegates/.obsidian/workspace.json`
- Delete: `thegates/docs/.obsidian/` (entire folder)

- [ ] **Step 1: Verify current vault state**

Run:
```bash
ls "C:/Users/Nordup/Documents/Projects/thegates/.obsidian/"
ls "C:/Users/Nordup/Documents/Projects/thegates/docs/.obsidian/"
```

Expected: parent `.obsidian/` has `app.json`, `appearance.json`, `core-plugins.json` (no `workspace.json`). `docs/.obsidian/` has those four plus `workspace.json`.

If parent `.obsidian/` is missing entirely, stop and ask the user — the orphan we relied on may have been cleaned up.

- [ ] **Step 2: Copy workspace.json up to the parent .obsidian/**

Run:
```bash
cp "C:/Users/Nordup/Documents/Projects/thegates/docs/.obsidian/workspace.json" "C:/Users/Nordup/Documents/Projects/thegates/.obsidian/workspace.json"
```

Expected: command returns silently.

- [ ] **Step 3: Verify the copy**

Run:
```bash
ls "C:/Users/Nordup/Documents/Projects/thegates/.obsidian/"
```

Expected: now shows `app.json`, `appearance.json`, `core-plugins.json`, `workspace.json`.

- [ ] **Step 4: Delete the docs/.obsidian/ folder**

Run:
```bash
rm -rf "C:/Users/Nordup/Documents/Projects/thegates/docs/.obsidian/"
```

Expected: command returns silently.

- [ ] **Step 5: Verify the deletion**

Run:
```bash
ls -la "C:/Users/Nordup/Documents/Projects/thegates/docs/" | grep obsidian || echo "no .obsidian in docs/ — good"
```

Expected: `no .obsidian in docs/ — good`.

- [ ] **Step 6: Tell the user to re-open the vault**

This is a USER action — do not skip. Print this message to the user verbatim:

> "Vault config moved up to `thegates/.obsidian/`. Please open Obsidian and: File → Open vault → Open folder as vault → select `C:/Users/Nordup/Documents/Projects/thegates/`. Confirm the existing notes are visible and wikilinks resolve (click any wikilink in `docs/Index.md`). Reply 'vault opened' when done."

Wait for the user's confirmation before continuing. The `.obsidian/` folders are untracked by git — no commit needed for this task.

---

### Task 2: Create godot/notes/ and move 6 notes

**Files:**
- Create: `godot/notes/` (directory)
- Move: `thegates/docs/C++ Style Guide.md` → `godot/notes/C++ Style Guide.md`
- Move: `thegates/docs/Custom Godot Fork.md` → `godot/notes/Custom Godot Fork.md`
- Move: `thegates/docs/Custom Godot Module.md` → `godot/notes/Custom Godot Module.md`
- Move: `thegates/docs/External Texture Sharing.md` → `godot/notes/External Texture Sharing.md`
- Move: `thegates/docs/Platform Differences.md` → `godot/notes/Platform Differences.md`
- Move: `thegates/docs/Build System.md` → `godot/notes/Build System.md`

Important: the moves cross two git repos (parent thegates and the godot submodule). `git mv` from one repo into another is not supported — git treats it as delete-on-one-side + add-on-the-other. We'll do the move with regular filesystem ops and let each repo handle its own staging in Task 8 and Task 9.

- [ ] **Step 1: Create the godot/notes/ directory**

Run:
```bash
mkdir -p "C:/Users/Nordup/Documents/Projects/thegates/godot/notes"
```

Expected: command returns silently.

- [ ] **Step 2: Move all six files**

Run:
```bash
cd "C:/Users/Nordup/Documents/Projects/thegates"
mv "docs/C++ Style Guide.md"          "godot/notes/C++ Style Guide.md"
mv "docs/Custom Godot Fork.md"        "godot/notes/Custom Godot Fork.md"
mv "docs/Custom Godot Module.md"      "godot/notes/Custom Godot Module.md"
mv "docs/External Texture Sharing.md" "godot/notes/External Texture Sharing.md"
mv "docs/Platform Differences.md"     "godot/notes/Platform Differences.md"
mv "docs/Build System.md"             "godot/notes/Build System.md"
```

Expected: all six commands return silently.

- [ ] **Step 3: Verify the moves**

Run:
```bash
ls "C:/Users/Nordup/Documents/Projects/thegates/godot/notes/"
```

Expected output: lists all six `.md` files.

Run:
```bash
ls "C:/Users/Nordup/Documents/Projects/thegates/docs/" | grep -E "(Custom Godot|External Texture|Platform Differences|C\+\+ Style|Build System)" || echo "no moved files left in docs/ — good"
```

Expected: `no moved files left in docs/ — good`.

- [ ] **Step 4: Verify both git repos see the changes**

Run:
```bash
cd "C:/Users/Nordup/Documents/Projects/thegates" && git status -s | grep -E "(Custom Godot|External Texture|Platform Differences|C\+\+ Style|Build System)"
```

Expected: six lines starting with `D` (deleted) for each moved file under `docs/`.

Run:
```bash
cd "C:/Users/Nordup/Documents/Projects/thegates/godot" && git status -s notes/
```

Expected: six lines starting with `??` (untracked) for each new file under `notes/`.

No commit yet — Task 8 and Task 9 will do the commits.

---

### Task 3: Write godot/notes/Index.md

**Files:**
- Create: `godot/notes/Index.md`

- [ ] **Step 1: Write the file**

Write `C:/Users/Nordup/Documents/Projects/thegates/godot/notes/Index.md` with this exact content:

````markdown
---
tags: [meta, moc, fork]
---

# Notes Index — godot/ fork

The starting point for engine-side work. Every fork-specific note is reachable from here.

## Start here

- [[Custom Godot Fork]] — what's modified vs. upstream Godot 4.5 (the surgical diff)
- [[Custom Godot Module]] — `modules/the_gates/`: the only new C++ module

## The two-process architecture (engine side)

- [[External Texture Sharing]] — how a Vulkan-rendered framebuffer in one process becomes a `Texture2D` in another, with no CPU copy

## Per-OS

- [[Platform Differences]] — Windows handles vs. macOS IOSurface vs. Linux file descriptors

## Style and patterns (mandatory before writing C++)

- [[C++ Style Guide]] — the rules for this folder. Mostly defers to upstream Godot's docs + pre-commit.

## Build

- [[Build System]] — `scons` flags, build variants, output binaries

## Broader project context

For the launcher app, gate format, two-process overview, GDScript style, and event architecture, open the parent `thegates/` checkout and start at [`../../docs/Index.md`](../../docs/Index.md). The whole tree is one Obsidian vault — wikilinks like [[Two-Process Model]] resolve across folders.

## Related external resources

- [Godot 4.5 source docs](https://docs.godotengine.org/en/stable/) — for anything in this tree we *haven't* modified
- [Godot contributing guidelines](https://contributing.godotengine.org/en/latest/engine/guidelines/code_style.html) — what [[C++ Style Guide]] defers to
- [Vulkan external memory spec (Win32)](https://registry.khronos.org/vulkan/specs/latest/man/html/VK_KHR_external_memory_win32.html) — the mechanism behind [[External Texture Sharing]] on Windows
````

- [ ] **Step 2: Verify the file exists and has the expected first line**

Run:
```bash
head -3 "C:/Users/Nordup/Documents/Projects/thegates/godot/notes/Index.md"
```

Expected: shows the frontmatter `---` / `tags: [meta, moc, fork]` / `---`.

---

### Task 4: Write godot/CLAUDE.md

**Files:**
- Create: `godot/CLAUDE.md`

- [ ] **Step 1: Write the file**

Write `C:/Users/Nordup/Documents/Projects/thegates/godot/CLAUDE.md` with this exact content:

````markdown
# Contract for AI agents working on the godot/ fork

If you are an AI agent (Claude Code, Codex, Cursor, Copilot, anything) about to touch this submodule, **read this file first**. The fork-specific docs in [`notes/`](./notes/) are short and load-bearing — read them before writing code.

## What this project is

TheGates is a 3D web browser. Two cooperating Godot processes — a launcher (the browser UI) and a sandboxable renderer (the world being visited) — share a Vulkan texture via OS-level external memory. This submodule is the engine they both run on: upstream Godot 4.5 with a small, surgical set of fork-specific changes.

If you have the parent `thegates/` checkout, the higher-level architecture and the launcher (`app/`) side of the project are documented in `../docs/`. If you only have this submodule, the [`notes/`](./notes/) folder here covers everything needed to work on the engine.

## What this fork is

Upstream Godot 4.5 plus:

1. A new SCons option `tg_renderer=False` that defines the `TG_RENDERER` macro.
2. Surgical `#ifdef TG_RENDERER` blocks in `main/main.cpp` and the per-OS display servers (`platform/windows/`, `platform/macos/`, `platform/linuxbsd/`). These make the renderer build a headless, sandboxable Godot whose frames are shared with the launcher process.
3. A new module: `modules/the_gates/` — IPC primitives (named-pipe transport, command + input sync, external texture wrapper) and Linux seccomp sandboxing.
4. New methods on `RenderingDevice`: `external_texture_create`, `external_texture_import`, `screen_copy`. Implemented for Vulkan and Metal.

Anything else in this tree is upstream — see [Godot's docs](https://docs.godotengine.org/en/stable/) for it.

## Mandatory reading before writing code

Read these in order. ~10 minutes total.

1. [`notes/Custom Godot Fork.md`](./notes/Custom%20Godot%20Fork.md) — the surgical-diff catalog
2. [`notes/Custom Godot Module.md`](./notes/Custom%20Godot%20Module.md) — `modules/the_gates/` walkthrough
3. [`notes/External Texture Sharing.md`](./notes/External%20Texture%20Sharing.md) — the Vulkan shared-memory architecture
4. [`notes/Platform Differences.md`](./notes/Platform%20Differences.md) — three-way OS branches
5. [`notes/Build System.md`](./notes/Build%20System.md) — scons flags and build variants
6. [`notes/C++ Style Guide.md`](./notes/C%2B%2B%20Style%20Guide.md) — required reading before any C++ change

For broader project context (launcher app, gate format, two-process model, GDScript style, event architecture), open the parent `thegates/` checkout and start at [`../CLAUDE.md`](../CLAUDE.md) / [`../docs/Index.md`](../docs/Index.md).

## Non-negotiable rules

### C++ (this repo)

- **Match upstream Godot 4.5 exactly.** This is a fork; we don't have our own C++ style. Run `pre-commit` (configured in `.pre-commit-config.yaml`) — it enforces clang-format 20.1, clang-tidy, header guards, copyright headers, codespell.
- **Fork-specific changes go in exactly two places:** `modules/the_gates/`, or `#ifdef TG_RENDERER` blocks in upstream files. Nothing else. If your change doesn't fit one of those, it probably belongs upstream — discuss before merging.
- **Renderer is hardcoded to Vulkan.** `--rendering-driver d3d12` is silently ignored in `TG_RENDERER` builds. Don't propose D3D12 fixes for the renderer without first patching `main/main.cpp`'s hardcoded line. See [`notes/Custom Godot Fork.md`](./notes/Custom%20Godot%20Fork.md).

Full rules: [`notes/C++ Style Guide.md`](./notes/C%2B%2B%20Style%20Guide.md).

### Architecture

- **Don't break the IPC protocol.** Old renderer binaries cached on user machines call the existing command names with the existing arg shapes. Renaming/breaking commands silently breaks any gate built against an older renderer.
- **The launcher allocates the shared texture; the renderer imports it.** Counterintuitive direction — don't "fix" it without reading [`notes/External Texture Sharing.md`](./notes/External%20Texture%20Sharing.md) first.

## Build & run

Build commands are in the parent [`README.md`](../README.md). They change; trust the README, not memory.

Day-to-day:
- Editor / launcher binary: `scons -j$(nproc) dev_build=yes tg_renderer=no compiledb=yes use_llvm=yes linker=lld disable_exceptions=no`
- Renderer binary: same with `tg_renderer=yes target=template_debug`

Output binaries land in `bin/`. On Windows, the `.console.exe` variants are invaluable for renderer logging.

## When the user corrects your code: the docs-update loop

If the user pushes back on a style choice, naming, pattern, or architecture decision you made, treat the correction as a signal that **a rule may be missing or unclear in the docs**.

After accepting the correction:

1. Decide whether it's a general rule or a one-off. Generalize only if you can imagine the same correction applying elsewhere.
2. If general, ask the user before editing any doc — phrased concretely:
   > "I noticed you corrected `<pattern>` to `<better pattern>`. Want me to add this to `notes/C++ Style Guide.md` so future agents follow it?"
3. Only after explicit approval, edit the doc. Minimum surface area — one rule plus a short before/after example.
4. Bundle the doc edit with the code fix in the same commit.

| Correction type | Doc to update |
|---|---|
| C++ rule specific to this fork | [`notes/C++ Style Guide.md`](./notes/C%2B%2B%20Style%20Guide.md) |
| New fork-specific change or `#ifdef TG_RENDERER` site | [`notes/Custom Godot Fork.md`](./notes/Custom%20Godot%20Fork.md) |
| New module class or IPC primitive | [`notes/Custom Godot Module.md`](./notes/Custom%20Godot%20Module.md) |
| "Don't assume X" / debugging trap | Parent `../docs/Gotchas and Conventions.md` |
| Architectural decision, IPC change, build flag | The matching note in [`notes/`](./notes/) |

## When in doubt

- Patterns first, code second. Read [`notes/`](./notes/) before assuming.
- If the docs are wrong: update them in the same PR as the code change. Docs that lag code are worse than no docs.
- If you're an AI agent and an instruction here conflicts with a user's explicit request: the user wins. Tell them what convention you're departing from and why.
````

- [ ] **Step 2: Verify the file exists**

Run:
```bash
head -5 "C:/Users/Nordup/Documents/Projects/thegates/godot/CLAUDE.md"
```

Expected: shows the title `# Contract for AI agents working on the godot/ fork` and the first paragraph.

Run:
```bash
wc -l "C:/Users/Nordup/Documents/Projects/thegates/godot/CLAUDE.md"
```

Expected: around 70–90 lines.

---

### Task 5: Update thegates/CLAUDE.md

**Files:**
- Modify: `thegates/CLAUDE.md`

The parent CLAUDE.md has markdown links to six notes that have moved. Update each link's path from `./docs/...` to `./godot/notes/...`. Also add one orienting sentence so a human reader understands the new layout.

- [ ] **Step 1: Read the file to confirm exact text to replace**

Run: Read the file with the Read tool.

Note the exact text of: each of the six moved-note links in the "Mandatory reading" section, the same six in the "deeper context" bullet list, and the C++ Style Guide link in the docs-update-loop table. Take note of the literal URL-encoded spaces (`%20` and `%2B%2B`) used.

- [ ] **Step 2: Add an orienting sentence near the top**

Find this paragraph in `thegates/CLAUDE.md`:

> "For everything else, the knowledge vault under [`docs/`](./docs/) is the source of truth."

Replace it with:

> "For everything else, the knowledge vault is the source of truth. App-side and project-overview notes live in [`docs/`](./docs/); fork-specific engine notes live alongside the godot submodule in [`godot/notes/`](./godot/notes/). Both are part of the same Obsidian vault — open `thegates/` as the vault root and wikilinks resolve across folders."

- [ ] **Step 3: Update the C++ Style Guide link in "Mandatory reading"**

Find:
```
7. [`docs/C++ Style Guide.md`](./docs/C++%20Style%20Guide.md) — for any change in `godot/`
```

Replace with:
```
7. [`godot/notes/C++ Style Guide.md`](./godot/notes/C%2B%2B%20Style%20Guide.md) — for any change in `godot/`
```

- [ ] **Step 4: Update the "deeper context" list**

Find this bullet list paragraph:

```
- [`docs/Two-Process Model.md`](./docs/Two-Process%20Model.md), [`docs/External Texture Sharing.md`](./docs/External%20Texture%20Sharing.md), [`docs/Renderer Process.md`](./docs/Renderer%20Process.md), [`docs/Launcher App.md`](./docs/Launcher%20App.md), [`docs/Custom Godot Fork.md`](./docs/Custom%20Godot%20Fork.md), [`docs/Custom Godot Module.md`](./docs/Custom%20Godot%20Module.md), [`docs/Build System.md`](./docs/Build%20System.md), [`docs/Platform Differences.md`](./docs/Platform%20Differences.md), [`docs/Gate Format and Lifecycle.md`](./docs/Gate%20Format%20and%20Lifecycle.md), [`docs/Repository Layout.md`](./docs/Repository%20Layout.md)
```

Replace with:

```
- [`docs/Two-Process Model.md`](./docs/Two-Process%20Model.md), [`godot/notes/External Texture Sharing.md`](./godot/notes/External%20Texture%20Sharing.md), [`docs/Renderer Process.md`](./docs/Renderer%20Process.md), [`docs/Launcher App.md`](./docs/Launcher%20App.md), [`godot/notes/Custom Godot Fork.md`](./godot/notes/Custom%20Godot%20Fork.md), [`godot/notes/Custom Godot Module.md`](./godot/notes/Custom%20Godot%20Module.md), [`godot/notes/Build System.md`](./godot/notes/Build%20System.md), [`godot/notes/Platform Differences.md`](./godot/notes/Platform%20Differences.md), [`docs/Gate Format and Lifecycle.md`](./docs/Gate%20Format%20and%20Lifecycle.md), [`docs/Repository Layout.md`](./docs/Repository%20Layout.md)
```

- [ ] **Step 5: Update the docs-update-loop table**

Find:

```
| C++ rule specific to the fork (not upstream) | [C++ Style Guide](./docs/C++%20Style%20Guide.md) |
```

Replace with:

```
| C++ rule specific to the fork (not upstream) | [C++ Style Guide](./godot/notes/C%2B%2B%20Style%20Guide.md) |
```

- [ ] **Step 6: Verify all expected replacements are in place**

Run:
```bash
grep -n "godot/notes/" "C:/Users/Nordup/Documents/Projects/thegates/CLAUDE.md"
```

Expected: at least 7 matches (one orienting sentence + six link updates + one table entry; the C++ Style Guide is two separate links).

Run:
```bash
grep -n "docs/C++ Style Guide\|docs/Custom Godot\|docs/External Texture Sharing\|docs/Platform Differences\|docs/Build System" "C:/Users/Nordup/Documents/Projects/thegates/CLAUDE.md"
```

Expected: no matches. (If matches appear, a stale link slipped through — re-read the file and find it.)

---

### Task 6: Update thegates/docs/Index.md

**Files:**
- Modify: `thegates/docs/Index.md`

- [ ] **Step 1: Read the file to confirm exact text**

Run: Read the file with the Read tool. Find the line `## Start here` and confirm it follows the intro line `The starting point. Every note in the vault is reachable from here.`.

- [ ] **Step 2: Insert a short note about the new folder**

Find this line:
```
The starting point. Every note in the vault is reachable from here.
```

Replace with:
```
The starting point. Every note in the vault is reachable from here.

> **Note:** Fork-specific engine notes (Custom Godot Fork, Custom Godot Module, External Texture Sharing, Platform Differences, Build System, C++ Style Guide) live alongside the godot submodule in `../godot/notes/`. They are still part of this Obsidian vault when opened from the parent `thegates/` folder — wikilinks below resolve normally.
```

- [ ] **Step 3: Verify the insertion**

Run:
```bash
grep -n "godot/notes" "C:/Users/Nordup/Documents/Projects/thegates/docs/Index.md"
```

Expected: one match, line near the top.

---

### Task 7: Verify wikilinks (user-coordinated)

This is a sanity check before committing. Even though wikilinks should resolve by note name across the unified vault, eyeballing a few catches mistakes early.

- [ ] **Step 1: Ask the user to verify wikilinks resolve**

Print this message to the user verbatim:

> "Open Obsidian (vault rooted at `thegates/`). Open `docs/Index.md` and click `[[External Texture Sharing]]` — it should jump to the note at `godot/notes/External Texture Sharing.md`. Then in that note, click `[[Custom Godot Fork]]` and `[[Platform Differences]]` — both should resolve. If any wikilink is broken, tell me which one and I'll fix it before we commit. Reply 'wikilinks good' to continue."

Wait for the user's confirmation. If they report a broken wikilink, investigate: the note's filename (header or `name:` frontmatter is irrelevant — Obsidian resolves on filename), or Obsidian may need a manual reindex (Settings → Files & Links → Detect all file extensions toggle, or simply restart Obsidian).

---

### Task 8: Commit in the godot submodule

**Files staged:**
- New file: `CLAUDE.md`
- New directory: `notes/` with seven files (the six moved + the new `Index.md`)

The submodule has its own `.git` (a submodule .git file pointing at the parent's `.git/modules/godot`). The current branch is `tg-4.5`.

- [ ] **Step 1: Confirm we're on the right branch**

Run:
```bash
cd "C:/Users/Nordup/Documents/Projects/thegates/godot" && git branch --show-current
```

Expected: `tg-4.5`. If anything else, stop and ask the user — don't commit on a wrong branch.

- [ ] **Step 2: Check the working tree only contains expected changes**

Run:
```bash
cd "C:/Users/Nordup/Documents/Projects/thegates/godot" && git status -s
```

Expected: only `CLAUDE.md` and `notes/...` files appear as new (`??`). No other unexpected modifications. If you see modifications the user did not authorize, stop and ask.

- [ ] **Step 3: Stage the new files**

Run:
```bash
cd "C:/Users/Nordup/Documents/Projects/thegates/godot" && git add CLAUDE.md notes/
```

Expected: command returns silently.

- [ ] **Step 4: Verify staged contents**

Run:
```bash
cd "C:/Users/Nordup/Documents/Projects/thegates/godot" && git diff --cached --stat
```

Expected: 8 files changed — `CLAUDE.md` plus the seven files under `notes/` (six moved + `Index.md`).

- [ ] **Step 5: Commit**

Run:
```bash
cd "C:/Users/Nordup/Documents/Projects/thegates/godot" && git commit -m "$(cat <<'EOF'
docs: add CLAUDE.md and notes/ for fork-specific knowledge

Adds a self-contained agent-entry contract at the submodule root and
relocates the six fork-specific notes (Custom Godot Fork, Custom Godot
Module, External Texture Sharing, Platform Differences, Build System,
C++ Style Guide) from the parent thegates/docs/ vault into godot/notes/
so they travel with the submodule and are present when the godot/ tree
is opened standalone.

Includes notes/Index.md as a local map of content. The notes are still
part of the unified Obsidian vault when the parent thegates/ is opened
as the vault root, so wikilinks across docs/ and godot/notes/ resolve.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Expected: commit succeeds. If a pre-commit hook fails (clang-format / codespell / etc.), investigate. Markdown files generally don't trigger C++ hooks, but `codespell` can complain about uncommon words — fix or whitelist as appropriate, do not bypass.

---

### Task 9: Commit in the parent thegates repo

**Files staged:**
- Modified: `CLAUDE.md`
- Modified: `docs/Index.md`
- Deleted: six files under `docs/` (the moves are recorded in the parent repo as deletions; the godot submodule already has them as additions in its own commit)

Do NOT stage:
- The submodule pointer (`godot` "new commits") — the user will bump it as part of their normal ship process.
- The pre-existing dirty state in `.cursorignore`.

- [ ] **Step 1: Inspect the working tree**

Run:
```bash
cd "C:/Users/Nordup/Documents/Projects/thegates" && git status -s
```

Expected output includes:
- `M  CLAUDE.md`
- `M  docs/Index.md`
- Six `D  docs/<note>.md` lines (or `R` if git detects renames; both are fine)
- `M  godot` (submodule pointer changed — DO NOT STAGE)
- The pre-existing `.cursorignore` modification (DO NOT STAGE)
- `docs/superpowers/` already tracked from the spec commit

- [ ] **Step 2: Stage only the intended files**

Run:
```bash
cd "C:/Users/Nordup/Documents/Projects/thegates" && git add CLAUDE.md docs/Index.md "docs/C++ Style Guide.md" "docs/Custom Godot Fork.md" "docs/Custom Godot Module.md" "docs/External Texture Sharing.md" "docs/Platform Differences.md" "docs/Build System.md"
```

Note: the six deleted-file paths still work with `git add` even though the files no longer exist on disk — git stages the deletion.

Expected: command returns silently.

- [ ] **Step 3: Verify staged contents**

Run:
```bash
cd "C:/Users/Nordup/Documents/Projects/thegates" && git diff --cached --stat
```

Expected: 8 files in the staged set — 2 modifications (`CLAUDE.md`, `docs/Index.md`) and 6 deletions under `docs/`. No submodule line, no `.cursorignore`.

- [ ] **Step 4: Commit**

Run:
```bash
cd "C:/Users/Nordup/Documents/Projects/thegates" && git commit -m "$(cat <<'EOF'
docs: relocate fork-specific notes to godot/notes/

Removes the six fork-specific notes (Custom Godot Fork, Custom Godot
Module, External Texture Sharing, Platform Differences, Build System,
C++ Style Guide) from docs/ — they now live in the godot submodule at
godot/notes/ so they travel with the submodule when cloned standalone.

Updates CLAUDE.md links and adds an orienting sentence about the new
layout. Updates docs/Index.md with a note pointing readers to the new
location. The Obsidian vault root is now thegates/ rather than
thegates/docs/ so wikilinks resolve across both folders.

Does not bump the godot submodule pointer; that will land in the user's
normal ship cycle.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Expected: commit succeeds.

- [ ] **Step 5: Final status check**

Run:
```bash
cd "C:/Users/Nordup/Documents/Projects/thegates" && git status
```

Expected: working tree shows the pre-existing dirty state only — `.cursorignore` modified, `godot` (new commits including our submodule commit), no other surprises. Report this status to the user as the final summary.

---

## Self-review

**Spec coverage:**
- Vault root migration → Task 1 ✓
- Move 6 notes → Task 2 ✓
- godot/CLAUDE.md → Task 4 ✓
- godot/notes/Index.md → Task 3 ✓
- Update thegates/CLAUDE.md → Task 5 ✓
- Update thegates/docs/Index.md → Task 6 ✓
- Verify wikilinks → Task 7 ✓
- Submodule commit → Task 8 ✓
- Parent commit (without submodule pointer bump) → Task 9 ✓

**Placeholder scan:** All file contents are inline. No TBDs. All commands have explicit expected output.

**Type/path consistency:**
- Path `godot/notes/` used consistently.
- URL-encoded space `%20` and plus `%2B%2B` used consistently in markdown links.
- Submodule branch `tg-4.5` (matches current state per session start).

**Risk note:** Task 1 step 6 and Task 7 step 1 are user-coordinated steps. Stop and wait for the user; do not proceed silently.
