extends Node
class_name StringTools


static func to_alpha(text: String) -> String:
	var clean_text = ""
	var last_is_char = false
	
	for char in text:
		if (char >= 'a' and char <= 'z') or (char >= 'A' and char <= 'Z'):
			clean_text += char
			last_is_char = true
		elif last_is_char:
			clean_text += " "
			last_is_char = false
	
	return clean_text
