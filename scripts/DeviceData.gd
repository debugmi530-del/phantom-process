extends Node
class_name DeviceData

var device_model: String = "Неизвестное устройство"
var battery_level: int = -1
var battery_charging: bool = false
var current_hour: int = 0
var current_minute: int = 0
var current_second: int = 0
var day_of_week: int = 0
var day_of_month: int = 0
var month: int = 0
var year: int = 0
var memory_total_mb: int = 0
var memory_free_mb: int = 0
var processor_name: String = "Неизвестно"
var processor_count: int = 0
var screen_width: int = 1920
var screen_height: int = 1080
var locale: String = "ru"
var play_start_ticks: int = 0
var os_name: String = "Android"

func _ready() -> void:
	play_start_ticks = Time.get_ticks_msec()
	collect_all()

func collect_all() -> void:
	device_model = _get_device_model()
	_refresh_battery()
	_refresh_time()
	_refresh_memory()
	processor_name = OS.get_processor_name()
	processor_count = OS.get_processor_count()
	locale = OS.get_locale_language()
	os_name = OS.get_name()
	var screen_size = DisplayServer.screen_get_size()
	screen_width = screen_size.x
	screen_height = screen_size.y

func _get_device_model() -> String:
	var model = OS.get_model_name()
	if model.is_empty() or model == "":
		return "Неизвестное устройство"
	return model

func _refresh_battery() -> void:
	battery_level = OS.get_power_percent_left()
	var state = OS.get_power_state()
	battery_charging = (state == OS.POWERSTATE_CHARGING or state == OS.POWERSTATE_CHARGED)

func _refresh_time() -> void:
	var time_dict = Time.get_time_dict_from_system()
	current_hour = time_dict.hour
	current_minute = time_dict.minute
	current_second = time_dict.second
	var date_dict = Time.get_date_dict_from_system()
	day_of_week = date_dict.weekday
	day_of_month = date_dict.day
	month = date_dict.month
	year = date_dict.year

func _refresh_memory() -> void:
	var mem = OS.get_memory_info()
	memory_total_mb = int(mem.physical / 1048576)
	memory_free_mb = int(mem.free / 1048576)

func refresh() -> void:
	_refresh_battery()
	_refresh_time()
	_refresh_memory()

# ─── Formatted getters ───────────────────────────────────────

func get_time_formatted() -> String:
	return "%02d:%02d" % [current_hour, current_minute]

func get_battery_text() -> String:
	if battery_level < 0:
		return "неизвестно"
	var suffix = " (заряжается)" if battery_charging else "%"
	return str(battery_level) + suffix

func get_play_time_seconds() -> int:
	return (Time.get_ticks_msec() - play_start_ticks) / 1000

func get_play_time_formatted() -> String:
	var s = get_play_time_seconds()
	return "%d мин %02d сек" % [s / 60, s % 60]

func get_screen_formatted() -> String:
	return "%dx%d" % [screen_width, screen_height]

func get_day_name() -> String:
	var days = ["Воскресенье", "Понедельник", "Вторник", "Среда",
				"Четверг", "Пятница", "Суббота"]
	return days[day_of_week] if day_of_week < days.size() else "Неизвестно"

func get_month_name() -> String:
	var months = ["", "января", "февраля", "марта", "апреля", "мая", "июня",
				  "июля", "августа", "сентября", "октября", "ноября", "декабря"]
	return months[month] if month < months.size() else ""

func get_date_formatted() -> String:
	return "%d %s %d" % [day_of_month, get_month_name(), year]

func get_time_of_day_comment() -> String:
	if current_hour >= 0 and current_hour < 5:
		return "глубокой ночью"
	elif current_hour >= 5 and current_hour < 9:
		return "ранним утром"
	elif current_hour >= 9 and current_hour < 12:
		return "утром"
	elif current_hour >= 12 and current_hour < 17:
		return "днём"
	elif current_hour >= 17 and current_hour < 22:
		return "вечером"
	else:
		return "ночью"

func substitute(text: String) -> String:
	return text\
		.replace("{device}", device_model)\
		.replace("{battery}", get_battery_text())\
		.replace("{time}", get_time_formatted())\
		.replace("{date}", get_date_formatted())\
		.replace("{day}", get_day_name())\
		.replace("{time_of_day}", get_time_of_day_comment())\
		.replace("{ram_total}", str(memory_total_mb))\
		.replace("{ram_free}", str(memory_free_mb))\
		.replace("{cpu}", processor_name)\
		.replace("{cpu_cores}", str(processor_count))\
		.replace("{screen}", get_screen_formatted())\
		.replace("{play_time}", get_play_time_formatted())\
		.replace("{os}", os_name)
