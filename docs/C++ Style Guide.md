---
tags: [style, cpp, fork]
---

# C++ Style Guide

For all C++ in `godot/`. **Match upstream Godot 4.5 exactly.** This is a fork; we don't have our own C++ style. The fork-specific code (the [[Custom Godot Module]] and the `#ifdef TG_RENDERER` blocks — see [[Custom Godot Fork]]) follows the same rules as upstream.

The authoritative sources, in priority order:

1. The repo's own enforced config in `godot/.clang-format`, `godot/.clang-tidy`, `godot/.editorconfig`, `godot/.pre-commit-config.yaml` — **truth lives in these files; this doc is a pointer**.
2. Godot's [Code style guidelines](https://contributing.godotengine.org/en/latest/engine/guidelines/code_style.html).
3. Godot's [C++ usage guidelines](https://contributing.godotengine.org/en/latest/engine/guidelines/cpp_usage_guidelines.html).
4. Godot's [Best practices for engine development](https://contributing.godotengine.org/en/latest/engine/guidelines/best_practices_for_engine_development.html).

If anything in this note conflicts with the upstream docs above, **the upstream docs win** — open a PR to fix this note.

## Tooling

The repo uses [pre-commit](https://pre-commit.com/). One-time setup:

```bash
cd godot
pip install pre-commit
pre-commit install
```

Then every commit auto-runs:

| Hook | What | Configured in |
|------|------|---------------|
| `clang-format` (v20.1.0) | C/C++/ObjC/Java formatting | `godot/.clang-format` |
| `clang-format-glsl` | GLSL shader formatting | `godot/misc/utility/clang_format_glsl.yml` |
| `ruff` (+ `ruff-format`) | Python (`SConstruct`, `SCsub`, build scripts) | upstream defaults |
| `mypy` | Python type checking | upstream defaults |
| `codespell` | Spell-check across all text | upstream defaults |
| `make-rst` | Doc XML → reST validation | local |

`clang-tidy` is wired but only runs on demand:

```bash
pre-commit run --hook-stage manual clang-tidy
```

There are also helper scripts under `godot/misc/scripts/`:
- `file_format.py` — checks line endings, BOMs, trailing whitespace
- `header_guards.py` — verifies `#pragma once` (since 4.5)
- `copyright_headers.py` — adds/checks the GPL header comment
- `check_ci_log.py` — what CI runs

## The rules — short version

If you've read upstream Godot's docs once, this section is enough.

| Aspect | Rule |
|--------|------|
| Standard | C++17 subset |
| Header guards | `#pragma once` (4.5+; **no** `#ifdef GUARD_H` style) |
| Indentation | Tabs (alignment uses tabs too) |
| Naming — types & namespaces | `PascalCase` |
| Naming — methods, vars, fields | `snake_case` |
| Naming — constants & macros | `UPPER_SNAKE_CASE` |
| Method parameters | `p_*` prefix for inputs, `r_*` for outputs |
| Includes | Class header → compatibility header → Godot headers (alphabetical, in `""`) → third-party (`""`) → system (`<>`); blank line between groups |
| Comments | Begin with a space; sentence case; end with `.`; wrap to ~100 chars |
| Braces | LLVM-derived (see `.clang-format`); attached braces (`if (cond) {`) |
| Line length | Soft 100; hard limit not enforced (`.clang-format` doesn't `ColumnLimit`) |
| `auto` | Forbidden except where unavoidable |
| Lambdas | Avoid unless clearly necessary |
| STL | Forbidden — use Godot containers (`Vector`, `HashMap`, `String`, `Ref<>`, etc.) |
| Exceptions | Disabled — no `try` / `catch` |
| RTTI | Avoid `dynamic_cast` — Godot has its own type system |

## Fork-specific conventions

These are *additional* rules for code we own:

### Where new code goes

Two places, no exceptions:

1. **`godot/modules/the_gates/`** — new C++ classes, IPC primitives, anything that's "the project's code." Module structure follows Godot's [module docs](https://docs.godotengine.org/en/stable/contributing/development/core_and_modules/custom_modules_in_cpp.html). See [[Custom Godot Module]].
2. **`#ifdef TG_RENDERER` blocks** in upstream Godot files — **only** when the change must hook into engine bootstrap or per-OS display server logic. Keep blocks short, greppable, and preferably co-located.

If your change doesn't fit one of those, you're probably writing engine improvements that should go upstream first. Discuss before merging.

### Class registration

Every GDScript-visible class is registered in `modules/the_gates/register_types.cpp`:

```cpp
void initialize_the_gates_module(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }

    GDREGISTER_CLASS(Sandboxing);
    GDREGISTER_CLASS(InputSync);
    GDREGISTER_CLASS(Command);
    GDREGISTER_CLASS(CommandSync);
    GDREGISTER_CLASS(TGExternalTexture);
}
```

Each class follows the upstream `GDCLASS(Foo, ParentType)` macro pattern, has a `static void _bind_methods()`, and uses `ClassDB::bind_method(D_METHOD("name", "arg"), &Foo::method)`.

### Per-OS branches

`#ifdef WINDOWS_ENABLED` / `#elif MACOS_ENABLED` / `#else` (Linux). Use `LINUXBSD_ENABLED` only when you specifically need to *exclude* Mac:

```cpp
#ifdef WINDOWS_ENABLED
    // Win32 path
#elif MACOS_ENABLED
    // IOSurface path
#else
    // Linux flingfd path
#endif
```

Three-way branches like this appear in `external_texture.cpp`, `command_sync.h`, `input_sync.h`. When adding a new IPC primitive, you'll need three implementations. See [[Platform Differences]].

### Headers and pNext chains (Vulkan-adjacent code)

When extending Godot's Vulkan driver (e.g. `external_texture_create` / `external_texture_import`), use the same `VkStructureType sType; void *pNext;` chaining pattern upstream uses, with brace-init and explicit field comments:

```cpp
VkExternalMemoryImageCreateInfo create_pnext = {
    /*sType*/ VK_STRUCTURE_TYPE_EXTERNAL_MEMORY_IMAGE_CREATE_INFO,
    /*pNext*/ nullptr,
    /*handleTypes*/ ext_handle_type
};
```

The `/*field*/` comments aren't strictly required, but match what's already in the file. Match what's there.

### Error handling

Use Godot's `ERR_FAIL_*` macros instead of `if (...) { print_line(...); return; }` patterns:

```cpp
ERR_FAIL_COND_V_MSG(!rid.is_valid(), ERR_CANT_CREATE, "Unable to create external texture");
ERR_FAIL_COND_V_MSG(filehandle == FileHandleInvalid, ERR_CANT_CREATE, "Unable to export filehandle");
```

Read upstream `core/error/error_macros.h` for the full list.

## Things that surprise people

- **No `try` / `catch`.** Exceptions are off. Use `Error` returns or `ERR_FAIL_*` macros.
- **No `std::string`, `std::vector`, etc.** Use `String`, `Vector<T>`, `HashMap<K,V>`, `LocalVector<T>`. The standard library is mostly off-limits.
- **No `auto`.** Even when type is "obvious" — write it out. Exception is genuinely impossible-to-spell types (e.g. lambda return types when lambdas are unavoidable).
- **No lambdas (mostly).** Free functions or member functions instead. Acceptable when used as `Callable` or for one-off internal use where extracting a function is genuinely worse.
- **`#pragma once`, not `#ifdef GUARD_H`.** Switched in Godot 4.5. The `header_guards.py` script will catch you.
- **Method parameters are `p_*` for in, `r_*` for out.** Old code may not follow this; new code must.
- **Forward-declare aggressively** in headers. Include the full type only in the `.cpp`. Reduces compile times.
- **Tabs, not spaces.** Both for indent *and* alignment. clang-format will fix it; don't fight it.

## What "match upstream" means in practice

When you're unsure how to format something:

1. Find a similar pattern elsewhere in `godot/` (same subsystem, ideally).
2. Match it.
3. Run `pre-commit run --files <your-changed-files>` before committing.
4. If clang-format reformats your code, accept the reformatting.

Reading existing module code (e.g. `godot/modules/openxr/`, `godot/modules/jolt_physics/`) is the fastest way to internalize the conventions.

## When to write GDScript vs. C++ in this project

- **GDScript** for app-level logic in `app/` — UI, navigation, gate lifecycle orchestration, anything user-facing.
- **C++** for engine extensions that need to live below GDScript (IPC primitives, Vulkan extensions, OS-level resource sharing, sandboxing) — anything that has to integrate with Godot internals or talk to OS APIs we don't have GDScript bindings for.

If you're tempted to add a C++ class for "performance," profile first. Most of the time GDScript is fine for app-level work.

## Related

- [[Custom Godot Fork]] — the actual list of fork-specific changes
- [[Custom Godot Module]] — `modules/the_gates/` contents
- [[Build System]] — how to build
- [[Platform Differences]] — when you need three implementations
