---
tags: [architecture, gdscript, app, patterns]
---

# Event Architecture

The most important architectural pattern in `app/`. Read it before writing any code that crosses object boundaries.

## The pattern, in one sentence

> Cross-cutting communication uses **`Resource` event buses with signals + `_emit` wrapper methods + state**, instantiated as `.res`/`.tres` files in `app/resources/`, and distributed by **`@export`** — not by autoload.

## Why this exists

Godot's two default ways to share state across objects are:
1. **Singletons / autoloads** — globally accessible, but invisible in the inspector, untyped at the call site, and create implicit coupling.
2. **`get_node("/root/...")` lookups** — fragile to scene refactors.

Both make the data flow invisible. This project's pattern instead treats event buses as **values you wire through the inspector**, the same way you'd wire any other configuration. You can see in any `.tscn` exactly which events a script is subscribed to. Refactors stay safe. Tests can swap in fakes.

## The recipe

A bus is a `Resource` subclass with three things: signals, an `_emit` wrapper for each, and any cached state.

```gdscript
extends Resource
class_name GateEvents

# 1. Signals — declared at top, snake_case
signal search(query: String)
signal open_gate(url: String)
signal gate_entered
signal first_frame
signal exit_gate

# 2. (Optional) Enums for closed sets the bus exposes
enum GateError {
    NOT_FOUND,
    INVALID_CONFIG,
    MISSING_PACK,
    MISSING_LIBS,
    MISSING_RENDERER
}

# 3. Cached state — what subscribers may need to query
var current_gate_url: String
var current_gate: Gate
var emitted_events: Array[Early] = []


# 4. _emit wrappers — one per signal. They (a) update state, (b) emit
func search_emit(query: String) -> void:
    clear_current_gate()
    current_search_query = query
    search.emit(query)


func gate_entered_emit() -> void:
    emitted_events.append(Early.ENTERED)
    gate_entered.emit()
```

### The wrapper rule

Callers **never** call `bus.signal_name.emit(...)` directly. They always go through `bus.signal_name_emit(...)`. The wrapper is the contract: it can update bookkeeping, normalize args (e.g. URL fixing), or fire downstream signals before emitting.

```gdscript
# GOOD
gate_events.open_gate_emit(url)

# BAD
gate_events.open_gate.emit(url)              # bypasses URL normalization + state update
```

Subscribers of course just do `gate_events.open_gate.connect(handler)` — no wrapper involved on the listening side.

## Storing instances on disk

Each bus is instantiated **once** as a `.res` (binary, compact) or `.tres` (text, diff-friendly) file under `app/resources/`:

```
app/resources/
├── gate_events.res        ← single shared instance of GateEvents
├── app_events.res
├── ui_events.res
├── command_events.res
├── api_settings.tres
├── bookmarks.tres
├── history.tres
├── renderer_executable.tres
└── tld_list.txt
```

- **`.res`** for instances modified at runtime (events — Godot loads them as a single shared instance).
- **`.tres`** for instances meant to be edited in the inspector (config Resources like `ApiSettings`).

## Wiring instances into scenes

Any node that needs the bus declares an `@export` slot and the `.tscn` references the `.res`:

```gdscript
extends Node


@export var gate_events: GateEvents
@export var app_events: AppEvents


func _ready() -> void:
    gate_events.open_gate.connect(on_open_gate)
    app_events.open_link.connect(on_open_link)
```

In the editor, the `gate_events` slot in the inspector is set to `res://resources/gate_events.res`. Because Godot resource loading is reference-shared by default, **every scene that exports the same `.res` gets the same instance** — they communicate by virtue of pointing at the same memory.

This is the architectural trick: the bus is *one instance*, but every script that needs it has a typed reference to it via `@export`.

## When to add a new bus vs. extend an existing one

We currently have:
- **`GateEvents`** — gate lifecycle (load, enter, first_frame, exit, error)
- **`AppEvents`** — app-level (open_link)
- **`UiEvents`** — UI state changes (size, mode, debug window, onboarding, typing/dragging flags)
- **`CommandEvents`** — commands flowing in from the renderer process (heartbeat, send_filehandle, set_mouse_mode, highlight_button)

Add a new bus when a feature has its own lifecycle and 3+ signals that don't fit any existing bus. Extend an existing bus when the new signal is conceptually within an existing domain.

Don't put commands from the renderer into `GateEvents`; that's what `CommandEvents` is for. The split is intentional and load-bearing — see [[Two-Process Model]].

## State on the bus

Buses can carry small amounts of cached state — usually "the latest value" of something that subscribers may want without subscribing:

```gdscript
# UiEvents
var current_ui_size: Vector2
var is_debug_window_opened: bool
var is_onboarding_requested: bool
var is_onboarding_started: bool
var is_typing_search: bool
var is_dragging_window: bool
```

The `_emit` wrappers update these before emitting:

```gdscript
func ui_size_changed_emit(size: Vector2) -> void:
    current_ui_size = size               # ← state update
    ui_size_changed.emit(size)           # ← then emit


func debug_window_opened_emit() -> void:
    is_debug_window_opened = true
    debug_window_opened.emit()
```

This means a late subscriber can ask `ui_events.current_ui_size` for the current value rather than waiting for the next change. Keep state to the bare minimum; buses are not databases.

## The `call_or_subscribe` pattern

For lifecycle events that may have *already happened* by the time a subscriber is ready (e.g. a node added late in the tree wants to react to "gate entered"), `GateEvents` provides:

```gdscript
gate_events.call_or_subscribe(GateEvents.Early.ENTERED, start_renderer)
```

Semantics: if the event has already been emitted in this session, call the callback now (with the cached `current_gate` if applicable). Otherwise, subscribe one-shot.

Implementation lives in `app/scripts/resources/gate_events.gd`. The `Early` enum names the events we track this way:

```gdscript
enum Early {
    INFO_LOADED,
    ICON_LOADED,
    IMAGE_LOADED,
    ALL_LOADED,
    ENTERED
}

var emitted_events: Array[Early] = []          # filled by _emit wrappers
```

Use `call_or_subscribe` whenever a subscriber must run logic *as if* it were present from the start, even if it joined late. Most renderer-related code uses it for `Early.ENTERED`.

## Forwarding pattern (event → emit chain)

Sometimes one bus's wrapper triggers another bus's wrapper. `GateEvents.open_gate_emit` is a clean example:

```gdscript
func open_gate_emit(url: String) -> void:
    clear_current_gate()
    current_gate_url = Url.fix_gate_url(url)
    open_gate.emit(current_gate_url)
    open_gate_app.emit(current_gate_url)        # ← also emits a second signal that only app.gd listens to
```

Useful when you have a "raw" signal everyone subscribes to plus a "decorated" one for a specific consumer that wants slightly different timing/args. Don't overuse — three `open_*` signals would be smell.

## Existing autoloads (grandfathered)

We have a few autoloads from before the event-bus pattern was established. They remain because they're conceptually services, not state:

```ini
[autoload]
Debug=                    ; logging service
DataSaver=                ; persistent KV store
FileDownloader=           ; download service with sessions
Backend=                  ; HTTP API client
AnalyticsEvents=          ; analytics service
AfkManager=               ; idle detector
HTTPClientPool=           ; pooled HTTP clients
Navigation=               ; URL/history dispatcher (subscribes to gate_events)
Url=                      ; URL parsing static methods
```

Two grandfathered patterns, both fine:
- **Pure-static "namespace" classes** loaded as autoloads (`Url`, `StringTools`-likes). Acceptable for stateless utility libraries.
- **Service nodes** that wrap something stateful (`AfkManager`, `Backend`, `FileDownloader`). Acceptable when the service genuinely is a singleton (e.g. a single download queue).

**Don't add new autoloads for new shared state.** Use the bus pattern.

## Anti-patterns to avoid

```gdscript
# BAD — emit directly, bypassing the wrapper's state update
gate_events.open_gate.emit(url)

# BAD — autoload for what should be a bus
# project.godot:
#   GameState = "*res://scripts/game_state.gd"
# game_state.gd:
#   var current_gate

# BAD — invisible coupling via global lookup
get_node("/root/SomeManager").do_thing()

# BAD — String-based signal connection (Godot 3.x style)
button.connect("pressed", self, "_on_pressed")

# BAD — adding both a wrapper-less signal and an emitter; do one or the other
signal foo
func emit_foo(): foo.emit()         # OK, this is a bus pattern
gate_events.foo.emit()              # if you do this, the wrapper isn't a contract anymore
```

## Quick checklist for a new event

1. Does it belong to an existing bus? If yes, add a `signal` and a matching `_emit` wrapper there. Done.
2. If it needs a new bus: create `app/scripts/resources/foo_events.gd` (`extends Resource`, `class_name FooEvents`).
3. Instantiate: in the editor, create `app/resources/foo_events.res` from the new class.
4. Wire: every script that needs it adds `@export var foo_events: FooEvents`, and the `.tscn` is updated to point that slot at `foo_events.res`.
5. Use: callers use `foo_events.signal_name_emit(...)`, listeners use `foo_events.signal_name.connect(...)`.

## Related

- [[GDScript Style Guide]] — for the surrounding code style
- [[Two-Process Model]] — `CommandEvents` is the launcher-side adapter for renderer→launcher commands
- [[Launcher App]] — file-by-file map of where buses are used
