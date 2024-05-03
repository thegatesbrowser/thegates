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
