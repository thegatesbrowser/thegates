---
tags: [architecture, ipc]
---

# Two-Process Model

TheGates runs as **two cooperating Godot processes**: the **launcher** (the browser UI) and the **renderer** (the world being visited). They are *both* Godot binaries built from the same `godot/` fork — but with different SCons flags so behave differently. See [[Build System]].

## The two binaries

| Role | Built from `godot/` with | What it does |
|------|--------------------------|--------------|
| Launcher | normal flags (NO `tg_renderer=yes`) | Runs `app/` — the browser project. Visible window. |
| Renderer | `tg_renderer=yes` | Runs a downloaded gate's `.pck`. Window is invisible. Hardcoded to Vulkan. Crashes if the launcher pipe dies. |

`TG_RENDERER` is the C preprocessor define injected by the build flag. Greppable across `godot/`.

## Spawning

Launcher → renderer is a parent → child process via Godot's `OS.execute_with_pipe`. From `app/scripts/renderer/renderer_manager.gd`:

```gdscript
return OS.execute_with_pipe(gate.renderer, [
    "--main-pack", pack_file,
    "--resolution", "%dx%d" % [render_result.width, render_result.height],
    "--url", gate.url,
    "--verbose"
])
```

`gate.renderer` is the path to a renderer binary specific to this `.gate` (each gate ships its own — see [[Gate Format and Lifecycle]]).

## IPC channels — three zmq sockets + one broker socketpair

Three of the four launcher↔renderer channels are libzmq `ipc://` PAIR sockets (AF_UNIX under the hood — on Windows that needs Win10 1803+ for `afunix.h`; libzmq's `wepoll` provides the I/O loop). cppzmq + libzmq are vendored under `godot/thirdparty/`. Direction by channel:

- `command_sync` and `input_sync`: launcher **binds**, renderer **connects**. On Windows the launcher stamps an Untrusted mandatory label (`S:(ML;;NW;;;S-1-16-0)`) + permissive DACL on the bound socket file via `SetNamedSecurityInfo`, otherwise Windows Mandatory Integrity Control blocks the sandboxed renderer's `connect()` with ACCESS_DENIED before any DACL check — `connect()` on AF_UNIX opens the file for write. See `socket_acl_win.cpp`. Refs: [AF_UNIX comes to Windows](https://devblogs.microsoft.com/commandline/af_unix-comes-to-windows/), [Mandatory Integrity Control](https://learn.microsoft.com/en-us/windows/win32/secauthz/mandatory-integrity-control). Only the connect side sets up a zmq monitor — wiring `zmq_socket_monitor` on the bind side breaks multi-gate on Windows (new bind never sees ACCEPTED).
- `external_texture`: renderer **binds**, launcher **connects**. One-shot per gate, both ends still at Medium IL when this happens (`recv_filehandle` runs before `LowerToken()`), so no label dance needed.
- `network_broker`: **inherited socketpair** — no filesystem rendezvous. The launcher creates `socketpair(AF_UNIX, SOCK_STREAM)` before `posix_spawn` (or `fork+execve` on Linux), dups the child end to a known FD number (currently 3) via `posix_spawn_file_actions_adddup2`, and passes `TG_BROKER_FD=3` as an env var. The launcher half stays in the broker thread; the renderer half is adopted by `RendererNetClient::install` pre-lockdown. Length-prefixed framed messages carry socket-open and DNS requests; kernel FDs travel via `SCM_RIGHTS`. See [[Network Isolation]] (in `godot/notes/Sandboxing/`).

| Channel | Address (Windows) | Address (macOS) | Address (Linux) | Purpose |
|---------|-------------------|-----------------|-----------------|---------|
| `command_sync` | `ipc://user://command_sync` | `ipc:///tmp/command_sync` | `ipc:///tmp/command_sync` | Renderer → launcher commands (asks for filehandle, signals first frame, heartbeats, opens links/gates) |
| `input_sync` | `ipc://user://input_sync` | `ipc:///tmp/input_sync` | `ipc:///tmp/input_sync` | Launcher → renderer input event forwarding |
| `external_texture` | `ipc://user://external_texture` (one-shot zmq PAIR) | `ipc:///tmp/external_texture` (one-shot zmq PAIR) | `/tmp/external_texture` (Unix socket via `flingfd`) | One-shot: launcher → renderer transmission of the GPU memory handle (see [[External Texture Sharing]]) |
| `network_broker` | named-pipe pair (Windows broker plumbing TBD) | inherited socketpair, child end at FD = `TG_BROKER_FD` | inherited socketpair, child end at FD = `TG_BROKER_FD` | All renderer socket creation + DNS resolution, mediated by the launcher's broker thread |

On Windows, `user://` is a marker that `tg_resolve_ipc_address` (in `godot/modules/the_gates/zmq_context.h`) rewrites to an absolute path before handing it to libzmq. The launcher passes its own (shallow) `OS::get_user_data_dir()` to the renderer via `--tg-ipc-dir <abs path>` so both ends agree on where the socket files live — kept shallow because AF_UNIX `sun_path` caps at 108 chars. The renderer's gate-side `user://` (for saves) is a separate per-gate path passed via `--tg-user-data-dir <abs path>` — see [[Renderer Process]]. macOS and Linux don't have the sandbox constraint today, so they use `/tmp` directly with no rewrite.


Linux `external_texture` is the one channel that doesn't go through zmq — it uses the `flingfd` helper to pass a file descriptor as ancillary data over a Unix socket, which zmq can't carry. The `network_broker` channel uses raw `AF_UNIX SOCK_STREAM` (not zmq) for the same reason: zmq doesn't expose SCM_RIGHTS ancillary data.

## Command vocabulary (`command_sync`)

The renderer sends commands to the launcher. The launcher's GDScript `CommandSync` handler in `app/scripts/renderer/command_sync.gd` dispatches them. Current commands:

| Command | Args | Meaning |
|---------|------|---------|
| `ext_texture_format` | `format: int` | Renderer tells launcher its screen format (RGBA8 / BGRA8) so launcher's shader can match swizzle |
| `send_filehandle` | `path: String` | Renderer asks launcher to allocate the shared texture and pipe its handle to `path` (on Windows, `path` includes `|<renderer-pid>` because of `DuplicateHandle`) |
| `first_frame` | — | Renderer has produced its first frame (used to fade in the gate UI) |
| `heartbeat` | — | Liveness ping every ~1 second |
| `set_mouse_mode` | `mode` | Renderer requests mouse mode change (e.g. captured) |
| `open_gate` | `relative_url` | Renderer asks browser to navigate to another gate (relative to current) |
| `open_link` | `url` | Renderer asks OS to open a non-gate URL (system browser) |
| `highlight_button` | `button_id` | Renderer asks launcher UI to highlight a button (onboarding hint) |

All command bodies are `Command` ref-counted objects (`godot/modules/the_gates/command.h`): `name: String`, `args: Array`. Serialized via Godot's variant binary encoding through the pipe.

## Lifetime contract

- Launcher binds all three pipes when a gate is entered (`GateEvents.ENTERED`).
- Renderer connects to those pipes at startup (`Main::start()` under `#ifdef TG_RENDERER`).
- Renderer's `command_sync->poll_monitor()` checks every iteration that the parent's pipe is still alive. If the parent disappears, the renderer **deliberately crashes** with `CRASH_NOW_MSG("CommandSync peer disconnected. Exiting child.")` — a hack documented as "to avoid hanging because of uncleaned pipes created by `OS::execute_with_pipe`." See [[Gotchas and Conventions]].
- Launcher kills the renderer with `OS.kill(renderer_pid)` on tab close or app exit.

## What does NOT cross the pipe

- **Pixels.** Pixels never travel through the pipe — they live in shared GPU memory. The pipe only carries the *handle* to that memory once, at startup. See [[External Texture Sharing]].
- **Audio.** Audio routing between processes is not (yet?) covered by this vault. Worth investigating before changing audio paths.
- **Filesystem.** The renderer reads its `.pck` directly from disk (`--main-pack` arg). The launcher doesn't proxy file I/O.
