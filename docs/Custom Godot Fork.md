---
tags: [fork, engine]
---

# Custom Godot Fork

`godot/` is upstream Godot 4.5 plus a small, surgical set of changes. This note enumerates them so future-you (or an agent) can reason about *what's ours vs. upstream*. Anything not listed here is upstream — read [Godot's docs](https://docs.godotengine.org/en/stable/) for it.

## The diff, in shape

1. **A new SCons option**: `tg_renderer=False` — defines the `TG_RENDERER` macro when true. (`SConstruct`, line ~188.)
2. **A new module**: `modules/the_gates/` — see [[Custom Godot Module]].
3. **`#ifdef TG_RENDERER` blocks** sprinkled across `main/main.cpp` and the per-OS display servers. Greppable.
4. **New methods on `RenderingDevice`**: `external_texture_create`, `external_texture_import`, `screen_copy`. Implemented per-driver (currently Vulkan + Metal). See [[External Texture Sharing]].
5. Misc upstream contributions merged in (see commit log).

## Where to find each

### Build flag

```
godot/SConstruct
  ~line 188:  opts.Add(BoolVariable("tg_renderer", "TheGates renderer build", False))
  ~line 526:  if env.tg_renderer: env.Append(CPPDEFINES=["TG_RENDERER"])
  ~line 999:  if env.tg_renderer: suffix += ".renderer"        # naming the output binary
```

### `main/main.cpp` TG_RENDERER blocks

```
~line 150  : forward declarations for ext_texture / command_sync / input_sync globals
~line 296  : static TGExternalTexture *ext_texture = nullptr; (and command/input sync globals)
~line 2456 : rendering_driver = "vulkan"  ← hardcodes the Vulkan driver for renderer builds
~line 3240 : (skipped UI bits during setup)
~line 4323 : (skipped UI bits during start)
~line 4686 : the handshake — connect command_sync, send_command(...), recv_filehandle, import
~line 4970 : per-iteration work — first_frame/heartbeat, copy_from_screen, receive_input_events,
             poll_monitor (CRASH_NOW if disconnected)
```

### Per-OS display server tweaks

All do the same thing: when `TG_RENDERER` is defined, suppress everything that would make a window visible to the user, because the renderer's window must stay invisible (its frames go through the [[External Texture Sharing]] path).

| File | What's hidden |
|------|---------------|
| `platform/windows/display_server_windows.cpp` | `show_window` returns early; `_create_window` strips `WS_VISIBLE`; `window_set_mode` / `window_set_flag` no-op |
| `platform/macos/display_server_macos.mm` | `show_window`, `window_set_mode`, `window_set_flag` no-op |
| `platform/macos/godot_application.mm` | `forceUnbundledWindowActivationHackStep1` no-op |
| `platform/linuxbsd/x11/display_server_x11.cpp` | `show_window`, `window_set_ime_active` no-op |

### `RenderingDevice` additions

```
godot/servers/rendering/rendering_device.h         : declares external_texture_create/import + screen_copy on RD
godot/servers/rendering/rendering_device.cpp       : trampoline to the driver
godot/servers/rendering/rendering_device_driver.h  : driver-level interface
godot/drivers/vulkan/rendering_device_driver_vulkan.h
godot/drivers/vulkan/rendering_device_driver_vulkan.cpp
                                                    : the Vulkan implementation
                                                      (vmaCreateImage with VkExternalMemory*CreateInfo,
                                                       vkGetMemoryWin32HandleKHR /
                                                       vkExportMetalObjectsEXT)
```

The Metal-side IOSurface export uses `VkExportMetalObjectsEXT` — that's why `modules/the_gates/config.py` and the build defaults touch the Metal extension on macOS. See the commit `9b5f90d209` ("default function bodies to build with metal").

## What is *not* changed

- The renderer architecture (Forward+, Mobile, Compatibility) — all upstream.
- The shader compiler.
- The asset import pipeline.
- The editor itself.
- Networking, physics, audio.
- The vast majority of platform code.

So if you're debugging anything that's not on the list above, treat it as a **vanilla Godot 4.5 issue** — search the [Godot issue tracker](https://github.com/godotengine/godot/issues) first.

## Auditing the diff against upstream

If you ever need a complete, current diff vs. upstream Godot 4.5:

```bash
# in godot/
git diff 4.5-stable..HEAD --stat
```

(The merge commit `8ae0f74c2e` brought in `4.5-stable` from upstream. Anything `tg-master`-side of that is ours.)
