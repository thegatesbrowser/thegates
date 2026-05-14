---
tags: [architecture, ipc]
---

# Two-Process Model

TheGates runs as **two cooperating Godot processes**: the **launcher** (the browser UI) and the **renderer** (the world being visited). They are *both* Godot binaries built from the same `godot/` fork — but with different SCons flags so behave differently. See [[Build System]].

## The two binaries

| Role | Built from `godot/` with | What it does |
|------|--------------------------|--------------|
| Launcher | normal flags (NO `tg_renderer=yes`) | Runs `app/` — the browser project. Visible window. |
| Renderer | `tg_renderer=yes` | Runs a downloaded gate's `.pck`. Window is invisible. Hardcoded to Vulkan. Crashes if the launcher pipe dies. |

`TG_RENDERER` is the C preprocessor define injected by the build flag. Greppable across `godot/`.

## Spawning

Launcher → renderer is a parent → child process via Godot's `OS.execute_with_pipe`. From `app/scripts/renderer/renderer_manager.gd`:

```gdscript
return OS.execute_with_pipe(gate.renderer, [
    "--main-pack", pack_file,
    "--resolution", "%dx%d" % [render_result.width, render_result.height],
    "--url", gate.url,
    "--verbose"
])
```

`gate.renderer` is the path to a renderer binary specific to this `.gate` (each gate ships its own — see [[Gate Format and Lifecycle]]).

## IPC channels — three named pipes

All three pipes are implemented by `TgPipeIpc` (`godot/modules/the_gates/tg_pipe_ipc.cpp`), which uses Godot 4.5's built-in `FileAccess` named-pipe support — recently swapped in to replace ZMQ (commit `1adce7ef13`, "replace zmq ipc with godot's build in named pipes"). The launcher *binds* the pipe; the renderer *connects*.

| Pipe | Address (Windows) | Address (Unix) | Purpose |
|------|-------------------|----------------|---------|
| `command_sync` | `pipe://renderer/command_sync` | `pipe:///tmp/command_sync` | Renderer → launcher commands (asks for filehandle, signals first frame, heartbeats, opens links/gates) |
| `input_sync` | `pipe://renderer/input_sync` | `pipe:///tmp/input_sync` | Launcher → renderer input event forwarding |
| `external_texture` | `pipe://renderer/external_texture` | `pipe:///tmp/external_texture` | One-shot: launcher → renderer transmission of the GPU memory handle (see [[External Texture Sharing]]) |

`pipe://` is Godot 4.5's named-pipe URI scheme (Windows `\\.\pipe\` namespace under the hood). On Unix, the pipe is a normal file in `/tmp/`.

## Command vocabulary (`command_sync`)

The renderer sends commands to the launcher. The launcher's GDScript `CommandSync` handler in `app/scripts/renderer/command_sync.gd` dispatches them. Current commands:

| Command | Args | Meaning |
|---------|------|---------|
| `ext_texture_format` | `format: int` | Renderer tells launcher its screen format (RGBA8 / BGRA8) so launcher's shader can match swizzle |
| `send_filehandle` | `path: String` | Renderer asks launcher to allocate the shared texture and pipe its handle to `path` (on Windows, `path` includes `|<renderer-pid>` because of `DuplicateHandle`) |
| `first_frame` | — | Renderer has produced its first frame (used to fade in the gate UI) |
| `heartbeat` | — | Liveness ping every ~1 second |
| `set_mouse_mode` | `mode` | Renderer requests mouse mode change (e.g. captured) |
| `open_gate` | `relative_url` | Renderer asks browser to navigate to another gate (relative to current) |
| `open_link` | `url` | Renderer asks OS to open a non-gate URL (system browser) |
| `highlight_button` | `button_id` | Renderer asks launcher UI to highlight a button (onboarding hint) |

All command bodies are `Command` ref-counted objects (`godot/modules/the_gates/command.h`): `name: String`, `args: Array`. Serialized via Godot's variant binary encoding through the pipe.

## Lifetime contract

- Launcher binds all three pipes when a gate is entered (`GateEvents.ENTERED`).
- Renderer connects to those pipes at startup (`Main::start()` under `#ifdef TG_RENDERER`).
- Renderer's `command_sync->poll_monitor()` checks every iteration that the parent's pipe is still alive. If the parent disappears, the renderer **deliberately crashes** with `CRASH_NOW_MSG("CommandSync peer disconnected. Exiting child.")` — a hack documented as "to avoid hanging because of uncleaned pipes created by `OS::execute_with_pipe`." See [[Gotchas and Conventions]].
- Launcher kills the renderer with `OS.kill(renderer_pid)` on tab close or app exit.

## What does NOT cross the pipe

- **Pixels.** Pixels never travel through the pipe — they live in shared GPU memory. The pipe only carries the *handle* to that memory once, at startup. See [[External Texture Sharing]].
- **Audio.** Audio routing between processes is not (yet?) covered by this vault. Worth investigating before changing audio paths.
- **Filesystem.** The renderer reads its `.pck` directly from disk (`--main-pack` arg). The launcher doesn't proxy file I/O.
