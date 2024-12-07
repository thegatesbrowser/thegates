extends Node
class_name StringTools


static func to_alpha(text: String) -> String:
	var last_is_alpha = false
	var result = ""
	
	for symbol in text:
		if (symbol >= 'a' and symbol <= 'z') or (symbol >= 'A' and symbol <= 'Z'):
			result += symbol
			last_is_alpha = true
		elif last_is_alpha:
			result += " "
			last_is_alpha = false
	
	result = result.strip_edges()
	return result


static func bytes_to_string(bytes: int) -> String:
	if bytes < 1024: return str(bytes) + "B"
	
	var kb = bytes / 1024
	if kb < 1024: return str(kb) + "KB"
	
	var mb = kb / 1024.0
	var text = "%.1fMB" if mb < 10.0 else "%.0fMB"
	return text % [mb]
