# TheGates browser

Free and open-source 3D internet browser build with Godot Engine <br/>
It connects game experiences together like world wide web and allows you to easily access them without installing

[Documentation](https://thegates.readthedocs.io) <br/>
[Other links](https://lnk.bio/thegates)

## Screenshots

<img src="screenshots\1-home.png" width="500"> <br/> <br/>
<img src="screenshots\2-loading.png" width="500"> <br/> <br/>
<img src="screenshots\3-in-game-ui.png" width="500"> <br/> <br/>

## Build

#### 1. Build godot submodule:

From `godot/`:

Editor / launcher:
```
python tools/build.py launcher
```

Renderer:
```
python tools/build.py renderer
```

`tools/build.py` wraps scons with the canonical flag combinations. Run `python tools/build.py --help` for release variants and flags (`--mac-intel`, `--no-sandbox`, `-j N`). It defaults to `-j (cpu_count - 2)` so the OS stays responsive during builds.

Godot 3.6 renderer (for gates declaring `godot_version = "3.6"`). `tg-3.6` is a branch of the same godot fork — like `tg-4.5` and the download-only `tg-4.3` — not a second submodule. The `the_gates` module, libzmq and the Chromium sandbox subset live in-tree on that branch. From `godot/`:

```
git checkout tg-3.6
python tools/build.py renderer
git checkout tg-4.5
```

Or use a worktree so the parent's `godot/` stays on the launcher branch:

```
git -C godot worktree add ../godot-3.6 tg-3.6
python godot-3.6/tools/build.py renderer --stage-to app/renderer
```

See `docs/Godot 3 Renderer.md`.

#### 2. Run project

Start compiled editor and open godot project inside **app** folder
