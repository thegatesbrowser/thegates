extends Resource
class_name ApiSettings

enum HostType {
	Local,
	Remote
}

@export var local_url: String
@export var remote_url: String
@export var host_type: HostType

var url: String :
	get: return local_url if host_type == HostType.Local else remote_url

var analytics_event: String :
	get: return url + "/api/analytics_event"

var create_user_id: String :
	get: return url + "/api/create_user_id"

var discover_gate: String :
	get: return url + "/api/discover_gate"

var featured_gates: String :
	get: return url + "/api/featured_gates"

var search: String :
	get: return url + "/api/search?query="

var prompt: String :
	get: return url + "/api/prompt?query="

var search_suggestions: String :
	get: return url + "/api/search_suggestions"

var send_logs: String :
	get: return url + "/api/send_logs?url="
