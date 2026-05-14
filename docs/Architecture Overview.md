---
tags: [architecture]
---

# Architecture Overview

TheGates is a "3D web browser." A user enters a URL like `https://thegates.io/worlds/godot_platformer.gate`; the app downloads a Godot project (`.pck`) plus a sidecar `.gate` manifest, then runs that downloaded world inside a separate, sandboxable process. The browser UI itself is also a Godot project — so the whole stack is two cooperating Godot processes.

> For the rendered (and richer) version of the diagrams below, see [[Architecture Diagrams]] — same content as Mermaid, which Obsidian renders inline.

## One-screen mental model

```
┌────────────────────────────────────────┐    ┌────────────────────────────────────────┐
│  LAUNCHER process                       │    │  RENDERER process (per gate)            │
│  godot.windows.editor.dev...exe         │    │  godot.windows.template_release         │
│  (Godot built without TG_RENDERER)      │    │      .renderer.x86_64.exe               │
│                                         │    │  (Godot built WITH tg_renderer=yes)     │
│  Runs:  app/  (the browser project)     │    │  Runs:  the gate's downloaded .pck      │
│                                         │    │                                         │
│  • UI / 2D scenes (menu, search, tabs)  │    │  • Loads the gate's Godot project       │
│  • Bookmark + history storage           │    │  • Renders the 3D world                 │
│  • Spawns the renderer process          │    │  • Vulkan only (hardcoded)              │
│  • Forwards keyboard/mouse to renderer  │    │  • Window is invisible (WS_VISIBLE off) │
│  • Displays renderer's framebuffer      │    │  • Sandboxed (Linux: seccomp; others:   │
│    as a TextureRect in its own scene    │    │    sandboxing TODO)                     │
│                                         │    │                                         │
│         imports VkImage  ◄──────────────┼────┼── exports VkImage (shared GPU memory)   │
│                          HANDLE/FD/IOSurface│                                         │
│                                         │    │                                         │
│         InputEvents  ───────────────────┼───►│  receive_input_events()                 │
│                          (input_sync pipe)   │                                         │
│                                         │    │                                         │
│         Commands  ◄─────────────────────┼────┤  send_command(...)                      │
│                          (command_sync pipe) │     • send_filehandle                   │
│                                         │    │     • ext_texture_format                │
│                                         │    │     • first_frame                       │
│                                         │    │     • heartbeat                         │
│                                         │    │     • open_gate / open_link             │
│                                         │    │     • set_mouse_mode                    │
└────────────────────────────────────────┘    └────────────────────────────────────────┘
                                                              ▲
                                                              │ spawned by launcher with
                                                              │ OS.execute_with_pipe(
                                                              │   gate.renderer,
                                                              │   ["--main-pack", pack,
                                                              │    "--resolution", "WxH",
                                                              │    "--url", url, "--verbose"])
```

See [[Two-Process Model]] for what flows over each channel and [[External Texture Sharing]] for how the framebuffer is actually shared without copying through CPU.

## Why this design

> Browsers sandbox tabs. We sandbox worlds.

A `.gate` is untrusted user content. Running it in-process with the launcher would let any third-party world crash, exploit, or eavesdrop on the browser. Spinning up a separate renderer process gives us:

1. **Crash isolation.** Renderer dies → launcher shows "not responding," kills it, navigates away.
2. **Sandboxing.** The renderer process can be locked down (seccomp on Linux today; chromium-style sandbox on other OSes is in development per the [security model docs](https://docs.thegates.io/en/latest/about/security.html)).
3. **Per-gate engine version.** Each `.gate` declares which Godot version it needs (4.3 or 4.5). The launcher downloads the matching renderer binary and runs that — see [[Gate Format and Lifecycle]].
4. **Browser stays responsive.** UI never blocks on world-load.

## The clever bit

Browsers use IPC + bitmaps for tab compositing. We use **Vulkan external memory** instead — both processes have a `VkImage` backed by the same GPU allocation. The renderer writes; the launcher reads; no CPU round-trip. See [[External Texture Sharing]].

## Flow of a single gate visit

1. User enters URL → launcher fetches `.gate` manifest → downloads `.pck` and the matching renderer binary if not cached. ([[Gate Format and Lifecycle]])
2. Launcher's `RenderResult` (a `TextureRect`) allocates a Vulkan-external `TGExternalTexture` and parks it.
3. Launcher spawns renderer with `OS.execute_with_pipe(...)`. ([[Two-Process Model]])
4. Renderer connects to launcher's command pipe and asks for the texture handle.
5. Launcher `DuplicateHandle`s its Vulkan memory handle into the renderer's process and pipes it back. ([[External Texture Sharing]])
6. Renderer imports the same memory locally → both processes share one VkImage.
7. Each frame the renderer renders to its (invisible) screen, then `RD::screen_copy()`s into the shared texture; the launcher's `_process` blits it into its own scene texture; the `TextureRect` shader handles BGRA/RGBA differences.
8. Input events captured by launcher are pushed over `input_sync` and replayed inside the renderer.
9. Heartbeat pings keep the connection alive; if the launcher pipe closes, the renderer self-crashes (intentional — see [[Gotchas and Conventions]]).

## Where to look next

- Building any of this: [[Build System]]
- The 80% of code that's normal Godot: just read upstream docs
- The 20% that's ours: [[Custom Godot Fork]] (engine-side) and `app/` (browser-side, see [[Launcher App]])
