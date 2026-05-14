---
tags: [architecture, renderer]
---

# Renderer Process

The renderer is a Godot binary built with `tg_renderer=yes` (which defines the `TG_RENDERER` macro). It runs the gate's `.pck` and pumps frames into a shared GPU texture for the launcher to display. See [[Two-Process Model]] and [[External Texture Sharing]] for the surrounding context.

## What's different from a normal Godot game

All the changes are guarded by `#ifdef TG_RENDERER` inside `godot/`. Greppable. Significant ones:

| Where | Behavior change |
|-------|-----------------|
| `main/main.cpp` (~line 2456) | Hardcoded `rendering_driver = "vulkan"` — overrides any `--rendering-driver` arg from the command line |
| `main/main.cpp` (~line 4686) | Connects to launcher's `command_sync` pipe at startup, asks for the shared external texture, imports it as `ext_texture` |
| `main/main.cpp` (~line 4970, in `iteration()`) | Each frame: sends `first_frame`/`heartbeat` commands; calls `ext_texture->copy_from_screen()` to push frame into shared texture; pulls input from `input_sync`; checks pipe peer is alive — crashes if not |
| `platform/windows/display_server_windows.cpp` | `show_window` is no-op; window created without `WS_VISIBLE`; `window_set_mode` and `window_set_flag` no-op |
| `platform/macos/display_server_macos.mm`<br>`platform/macos/godot_application.mm` | Same window-show suppression on macOS |
| `platform/linuxbsd/x11/display_server_x11.cpp` | Same on Linux/X11 |

The result: the renderer is a "headless-ish" Godot — a real Godot with a real display server, swapchain, and Vulkan device, but its window is invisible and its frames are exfiltrated via shared GPU memory instead of a swapchain present.

## Lifecycle

```
0. Spawned by launcher with: gate.renderer --main-pack <gate.pck> --resolution WxH --url <url> --verbose
1. Normal Godot bootstrap (Main::setup, Main::start) — runs the .pck's autoloads and main scene
2. Under TG_RENDERER, after Main::start completes:
     command_sync->bind_commands(); command_sync->socket_connect()
     send_command("ext_texture_format", [screen_format])
     send_command("send_filehandle", [<addr>|<my_pid>])
     ext_texture->recv_filehandle(...)         // BLOCKING
     ext_texture->import(format, view)         // create local VkImage on the imported memory
     input_sync->socket_connect()
3. Each iteration of the engine main loop:
     send "first_frame" once when frames_drawn > 2
     send "heartbeat" every ~1s
     ext_texture->copy_from_screen()           // shared texture <- this frame's screen
     input_sync->receive_input_events()        // drain forwarded input from launcher
     command_sync->poll_monitor()
       if peer disconnected: CRASH_NOW         // intentional, see Gotchas
4. Exits when launcher kills it or peer disconnects
```

## Per-gate binaries (important)

The renderer binary is **not bundled with the launcher**. Each `.gate` declares which Godot version it needs (currently 4.3 or 4.5 per the [.gate spec](https://docs.thegates.io/en/latest/reference/gate_file.html)), and the launcher downloads a matching renderer binary lazily via `app/scripts/renderer/renderer_executable.gd`. They cache under `user://` (or, for the version that matches the launcher itself, alongside the launcher exe).

Implications:
- Multiple renderer binaries can coexist on disk — one per Godot version the user has visited gates for.
- If a gate ships an *old* renderer with bugs (or built against an old `modules/the_gates/` API), the protocol must stay backward-compatible. The pipe message format and command names are the protocol surface.

See [[Gate Format and Lifecycle]].

## What the renderer can and can't do

- **Can**: render anything Godot can render in Vulkan; use any GDExtension declared in the `.gate`'s `[libraries]` section.
- **Can't**: show its own window, present to the OS swapchain, escape its sandbox (Linux only today — see [security model docs](https://docs.thegates.io/en/latest/about/security.html)), use D3D12 or OpenGL. The Vulkan-only constraint is hardcoded — see [[Custom Godot Fork]].

## Operational tip

There are `.console.exe` variants in `godot/bin/` (e.g. `godot.windows.template_release.renderer.x86_64.console.exe`). Same binary, but with a console attached — useful for reading `print_line` output and Godot's `--verbose` flag while debugging the renderer in isolation.
