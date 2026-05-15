---
tags: [style, gdscript, app]
---

# GDScript Style Guide

Style and structure rules for **all GDScript in `app/`**. The renderer's GDScript is supplied by gates and is out of scope.

This is a **strict superset** of the [official Godot GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html). Read that first; the rules here add on top and override where they differ. Anything not addressed here defers to upstream Godot.

> **Required companion reading:** [[Event Architecture]] — the project's most important architectural pattern.

## TL;DR — the rules that bite first

1. **Reference nodes via `@export var foo: NodeType`. Never `$NodePath`. Never `get_node()`.** One existing `$AnimationPlayer` line in `hint.gd` is grandfathered. Don't add a second.
2. **Two blank lines between every function**, after the header block, after the var block. Consistent with Godot's official guide; we're stricter about enforcing it.
3. **Type hints everywhere.** No untyped `var x = 5` in committed code. Use `:=` only for inferred locals.
4. **No new autoloads.** Use the [[Event Architecture]] pattern (`Resource` + `_emit` wrappers + `@export`) instead.
5. **Logging is `Debug.logclr` / `Debug.logerr` / `Debug.logr`.** Never raw `print()` or `printerr()`.

The rest of this doc explains why and the fine print.

---

## File header order

Every `.gd` file follows this exact order, with blank lines as shown:

```gdscript
extends Control                  # 1. extends — always first
class_name MyComponent           # 2. class_name — second, OR commented out (see below)

signal some_event(arg: Type)     # 3. signals
signal another_event

const SOME_CONSTANT := "value"   # 4. constants (UPPER_SNAKE_CASE)
const OTHER_CONSTANT = 42

enum Mode { A, B, C }            # 5. enums

@export var some_node: Control   # 6. @export properties first
@export var some_resource: GateEvents
@export_group("Debug")           # 6a. @export_group for inspector organization
@export var debug_flag: bool

var instance_state: int          # 7. plain vars
var another_var: bool

@onready var derived = some_node.size  # 8. @onready (rare; only for derived state)


func _ready() -> void:           # 9. lifecycle methods (_init, _enter_tree, _ready, _input, _process, _physics_process, _exit_tree)
    pass


func public_method() -> void:    # 10. public methods
    pass


func _on_signal_handler() -> void:  # 11. private/handler methods (Godot's _on_X_pressed convention OK)
    pass


func _exit_tree() -> void:       # 12. cleanup last
    pass
```

### When to comment out `class_name`

Some scripts are loaded as autoloads in `project.godot` (e.g. `navigation.gd`, `data_saver.gd`, `afk_manager.gd`). Autoloading **and** `class_name`-ing creates a name collision. Convention:

```gdscript
extends Node
#class_name Navigation        ← commented out because the autoload is named "Navigation"
```

Keep the comment so future-you knows the script *would* be class-named if not for the autoload.

## Two blank lines between functions

Universal in this repo. No exceptions:

```gdscript
func foo() -> void:
    pass


func bar() -> void:                  # 2 blank lines above this
    pass
```

`gdformat` defaults to one blank line. Don't run it without overriding.

## Naming

| Thing | Convention | Example |
|-------|------------|---------|
| Files | `snake_case.gd` | `bookmark_saver.gd` |
| Classes (`class_name`) | `PascalCase` | `class_name BookmarkSaver` |
| Functions | `snake_case()` | `func save_bookmarks() -> void:` |
| Variables | `snake_case` | `var current_url: String` |
| Constants | `UPPER_SNAKE_CASE` | `const AFK_TIMEOUT_SEC = 180` |
| Signals | `snake_case` (verb or past-tense) | `signal gate_entered`, `signal updated` |
| Enums | `PascalCase` for type, `UPPER_SNAKE_CASE` for values | `enum UiMode { INITIAL, FOCUSED }` |
| Boolean vars | start with `is_` / `has_` / `should_` / `was_` | `var is_typing_search: bool` |
| Signal handlers | `_on_<source>_<signal>()` (Godot's editor default) | `_on_button_pressed()` |
| Private-ish methods | no special prefix; just don't expose them in interfaces. Godot has no `private` keyword. | `func collect_boards() -> void:` |
| Local vars shadowing instance vars | underscore-prefix the parameter | `func show(_url): url = _url` |
| Unused signal/callback args | underscore-prefix | `func cb(_arg, used): ...` |

## Type hints — everywhere

```gdscript
# GOOD
@export var gate_events: GateEvents
var current_url: String
var bookmarks: Array[Gate] = []
const AFK_TIMEOUT_SEC: int = 180          # explicit when type isn't obvious

func load_gate(gate_url: String) -> void:
    var session := FileDownloader.create_session()    # := for inferred locals
    var name: String = derive_name()                  # explicit when value isn't a literal of the obvious type

# BAD
var current_url                            # untyped
var x = 5                                  # untyped, even if obvious
func foo(arg):                             # untyped param, missing return type
```

`-> void` for procedures, `-> Variant` only when truly polymorphic. Never omit return type.

For typed arrays: `Array[Gate]` not `Array`.

## `@export` for everything reference-like

This is the project's signature pattern. **Almost every cross-object reference uses `@export`** — including child node references, sibling references, scene references, and shared resources.

```gdscript
# GOOD — typical script header
@export var gate_events: GateEvents          # event bus (shared Resource)
@export var renderer: RendererExecutable      # configuration Resource
@export var icon: TextureRect                 # child node — wired in the .tscn
@export var bookmark_scene: PackedScene       # scene to instantiate
@export_dir var save_dir: String              # filesystem dir picker
@export_group("Debug")                        # inspector grouping
@export var show_always: bool

# BAD — what we don't do
@onready var icon = $VBoxContainer/HBoxContainer/Icon  # fragile path
var icon = get_node("../Icon")                          # fragile path, untyped
const SCENE = preload("res://scenes/foo.tscn")          # use @export var foo: PackedScene instead
```

**Why:** the inspector becomes the wiring layer. Refactors that move nodes around don't break scripts. Scenes are self-documenting.

### When `@onready` *is* OK

Only for derived state from `@export` vars or other locals — never for `get_node` lookups:

```gdscript
@export var save_dir: String
@export var bookmarks: Bookmarks

@onready var path = save_dir + "/" + bookmarks.resource_path.get_file()   # OK
@onready var start := Vector2(start_scale, start_scale)                   # OK
```

There are exactly **4** `@onready` uses in the entire `app/` codebase. Don't add many more.

### `$NodePath` is essentially banned

There is exactly **one** `$NodePath` use in `app/` (`hint.gd::$AnimationPlayer.play("Bounce")`), grandfathered from before the convention. **Don't add more.** Convert any you encounter to `@export var animation_player: AnimationPlayer`.

## Constants and enums

```gdscript
# Constants — module-level, UPPER_SNAKE_CASE, prefer typed but := also fine
const AFK_TIMEOUT_SEC = 180
const LOG_FOLDER := "user://logs"
const PRINT_LOGS_ARG := "--renderer-logs"
const SHOWN = Color(1, 1, 1, 1)               # Color constants are common
const HIDDEN = Color(1, 1, 1, 0)

# Enums — PascalCase type, UPPER_SNAKE_CASE values
enum UiMode {
    INITIAL,
    FOCUSED
}

# Enum without name = anonymous, used for namespacing constants on a class
class_name Platform
enum {
    WINDOWS,
    MACOS,
    LINUX_BSD,
    ANDROID,
    IOS,
    WEB
}
```

Enums in `Resource` event classes commonly carry semantic meaning (e.g. `GateEvents.GateError`). Iterate them with `EnumName.keys()[index]` if you need string names.

## Static utility classes

Pure-namespace utility "classes" extend `Node` (or `RefCounted`) and contain only `static` methods + `static var`s. Used as namespaces:

```gdscript
extends Node
class_name Platform


static func is_windows() -> bool:
    return get_platform() == WINDOWS


static func get_platform() -> int:
    match OS.get_name():
        "Windows", "UWP":
            return WINDOWS
        ...
        _:
            assert(false, "No such platform")
            return -1
```

Existing examples: `Platform`, `StringTools`, `Url`, `FileTools`. Call as `Platform.is_windows()`.

## Resource classes (data with optional state and signals)

Many "data" classes are `Resource` subclasses, which lets them be saved as `.tres` / `.res` files and dropped into the inspector via `@export`:

```gdscript
extends Resource
class_name Gate

@export var url: String:
    set(value): url = Url.fix_gate_url(value)   # inline setter — common pattern

@export var title: String
@export var description: String

# Runtime-only state (not exported, not serialized)
var resource_pack: String
var renderer: String


# Static factories with underscore params to avoid shadowing
static func create(_url: String, _title: String, _description: String) -> Gate:
    var gate = Gate.new()
    gate.url = _url
    gate.title = _title
    gate.description = _description
    return gate
```

The event buses (`GateEvents`, `AppEvents`, `UiEvents`, `CommandEvents`) are also `Resource` classes — see [[Event Architecture]] for the full pattern.

## Logging

```gdscript
Debug.logr(msg)                      # plain (uses print_rich)
Debug.logerr(msg)                    # error
Debug.logclr(msg, Color.DIM_GRAY)    # colored

# Color constants
Debug.SILENT_CLR                     # for low-priority noise
Debug.WARN_CLR                       # for warnings
Debug.ERROR_CLR                      # rarely needed; logerr already colors
```

Common color choices in actual code: `Color.DIM_GRAY` (silent), `Color.GRAY` (silent-ish), `Color.GREEN` (gate boundary), `Color.RED` / `Color.MAROON` (error), `Color.SANDY_BROWN` (received command), `Color.YELLOW` (warn).

Format strings prefer `"%dx%d" % [w, h]` over concatenation when interpolating.

`print()`, `print_rich()`, `printerr()` are reserved for `debug.gd` itself. Don't use them elsewhere.

## Connecting to signals

```gdscript
# GOOD — direct method connection
button.pressed.connect(on_pressed)

# GOOD — inline lambda for trivial handlers (and we use lambdas freely)
gate_events.search.connect(func(_query): switch_scene(search_results))
focus_button.pressed.connect(func(): request_focus.emit())

# GOOD — bind for partial application
gate_events.exit_gate.connect(new.bind(""))
boards[i].request_focus.connect(animate_to_board.bind(i))

# GOOD — one-shot connections
gate_loaded.connect(callback, CONNECT_ONE_SHOT)

# DON'T — String-based dispatch via call/connect("name") in new code
button.connect("pressed", self, "_on_pressed")     # legacy 3.x style
```

For unused parameters in handler signatures use `_`:

```gdscript
func on_progress(url: String, body_size: int, _downloaded_bytes: int) -> void: ...
```

For "swallow extra arg" (e.g. signal passes a value you ignore):

```gdscript
func unhighlight(_unbind: String = "") -> void: ...
gate_events.search.connect(unhighlight)        # passes a String we don't care about
```

## Single-line `if`

We use single-line `if cond: stmt` heavily for guards and trivial branches:

```gdscript
# GOOD
if not is_visible_in_tree(): return
if disabled: disable()
else: enable()

# GOOD — multi-statement on one line is OK with `;`
starred_gates.erase(gate); continue

# Multi-line when there's real work
if is_special and gate_events.current_gate_url.is_empty():
    special_effect.visible = true
    jump_animation.start_jump_animation()
else:
    special_effect.visible = false
    jump_animation.stop_jump_animation()
```

Use early-return guard style aggressively. A long `if X: do_thing` block is often cleaner as `if not X: return` followed by the work.

## Async / await

`async`/`await` are first-class in this codebase:

```gdscript
func load_icon(c_gate: ConfigGate) -> void:
    gate.icon = await FileDownloader.download(c_gate.icon_url, 0.0, false, active_session)
    gate_events.gate_icon_loaded_emit(gate)

# Common timer pattern
await get_tree().create_timer(INITIAL_DELAY).timeout

# Wait for next frame (used to defer Vulkan resource cleanup, etc.)
await get_tree().process_frame
await get_tree().process_frame    # multiple frames if needed for resource lifecycle
```

Don't fire-and-forget without a session/cancellation handle if the call could outlive the caller — see how `gate_loader.gd` uses `FileDownloader.create_session()` + `cancel_session()` in `_exit_tree`.

## Tweens

```gdscript
# Always: store, kill old, create new
var tween: Tween

func animate() -> void:
    if is_instance_valid(tween): tween.stop()
    tween = create_tween()
    tween.set_parallel(true)                                        # if multiple props in parallel

    tween.tween_property(self, "scale", Vector2.ONE, duration) \
        .set_trans(Tween.TRANS_SINE) \
        .set_ease(Tween.EASE_IN_OUT)
```

Always check `is_instance_valid` before stopping a previous tween. Always assign the new tween back to the var.

## Cleanup conventions

`_exit_tree` is the standard cleanup hook. Disconnect signals you connected, free timers/threads/sockets you opened, save state if applicable.

```gdscript
func _exit_tree() -> void:
    FileDownloader.progress.disconnect(on_progress)
    FileDownloader.cancel_session(active_session)
```

Resources don't get `_exit_tree`; the moral equivalent is destructor-like behavior at usage site or a manual `close()` method (e.g. `InputSync.close()`).

## Comments

**The codebase is nearly comment-free, and that's the rule, not an accident.** Across `app/` there are roughly 1–2 comment lines per 100 LOC, and the modal function has zero. Match that density.

**The real test is intent, not line count: would this comment make more sense in the commit message?** If yes, delete it and let `git log` carry it. Comments that justify a change you just made age into noise — they describe the diff, not the code. Comments that name an invariant the symbol can't carry stay true regardless of what changed:

```gdscript
# BAD — PR-description prose pretending to be a code comment
# sandbox-spawned children have no inherited stdio handles — they write their own log file
if pipe.has("stdio") and pipe.has("stderr"):
	start_reading_pipes()


# GOOD — names an invariant the symbol can't carry, true regardless of edits
# only for app.gd, called after open_gate
signal first_gate_open_started
```

Multi-line `#` blocks are usually a tell — agents reach for them when explaining "why I did this." If you find one in front of you, the right move is almost always delete (the commit message explains itself) or move the prose into the relevant note under `docs/` and let that be the source of truth.

```gdscript
# BAD — multi-line block narrating a fix; AI smell, delete it
# Use a per-renderer-spawn ipc subdir and unique monitor endpoint so
# nothing about the previous gate's sockets contaminates the new one.
# Without this, the third and later gate openings on Windows don't
# receive any commands from the renderer.


# GOOD — one line, lowercase, no period, names a constraint the symbol can't carry
# only for app.gd, called after open_gate
signal first_gate_open_started

# might be empty icon
signal gate_icon_loaded(gate: Gate)

# local path where libs downloaded
@export var libs_path: String


# GOOD — section divider labeling a multi-line phase within a function (file_tools.gd)
# List directory content
var err : Error
dir.list_dir_begin()
var file_name = dir.get_next()
while file_name != "":
	...
	file_name = dir.get_next()

# Remove current path
err = dir.remove(path)
if err != OK: Debug.logerr("Error removing: " + path)
```

Section dividers exist at multiple scopes and are all the same pattern: labelling a *group* of related lines so a human can scan the file or function in chunks. Between top-level symbols (`analytics_events.gd`'s `# APP` / `# SEARCH` / `# GATE`), between function groups (`renderer_logger.gd`'s `# READING FROM PIPES` / `# FLUSH AND SEND LOGS`), or within a long function (`file_tools.gd`'s `# List directory content` / `# Remove current path`). They earn their place as long as the block they label is genuinely multi-line and represents a single phase. A 1-line "comment" over a 1-line call is *not* a section divider — that's narration, delete it.

If a constraint really does span two systems and one line genuinely can't hold it, the comment is in the wrong place — write a paragraph in the right note under `docs/` (e.g. `Renderer Process.md`, `Two-Process Model.md`) and point to it from a one-liner, or skip the comment entirely and let the doc be the source of truth.

Approved styles:

| Style | When |
|-------|------|
| `# one line, lowercase, no period` | The default. |
| `# TODO: ...` | Known follow-ups. Actionable. Keep rare. |
| `# TODO: cleanup ai generated code` | Marker meaning "this file's style doesn't represent the project — don't copy patterns from it." |
| `## doc comment` (Godot) | Reserved. Add only if Godot editor hover-help is genuinely the right home — usually it isn't, the docs vault is. |
| `# SECTION HEADER` | Labels a multi-line group of related code so it can be scanned as one chunk. Works at file scope (`analytics_events.gd`'s `# APP` / `# SEARCH` / `# GATE`), between function groups (`renderer_logger.gd`'s `# READING FROM PIPES` / `# FLUSH AND SEND LOGS`), and within a long function (`file_tools.gd`'s `# List directory content` over the traversal loop, `# Remove current path` over the final removal). A 1-line label over 1 line of code is narration, not a divider. |
| `#commented-out code` | Acceptable when kept as an alternative you'd un-comment again (`config_base.gd`'s `#Debug.logr(...)` debug lines). |

> **Note on `app/scripts/renderer/`.** This subdirectory was largely added by AI agents during the chromium-sandboxing work and contains multi-line WHY blocks that violate this rule. Read it for behavior, not for comment style — clean comments as you touch it. The same applies to any other file with the `# TODO: cleanup ai generated code` marker.

If you're about to write a comment, first try: rename the variable, extract a function, split the line, or write a note in `docs/`. Comment only what those moves can't fix. See [[Gotchas and Conventions]].

**Don't enforce this rule retroactively.** Old terse 1-liners that predate the agent-assistance era are part of the codebase's vernacular and earned their place at the time. Cleanup passes target *uncommitted WIP* and *recent agent-flavored commits*, not legacy lines. Use `git blame` before deleting — if the line is old, leave it.

## Idioms catalog

A few patterns worth recognizing on sight:

```gdscript
# Validate-or-return guards at top of function
if gate == null: return
if url.is_empty(): return

# Ternary expression
title.text = "Unnamed" if gate.title.is_empty() else gate.title

# Iterating a Dictionary's values typed as some class
for gate in bookmarks.gates.values():
    show_bookmark(gate)

# String formatting with % and array
"%dx%d" % [size.x, size.y]
"%.2f" % [val]

# Type-checking a child node
if child is not OnboardingBoard: continue

# Calling a method on a deferred call (cross-thread → main-thread)
store_buffer.call_deferred(buffer)

# Dictionary-as-default for missing config
var status: int = int(cfg_result.get("status", 0))
```

## What goes in `.uid` files

Godot 4.4+ generates `<script>.gd.uid` and `<scene>.tscn.uid` siblings for stable cross-rename references. Format:

```
uid://cp0xkloif6sa0
```

Don't edit. Don't delete. Commit them alongside their parent file. They're how `.tscn` files reference scripts/scenes by ID instead of by path.

## What lives where (mini map of `app/`)

| Folder | What it holds |
|--------|---------------|
| `app/scripts/` | All `.gd` files |
| `app/scripts/resources/` | Event bus classes (`*_events.gd`), data classes (`Gate`, `Bookmarks`, etc.) |
| `app/resources/` | **Instances** of those classes saved as `.tres` / `.res` (the actual shared instances loaded by the project) |
| `app/scenes/` | `.tscn` files |
| `app/scenes/components/` | Reusable UI scenes |
| `app/scenes/menu_body/` | Top-level page scenes (home, world, search) |
| `app/shaders/` | Project-specific shaders |

For broader project layout: [[Repository Layout]].

## What to skip when learning the style

These were AI-generated and don't represent the conventions:
- `app/scripts/networking/http_*.gd`
- `app/scripts/loading/gate_loader.gd` (marker comment at the bottom)
- `app/scripts/ui/menu/window_drag.gd` (marker comment at the bottom)
- Any future file with `# TODO: cleanup ai generated code`

Read them for behavior, not for patterns.

## Tools

- **Project-wide:** Godot Editor's built-in script editor handles whitespace and basic indentation correctly.
- **`gdformat`:** can be used selectively but its default of 1 blank line between functions is wrong for this repo. Configure to 2 or run with explicit overrides.
- **`gdlint`:** OK for catching dead code / cyclomatic warnings; not authoritative on style here.
- **No CI gate yet on GDScript style** — reviews enforce.

If you're an agent and your editor inserted single blank lines between functions, fix them before committing.
