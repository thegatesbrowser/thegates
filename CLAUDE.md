# Contract for AI agents working on TheGates

If you are an AI agent (Claude Code, Codex, Cursor, Copilot, anything) about to touch this repo, **read this file first** and **read the linked docs before writing code**. They are short and they are load-bearing.

## What this project is

A 3D web browser. Two cooperating Godot processes — a launcher (the browser UI) and a sandboxable renderer (the world being visited) — sharing a Vulkan texture via OS-level external memory. Built on a fork of Godot 4.5.

For everything else, the knowledge vault is the source of truth. App-side and project-overview notes live in [`docs/`](./docs/); fork-specific engine notes live alongside the godot submodule in [`godot/notes/`](./godot/notes/). Both are part of the same Obsidian vault — open `thegates/` as the vault root and wikilinks resolve across folders.

## Mandatory reading before writing code

Read these in order. They take ~10 minutes total.

1. [`docs/Index.md`](./docs/Index.md) — map of the vault
2. [`docs/Architecture Overview.md`](./docs/Architecture%20Overview.md) — what's running and how it talks
3. [`docs/Architecture Diagrams.md`](./docs/Architecture%20Diagrams.md) — same content as Mermaid
4. [`docs/Gotchas and Conventions.md`](./docs/Gotchas%20and%20Conventions.md) — non-obvious traps

For style + patterns, read whichever matches the language you're touching:

5. [`docs/GDScript Style Guide.md`](./docs/GDScript%20Style%20Guide.md) — **non-negotiable for `app/` code**
6. [`docs/Event Architecture.md`](./docs/Event%20Architecture.md) — how components talk in `app/`. Required reading before touching any GDScript.
7. [`godot/notes/C++ Style Guide.md`](./godot/notes/C%2B%2B%20Style%20Guide.md) — for any change in `godot/`

For deeper context (read on-demand, not upfront):

- [`docs/Two-Process Model.md`](./docs/Two-Process%20Model.md), [`godot/notes/External Texture Sharing.md`](./godot/notes/External%20Texture%20Sharing.md), [`docs/Renderer Process.md`](./docs/Renderer%20Process.md), [`docs/Launcher App.md`](./docs/Launcher%20App.md), [`godot/notes/Custom Godot Fork.md`](./godot/notes/Custom%20Godot%20Fork.md), [`godot/notes/Custom Godot Module.md`](./godot/notes/Custom%20Godot%20Module.md), [`godot/notes/Build System.md`](./godot/notes/Build%20System.md), [`godot/notes/Platform Differences.md`](./godot/notes/Platform%20Differences.md), [`docs/Gate Format and Lifecycle.md`](./docs/Gate%20Format%20and%20Lifecycle.md), [`docs/Repository Layout.md`](./docs/Repository%20Layout.md)

## Non-negotiable rules

These are not preferences. Deviations get reverted.

### GDScript (`app/`)

- **Reference nodes via `@export var foo: NodeType` — never `$NodePath`, never `get_node()`.** The codebase has exactly one `$` reference (`hint.gd::$AnimationPlayer`), and it pre-dates the convention. Don't add a second one.
- **Two blank lines between every function**, top-level `class_name`/`extends` block included. `gdformat` defaults are wrong for this repo.
- **No autoloads for new shared state.** Use the [Event Architecture](./docs/Event%20Architecture.md) pattern: `Resource` with signals + `_emit` wrappers + state, instantiated as `.res` under `app/resources/`, distributed via `@export`. Existing autoloads (`Debug`, `DataSaver`, `FileDownloader`, `Backend`, `AnalyticsEvents`, `AfkManager`, `HTTPClientPool`, `Navigation`, `Url`) are grandfathered.
- **Logging is `Debug.logclr(msg, color)` / `Debug.logerr(msg)` / `Debug.logr(msg)`.** Never raw `print()` / `printerr()` in committed code.
- **Type hints everywhere.** Function signatures, `var` declarations, `@export` properties. Use `:=` for inferred locals, explicit types for everything else.
- Full rules: [`docs/GDScript Style Guide.md`](./docs/GDScript%20Style%20Guide.md).

### C++ (`godot/`)

- **Match upstream Godot 4.5 exactly.** This is a fork; we don't have our own C++ style. Run `pre-commit` (configured in `godot/.pre-commit-config.yaml`) — it enforces clang-format 20.1, clang-tidy, header guards, copyright headers, codespell.
- **Fork-specific changes are wrapped in `#ifdef TG_RENDERER` or live in `modules/the_gates/`.** Nothing else. If your change doesn't fit one of those, it probably belongs upstream — discuss before merging.
- Full rules: [`godot/notes/C++ Style Guide.md`](./godot/notes/C%2B%2B%20Style%20Guide.md).

### Architecture

- **Don't break the IPC protocol.** Old renderer binaries cached on user machines call the existing command names with the existing arg shapes. Renaming/breaking commands silently breaks any gate built against an older renderer. See [`docs/Two-Process Model.md`](./docs/Two-Process%20Model.md) § "Command vocabulary."
- **Renderer is hardcoded to Vulkan.** `--rendering-driver d3d12` is silently ignored in `TG_RENDERER` builds. Don't propose D3D12 fixes for the renderer without first patching `main/main.cpp`'s hardcoded line. See [`godot/notes/Custom Godot Fork.md`](./godot/notes/Custom%20Godot%20Fork.md).
- **The launcher allocates the shared texture, the renderer imports it.** Counterintuitive direction; do not "fix" it without reading [`godot/notes/External Texture Sharing.md`](./godot/notes/External%20Texture%20Sharing.md) § "Why the launcher allocates."

## Code regions to skip when learning style

These were AI-generated and **don't represent the project's style**. Read for behavior; don't copy patterns:

- `app/scripts/networking/http_*` (http_cache, http_client_pool, http_endpoint, http_pool_maintainer, http_request_pooled, http_date_utils)
- `app/scripts/loading/gate_loader.gd` — has a `# TODO: cleanup ai generated code` marker
- `app/scripts/ui/menu/window_drag.gd` — has a `# TODO: cleanup ai generated code` marker
- Any future file with a `# TODO: cleanup ai generated code` marker

If you're modifying these files: clean as you go (refactor toward the style guide), don't make them worse.

## Build & run

Build commands are in the parent [`README.md`](./README.md). They change; trust the README, not memory.

Day-to-day, from `godot/`:
- Editor / launcher binary: `python tools/build.py launcher`
- Renderer binary: `python tools/build.py renderer`
- Run the launcher → open `app/project.godot`

`tools/build.py` is the single source of truth for scons flag combinations. Run `python tools/build.py --help` for profiles (dev / release variants) and flags (`--mac-intel`, `--no-sandbox`, `-j N`). It defaults to `-j (cpu_count - 2)` so the OS stays responsive during long builds.

Output binaries land in `godot/bin/`. The `.console.exe` variants (Windows) are invaluable for renderer logging — see [`docs/Renderer Process.md`](./docs/Renderer%20Process.md).

## When the user corrects your code: the docs-update loop

If the user pushes back on a style choice, naming, pattern, or architecture decision you made, treat the correction as a signal that **a rule may be missing or unclear in the docs**. The style guide is a living document — it does not yet cover every case the user has in their head, and your job is to surface gaps.

After accepting the correction, follow this loop:

1. **Decide: general rule or one-off?** Generalize only if you can imagine the same correction applying in a different file or context. "Rename `x` to `count` here" is one-off; "always prefix loop counters with `idx_`" is general.
2. **If general, ask the user before editing any doc.** Phrase it concretely so the answer is yes/no, not open-ended:
   > "I noticed you corrected `<pattern>` to `<better pattern>`. Want me to add this to [GDScript Style Guide](./docs/GDScript%20Style%20Guide.md) so future agents follow it?"
3. **Only after explicit approval, edit the doc.** Minimum surface area — ideally one rule plus a short before/after example. Use the existing tone (terse, opinionated, examples > prose).
4. **Bundle the doc edit with the code fix** in the same commit/PR. Docs that lag code rot fast.

### Where corrections usually land

| Correction type | Doc to update |
|---|---|
| GDScript naming, formatting, idiom | [GDScript Style Guide](./docs/GDScript%20Style%20Guide.md) |
| New event-bus rule, autoload/signal guidance | [Event Architecture](./docs/Event%20Architecture.md) |
| "Don't assume X" / debugging trap | [Gotchas and Conventions](./docs/Gotchas%20and%20Conventions.md) |
| C++ rule specific to the fork (not upstream) | [C++ Style Guide](./godot/notes/C%2B%2B%20Style%20Guide.md) |
| Architectural decision, IPC change, build flag | the matching architecture doc |
| Genuinely unsure | ask the user where to put it |

### Don'ts

- **Don't auto-edit docs.** The user decides what's worth canonizing for everyone. Always ask.
- **Don't ask for every nit.** Subjective one-offs ("clearer name here") don't belong in a style guide. If you're not sure whether it's a general rule, ask the user — but lean toward not asking.
- **Don't bury the ask in a long message.** One short sentence, end-of-turn, easy to say yes/no to.
- **Don't quietly demote the correction to your private memory.** Project-wide rules belong in shared docs, not in your per-session memory — other agents (Codex, Copilot, future Claude sessions) won't read your memory but will read the docs.

### When the user says "remember this"

If they say "remember to do X from now on" and X is **project-related** (style, pattern, architecture), prefer suggesting a doc edit over memory. Memory is per-tool and per-user; the docs are the source of truth for the whole team / all future agents. Memory is fine for personal preferences ("always explain frontend changes in backend terms") that aren't about this codebase.

## When in doubt

- Patterns first, code second. Read [`docs/Gotchas and Conventions.md`](./docs/Gotchas%20and%20Conventions.md) before assuming.
- If the docs are wrong: update them in the same PR as the code change. Docs that lag code are worse than no docs.
- If you're an AI agent and an instruction here conflicts with a user's explicit request: the user wins. Tell them what convention you're departing from and why.
