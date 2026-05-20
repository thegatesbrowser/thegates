extends Node
class_name NetworkDiagnostic

const FLAG := "--network-diagnostic"


static func is_enabled() -> bool:
	var all := OS.get_cmdline_user_args()
	if all.is_empty(): all = OS.get_cmdline_args()
	return FLAG in all


# Prints the platform-specific network filter state and exits. Used for
# support cases: a user reports "my gate can't reach my server", runs the
# launcher with --network-diagnostic, pastes output.
static func run_and_quit() -> void:
	var sandbox := Sandbox.create()
	if sandbox == null:
		print("Sandbox: not available on this build (no TG_SANDBOX)")
		OS.kill(OS.get_process_id())
		return

	var report := {
		"network_state": sandbox.network_state(),
	}

	print(JSON.stringify(report, "\t", false))
	OS.kill(OS.get_process_id())
