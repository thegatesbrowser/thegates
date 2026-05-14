---
tags: [spec, meta, docs]
---

# Godot fork knowledge base — design

**Status:** approved (2026-05-14)
**Owner:** Nordup
**Scope:** This repo only. No upstream-Godot changes.

## Problem

The `godot/` submodule (`thegatesbrowser/godot`, fork of Godot 4.5) has accumulated fork-specific changes — a `TG_RENDERER` build flag, `#ifdef` blocks in `main/main.cpp` and the per-OS display servers, a new `modules/the_gates/` module, and `RenderingDevice` additions for cross-process Vulkan texture sharing. The architecture and rationale for those changes is already documented in the parent vault (`thegates/docs/`), but:

1. The godot submodule has **no entry-point file** for AI agents working in it. There is no `CLAUDE.md` at the godot/ root.
2. The fork-specific notes (C++ Style Guide, Custom Godot Fork, Custom Godot Module, External Texture Sharing, Platform Differences, Build System) live in the parent `thegates/docs/` vault, not next to the code they describe.
3. The user's workflow uses **two separate IDE/terminal sessions** — one for `app/` GDScript work (parent thegates/), one for `godot/` C++ engine work. The C++ session may not have the parent vault loaded.
4. Because `godot/` is a git submodule, anything committed inside it travels with the submodule when cloned standalone. The parent vault doesn't travel with it.

## Goals

- Make the godot submodule **self-contained** for engine work: a developer or agent who only has `godot/` checked out can understand what the fork is, why it exists, and how to work on it without needing the parent thegates/ checkout.
- Preserve a **cohesive Obsidian vault graph** — wikilinks across all project notes must continue to resolve.
- **No duplication.** One source of truth per topic.
- Scoped move only. **No new docs** beyond a `CLAUDE.md` and a local `Index.md` for the fork's notes folder. The existing parent-vault content already covers the fork's architecture; we move it, we don't rewrite it.

## Non-goals

- Adding new documentation content beyond the entry contract and a local index.
- Refactoring the existing godot-specific notes (they stay as-is, just relocated).
- Touching upstream Godot files or `godot/doc/` (Godot's class-reference XML).
- Restructuring the parent vault's app-side notes (Launcher App, GDScript Style Guide, Event Architecture, etc. — they stay in `thegates/docs/`).

## Design

### Vault root migration

The current active Obsidian vault is `thegates/docs/.obsidian/` (confirmed: only that location has `workspace.json`, which Obsidian writes when a vault is opened). An orphan `.obsidian/` already exists at `thegates/` (missing `workspace.json`).

Migrate the vault root up one level so the whole `thegates/` tree is one vault. After that, wikilinks resolve across `thegates/docs/` and `thegates/godot/notes/` (Obsidian wikilinks are name-based, not path-based).

Steps:

1. Copy `thegates/docs/.obsidian/workspace.json` to `thegates/.obsidian/workspace.json`.
2. Delete `thegates/docs/.obsidian/` so Obsidian doesn't treat docs/ as a nested vault.
3. Open Obsidian → "Open folder as vault" → select `thegates/`. (User action.)

### Notes to move

These six notes are godot-fork-specific. They move from `thegates/docs/` to `thegates/godot/notes/`:

- `C++ Style Guide.md`
- `Custom Godot Fork.md`
- `Custom Godot Module.md`
- `External Texture Sharing.md`
- `Platform Differences.md`
- `Build System.md`

These notes **stay in `thegates/docs/`** (they describe the app side or the project broadly):

- `Architecture Overview.md`
- `Architecture Diagrams.md`
- `Repository Layout.md`
- `Two-Process Model.md`
- `Renderer Process.md`
- `Launcher App.md`
- `Gate Format and Lifecycle.md`
- `GDScript Style Guide.md`
- `Event Architecture.md`
- `Gotchas and Conventions.md`
- `Index.md`

### Wikilink behavior after the move

Wikilinks in the moved notes (e.g. `[[Custom Godot Fork]]`, `[[Platform Differences]]`) keep working because Obsidian resolves them by note name across the unified vault. Wikilinks in the not-moved notes that reference moved notes also keep working for the same reason.

No wikilink edits required in the note bodies themselves.

### New files

#### `godot/CLAUDE.md` — agent entry contract

Self-contained (works without parent vault). Structure:

- **What this project is** — 1 paragraph. TheGates is a 3D web browser; two cooperating Godot processes (launcher + sandboxable renderer) share a Vulkan texture via OS-level external memory.
- **What this fork is** — 1 paragraph. Upstream Godot 4.5 plus: `TG_RENDERER` build flag with `#ifdef` blocks in `main/main.cpp` and per-OS display servers; `modules/the_gates/` module; new methods on `RenderingDevice` (`external_texture_create`, `external_texture_import`, `screen_copy`).
- **Mandatory reading for engine work** — bullet list of the six moved notes via relative markdown links (`./notes/<name>.md`).
- **For broader project context** — pointer to `../CLAUDE.md` and `../docs/Index.md`, with the note that those require the parent thegates/ checkout.
- **Non-negotiable rules for C++** — short version (match upstream, pre-commit, two places for changes: `modules/the_gates/` or `#ifdef TG_RENDERER` blocks). 5–10 lines.
- **Build & run** — quick scons command reference, with a pointer to the parent README for canonical commands.
- **The docs-update loop** — adapted from parent CLAUDE.md, scoped to fork docs: if user corrects a style/pattern choice, ask whether to canonize it in `notes/C++ Style Guide.md` or `notes/Custom Godot Fork.md`.

Target length: 80–120 lines.

#### `godot/notes/Index.md` — local map of content

Short. Lists the six moved notes in the same groupings the parent Index uses (fork, engine, per-OS, style), with a "go up" pointer to the parent vault's `../../docs/Index.md` for app-side and project-overview notes.

### Files to update

#### `thegates/CLAUDE.md`

The "Mandatory reading" section currently uses markdown links like `[`docs/C++ Style Guide.md`](./docs/C++%20Style%20Guide.md)`. For each of the six moved notes, change the path from `./docs/...` to `./godot/notes/...`. Add one sentence near the top explaining: "Fork-specific notes (C++/engine) live in `godot/notes/`; app-side and project-overview notes live in `docs/`. Both are part of the same Obsidian vault when opened from this folder."

#### `thegates/docs/Index.md`

Wikilinks themselves don't change. Add a short sentence under the relevant section: "C++/engine details have moved to `godot/notes/` (still in this vault — wikilinks resolve normally)."

## Constraints / decisions captured

- **Folder name inside godot/ is `notes/`.** Decided to avoid conflict with `godot/doc/` (upstream Godot's class-reference XML). `notes/` is short, clear, and a common convention.
- **CLAUDE.md is self-contained, not pointer-only.** Required because the user's C++ workflow may open `godot/` as the root in a separate IDE without the parent vault.
- **No new content beyond CLAUDE.md and the local Index.md.** Scope is move + entry contract. Future notes (e.g. submodule git workflow, IPC pipe stack deep dive, upstream Godot architecture pointers) can be added as separate work if gaps surface.

## Risks and how to handle

- **workspace.json stale paths after vault migration.** Obsidian gracefully re-resolves missing files; the user may need to re-open the notes they had pinned. Minor one-time inconvenience.
- **Submodule commit hygiene.** Adding `godot/CLAUDE.md` and `godot/notes/` to the godot submodule means a commit on the fork's `tg-4.5` branch and a corresponding submodule-pointer bump on parent thegates `tg-master` (or wherever the submodule pointer lives). This is normal submodule workflow; the user will handle it via their usual ship process.
- **Notes referencing each other via wikilinks across folders.** Verified: Obsidian resolves wikilinks by note name across the whole vault. As long as note names stay unique within the vault, no path edits are needed in note bodies. Sanity-check after the move by clicking through a few wikilinks.
- **If `godot/` is cloned standalone (no parent thegates/).** The wikilinks in the moved notes (e.g. `[[Two-Process Model]]`) won't resolve because their targets live in the parent vault. Mitigation: `godot/CLAUDE.md` flags this explicitly. The moved notes still render as readable Markdown — the wikilinks just become non-clickable text.

## Implementation order (for the plan)

1. Vault migration (workspace.json copy + delete docs/.obsidian/). User-coordinated step.
2. Create `godot/notes/` directory.
3. `git mv` the six notes into `godot/notes/`. (Use `git mv` to preserve history across the submodule.)
4. Write `godot/CLAUDE.md`.
5. Write `godot/notes/Index.md`.
6. Update `thegates/CLAUDE.md` paths.
7. Update `thegates/docs/Index.md` with the migration note.
8. Verify by opening `thegates/` as the vault in Obsidian and clicking a sample of wikilinks across both folders.
9. Commit: one commit in the godot submodule, one commit in the parent thegates repo (which includes the submodule pointer bump and parent-vault edits).

## Out of scope (explicit)

- New deep-dive notes (e.g. detailed IPC pipe walkthrough, upstream Godot architecture summary, submodule git workflow guide).
- Restructuring the parent vault's app-side notes.
- Editing the body of any moved note. Move only.
- Touching `godot/doc/`, `godot/CONTRIBUTING.md`, `godot/README.md`, or any upstream Godot file.
