extends RefCounted
class_name HTTPDateUtils


# Parses RFC1123 HTTP-date (e.g., "Sat, 07 Jun 2025 00:02:24 GMT") to Unix time (UTC). Returns 0 on failure.
static func parse_http_date_rfc1123(date_str: String) -> int:
	var s := date_str.strip_edges()
	var comma_idx := s.find(",")
	if comma_idx != -1:
		s = s.substr(comma_idx + 1, s.length() - comma_idx - 1).strip_edges()
	# Expect: DD Mon YYYY HH:MM:SS GMT
	var parts := s.split(" ", false)
	if parts.size() < 5:
		return 0
	var day_str := parts[0]
	var mon_str := parts[1]
	var year_str := parts[2]
	var time_str := parts[3]
	if not day_str.is_valid_int() or not year_str.is_valid_int():
		return 0
	var day := int(day_str)
	var year := int(year_str)
	var month := parse_month_to_number(mon_str)
	if month == 0:
		return 0
	var time_parts := time_str.split(":", false)
	if time_parts.size() != 3:
		return 0
	if not time_parts[0].is_valid_int() or not time_parts[1].is_valid_int() or not time_parts[2].is_valid_int():
		return 0
	var hour := int(time_parts[0])
	var minute := int(time_parts[1])
	var second := int(time_parts[2])
	return unix_time_from_utc_components(year, month, day, hour, minute, second)


static func parse_month_to_number(mon: String) -> int:
	match mon.capitalize():
		"Jan":
			return 1
		"Feb":
			return 2
		"Mar":
			return 3
		"Apr":
			return 4
		"May":
			return 5
		"Jun":
			return 6
		"Jul":
			return 7
		"Aug":
			return 8
		"Sep":
			return 9
		"Oct":
			return 10
		"Nov":
			return 11
		"Dec":
			return 12
		_:
			return 0


static func unix_time_from_utc_components(year: int, month: int, day: int, hour: int, minute: int, second: int) -> int:
	if year < 1970:
		return 0
	var days_in_month := [0,31,28,31,30,31,30,31,31,30,31,30,31]
	var days := 0
	for y in range(1970, year):
		days += 365
		if is_leap_year(y):
			days += 1
	if is_leap_year(year):
		days_in_month[2] = 29
	for m in range(1, month):
		days += int(days_in_month[m])
	days += (day - 1)
	var total_seconds := days * 86400 + hour * 3600 + minute * 60 + second
	return total_seconds


static func is_leap_year(year: int) -> bool:
	return (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0)

# TODO: cleanup ai generated code
