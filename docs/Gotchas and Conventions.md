---
tags: [conventions, gotchas]
---

# Gotchas and Conventions

Non-obvious things that bite. If you're an agent walking into this project for the first time, skim these *before* writing code.

## Architecture-level traps

### "It's just one Godot project"
No. There are **two Godot binaries** (one launcher, one renderer per gate) and **multiple Godot projects** (`app/` is the launcher's; the gate's `.pck` is the renderer's). When something is "broken," your first question is: which process? See [[Two-Process Model]].

### "If 2D works, the IPC is fine"
Mostly true. The launcher's UI is itself 2D in its own process and doesn't go through the IPC. The launcher *displays* the renderer's framebuffer (which contains 3D content) via [[External Texture Sharing]]. So 2D in the launcher = launcher's local rendering. 3D in the world = renderer's rendering, exfiltrated via shared GPU texture.

### "The renderer is just a headless Godot"
Almost. It's a Godot with a real Vulkan device and a real (invisible) window — see the platform display server changes in [[Custom Godot Fork]]. It is **not** `--headless` in the upstream-Godot sense. Don't try to wire it up that way.

## Code-level traps

### `recv_filehandle` is BLOCKING
Both `TGExternalTexture::recv_filehandle` and `TgPipeIpc::pop_message` (when called in the recv loop) will sit forever waiting. The renderer's startup blocks here intentionally. If you're adding a new handshake step, do not add a new blocking call without a timeout or a peer-liveness check.

### The renderer crashes itself on disconnect — *on purpose*
```cpp
if (!command_sync->is_peer_connected()) {
    CRASH_NOW_MSG("CommandSync peer disconnected. Exiting child.");
}
```
Comment in source: *"hack to avoid hanging because of uncleaned pipes created by `OS::execute_with_pipe`."* So if you see the renderer "crash" when the user closes the launcher, that's not a bug — it's the cleanup mechanism. If you're investigating the renderer crashing for other reasons, this same path will fire if the pipe is still alive but the peer-side process has gone away.

### The launcher allocates the shared texture, the renderer imports it
Counterintuitive. Even though the renderer is the producer of pixels, the *launcher* calls `TGExternalTexture::create()` (allocates Vulkan memory + exports a handle) and the *renderer* calls `TGExternalTexture::import()`. Direction is intentional — the launcher outlives any single renderer. Documented at [[External Texture Sharing]] § "Why the launcher allocates."

### Vulkan is hardcoded for the renderer
`#ifdef TG_RENDERER` in `main/main.cpp` (~line 2456) sets `rendering_driver = "vulkan"` *after* command-line parsing. Passing `--rendering-driver d3d12` to the renderer **silently does nothing**. To switch the renderer to D3D12 you must either:
- patch out that line and rebuild, or
- read the flag from an env var instead and propagate.

The launcher (no `TG_RENDERER`) accepts `--rendering-driver` normally.

### Skinned meshes / mesh corruption on Windows AMD ≠ engine bug
There's a recurring AMD Adrenalin Vulkan regression on RDNA1/RDNA2 (Godot issues #109378, #109679; forum thread 119150) that produces black-triangle artifacts on meshes. Driver-level. Goes away with a driver update or D3D12. **Update the driver before suspecting the code.**

### Each gate brings its own renderer binary
The launcher does *not* ship one renderer binary. It downloads the matching binary for each gate's declared `godot_version`. Cached under `user://`, except the binary that matches the launcher's own version, which lives next to the launcher exe. See [[Gate Format and Lifecycle]].

This means:
- **You can't fix every gate by rebuilding the renderer in `godot/bin/`** — only gates declaring the same `godot_version` as your build will pick it up.
- The IPC protocol is a public stable surface across renderer versions. Don't change command names or payload shapes without a version negotiation.

### Stale named pipe placeholder files
On Windows, `app/renderer/` contains zero-byte placeholder files (`command_sync`, `input_sync`, `external_texture`) that may be left over after a process exits. They aren't lock files and don't prevent re-launch — but they can be confusing on inspection. Leave them; the actual pipes live in the `\\.\pipe\` namespace.

## GDScript / engine API conventions used in `app/`

- **Event buses are autoload singletons.** `GateEvents`, `CommandEvents`, `AppEvents`, `UiEvents` etc. — find them in `project.godot`'s `[autoload]` section.
- **`Debug.logclr(msg, color)` and `Debug.logerr(msg)`** are the project's logging conventions, not raw `print`. Honors the in-app debug overlay.
- **Resource classes for data**: `RendererExecutable`, `RenderResult`, `ApiSettings` etc. are `extends Resource` — they're *.tres* serializable data containers, not nodes. Edit their `.tres` instances when changing config, not the .gd.

## Build / deploy conventions

- Build commands live in the parent `README.md`, not in this vault. Don't duplicate; they change.
- The `.console.exe` variants are built automatically alongside the GUI ones on Windows. Use them for renderer logging — see [[Renderer Process]] § "Operational tip".
- `compile_commands.json` is at repo root (`compiledb=yes` in the build flags) — point your LSP at it for `godot/`.

## When changing engine code (`godot/`)

- **Confirm the change is needed in the fork.** Most engine bugs are fixable upstream. The point of the fork is `tg_renderer` + the few hooks listed in [[Custom Godot Fork]] — not divergence for its own sake.
- **Greppable convention**: every fork-specific block is wrapped in `#ifdef TG_RENDERER` *or* lives under `modules/the_gates/`. If your change doesn't fit one of those, you're probably going off-pattern — discuss before merging.
- **Recompile the right binary.** Editing only-renderer code? `tg_renderer=yes`. Editing the launcher binary's behavior? `tg_renderer=no`. Editing both? Build both.

## When changing IPC

- All three pipes use `TgPipeIpc`. Touch one place, all the IPC works.
- **Do not** change the command name strings or arg counts in `command_sync.gd` without a version-aware fallback — there are old renderer binaries cached on users' machines that will send the old names.
- Adding a new command? Both ends:
  1. Renderer side: `command_sync->send_command("new_name", args)` somewhere meaningful.
  2. Launcher side: add a `match` arm in `app/scripts/renderer/command_sync.gd::_execute_function`.
  3. Add the corresponding event to the relevant event bus autoload.
- Adding a new IPC channel? You'll need three implementations (Win/Mac/Linux) — see [[Platform Differences]].
