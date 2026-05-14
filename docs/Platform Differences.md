---
tags: [platform, windows, macos, linux]
---

# Platform Differences

The two-process architecture has to bridge OS boundaries — every step of cross-process resource sharing differs per OS. This is the cheat sheet.

## At a glance

| Concern | Windows | macOS | Linux |
|---------|---------|-------|-------|
| GPU API | Vulkan only (renderer) | Vulkan via MoltenVK + Metal extension | Vulkan only |
| Shared GPU image handle | Win32 `HANDLE` (OPAQUE_WIN32) | `IOSurfaceRef` (Metal interop) | file descriptor (OPAQUE_FD) |
| Handle transport | `DuplicateHandle` into target PID, then int64 over named pipe | `IOSurfaceGetID` → uint32 over named pipe → `IOSurfaceLookup` on the other side | FD passing via `SCM_RIGHTS` over Unix socket (`flingfd` helper) |
| Pipe path | `pipe://renderer/<name>` (Win32 named pipe namespace) | `pipe:///tmp/<name>` (Godot's pipe URI on a Unix path) | `/tmp/<name>` (raw Unix path, no `pipe://`) |
| Sandbox | Not implemented (TODO — chromium-style) | Not implemented (TODO) | seccomp syscall allowlist (~100 calls) |
| Window invisibility | Window created without `WS_VISIBLE`; `show_window` no-op | `show_window`, `window_set_mode`, `window_set_flag` no-op | `show_window`, `window_set_ime_active` no-op |

## Windows

### Texture sharing
- Vulkan: `VK_EXTERNAL_MEMORY_HANDLE_TYPE_OPAQUE_WIN32_BIT`
- Image is created with a `VkExternalMemoryImageCreateInfo` `pNext`; memory is allocated via VMA with an export pool whose `pMemoryAllocateNext` is a `VkExportMemoryAllocateInfo`.
- After allocation, `vkGetMemoryWin32HandleKHR` returns a `HANDLE` that's *process-local*.
- To get it to the renderer, the launcher calls `DuplicateHandle(GetCurrentProcess(), src, target_proc, &dup, ..., DUPLICATE_SAME_ACCESS)`. This is why `send_filehandle` payloads on Windows are `path|target_pid` — we need the renderer's PID to call `OpenProcess(PROCESS_DUP_HANDLE, …)`.

### IPC
- Named pipes via Godot 4.5's `FileAccess` `pipe://` URI. Backed by `\\.\pipe\renderer\<name>`.
- The pipe directory is created at runtime by `RendererManager.start_process` (`DirAccess.make_dir_recursive_absolute("renderer")`).

### Driver constraints
- The renderer's hardcoded `rendering_driver = "vulkan"` means D3D12 is not currently an option *for the renderer*. The launcher (no `TG_RENDERER`) can use D3D12 if you set it via Project Settings or `--rendering-driver d3d12`. Useful as a workaround when the AMD/NVIDIA Vulkan driver of the day is broken.

### Handle leak edge case
- `OpenProcess` and the duplicated handle must be closed by the launcher after sending. `external_texture.cpp::send_filehandle` does both, with explicit cleanup of the duplicated handle on failure.

## macOS

### Texture sharing
- Vulkan via MoltenVK; uses Apple's Metal extension `VK_EXT_metal_objects`.
- `VkImportMetalIOSurfaceInfoEXT` / `VkExportMetalIOSurfaceInfoEXT` to bridge between `VkImage` and `IOSurfaceRef`.
- After image creation, `vkExportMetalObjectsEXT` populates `export_iosurface_info.ioSurface`.
- `IOSurfaceRef` is just a kernel object reference; export with `IOSurfaceGetID` → uint32, send over pipe, recipient calls `IOSurfaceLookup`.

### IPC
- `pipe:///tmp/<name>` — Godot's named-pipe URI on a Unix-style path.

### Quirks
- `forceUnbundledWindowActivationHackStep1` is suppressed in TG_RENDERER builds — otherwise Cocoa would foreground the renderer's invisible window.
- A separate macOS commit handles the renderer focus issue: `2aa356927f macos fix switching focus to SystemUIServer in sandbox`.

## Linux

### Texture sharing
- Vulkan: `VK_EXTERNAL_MEMORY_HANDLE_TYPE_OPAQUE_FD_BIT`
- `vkGetMemoryFdKHR` returns a file descriptor.
- File descriptors aren't naturally shareable between unrelated processes — Linux requires passing them as ancillary data over a Unix socket. The `flingfd` library (vendored in `godot/modules/the_gates/`) is the tiny helper that does the `sendmsg`/`recvmsg` dance.

### IPC
- `/tmp/<name>` — straight Unix socket path. (No `pipe://` URI scheme; raw paths used directly.)

### Sandbox
- The only platform with a real sandbox today. `Sandboxing::sandbox()` (in `sandboxing.cpp`) sets up a `SCMP_ACT_TRAP` seccomp filter and punches holes for ~100 syscalls observed during normal Godot operation. SIGSYS handler logs the disallowed syscall name.
- Notably permissive (sockets, signals, threads all allowed) — there's a comment in the source about not trusting a comprehensive denylist.

## Cross-platform code patterns to know

```cpp
#ifdef WINDOWS_ENABLED
   …Win32 path, including DuplicateHandle…
#elif MACOS_ENABLED
   …IOSurface path…
#else
   …Linux flingfd path…
#endif
```

Three-way branches like this appear in `external_texture.cpp`, `command_sync.h`, `input_sync.h`, etc. When adding a new IPC primitive, expect to need three implementations.

## Per-OS pipe address format reference

| Constant | Defined in | Windows | macOS | Linux |
|----------|------------|---------|-------|-------|
| `FILEHANDLE_PATH` | `external_texture.h` | `pipe://renderer/external_texture` | `pipe:///tmp/external_texture` | `/tmp/external_texture` |
| `COMMAND_SYNC_ADDRESS` | `command_sync.h` | `pipe://renderer/command_sync` | `pipe:///tmp/command_sync` | `pipe:///tmp/command_sync` |
| `INPUT_SYNC_ADDRESS` | `input_sync.h` | `pipe://renderer/input_sync` | `pipe:///tmp/input_sync` | `pipe:///tmp/input_sync` |

(Note `external_texture.h` is the only one that uses raw `/tmp/...` instead of `pipe:///tmp/...` on Linux — that's because the Linux external-texture transport is `flingfd` over a Unix socket, not Godot's pipe URI. The other two channels use Godot's pipe URI on all non-Win platforms.)
