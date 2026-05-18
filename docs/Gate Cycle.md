---
tags: [gate, lifecycle, launcher]
---

# Gate Cycle

What happens at runtime when a gate opens, populates, and re-opens. Sibling to [[Gate Format and Lifecycle]] (which covers the `.gate` file shape) — this note covers the **event sequence** the launcher walks through every time the user navigates to a new gate, including the subtler bits (what gets torn down, what survives, why `emitted_events` exists).

Understanding this is load-bearing for anything that needs to react to a gate becoming current — renderer spawn, IPC bind, UI overlays, telemetry. It's also where the recent multi-gate test bug was hiding (see [[#Pitfalls]]).

## The triggers

`gate_events.open_gate_emit(url)` is the entry point for every gate switch. Three callers fire it:

| Caller | Where | When |
|---|---|---|
| User UI | `Navigation.open(url)` from URL bar / bookmark / link click | User explicitly opens a gate |
| Renderer command | `command_sync.gd` `"open_gate"` handler | A running gate's GDScript calls a launcher-bridge function asking to navigate (cross-gate links) |
| Autotest | `app/scripts/autotest.gd` | Test harness, multi-cycle test |

All three converge on the same `GateEvents.open_gate_emit(url)` method.

## What happens in one cycle

```
gate_events.open_gate_emit(url)
       │
       ▼
clear_current_gate()                ─── current_search_query = ""
                                        current_gate_url = ""
                                        current_gate = null
                                        emitted_events.clear()      ← critical
       │
       ├──► open_gate.emit(url)         ── listened by GateLoader (downloads
       │                                   .gate manifest, .pck, libraries,
       │                                   icon, image; fires Early.* events
       │                                   as each piece lands)
       │
       └──► open_gate_app.emit(url)     ── listened by App.gd:
                                            switch_scene(world_scene)
                                              ├─ queue_free every child of
                                              │  scenes_root  (the OLD world)
                                              └─ instantiate world_scene
                                                 (the NEW world)
```

After `switch_scene` returns:

- The OLD `world_scene` subtree (`RendererManager`, `CommandSync`, `InputSync`, `RenderResult`, `RendererLogger`, `ProcessChecker`, `Foreground`, etc.) is queue_free'd. Deferred — actually deleted at end of frame.
- The NEW `world_scene` subtree is `_ready`'d. Each child node subscribes to the `GateEvents` it cares about. Most use `call_or_subscribe(Early.<X>, callback)` — see [[#The Early events]].

Meanwhile the gate-loader pipeline is downloading assets in parallel. When each milestone lands it emits an `Early` event:

```
INFO_LOADED  ── gate config + manifest parsed
ICON_LOADED  ── icon image fetched
IMAGE_LOADED ── preview image fetched
ALL_LOADED   ── manifest + assets + .pck + renderer binary all on disk
ENTERED      ── renderer process spawned, gate_entered_emit called
FIRST_FRAME  ── renderer's tg_renderer_boot reached [RENDERER-READY]
```

Each emit appends to `emitted_events` (which is why `clear_current_gate()` resets it). Subscribers that arrived AFTER an event already fired use `call_or_subscribe` to back-fill — the callback runs immediately for already-emitted events, or registers a `CONNECT_ONE_SHOT` for future ones.

## The Early events

`GateEvents.Early` is the runtime contract for gate-load milestones. The pattern in callers is **always** `gate_events.call_or_subscribe(Early.<X>, callback)`, never `gate_events.<signal>.connect(...)` directly. Direct `.connect` connections accumulate across cycles; `call_or_subscribe` connects via `CONNECT_ONE_SHOT` for the current gate only.

```gdscript
# In Foo._ready():
gate_events.call_or_subscribe(GateEvents.Early.ALL_LOADED, start_renderer)
```

Two cases handled inside `call_or_subscribe`:

1. `emitted_events.has(Early.ALL_LOADED)` → fire `callback` immediately. The world scene was instantiated after the event had already fired (rare but happens when a node `_ready`s late).
2. Not yet emitted → `gate_loaded.connect(callback, CONNECT_ONE_SHOT)`. The callback fires when the signal next emits, then auto-disconnects.

`ENTERED` is the most-used one. It's what makes `command_sync.gd` bind its zmq socket, `process_checker.gd` start its bootup watchdog, `loading_status.gd` swap to the post-load UI, etc.

## Renderer spawn within a cycle

`RendererManager._ready` subscribes to `Early.ALL_LOADED`. When the gate's assets are all downloaded, `start_renderer(gate)` fires:

```
start_renderer(gate)
       │
       ▼
start_process(gate)
       │
       ├─ resolve user_dir = user://gates_storage/<gate-folder>
       ├─ broker = Sandbox.create()
       ├─ await broker.verify_binary(gate.renderer)
       │     └─ Signal; worker thread runs SHA-256 + pin check (fail-closed).
       │        Main loop stays responsive while the hash runs.
       ├─ broker.apply_renderer_acl(user_dir)
       ├─ policy = SandboxPolicy(rw_dir, ro_files=[pack], rw_files=[ipc sockets])
       ├─ info = broker.spawn_target(policy, gate.renderer, args)
       │     └─ Linux: fork() + execve() with TG_SANDBOX_* env vars
       │     └─ Windows: chromium TargetPolicy + BrokerServices::SpawnTarget
       ├─ renderer_pid = info["pid"]
       └─ gate_events.gate_entered_emit()
              │
              ▼
       ENTERED fires
              │
              ├─► CommandSync.socket_bind()     ── launcher BINDS zmq AF_UNIX
              ├─► InputSync.socket_bind()           sockets in user_data_dir
              ├─► RenderResult.create_external_texture()
              └─► ProcessChecker.start_bootup_check()
```

Meanwhile the renderer process runs `tg_renderer_boot` (see [[Renderer Process]]), CONNECTS to the launcher's sockets, imports the external texture, calls `Sandbox::lower_token()`, prints `[RENDERER-READY]`, and starts drawing. The first command back to the launcher is `ext_texture_format`, then `send_filehandle`, then eventually `first_frame` which triggers the launcher to fade the world view in.

## Re-opening a gate (cycle)

Re-opening is just a second `open_gate_emit` call. The full sequence:

```
─── cycle 1 → cycle 2 ───────────────────────────────────────────────

gate_events.open_gate_emit(url)               (autotest / UI / renderer cmd)
  │
  ├─ clear_current_gate()    (emitted_events cleared)
  ├─ open_gate.emit          (GateLoader starts downloading)
  └─ open_gate_app.emit
       │
       ▼
  switch_scene(world_scene)
       │
       ├─ queue_free old world's children   ← schedules deletion this frame
       │     │
       │     │  At end of frame, ~ in order of tree:
       │     ├─ RendererManager._exit_tree()
       │     │     └─ kill_renderer()
       │     │           └─ sandbox_broker.kill_target()  (SIGTERM to renderer)
       │     ├─ CommandSync._exit_tree()
       │     │     └─ close()  (zmq sock + monitor sock closed)
       │     ├─ InputSync._exit_tree()
       │     │     └─ close()
       │     └─ ... rest of world subtree freed
       │
       └─ instantiate world_scene  (fresh subtree)
              │
              │  Each child's _ready runs:
              ├─ RendererManager._ready
              │     └─ call_or_subscribe(Early.ALL_LOADED, start_renderer)
              ├─ CommandSync._ready
              │     └─ call_or_subscribe(Early.ENTERED, socket_bind)
              ├─ InputSync._ready
              │     └─ call_or_subscribe(Early.ENTERED, socket_bind)
              └─ RenderResult._ready, ProcessChecker._ready, etc.

Asynchronously: gate downloads finish → ALL_LOADED → start_renderer →
                                       new sandbox.spawn_target → new
                                       renderer process → first_frame
```

Key point: **the launcher's `CommandSync` / `InputSync` / `ExternalTexture` nodes are NEW each cycle**, not reused. The zmq socket files in `user_data_dir/` get `unlink + bind`'d by zmq each time. The renderer process is also new each time. The only things that survive cycles are autoloads (`GateEvents`, `CommandEvents`, `Navigation`, `DataSaver`, etc.) and App's persistent children.

## Pitfalls

- **`emitted_events` MUST be cleared on every `open_gate_emit`.** That's `clear_current_gate()`'s only job. Without the clear, the second gate-open sees stale `Early.<X>` flags from the previous gate and `call_or_subscribe` callbacks fire immediately for events that haven't actually re-fired yet.
- **Don't `.connect()` directly to `Early.*` signals in `_ready`.** Use `call_or_subscribe`. Direct `.connect` accumulates connections that never auto-clear, so each cycle adds another callback, fires N callbacks per emit, and leaks references.
- **`SceneTreeTimer` and child-of-world Timer nodes don't reliably fire across cycles.** `switch_scene` queue_free's the world subtree every cycle; timers anchored to scenes freed mid-tick get their delta accumulator out of phase, and long timers (10s+) silently miss. The autotest's deadline lives on a `Thread` for exactly this reason — anything that needs to fire on **wall time across cycles** must be wall-time-driven, not SceneTree-tick-driven. See `app/scripts/autotest.gd`.
- **Renderer kill happens during `_exit_tree`, not before `switch_scene` returns.** `queue_free` is deferred — the old `RendererManager._exit_tree` doesn't run until the end of the current frame. Until then, the OLD renderer is still alive. If you need to coordinate against the old renderer's death (rare), use `gate_events.exit_gate` instead.
- **The launcher's zmq socket files are reused, not per-gate.** They live at `user_data_dir/command_sync`, `input_sync`, `external_texture`. Each cycle the old `CommandSync.close()` releases the bind, the new `CommandSync.socket_bind()` re-binds. ZMQ does `unlink + bind` so the file is recreated cleanly.
- **Old renderer ↔ new renderer overlap.** Between `switch_scene`'s scheduled `queue_free` and the new renderer's `first_frame`, *there is no running renderer at all*. The world view stays black. The renderer-side IPC sockets aren't valid in this window — the new ones are bound but no peer is connected yet.

## Related

- [[Gate Format and Lifecycle]] — the `.gate` file format and what's on disk.
- [[Launcher App]] — the file-by-file map of `app/scripts/renderer/`.
- [[Renderer Process]] — what the renderer does after spawn.
- [[Two-Process Model]] — IPC command vocabulary + socket layout.
- [[External Texture Sharing]] — how the framebuffer crosses the process boundary each cycle.
