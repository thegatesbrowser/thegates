# TODO: restore `class_name Autotest` once the editor regenerates the global class cache.
extends RefCounted

# Drives the launcher through a scripted gate-open session for an external
# verifier; emits [AUTOTEST-*] tagged lines that run-sandbox-test.ps1 greps.


const TAG := "[AUTOTEST-"


static func parse_args() -> Dictionary:
	# Args after `--` first; fall back to all args so the runner can pass either form.
	var all := OS.get_cmdline_user_args()
	if all.is_empty():
		all = OS.get_cmdline_args()
	var out := {}
	var i := 0
	while i < all.size():
		var a: String = all[i]
		if a == "--gate-url" and i + 1 < all.size():
			out["gate_url"] = all[i + 1]
			i += 2
		elif a == "--autotest-timeout" and i + 1 < all.size():
			out["timeout"] = float(all[i + 1])
			i += 2
		elif a == "--autotest-cycles" and i + 1 < all.size():
			# extra re-opens after the first; cycles=N → N+1 gate spawns total.
			out["cycles"] = int(all[i + 1])
			i += 2
		elif a == "--autotest-cycle-delay" and i + 1 < all.size():
			out["cycle_delay"] = float(all[i + 1])
			i += 2
		elif a == "--autotest":
			out["enabled"] = true
			i += 1
		else:
			i += 1
	return out


static func is_enabled() -> bool:
	var args := parse_args()
	return args.get("enabled", false) or args.has("gate_url") or args.has("timeout")


static func start(node: Node, gate_events: GateEvents) -> void:
	var args := parse_args()
	print("%sSTART] args=%s ms=%d" % [TAG, str(args), Time.get_ticks_msec()])

	var url: String = args.get("gate_url", "")
	var timeout: float = args.get("timeout", 0.0)
	var cycles: int = args.get("cycles", 0)
	var cycle_delay: float = args.get("cycle_delay", 5.0)

	var cycle_state := {
		"entered": 0,
		"remaining": cycles,
		"reopen_ms": 0,
		"last_tick_ms": 0,
		"max_gap_ms": 0,
	}

	# Sample main-thread liveness every frame; max gap between ticks during a
	# cycle is the responsiveness signal — a blocking call freezes ticks.
	node.get_tree().process_frame.connect(func():
		var now := Time.get_ticks_msec()
		var last: int = cycle_state["last_tick_ms"]
		if last != 0:
			var gap := now - last
			if gap > (cycle_state["max_gap_ms"] as int):
				cycle_state["max_gap_ms"] = gap
		cycle_state["last_tick_ms"] = now
	)

	gate_events.gate_entered.connect(func():
		cycle_state["entered"] += 1
		var idx: int = cycle_state["entered"]
		var now := Time.get_ticks_msec()
		var since_reopen: int = now - (cycle_state["reopen_ms"] as int) if cycle_state["reopen_ms"] != 0 else -1
		var max_gap: int = cycle_state["max_gap_ms"]
		print("%sGATE-ENTERED] cycle=%d ms=%d since_reopen=%d max_tick_gap=%d" % [
			TAG, idx, now, since_reopen, max_gap
		])
		cycle_state["max_gap_ms"] = 0

		if cycle_state["remaining"] > 0:
			cycle_state["remaining"] -= 1
			var next_cycle: int = idx + 1
			print("%sCYCLE-SCHEDULED] next_cycle=%d delay=%.1f url=%s" % [
				TAG, next_cycle, cycle_delay, url
			])
			var t := Timer.new()
			t.one_shot = true
			t.process_callback = Timer.TIMER_PROCESS_IDLE
			t.wait_time = cycle_delay
			node.add_child(t)
			t.timeout.connect(func():
				cycle_state["reopen_ms"] = Time.get_ticks_msec()
				print("%sCYCLE-REOPEN] cycle=%d url=%s ms=%d" % [
					TAG, next_cycle, url, cycle_state["reopen_ms"]
				])
				gate_events.open_gate_emit(url)
				t.queue_free()
			)
			t.start()
	)

	if not url.is_empty():
		# Defer the open call by one frame so all autoload _ready hooks have run.
		node.get_tree().process_frame.connect(func():
			print("%sOPEN] %s ms=%d" % [TAG, url, Time.get_ticks_msec()])
			Navigation.open(url)
		, CONNECT_ONE_SHOT)

	if timeout > 0.0:
		# Thread-based deadline. SceneTreeTimer and Timer-node approaches both
		# fail to fire reliably across multi-cycle gate switches — switch_scene
		# tears down + reinstantiates world_scene every cycle and the main
		# loop's idle delta accumulates against the timer in ways that delay
		# (or skip) the timeout signal. A separate thread that sleeps for
		# `timeout` seconds and then call_deferred's quit is the only path
		# that fires on real-wall-time regardless of scene churn.
		var deadline_thread := Thread.new()
		deadline_thread.start(func():
			OS.delay_msec(int(timeout * 1000.0))
			(func():
				print("%sTIMEOUT] elapsed=%.1f" % [TAG, timeout])
				print("%sEXIT] reason=timeout" % TAG)
				node.get_tree().quit(0)
			).call_deferred()
		)
