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
├── godot/               ← Godot fork (submodule of upstream Godot Engine)
├── app/                 ← The launcher's Godot project (the browser UI itself)
├── deployment/          ← Deployment / packaging scripts (not covered here yet)
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

Out of scope here — see commit history and any inline READMEs in that folder.

## `docs/`

What you're reading. New notes go in this folder. See [[README]] for conventions.
