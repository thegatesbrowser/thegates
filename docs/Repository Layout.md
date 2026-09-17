---
tags: [orientation]
---

# Repository Layout

The project lives under `~/Documents/Projects/thegates/`. It's a multi-repo workspace, not a monorepo — paths below are relative to that root.

```
thegates/
├── README.md            ← top-level "how to build" pointer
├── LICENSE
├── screenshots/         ← screenshots used in the parent README
├── godot/               ← Godot fork (submodule of upstream Godot Engine); branch tg-3.6 holds the 3.6 renderer
├── app/                 ← The launcher's Godot project (the browser UI itself)
├── deployment/          ← Export / package / upload scripts (see [[Release and Deployment]])
├── tests/               ← Integration harnesses (tests/godot3/ for the 3.6 renderer)
└── docs/                ← This vault
```

## `godot/` — the engine fork

A near-vanilla Godot 4.5 with the changes documented in [[Custom Godot Fork]]. The structure mirrors upstream Godot:

```
godot/
├── SConstruct           ← build system entry point — defines the `tg_renderer` flag
├── main/main.cpp        ← contains TG_RENDERER blocks that diverge from upstream
├── core/                ← upstream
├── scene/               ← upstream
├── servers/rendering/   ← upstream + a couple of additions for external textures
├── drivers/vulkan/      ← upstream + external_texture_create / external_texture_import
├── platform/            ← upstream + small TG_RENDERER tweaks (skip show_window etc.)
├── modules/the_gates/   ← OUR custom module (see [[Custom Godot Module]])
├── modules/...          ← all other modules upstream
├── thirdparty/          ← upstream
└── bin/                 ← built binaries land here (multiple variants — see [[Build System]])
```

## The Godot 3.6 renderer

Not a second submodule. `tg-3.6` is a branch of the `godot/` fork — like
`tg-4.5` and the download-only `tg-4.3` — based on upstream Godot 3.6.3, with
the module and its thirdparty vendored in-tree:

```
godot/ (branch tg-3.6)
├── SConstruct           ← tg_renderer option, TG_RENDERER define, .renderer suffix
├── main/main.cpp        ← TG_RENDERER blocks, --tg-ipc-dir / --tg-user-data-dir globals
├── tools/build.py       ← renderer / renderer-release profiles
├── modules/the_gates/   ← ipc, renderer, network, sandbox
└── thirdparty/          ← libzmq, cppzmq, flingfd, chromium-sandbox, vulkan
```

Build it from the branch (or a worktree) with `python tools/build.py renderer`.
See [[Godot 3 Renderer]].

`tests/` holds the integration harnesses; `tests/godot3/` is the 3.6 one
(`testgate/` serves a gate and renderer for end-to-end runs, `test_keycode_map.py`
checks the input translation table against both engines).

## `app/` — the browser project

A normal Godot 4.5 project that *is* the browser. It runs inside the launcher binary built from `godot/`. See [[Launcher App]] for the inner structure.

```
app/
├── project.godot
├── export_presets.cfg
├── addons/
├── app_icon/
├── assets/
├── resources/           ← Godot Resource files (data definitions, settings)
├── scenes/              ← UI scenes (menu, world, search, onboarding, …)
├── scripts/             ← GDScript: app logic
│   ├── app.gd           ← entry-point script
│   ├── navigation.gd
│   ├── networking/
│   ├── api/
│   ├── ui/
│   ├── loading/
│   ├── debug_log/
│   └── renderer/        ← orchestrates the spawned renderer process
├── shaders/             ← shaders used by the launcher UI (incl. RenderResult)
└── renderer/            ← runtime IPC pipe placeholders (Windows: pipe paths)
```

The `app/renderer/` *folder* on disk is just where Windows named-pipe placeholder files end up at runtime — `command_sync`, `external_texture`, `input_sync`. Don't confuse with `app/scripts/renderer/`, which is the GDScript that *manages* the renderer process.

## `deployment/`

The export → package → upload scripts that turn built binaries into the zips users
download. `build_release.py` is the orchestrator; `stage_renderer.py` /
`renderer_config.py` keep the bundled and server-side renderers in sync;
`upload_build.py` posts to the backend. Full breakdown of each script, the servers,
and the renderer-delivery model is in [[Release and Deployment]].

## `docs/`

What you're reading. New notes go in this folder. See [[README]] for conventions.
