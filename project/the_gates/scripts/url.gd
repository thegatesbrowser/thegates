extends RefCounted
class_name Url

const url_regex: String = "^(https?)://[^\\s()<>]+(?:\\([\\w\\d]+\\)|([^[:punct:]\\s]|/))$"


static func join(base_url: String, path: String) -> String:
	var url = ""
	if path.is_empty():
		url = base_url
	elif path.begins_with("http"):
		url = path
	else:
		url = base_url.get_base_dir() + "/" + path
	return url


static func fix_gate_url(url: String) -> String:
	if url.get_extension() != "gate":
		var slash = "" if url.ends_with("/") else "/"
		url += slash + "world.gate"
	return url


static func is_valid(url: String) -> bool:
	var regex = RegEx.new()
	regex.compile(url_regex)
	var result = regex.search(url)
	return false if result == null else result.get_string() == url
