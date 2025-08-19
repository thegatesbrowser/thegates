extends Node
# class_name Url

const url_regex: String = "^(https?)://[^\\s()<>]+(?:\\([\\w\\d]+\\)|([^[:punct:]\\s]|/))$"

@export_file("*.txt") var tld_list_file: String

var regex: RegEx
var tld_list: Dictionary = {}


func _ready() -> void:
	regex = RegEx.new()
	regex.compile(url_regex)
	
	var file = FileAccess.open(tld_list_file, FileAccess.READ)
	var tlds = file.get_as_text().split("\n")
	for tld in tlds:
		tld_list[tld] = true


func join(base_url: String, path: String) -> String:
	var url = ""
	if path.is_empty():
		url = ""
	elif path.begins_with("http"):
		url = path
	else:
		url = base_url.get_base_dir() + "/" + path
	return url


func fix_gate_url(url: String) -> String:
	if not url.begins_with("http://") and not url.begins_with("https://"):
		url = "https://" + url
	
	if url.get_extension() != "gate":
		var slash = "" if url.ends_with("/") else "/"
		url += slash + "world.gate"
	
	url = lower_domain(url)
	return url


func is_valid(url: String) -> bool:
	if not url.begins_with("http://") and not url.begins_with("https://"):
		var domain = url.split("/")[0]
		if is_valid_domain(domain):
			url = "https://" + url
	
	var result = regex.search(url)
	return false if result == null else result.get_string() == url


func lower_domain(url: String) -> String:
	# Assuming https?://domain/*.gate
	var split = url.split("/", true, 3)
	assert(split.size() == 4, "Invalid URL: " + url)
	
	var domain = split[2]
	return split[0] + "//" + domain.to_lower() + "/" + split[3]


func is_valid_domain(domain: String) -> bool:
	if domain.is_empty() or domain.split(".").size() != 2:
		return false
	
	return tld_list.has(domain.get_extension().to_lower())
