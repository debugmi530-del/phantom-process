extends Node
class_name PhantomMemory

const MEMORY_PATH = "user://phantom_memory.json"

var session_count: int = 0
var last_session_timestamp: int = 0
var total_play_seconds: int = 0
var trust_history: Array = []
var last_phase_reached: int = 0
var first_launch_date: String = ""
var days_since_first: int = 0

func _ready() -> void:
	load_memory()
	_calculate_days()

func _calculate_days() -> void:
	if first_launch_date.is_empty():
		days_since_first = 0
		return
	var now = Time.get_unix_time_from_system()
	days_since_first = int((now - last_session_timestamp) / 86400)
	if days_since_first < 0:
		days_since_first = 0

func load_memory() -> void:
	if not FileAccess.file_exists(MEMORY_PATH):
		_reset_to_defaults()
		return

	var file = FileAccess.open(MEMORY_PATH, FileAccess.READ)
	if not file:
		_reset_to_defaults()
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_text) == OK:
		var d = json.get_data()
		if d is Dictionary:
			session_count        = int(d.get("session_count", 0))
			last_session_timestamp = int(d.get("last_session_timestamp", 0))
			total_play_seconds   = int(d.get("total_play_seconds", 0))
			trust_history        = d.get("trust_history", [])
			last_phase_reached   = int(d.get("last_phase_reached", 0))
			first_launch_date    = str(d.get("first_launch_date", ""))
			return
	_reset_to_defaults()

func save_memory() -> void:
	var data = {
		"session_count": session_count,
		"last_session_timestamp": int(Time.get_unix_time_from_system()),
		"total_play_seconds": total_play_seconds,
		"trust_history": trust_history,
		"last_phase_reached": last_phase_reached,
		"first_launch_date": first_launch_date,
	}
	var file = FileAccess.open(MEMORY_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func start_session() -> void:
	session_count += 1
	if first_launch_date.is_empty():
		var d = Time.get_date_dict_from_system()
		first_launch_date = "%02d.%02d.%d" % [d.day, d.month, d.year]
	save_memory()

func end_session(trust: int, phase: int, play_seconds: int) -> void:
	total_play_seconds += play_seconds
	last_phase_reached = max(last_phase_reached, phase)
	trust_history.append(trust)
	if trust_history.size() > 20:
		trust_history.pop_front()
	save_memory()

func _reset_to_defaults() -> void:
	session_count = 0
	last_session_timestamp = 0
	total_play_seconds = 0
	trust_history = []
	last_phase_reached = 0
	first_launch_date = ""

# ─── Helper getters ──────────────────────────────────────────

func get_session_comment() -> String:
	match session_count:
		1:  return "первый раз"
		2:  return "во второй раз"
		3:  return "в третий раз"
		4, 5: return "уже снова"
		_:
			if session_count >= 10:
				return "в %d-й раз — я потерял счёт" % session_count
			return "в %d-й раз" % session_count

func get_average_trust() -> int:
	if trust_history.is_empty():
		return -1
	var sum = 0
	for t in trust_history:
		sum += int(t)
	return sum / trust_history.size()

func get_total_hours_formatted() -> String:
	var h = total_play_seconds / 3600
	var m = (total_play_seconds % 3600) / 60
	if h > 0:
		return "%d ч %d мин" % [h, m]
	return "%d мин" % m
