---
tags: [gate, format]
---

# Gate Format and Lifecycle

A `.gate` file is *the* unit of content in TheGates — analogous to a webpage, but instead of HTML it points at an exported Godot project and the runtime needed to play it.

The official spec is at https://docs.thegates.io/en/latest/reference/gate_file.html. This note covers what an *engineer or agent* working on the runtime needs to know — including the bits the public docs leave implicit.

## File shape (INI-like)

```ini
[gate]
title = "My World"
description = "..."
icon = "icon.png"
image = "preview.png"
resource_pack = "world.zip"
godot_version = "4.5"        ; either "4.3" or "4.5" today
discoverable = true

[libraries]
windows.debug = "libs/win/debug/foo.dll"
windows.release = "libs/win/release/foo.dll"
linux.debug = "libs/linux/debug/libfoo.so"
linux.release = "libs/linux/release/libfoo.so"
macos.debug = "libs/macos/debug/libfoo.dylib"
macos.release = "libs/macos/release/libfoo.dylib"
```

- Paths are relative to the `.gate` file unless absolute.
- All three OSes' libraries are required, even if you don't actively support an OS — supply a stub if needed.
- Both debug and release variants are required (can be the same file).
- `[libraries]` is only needed if the world uses GDExtension.

## What ships in the wild

A typical hosted gate is **three URLs**:
1. The `.gate` manifest (small INI file)
2. The `.pck` or `.zip` resource pack (the actual exported Godot project)
3. The icon/image assets

Plus *implicitly*: the renderer binary for the declared Godot version. That's not in the gate — it comes from TheGates' own download API (see [[Renderer Process]] § "Per-gate binaries").

## Lifecycle of a gate visit

```
1. URL entered → app/scripts/api/ fetches the .gate manifest
2. .pck and assets downloaded (or hit cache)
3. renderer_executable.gd resolves which renderer binary is needed for the
   gate's godot_version, downloads it if not cached
4. RenderResult creates and exports the shared GPU texture (launcher side)
5. RendererManager spawns the renderer with --main-pack pointing at the .pck
6. Handshake (see External Texture Sharing): renderer imports the texture
7. Renderer fires "first_frame"; launcher fades world view in
8. Steady state: input forwarded one way, frames + commands the other
9. User navigates away → kill renderer, free pipes, free texture
```

See [[Launcher App]] for the file-by-file map of step 1–9.

## Why each gate ships its own engine

A `.gate` declares `godot_version`. The launcher itself is built from one Godot version (currently 4.5). But a world authored against 4.3 might break under 4.5 — same way a website written against an old browser API might break under a new one. So:

- The launcher keeps its own Godot version for itself (the UI).
- For the *renderer*, it picks a binary that matches what the gate asked for.
- All the IPC protocol surface (the named pipes, command vocabulary, external texture format) must therefore be **stable across renderer versions**.

If you're tempted to change the IPC, see [[Two-Process Model]] § "Command vocabulary" first — every renderer binary in the wild expects the existing names and arg shapes.

## Practical gotchas

- **`godot_version` controls more than you'd think.** It selects the renderer binary, which means a gate's choice of 4.3 vs 4.5 changes which engine bug-fix landscape applies. When debugging "this gate is broken but that one works," check `godot_version` first.
- **`.pck` vs `.zip`** — both are accepted as `resource_pack`. Internally `--main-pack` opens whichever.
- **Cached renderer binaries live under `user://`** for non-current versions, and alongside the launcher exe for the current one (see `renderer_executable.gd::get_renderer_dir`). If you're chasing "the renderer feels old," that's where the file is.
- **`discoverable=false`** keeps the gate out of search indexes but doesn't make it private. Anyone with the URL can visit. There is no auth model in the gate format.
