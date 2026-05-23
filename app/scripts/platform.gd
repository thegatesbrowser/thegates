extends Node
class_name Platform

enum {
	WINDOWS,
	MACOS,
	LINUX_BSD,
	ANDROID,
	IOS,
	WEB
}

static var platform_to_string: Dictionary = {
	WINDOWS: "windows",
	MACOS: "macos",
	LINUX_BSD: "linux",
	ANDROID: "android",
	IOS: "ios",
	WEB: "web"
}


static func is_windows() -> bool:
	return get_platform() == WINDOWS


static func is_linux() -> bool:
	return get_platform() == LINUX_BSD


static func is_macos() -> bool:
	return get_platform() == MACOS


static func is_debug() -> bool:
	return OS.is_debug_build()


static func get_platform() -> int:
	match OS.get_name():
		"Windows", "UWP":
			return WINDOWS
		"macOS":
			return MACOS
		"Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD":
			return LINUX_BSD
		"Android":
			return ANDROID
		"iOS":
			return IOS
		"Web":
			return WEB
		_:
			assert(false, "No such platform")
			return -1


static func get_platform_string() -> String:
	return platform_to_string[get_platform()]


static func is_x11_session() -> bool:
	return is_linux() and not OS.has_environment("WAYLAND_DISPLAY")


# Empty string means "let Godot's display server pick the default". On Wayland
# sessions we force the native Wayland driver so the renderer doesn't route
# through Xwayland (which would share an X server with any other X11 client).
# TG_RENDERER_FORCE_X11=1 opts out for diagnostic and fallback purposes.
static func preferred_renderer_display_driver() -> String:
	if is_linux() and OS.has_environment("WAYLAND_DISPLAY") and not OS.has_environment("TG_RENDERER_FORCE_X11"):
		return "wayland"
	return ""


static func notify_x11_sandbox_caveat() -> void:
	if not is_x11_session(): return
	Debug.logclr("[SECURITY] X11 session detected; sandbox isolation is reduced.", Color.YELLOW)
	OS.alert(
		"TheGates runs gates in a sandbox. On X11 it's weaker — any X11 app, "
		+ "including a hostile gate, can read your clipboard, capture your "
		+ "screen, and inject input.\n\n"
		+ "Wayland sessions isolate that. Consider switching for stronger sandboxing.",
		"X11 detected: reduced sandbox isolation"
	)
