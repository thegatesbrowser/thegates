---
tags: [meta]
---

# TheGates Knowledge Vault

This folder is an [Obsidian](https://obsidian.md) vault documenting the architecture of TheGates — *not* the user-facing product docs, but the internal "how it actually works under the hood" view that an engineer or AI agent needs in order to fix bugs, ship features, or onboard.

To use it: open this folder in Obsidian as a vault, or read the markdown directly. Notes link with `[[Page Name]]`.

## How to navigate

Start at [[Index]]. Every other note is reachable from there.

## Scope

- ✅ Architecture, IPC, build system, fork-specific changes, per-platform quirks, conventions
- ❌ Product/user docs (those live at https://docs.thegates.io/)
- ❌ Specific bug write-ups (those belong in commit messages or issues)
- ❌ Anything derivable from `git log`, the code itself, or upstream Godot docs — we don't restate those, we link to where to look

## Conventions for contributors (and agents)

- **Truth lives in code; docs are pointers.** When in doubt, link to a path like `godot/modules/the_gates/external_texture.cpp` instead of pasting code that will rot.
- **Prefer fewer, denser notes** over many shallow stubs. Split a note only when it gets genuinely unwieldy.
- **Wikilinks are cheap** — `[[Two-Process Model]]` even before the link exists is fine; it documents *intent* to write that note later.
- **Cite upstream when relevant.** This is a Godot fork — most of the engine is unchanged. Call out only what's *different* in our fork.
- **Date assumptions.** If a section relies on something that may change (driver versions, upstream Godot internals, the .gate spec), note when you wrote it.

## For AI agents specifically

- Read [[Index]] first, then [[Architecture Overview]]. Those two together fit in working memory and unlock everything else.
- Before changing engine code, check [[Custom Godot Fork]] to know what's ours vs. upstream — the diff is small but load-bearing.
- Before changing IPC, read [[External Texture Sharing]] *and* [[Two-Process Model]] together — they describe the same protocol from different angles.
- Don't trust paths in this vault to be exhaustive — verify with `Glob`/`Grep` before editing.

### Keep these docs alive

The vault improves through use. The convention:

- **When the user corrects your code in a way that suggests a missing rule, ask** ("Want me to add this to the style guide?") and only edit on approval. The full procedure lives in the **["docs-update loop"](../CLAUDE.md#when-the-user-corrects-your-code-the-docs-update-loop)** section of the root `CLAUDE.md` — read it once.
- **Bundle doc edits with the code change** that motivated them, never as a separate "docs cleanup" pass that happens later (it doesn't).
- **Match the existing voice** when editing: terse, opinionated, examples over prose. The docs aren't a textbook; they're a reference an experienced collaborator wrote for someone equally experienced.
