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

#### 2. Run project

Start compiled editor and open godot project inside **app** folder
