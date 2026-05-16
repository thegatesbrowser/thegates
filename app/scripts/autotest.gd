# TODO: restore `class_name Autotest` once the editor regenerates the
# global script class cache. See app.gd for the matching note.
extends RefCounted


# Parses --gate-url and --autotest-timeout from OS.get_cmdline_user_args() and
# OS.get_cmdline_args() and drives the launcher through a deterministic scripted
# session so an external runner can verify the launcher+renderer pipeline.
#
# Tagged log lines emitted (always prefixed with [AUTOTEST-...] so a runner can
# grep them out of mixed engine output):
#   [AUTOTEST-START]         on _ready
#   [AUTOTEST-OPEN] <url>    when Navigation.open is called
#   [AUTOTEST-GATE-ENTERED]  when renderer has been spawned for the gate
#   [AUTOTEST-RENDERER-PID] <pid>
#   [AUTOTEST-TIMEOUT]       fired when the autotest timeout elapses
#   [AUTOTEST-EXIT] <reason> on quit


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
			# Number of additional times to re-open the gate after the first
			# entry. cycles=2 means: open initial gate, then re-open twice
			# (total 3 gate spawns). Used to reproduce the multi-gate IPC
			# regression on chromium-sandboxing.
			out["cycles"] = int(all[i + 1])
			i += 2
		elif a == "--autotest-cycle-delay" and i + 1 < all.size():
			# Seconds to wait after gate_entered before opening the next gate.
			# Needs to be long enough that the renderer has finished its bind
			# and the first command round-trip happened, otherwise we conflate
			# "no commands ever" with "didn't wait long enough."
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
	print("%sSTART] args=%s" % [TAG, str(args)])

	var url: String = args.get("gate_url", "")
	var timeout: float = args.get("timeout", 0.0)
	var cycles: int = args.get("cycles", 0)
	var cycle_delay: float = args.get("cycle_delay", 5.0)

	# Counter for tagging which gate-entry we're on. Starts at 0; the first
	# gate_entered bumps it to 1.
	var cycle_state := {"entered": 0, "remaining": cycles}

	gate_events.gate_entered.connect(func():
		cycle_state["entered"] += 1
		var idx: int = cycle_state["entered"]
		print("%sGATE-ENTERED] cycle=%d" % [TAG, idx])

		if cycle_state["remaining"] > 0:
			cycle_state["remaining"] -= 1
			var next_cycle: int = idx + 1
			print("%sCYCLE-SCHEDULED] next_cycle=%d delay=%.1f url=%s" % [
				TAG, next_cycle, cycle_delay, url
			])
			var t := node.get_tree().create_timer(cycle_delay)
			t.timeout.connect(func():
				print("%sCYCLE-REOPEN] cycle=%d url=%s" % [TAG, next_cycle, url])
				gate_events.open_gate_emit(url)
			)
	)

	if not url.is_empty():
		# Defer the open call by one frame so all autoload _ready hooks have run.
		node.get_tree().process_frame.connect(func():
			print("%sOPEN] %s" % [TAG, url])
			Navigation.open(url)
		, CONNECT_ONE_SHOT)

	if timeout > 0.0:
		var timer := node.get_tree().create_timer(timeout)
		timer.timeout.connect(func():
			print("%sTIMEOUT] elapsed=%.1f" % [TAG, timeout])
			print("%sEXIT] reason=timeout" % TAG)
			node.get_tree().quit(0)
		)
