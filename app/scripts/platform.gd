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


static func is_windows() -> bool:
	return get_platform() == WINDOWS


static func is_linux() -> bool:
	return get_platform() == LINUX_BSD


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
