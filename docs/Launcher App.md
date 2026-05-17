---
tags: [launcher, app]
---

# Launcher App

The browser UI itself. Lives in `app/` as a normal Godot 4.5 project; runs inside the launcher binary built from `godot/`. See [[Architecture Overview]] and [[Two-Process Model]] for context.

## Top-level scenes

`app/scenes/`:
- `app.tscn` — root scene
- `menu.tscn` — top chrome (URL bar, tabs, controls)
- `debug.tscn` — debug overlay
- `menu_body/home.tscn`, `menu_body/world.tscn`, `menu_body/search_results.tscn` — main panels
- `components/` — reusable UI: `bookmark.tscn`, `hint.tscn`, `loading_status.tscn`, `not_responding.tscn`, `round_button.tscn`, `tab.tscn`, `onboarding/`, `search/`

## Major script areas

`app/scripts/`:
| Folder/file | What it does |
|------|------|
| `app.gd` | App entry-point logic |
| `navigation.gd` | URL handling, gate navigation, history |
| `bookmark_saver.gd`, `data_saver.gd` | Persistence |
| `afk_manager.gd` | Idle detection |
| `string_tools.gd`, `url.gd` | Helpers |
| `platform.gd` | OS detection (`Platform.WINDOWS`, `Platform.LINUX_BSD`, `Platform.MACOS`) |
| `api/` | Backend HTTP API client |
| `networking/` | Lower-level networking utilities |
| `ui/` | UI controllers |
| `loading/` | Loading-screen logic |
| `debug_log/` | Debug output sink |
| `resources/` | Resource-class scripts (data containers) |
| `renderer/` | **Orchestrates the renderer process — the bridge to [[Renderer Process]]** |

## `app/scripts/renderer/` — the bridge

This folder is what makes the launcher a "browser" rather than just a Godot UI. Every file here exists to spawn, talk to, or display output from the [[Renderer Process]].

| File | Role |
|------|------|
| `renderer_manager.gd` | Spawns the renderer (`OS.execute_with_pipe`), tracks PID, kills it on exit |
| `renderer_executable.gd` | Resolves *which* renderer binary to run for a given gate's Godot version; downloads if missing; caches |
| `renderer_logger.gd` | Captures stdout/stderr from the renderer pipe |
| `process_checker.gd` | Watchdog for renderer liveness |
| `command_sync.gd` | Implements the launcher side of the `command_sync` IPC; dispatches commands from renderer (see [[Two-Process Model]] for the command vocabulary) |
| `input_sync.gd` | Forwards launcher-captured input events to the renderer over `input_sync` pipe |
| `render_result.gd` | The `TextureRect` displaying the renderer's framebuffer; owns the `TGExternalTexture` (see [[External Texture Sharing]]) |
| `unzip.gd` | Unzips downloaded renderer archives |

## How a gate visit hits these files

For the full runtime event sequence — open_gate → clear → switch_scene → spawn — plus what gets torn down vs reused when a second gate opens, see [[Gate Cycle]].


```
User clicks/types URL
       │
       ▼
navigation.gd / api/   ─── fetch .gate manifest, .pck
       │
       ▼
renderer_executable.gd ─── resolve+download matching renderer binary
       │
       ▼
GateEvents.ENTERED fires
       │
       ├──► render_result.gd            : create_external_texture()
       │                                  + bind command_sync, input_sync pipes
       │
       └──► renderer_manager.gd         : start_renderer() → OS.execute_with_pipe(...)
                                                                    │
                                                                    ▼
                                                          renderer process boots,
                                                          handshake completes
                                                          (see External Texture Sharing)
                                                                    │
                                                                    ▼
                                                  command_sync.gd receives
                                                  "first_frame" → fades in
                                                  the world view
```

## Project Settings notable bits

- Forward+ rendering is required (per the public docs; the launcher relies on the same RD external-texture path the renderer uses).
- Autoloads are visible at the top of `project.godot`; many of the events used here (e.g. `GateEvents`, `CommandEvents`) are autoload singletons.

## Where to look when adding a feature to the launcher UI

- New menu/page: add a `.tscn` in `app/scenes/menu_body/` and wire it via `navigation.gd`.
- New command from renderer: add to the renderer side (where it sends), then add a `match` arm in `app/scripts/renderer/command_sync.gd` and an event in `command_events`.
- Anything that touches the rendered framebuffer surface area: read [[External Texture Sharing]] first.
