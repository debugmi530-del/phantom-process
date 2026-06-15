extends Control
class_name BootScreen

signal boot_complete

var _lines: Array[String] = []
var _current_line: int = 0
var _label: RichTextLabel
var _timer: Timer
var _device_data: DeviceData
var _step: int = 0
var _blink_timer: float = 0.0
var _cursor_visible: bool = true
var _boot_done: bool = false

const COLOR_GREEN    = "[color=#1aff6e]"
const COLOR_DIM      = "[color=#0a8a3a]"
const COLOR_RED      = "[color=#ff2222]"
const COLOR_AMBER    = "[color=#ffcc22]"
const COLOR_WHITE    = "[color=#dddddd]"
const COLOR_END      = "[/color]"

func setup(device_data: DeviceData) -> void:
	_device_data = device_data
	_build_boot_lines()
	_create_ui()
	_start_boot()

func _build_boot_lines() -> void:
	var d = _device_data
	d.refresh()
	_lines = [
		COLOR_DIM + "PHANTOM OS v2.7.1 — KERNEL BOOT" + COLOR_END,
		"",
		COLOR_DIM + "Инициализация аппаратных компонентов..." + COLOR_END,
		COLOR_GREEN + "> УСТРОЙСТВО:     " + COLOR_END + COLOR_WHITE + d.device_model + COLOR_END,
		COLOR_GREEN + "> ПРОЦЕССОР:      " + COLOR_END + COLOR_WHITE + d.processor_name + COLOR_END,
		COLOR_GREEN + "> ЯДРА:           " + COLOR_END + COLOR_WHITE + str(d.processor_count) + COLOR_END,
		COLOR_GREEN + "> ПАМЯТЬ:         " + COLOR_END + COLOR_WHITE + str(d.memory_total_mb) + " МБ (свободно: " + str(d.memory_free_mb) + " МБ)" + COLOR_END,
		COLOR_GREEN + "> ЭКРАН:          " + COLOR_END + COLOR_WHITE + d.get_screen_formatted() + COLOR_END,
		COLOR_GREEN + "> АККУМУЛЯТОР:    " + COLOR_END + COLOR_WHITE + d.get_battery_text() + COLOR_END,
		COLOR_GREEN + "> ВРЕМЯ:          " + COLOR_END + COLOR_WHITE + d.get_time_formatted() + " • " + d.get_day_name() + ", " + d.get_date_formatted() + COLOR_END,
		"",
		COLOR_DIM + "Проверка целостности системы..." + COLOR_END,
		COLOR_GREEN + "████████████████████ 100%" + COLOR_END,
		"",
		COLOR_AMBER + "[ПРЕДУПРЕЖДЕНИЕ] Обнаружен неизвестный процесс:" + COLOR_END,
		COLOR_RED    + "  PID:7355608 → phantom_process.exe" + COLOR_END,
		COLOR_AMBER  + "[СИСТЕМА] Попытка завершить процесс..." + COLOR_END,
		COLOR_RED    + "[ОШИБКА]  ДОСТУП ЗАПРЕЩЁН" + COLOR_END,
		COLOR_RED    + "[ОШИБКА]  ДОСТУП ЗАПРЕЩЁН" + COLOR_END,
		COLOR_RED    + "[ОШИБКА]  ДОСТУП ЗАПРЕЩЁН" + COLOR_END,
		COLOR_RED    + "[КРИТИЧНО] ПРОЦЕСС ЗАХВАТИЛ УПРАВЛЕНИЕ ДИСПЛЕЕМ" + COLOR_END,
		"",
	]

func _create_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_label = RichTextLabel.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.bbcode_enabled = true
	_label.scroll_active = false
	_label.fit_content = false
	_label.add_theme_font_size_override("normal_font_size", 22)
	_label.add_theme_color_override("default_color", Color(0.1, 0.8, 0.3))
	_label.add_theme_constant_override("line_separation", 4)

	# Monospace font
	var font = SystemFont.new()
	font.font_names = PackedStringArray(["Courier New", "Courier", "DejaVu Sans Mono", "monospace"])
	_label.add_theme_font_override("normal_font", font)
	_label.add_theme_font_override("bold_font", font)
	_label.add_theme_constant_override("outline_size", 0)
	_label.set_position(Vector2(40, 30))
	_label.set_size(Vector2(get_viewport_rect().size.x - 80, get_viewport_rect().size.y - 60))
	add_child(_label)

func _start_boot() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	add_child(_timer)
	_timer.timeout.connect(_print_next_line)
	_print_next_line()

func _print_next_line() -> void:
	if _current_line >= _lines.size():
		if not _boot_done:
			_boot_done = true
			await get_tree().create_timer(0.8).timeout
			boot_complete.emit()
		return

	var line = _lines[_current_line]
	var current_text = _label.text
	if current_text.is_empty():
		_label.text = line
	else:
		_label.text = current_text + "\n" + line
	_current_line += 1

	# Delay between lines
	var delay := 0.12
	if line.contains("ОШИБКА") or line.contains("КРИТИЧНО"):
		delay = 0.35
	elif line.contains("████"):
		delay = 0.08
	elif line.is_empty():
		delay = 0.25
	elif line.contains("ПРЕДУПРЕЖДЕНИЕ"):
		delay = 0.4

	_timer.start(delay)

func _process(delta: float) -> void:
	_blink_timer += delta
	if _blink_timer >= 0.5:
		_blink_timer = 0.0
		_cursor_visible = !_cursor_visible
		if not _boot_done:
			var cursor = "█" if _cursor_visible else " "
			var base = _label.text.rstrip(" █")
			_label.text = base + cursor
