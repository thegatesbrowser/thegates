extends Node
#class_name AnalyticsEvents

var app_version := "none"
var user_id := "none"


func base(event_name: String) -> Dictionary:
	var event = {}
	event.event_name = event_name
	event.app_version = app_version
	event.user_id = user_id
	return event


# APP

func app_open() -> Dictionary:
	return base("application_open")


func heartbeat(time_spend: float) -> Dictionary:
	var event = base("heartbeat")
	event.time_spend = time_spend
	return event


func app_exit(time_spend: float) -> Dictionary:
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


func gate_load(url: String, download_time: float) -> Dictionary:
	var event = base("gate_load")
	event.gate_url = url
	event.download_time = download_time
	return event


func gate_start(url: String, bootup_time: float) -> Dictionary:
	var event = base("gate_start")
	event.gate_url = url
	event.bootup_time = bootup_time
	return event


func gate_exit(url: String, time_spend: float) -> Dictionary:
	var event = base("gate_exit")
	event.gate_url = url
	event.time_spend = time_spend
	return event


# BOOKMARK

func bookmark(url: String) -> Dictionary:
	var event = base("bookmark")
	event.gate_url = url
	return event


func unbookmark(url: String) -> Dictionary:
	var event = base("unbookmark")
	event.gate_url = url
	return event


# ERROR

func error(msg: String) -> Dictionary:
	var event = base("error")
	event.msg = msg
	return event


# ONBOARDING

func onboarding_started() -> Dictionary:
	return base("onboarding_started")


func onboarding_finished(time_spend: float) -> Dictionary:
	var event = base("onboarding_finished")
	event.time_spend = time_spend
	return event
