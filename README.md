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

Editor:
```
scons -j $(nproc) dev_build=yes tg_renderer=no compiledb=yes use_llvm=yes linker=lld disable_exceptions=no
```

Renderer:
```
scons -j $(nproc) dev_build=yes target=template_debug tg_renderer=yes compiledb=yes use_llvm=yes linker=lld disable_exceptions=no
```

#### 2. Run project

Start compiled editor and open godot project inside **app** folder
