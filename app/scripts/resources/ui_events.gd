extends Resource
class_name UiEvents

signal ui_mode_changed(mode: UiMode)
signal ui_size_changed(size: Vector2)

signal onboarding_requested()
signal onboarding_started()
signal onboarding_finished()

enum UiMode
{
	INITIAL,
	FOCUSED
}

var current_ui_size: Vector2
var is_onboarding_requested: bool
var is_onboarding_started: bool


func ui_mode_changed_emit(mode: UiMode) -> void:
	ui_mode_changed.emit(mode)


func ui_size_changed_emit(size: Vector2) -> void:
	current_ui_size = size
	ui_size_changed.emit(size)


func onboarding_requested_emit() -> void:
	is_onboarding_requested = true
	onboarding_requested.emit()


func onboarding_started_emit() -> void:
	is_onboarding_requested = false
	is_onboarding_started = true
	onboarding_started.emit()


func onboarding_finished_emit() -> void:
	is_onboarding_requested = false
	is_onboarding_started = false
	onboarding_finished.emit()
