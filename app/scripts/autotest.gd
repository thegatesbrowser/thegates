extends Node
class_name Autotest

const TAG := "[AUTOTEST-"

var url: String
var timeout: float
var cycle_delay: float
var cycles_remaining: int

var entered_count: int
var entered_ms: int
var first_frame_pending_cycle: int
var reopen_ms: int
var last_tick_ms: int
var max_tick_gap_ms: int

var gate_events: GateEvents
var deadline_thread: Thread


static func parse_args() -> Dictionary:
	var all := OS.get_cmdline_user_args()
	if all.is_empty(): all = OS.get_cmdline_args()
	var out := {}
	var i := 0
	while i < all.size():
		var a: String = all[i]
		if a == "--gate-url" and i + 1 < all.size():
			out["gate_url"] = all[i + 1]; i += 2
		elif a == "--autotest-timeout" and i + 1 < all.size():
			out["timeout"] = float(all[i + 1]); i += 2
		elif a == "--autotest-cycles" and i + 1 < all.size():
			# cycles=N → N+1 gate spawns total (initial open + N re-opens)
			out["cycles"] = int(all[i + 1]); i += 2
		elif a == "--autotest-cycle-delay" and i + 1 < all.size():
			out["cycle_delay"] = float(all[i + 1]); i += 2
		elif a == "--autotest":
			out["enabled"] = true; i += 1
		else:
			i += 1
	return out


static func is_enabled() -> bool:
	var args := parse_args()
	return args.get("enabled", false) or args.has("gate_url") or args.has("timeout")


static func attach(parent: Node, p_gate_events: GateEvents) -> Autotest:
	if not is_enabled(): return null
	var inst := Autotest.new()
	inst.gate_events = p_gate_events
	parent.add_child(inst)
	return inst


func _ready() -> void:
	var args := parse_args()
	url = args.get("gate_url", "")
	timeout = args.get("timeout", 0.0)
	cycles_remaining = args.get("cycles", 0)
	cycle_delay = args.get("cycle_delay", 5.0)
	print("%sSTART] args=%s ms=%d" % [TAG, str(args), Time.get_ticks_msec()])

	get_tree().process_frame.connect(sample_tick)
	gate_events.gate_entered.connect(on_gate_entered)
	gate_events.first_frame.connect(on_first_frame)
	gate_events.not_responding.connect(on_not_responding)
	gate_events.gate_error.connect(on_gate_error)

	if not url.is_empty():
		# defer first open one frame so all autoloads are _ready
		get_tree().process_frame.connect(open_first_gate, CONNECT_ONE_SHOT)

	if timeout > 0.0: arm_deadline()


# main-thread tick gap is the responsiveness signal — blocking calls freeze ticks
func sample_tick() -> void:
	var now := Time.get_ticks_msec()
	if last_tick_ms != 0:
		max_tick_gap_ms = max(max_tick_gap_ms, now - last_tick_ms)
	last_tick_ms = now


func on_gate_entered() -> void:
	entered_count += 1
	entered_ms = Time.get_ticks_msec()
	first_frame_pending_cycle = entered_count
	var since_reopen := entered_ms - reopen_ms if reopen_ms != 0 else -1
	print("%sGATE-ENTERED] cycle=%d ms=%d since_reopen=%d max_tick_gap=%d" % [
		TAG, entered_count, entered_ms, since_reopen, max_tick_gap_ms
	])
	max_tick_gap_ms = 0
	if cycles_remaining > 0: schedule_reopen()


func on_first_frame() -> void:
	if first_frame_pending_cycle == 0: return
	var cycle := first_frame_pending_cycle
	first_frame_pending_cycle = 0
	var now := Time.get_ticks_msec()
	print("%sFIRST-FRAME] cycle=%d ms=%d since_entered=%d" % [TAG, cycle, now, now - entered_ms])


func on_not_responding() -> void:
	print("%sNOT-RESPONDING] cycle=%d ms=%d" % [TAG, entered_count, Time.get_ticks_msec()])


func on_gate_error(code: int) -> void:
	print("%sGATE-ERROR] cycle=%d code=%d ms=%d" % [TAG, entered_count, code, Time.get_ticks_msec()])


func schedule_reopen() -> void:
	cycles_remaining -= 1
	var next_cycle := entered_count + 1
	print("%sCYCLE-SCHEDULED] next_cycle=%d delay=%.1f url=%s" % [TAG, next_cycle, cycle_delay, url])

	var t := Timer.new()
	t.one_shot = true
	t.wait_time = cycle_delay
	add_child(t)
	t.timeout.connect(func():
		reopen_ms = Time.get_ticks_msec()
		print("%sCYCLE-REOPEN] cycle=%d url=%s ms=%d" % [TAG, next_cycle, url, reopen_ms])
		gate_events.open_gate_emit(url)
		t.queue_free()
	)
	t.start()


func open_first_gate() -> void:
	print("%sOPEN] %s ms=%d" % [TAG, url, Time.get_ticks_msec()])
	Navigation.open(url)


# scene-tree timers don't survive gate switches; see docs/Gate Cycle.md pitfalls
func arm_deadline() -> void:
	deadline_thread = Thread.new()
	deadline_thread.start(func():
		OS.delay_msec(int(timeout * 1000.0))
		on_deadline.call_deferred()
	)


func on_deadline() -> void:
	print("%sTIMEOUT] elapsed=%.1f" % [TAG, timeout])
	print("%sEXIT] reason=timeout" % TAG)
	get_tree().quit(0)
