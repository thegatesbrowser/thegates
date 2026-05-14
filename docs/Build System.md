---
tags: [build]
---

# Build System

Standard Godot SCons build, plus one new flag (`tg_renderer`). See `godot/SConstruct` and the canonical [Godot compiling docs](https://docs.godotengine.org/en/stable/contributing/development/compiling/) for everything not covered here.

## The two builds you need

From `godot/`:

```bash
# Editor / launcher binary
scons -j $(nproc) dev_build=yes tg_renderer=no compiledb=yes use_llvm=yes linker=lld disable_exceptions=no

# Renderer binary
scons -j $(nproc) dev_build=yes target=template_debug tg_renderer=yes compiledb=yes use_llvm=yes linker=lld disable_exceptions=no
```

(Copied from the parent README.) Substitute `target=template_release` for production renderer.

## Output binaries land in `godot/bin/`

Naming pattern: `godot.<os>.<target>[.<dev>][.renderer].<arch>[.llvm][.console].exe`

What you'll see on Windows after building both flavors:

| File | What it is |
|------|------------|
| `godot.windows.editor.dev.x86_64.llvm.exe` | Editor / launcher (run this to run `app/`) |
| `godot.windows.editor.dev.x86_64.llvm.console.exe` | Same with attached console — useful for `print_line` |
| `godot.windows.template_debug.dev.renderer.x86_64.llvm.exe` | Debug renderer build |
| `godot.windows.template_release.renderer.x86_64.exe` | Release renderer build |
| `godot.windows.template_release.renderer.x86_64.console.exe` | Release renderer with console — invaluable for debugging the renderer in isolation |
| `godot.windows.template_release.sandbox.x86_64.exe` | Older naming — `sandbox` was renamed to `renderer` (commit `6e487bc2bc`); these are leftovers |

Things to know:
- The `.renderer` suffix is added by `SConstruct` only when `tg_renderer=yes`.
- `.llvm` indicates the LLVM-clang toolchain was used (`use_llvm=yes`).
- `.console.exe` is a sibling Windows variant with a `mainCRTStartup` console subsystem — same code, useful to read `print_line` output without running from a terminal.

## SCons flags worth knowing

| Flag | Purpose |
|------|---------|
| `tg_renderer=yes/no` | OUR flag. Toggles the `TG_RENDERER` macro and renames output. See [[Custom Godot Fork]]. |
| `target=editor / template_debug / template_release` | Standard Godot build target |
| `dev_build=yes` | Symbols + dev tooling |
| `use_llvm=yes` | Use clang/LLVM toolchain |
| `linker=lld` | Use LLD for faster linking |
| `compiledb=yes` | Emit `compile_commands.json` for clangd / LSP — already present in repo root |
| `disable_exceptions=no` | Keep C++ exceptions on |
| `production=yes` | Production-tuned release defaults |

Run `scons --help` from `godot/` for the full list.

## Building the launcher project

The launcher is a Godot project, not a C++ build:
1. Run the editor binary (`godot.windows.editor.dev.x86_64.llvm.exe`).
2. Open the project at `app/project.godot`.
3. Run from there for development; export via `app/export_presets.cfg` for distribution.

## Per-OS build notes

- **Windows**: building works with both MSVC and LLVM toolchains. The included README uses LLVM/LLD, which is faster.
- **macOS**: Metal-related code in `external_texture` requires the Metal extension. Default function bodies for it ship via commit `9b5f90d209` so vanilla builds compile.
- **Linux**: Sandboxing depends on `libseccomp` headers being available at compile time.

## Cross-build / cross-test

There is no formal cross-compile setup documented in the parent README — each platform is built natively. CI presumably handles this; the `deployment/` folder probably has more detail.
