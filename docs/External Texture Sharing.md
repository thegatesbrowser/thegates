---
tags: [architecture, ipc, gpu, vulkan]
---

# External Texture Sharing

The most non-obvious part of the system. Two processes share a single Vulkan-allocated texture so the renderer can write frames and the launcher can sample them with **zero CPU copy**.

This is what `godot/modules/the_gates/external_texture.cpp` and the matching `external_texture_create` / `external_texture_import` additions to `godot/drivers/vulkan/rendering_device_driver_vulkan.cpp` exist for. See [[Custom Godot Fork]] for the engine-side diff.

## The mechanism, one screen

```
LAUNCHER process                                    RENDERER process
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. RenderResult.create_external_texture()
       │
       ▼
   ext_texure = TGExternalTexture.new()
   ext_texure.create(format, view)
       │
       ▼
   RD.external_texture_create(...)
       │
       ▼
   ┌────────────────────────────┐
   │ vmaCreateImage with       │
   │  pNext = VkExternalMemory- │
   │   ImageCreateInfo          │
   │   handleTypes = OPAQUE_X   │
   │ vkGetMemoryWin32HandleKHR  │
   │  → returns HANDLE          │  ◄─── shared GPU allocation lives here
   └────────────────────────────┘
       │
       ▼
   filehandle = HANDLE                           2. (started later by launcher)
                                                    spawn renderer with --main-pack ...
                                                          │
                                                          ▼
                                                    Main::start() under TG_RENDERER:
                                                    command_sync->socket_connect()
                                                    command_sync->send_command(
                                                       "send_filehandle",
                                                       [path|renderer_pid])
                                                          │
                                                          │ (over command_sync pipe)
       ◄──────────────────────────────────────────────────┘

3. command_sync receives "send_filehandle"
       │
       ▼
   RenderResult.send_filehandle(path)
       │
       ▼
   ext_texure.send_filehandle(path|renderer_pid)
       │
       ▼
   DuplicateHandle(GetCurrentProcess(), HANDLE,
                   renderer_proc, &dup, ..., DUPLICATE_SAME_ACCESS)
       │
       ▼
   pipe.connect(path); pipe.queue_message(dup_handle_int64); pipe.poll()
       │
       │ (over external_texture pipe)
       └────────────────────────────────────────────────►  4. recv_filehandle(FILEHANDLE_PATH) blocks
                                                              │
                                                              ▼
                                                          ext_texture->import(format, view)
                                                              │
                                                              ▼
                                                          RD.external_texture_import(... HANDLE ...)
                                                              │
                                                              ▼
                                                          ┌────────────────────────────┐
                                                          │ vmaCreateImage with        │
                                                          │  pNext = VkImportMemoryWin32-│
                                                          │   HandleInfoKHR            │
                                                          │   handle = imported HANDLE │
                                                          └────────────────────────────┘
                                                              │
                                                              ▼  Both processes now back
                                                              │  the *same* GPU memory
                                                              ▼
5. (every frame, _process)                         (every frame, in Main::iteration)
   ext_texure.copy_to(texture_rid)                 ext_texture->copy_from_screen()
   = RD.texture_copy(local, shared, ...)           = RD.screen_copy(shared, ...)
                                                                 │
                                                                 ▼
                                                          renderer's invisible swapchain
                                                          contents are blitted into the
                                                          shared image; launcher's next
                                                          _process sees fresh pixels
```

## Per-platform handle types

The same conceptual flow, three different OS primitives:

| Platform | Vulkan handle type | OS object | Transport |
|----------|-------------------|-----------|-----------|
| Windows | `VK_EXTERNAL_MEMORY_HANDLE_TYPE_OPAQUE_WIN32_BIT` | `HANDLE` (Win32) | `DuplicateHandle` into target PID, then int64 over pipe |
| macOS | `VK_EXPORT_METAL_OBJECT_TYPE_METAL_IOSURFACE_BIT_EXT` | `IOSurfaceRef` | `IOSurfaceGetID` → uint32 over pipe → `IOSurfaceLookup` |
| Linux | `VK_EXTERNAL_MEMORY_HANDLE_TYPE_OPAQUE_FD_BIT` | file descriptor | `flingfd` (FD passing over a Unix socket — see `godot/modules/the_gates/flingfd.h`) |

In code these are unified as `OPAQUE_X` (`X` = the platform's primitive). See `external_texture.h`'s `FILEHANDLE_PATH` and `external_texture.cpp`'s `send_filehandle` / `recv_filehandle`. Per-platform notes in [[Platform Differences]].

## Why per-OS handle passing is even necessary

Vulkan can *create* a HANDLE / FD / IOSurface for an image that you've allocated, but the OS doesn't let you just hand a `HANDLE` value to another process — it's a process-local table index. Each OS has its own way to ferry the underlying kernel/IOKit reference across:
- Windows: `DuplicateHandle` writes a new entry in the target's handle table.
- Linux: file descriptors travel over `SCM_RIGHTS` ancillary messages on Unix sockets — `flingfd` is the helper.
- macOS: IOSurface IDs are global within a session; just pass the integer.

## Format negotiation

The renderer's screen format depends on the OS swapchain (RGBA8 on some, BGRA8 on others). The renderer queries `RD::screen_get_format()` and sends it to the launcher via `ext_texture_format` *before* the launcher allocates. The launcher's display shader has an `ext_texture_is_bgra` uniform and swizzles accordingly — see `app/shaders/` and `RenderResult.set_texture_format()`.

The shared texture is currently fixed to `DATA_FORMAT_R8G8B8A8_UNORM` on the launcher side (see `RenderResult.create_external_texture()`); the BGRA-vs-RGBA distinction is resolved in the sampling shader instead of by reformatting the shared image. Worth knowing if you ever change format.

## Gotchas

- **Renderer allocates the texture? No — the launcher does.** Even though the renderer is the one *writing* pixels, the launcher allocates and exports the GPU memory, and the renderer *imports* it. This direction is intentional: the launcher is the texture's "owner" and outlives any single renderer process.
- **The renderer's `recv_filehandle` is blocking.** It will sit there until the launcher pipes it the handle. If the launcher crashes mid-handshake, the renderer hangs — which is part of why the heartbeat + intentional self-crash exist.
- **The handshake is fragile to ordering.** Renderer sends `ext_texture_format` first, then `send_filehandle`, then blocks. Launcher must process commands fast enough to actually allocate the texture before the renderer's `recv_filehandle` times out. There's a deliberate `await get_tree().process_frame` x3 in `create_external_texture()` to give Godot's resource cleanup time to settle on scene switches.
- **Window resize** is *not* currently handled by reallocating the shared texture (size is locked to the launcher's `RenderResult` window size at gate-entry time, with `--resolution` passed to the renderer). Confirm this assumption before wiring up resize.
