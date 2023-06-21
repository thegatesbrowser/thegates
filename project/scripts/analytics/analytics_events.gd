extends Node
#class_name AnalyticsEvents

var user_id := "none"


func base(event_name: String) -> Dictionary:
	var event = {}
	event.event_name = event_name
	event.user_id = user_id
	return event


# APP

func app_open() -> Dictionary:
	return base("application_open")


func heartbeat(time_spend: int) -> Dictionary:
	var event = base("heartbeat")
	event.time_spend = time_spend
	return event


func app_exit(time_spend: int) -> Dictionary:
	var event = base("application_exit")
	event.time_spend = time_spend
	return event


# GATE

func search(query: String) -> Dictionary:
	var event = base("search")
	event.query = query
	return event


func gate_open(url: String) -> Dictionary:
	var event = base("gate_open")
	event.gate_url = url
	return event


func gate_enter(url: String, download_time: int) -> Dictionary:
	var event = base("gate_enter")
	event.gate_url = url
	event.download_time = download_time
	return event


func gate_exit(url: String, time_spend: int) -> Dictionary:
	var event = base("gate_exit")
	event.gate_url = url
	event.time_spend = time_spend
	return event


# ERROR

func error(msg: String) -> Dictionary:
	var event = base("error")
	event.msg = msg
	return event
