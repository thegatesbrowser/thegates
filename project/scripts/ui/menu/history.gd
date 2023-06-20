extends Resource
class_name History

var history: Array[String]
var index := -1


func get_current() -> String:
	if index == -1: return ""
	return history[index]


func can_forw() -> bool:
	return index + 1 < history.size()


func can_back() -> bool:
	return index > -1


func add(url: String) -> void:
	if url == get_current(): return
	
	index += 1
	history.resize(index)
	history.push_back(url)
	print(str(history) + " " + str(index))


func forw() -> String:
	index += 1
	print(str(history) + " " + str(index))
	return history[index]


func back() -> String:
	index -= 1
	print(str(history) + " " + str(index))
	if index == -1:
		return ""
	return history[index]


func clear() -> void:
	index = -1
	history.clear()
	print(str(history) + " " + str(index))
