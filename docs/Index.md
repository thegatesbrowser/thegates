---
tags: [meta, moc]
---

# Index — Map of Content

The starting point. Every note in the vault is reachable from here.

> **Note:** Fork-specific engine notes (Custom Godot Fork, Custom Godot Module, External Texture Sharing, Platform Differences, Build System, C++ Style Guide) live alongside the godot submodule in `../godot/notes/`. They are still part of this Obsidian vault when opened from the parent `thegates/` folder — wikilinks below resolve normally.

## Start here

- [[Architecture Overview]] — the one-page big picture
- [[Architecture Diagrams]] — Mermaid diagrams of the two-process model, handshake, and per-frame loop
- [[Repository Layout]] — what every folder under `~/Documents/Projects/thegates/` actually is

## How it runs

- [[Two-Process Model]] — launcher + renderer, why two processes, what flows between them
- [[External Texture Sharing]] — how a Vulkan-rendered framebuffer in one process becomes a `Texture2D` in another, with no CPU copy
- [[Renderer Process]] — what the sandboxed renderer build does differently from a normal Godot game
- [[Launcher App]] — the Godot project under `app/` that *is* the browser UI

## What we ship

- [[Gate Format and Lifecycle]] — what a `.gate` file is, how it's downloaded, why each gate ships its own renderer binary
- [[Build System]] — `scons` flags, build variants, output binaries

## The fork

- [[Custom Godot Fork]] — what's modified in `godot/` vs. upstream Godot 4.5
- [[Custom Godot Module]] — `modules/the_gates/`: the only new C++ module

## Per-OS specifics

- [[Platform Differences]] — Windows handles vs. macOS IOSurface vs. Linux file descriptors

## Working in this codebase

- [[Gotchas and Conventions]] — non-obvious things that bite. Read before debugging.

## Style and patterns (mandatory before writing code)

- [[GDScript Style Guide]] — the rules for `app/` GDScript. Strict.
- [[Event Architecture]] — how components in `app/` talk to each other. Read before touching any GDScript.
- [[C++ Style Guide]] — for `godot/`. Mostly defers to upstream Godot's docs + pre-commit.

A short [`CLAUDE.md`](../CLAUDE.md) at the repo root is the entry contract for AI agents — it points back here.

---

## Related external resources

- [TheGates user docs](https://docs.thegates.io) — product-level docs (gate format, quickstart, security model)
- [Godot 4.5 source docs](https://docs.godotengine.org/en/stable/) — for anything in `godot/` that we *haven't* modified
- [Vulkan external memory spec (Win32)](https://registry.khronos.org/vulkan/specs/latest/man/html/VK_KHR_external_memory_win32.html) — the mechanism behind [[External Texture Sharing]] on Windows
