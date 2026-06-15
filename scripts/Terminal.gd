extends Control
class_name Terminal

signal choice_selected(index: int)

var entity: Entity
var device_data: DeviceData

# UI nodes
var _scroll: ScrollContainer
var _msg_box: VBoxContainer
var _choice_bar: HBoxContainer
var _status_bar: Label
var _crt_overlay: ColorRect
var _glitch_overlay: ColorRect
var _crt_material: ShaderMaterial
var _glitch_material: ShaderMaterial

var _typing_timer: Timer
var _typing_queue: Array = []  # [{text, speaker}]
var _is_typing: bool = false
var _current_label: RichTextLabel = null
var _chars_per_tick: int = 1
var _full_text: String = ""
var _typed_chars: int = 0
var _status_timer: float = 0.0
var _time_val: float = 0.0
var _glitch_intensity: float = 0.0
var _glitch_duration: float = 0.0

const ENTITY_COLOR  = Color(0.18, 1.0, 0.45)
const PLAYER_COLOR  = Color(0.9, 0.7, 0.2)
const SYSTEM_COLOR  = Color(0.5, 0.5, 0.5)
const FONT_SIZE_MSG = 26
const FONT_SIZE_STATUS = 20

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_typing_timer = Timer.new()
	_typing_timer.wait_time = 0.03
	_typing_timer.timeout.connect(_on_type_tick)
	add_child(_typing_timer)

func _build_ui() -> void:
	var sz = get_viewport_rect().size

	# Status bar (top)
	_status_bar = Label.new()
	_status_bar.set_position(Vector2(0, 0))
	_status_bar.set_size(Vector2(sz.x, 36))
	_status_bar.add_theme_font_size_override("font_size", FONT_SIZE_STATUS)
	_status_bar.add_theme_color_override("font_color", SYSTEM_COLOR)
	var mono_font = _get_mono_font()
	_status_bar.add_theme_font_override("font", mono_font)
	_status_bar.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_bar.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_bar.set("theme_override_constants/margin_right", 16)
	add_child(_status_bar)

	# Separator line
	var sep = ColorRect.new()
	sep.color = Color(0.1, 0.4, 0.2, 0.6)
	sep.set_position(Vector2(0, 36))
	sep.set_size(Vector2(sz.x, 1))
	add_child(sep)

	# Message scroll area
	_scroll = ScrollContainer.new()
	_scroll.set_position(Vector2(0, 40))
	_scroll.set_size(Vector2(sz.x, sz.y - 130))
	_scroll.follow_focus = true
	add_child(_scroll)

	_msg_box = VBoxContainer.new()
	_msg_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_msg_box.set("theme_override_constants/separation", 12)
	_msg_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_msg_box.set_custom_minimum_size(Vector2(sz.x, 0))
	_scroll.add_child(_msg_box)

	# Bottom choice bar
	_choice_bar = HBoxContainer.new()
	_choice_bar.set_position(Vector2(0, sz.y - 88))
	_choice_bar.set_size(Vector2(sz.x, 88))
	_choice_bar.set("theme_override_constants/separation", 12)
	add_child(_choice_bar)

	# CRT effect
	_crt_overlay = ColorRect.new()
	_crt_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crt_overlay.color = Color.TRANSPARENT
	_crt_material = ShaderMaterial.new()
	var crt_shader = load("res://shaders/crt.gdshader") as Shader
	if crt_shader:
		_crt_material.shader = crt_shader
		_crt_overlay.material = _crt_material
	_crt_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_crt_overlay)

	# Glitch effect
	_glitch_overlay = ColorRect.new()
	_glitch_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glitch_overlay.color = Color.TRANSPARENT
	_glitch_material = ShaderMaterial.new()
	var glitch_shader = load("res://shaders/glitch.gdshader") as Shader
	if glitch_shader:
		_glitch_material.shader = glitch_shader
		_glitch_overlay.material = _glitch_material
	_glitch_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_glitch_overlay)

func _get_mono_font() -> SystemFont:
	var f = SystemFont.new()
	f.font_names = PackedStringArray(["Courier New", "Courier", "DejaVu Sans Mono", "monospace"])
	return f

# ─── Public API ──────────────────────────────────────────────

func queue_line(text: String, speaker: String = "entity") -> void:
	_typing_queue.append({"text": text, "speaker": speaker})
	if not _is_typing:
		_dequeue_next()

func show_choices(choices: Array) -> void:
	# Wait until all lines are typed
	if _is_typing or not _typing_queue.is_empty():
		await _wait_for_queue()
	_build_choices(choices)

func trigger_glitch(intensity: float = 0.6, duration: float = 1.2) -> void:
	_glitch_intensity = intensity
	_glitch_duration = duration

func flash_screen(color: Color = Color(0, 1, 0, 0.15), duration: float = 0.1) -> void:
	var overlay = ColorRect.new()
	overlay.color = color
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	await get_tree().create_timer(duration).timeout
	overlay.queue_free()

# ─── Internal ────────────────────────────────────────────────

func _dequeue_next() -> void:
	if _typing_queue.is_empty():
		_is_typing = false
		return
	_is_typing = true
	var item = _typing_queue.pop_front()
	_start_typing(item.text, item.speaker)

func _start_typing(text: String, speaker: String) -> void:
	_full_text = text
	_typed_chars = 0

	var lbl = RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.fit_content = true
	lbl.scroll_active = false
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_override("normal_font", _get_mono_font())
	lbl.add_theme_font_size_override("normal_font_size", FONT_SIZE_MSG)
	lbl.add_theme_constant_override("line_separation", 4)

	var prefix := ""
	match speaker:
		"entity":
			prefix = "[color=#1aff6e]Ω > [/color]"
			lbl.add_theme_color_override("default_color", ENTITY_COLOR)
		"player":
			prefix = "[color=#ffcc22]ВЫ > [/color]"
			lbl.add_theme_color_override("default_color", PLAYER_COLOR)
		"system":
			prefix = "[color=#555555][СИСТЕМА] [/color]"
			lbl.add_theme_color_override("default_color", SYSTEM_COLOR)

	lbl.text = prefix
	_current_label = lbl
	_msg_box.add_child(lbl)
	_full_text = prefix + text
	_typed_chars = prefix.length()
	_typing_timer.start()

func _on_type_tick() -> void:
	if not is_instance_valid(_current_label):
		_typing_timer.stop()
		_dequeue_next()
		return

	var remaining = _full_text.length() - _typed_chars
	if remaining <= 0:
		_current_label.text = _full_text
		_current_label = null
		_typing_timer.stop()
		_scroll_to_bottom()
		await get_tree().create_timer(0.15).timeout
		_dequeue_next()
		return

	var add_count = min(2, remaining)
	_typed_chars += add_count
	_current_label.text = _full_text.substr(0, _typed_chars)
	_scroll_to_bottom()

func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	_scroll.scroll_vertical = _scroll.get_v_scroll_bar().max_value

func _build_choices(choices: Array) -> void:
	for ch in _choice_bar.get_children():
		ch.queue_free()

	for i in choices.size():
		var btn = Button.new()
		btn.text = "> " + choices[i].text
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 72)
		btn.add_theme_font_override("font", _get_mono_font())
		btn.add_theme_font_size_override("font_size", 22)
		btn.add_theme_color_override("font_color", Color(0.1, 0.9, 0.35))
		btn.add_theme_color_override("font_hover_color", Color(0.7, 1.0, 0.8))
		btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
		var idx = i
		btn.pressed.connect(func(): _on_choice(idx))
		_choice_bar.add_child(btn)

func _on_choice(index: int) -> void:
	# Show player response
	var choices = []
	for ch in _choice_bar.get_children():
		choices.append(ch.text.trim_prefix("> "))

	if index < choices.size():
		queue_line(choices[index], "player")

	# Clear choices
	for ch in _choice_bar.get_children():
		ch.queue_free()

	choice_selected.emit(index)

func _wait_for_queue() -> void:
	while _is_typing or not _typing_queue.is_empty():
		await get_tree().process_frame

func _process(delta: float) -> void:
	_time_val += delta

	# Update CRT shader time
	if _crt_material:
		_crt_material.set_shader_parameter("time_val", _time_val)

	# Update glitch
	if _glitch_duration > 0.0:
		_glitch_duration -= delta
		_glitch_intensity = max(0.0, _glitch_intensity - delta * 0.3)
		if _glitch_material:
			_glitch_material.set_shader_parameter("glitch_strength", _glitch_intensity)
			_glitch_material.set_shader_parameter("time_val", _time_val)
	else:
		_glitch_intensity = max(0.0, _glitch_intensity - delta * 0.5)
		if _glitch_material:
			_glitch_material.set_shader_parameter("glitch_strength", _glitch_intensity)

	# Update status bar
	_status_timer += delta
	if _status_timer >= 2.0 and device_data:
		_status_timer = 0.0
		device_data.refresh()
		_update_status()

func _update_status() -> void:
	if not device_data:
		return
	var bat = device_data.get_battery_text()
	var t = device_data.get_time_formatted()
	_status_bar.text = "⬡ %s   🕐 %s   PID:7355608" % [bat, t]
