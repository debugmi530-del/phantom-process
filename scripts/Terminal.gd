extends Control
class_name Terminal

signal choice_selected(index: int)

var entity:      Entity
var device_data: DeviceData
var audio:       AudioManager

var _scroll:       ScrollContainer
var _msg_box:      VBoxContainer
var _choice_bar:   HBoxContainer
var _status_bar:   Label
var _crt_overlay:  ColorRect
var _glitch_mat:   ShaderMaterial
var _crt_mat:      ShaderMaterial

var _typing_timer:  Timer
var _typing_queue:  Array = []
var _is_typing:     bool  = false
var _current_lbl:   RichTextLabel = null
var _full_text:     String = ""
var _typed_chars:   int   = 0
var _time_val:      float = 0.0
var _status_timer:  float = 0.0
var _glitch_dur:    float = 0.0
var _glitch_lvl:    float = 0.0
var _char_tick:     int   = 0

const ENTITY_COLOR  = Color(0.18, 1.00, 0.45)
const PLAYER_COLOR  = Color(0.90, 0.70, 0.20)
const SYSTEM_COLOR  = Color(0.50, 0.50, 0.50)
const FONT_MSG_SZ   = 26
const FONT_STATUS_SZ= 20

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_typing_timer = Timer.new()
	_typing_timer.wait_time = 0.032   # ~31 chars/sec
	_typing_timer.timeout.connect(_on_type_tick)
	add_child(_typing_timer)

# ─── Public API ───────────────────────────────────────────────

func queue_line(text: String, speaker: String = "entity") -> void:
	_typing_queue.append({"text": text, "speaker": speaker})
	if not _is_typing:
		_dequeue_next()

func show_choices(choices: Array) -> void:
	await _wait_queue_empty()
	_build_choices(choices)

func trigger_glitch(intensity: float = 0.5, duration: float = 1.2) -> void:
	_glitch_lvl = max(_glitch_lvl, intensity)
	_glitch_dur = max(_glitch_dur, duration)
	if _glitch_mat:
		_glitch_mat.set_shader_parameter("glitch_strength", _glitch_lvl)

func flash_screen(color: Color = Color(0, 1, 0.3, 0.12), dur: float = 0.12) -> void:
	var ov = ColorRect.new()
	ov.color = color
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ov)
	await get_tree().create_timer(dur).timeout
	ov.queue_free()

# ─── UI Build ─────────────────────────────────────────────────

func _build_ui() -> void:
	var sz = get_viewport_rect().size

	# Status bar
	_status_bar = Label.new()
	_status_bar.set_position(Vector2(0, 0))
	_status_bar.set_size(Vector2(sz.x, 36))
	_status_bar.add_theme_font_size_override("font_size", FONT_STATUS_SZ)
	_status_bar.add_theme_color_override("font_color", SYSTEM_COLOR)
	_status_bar.add_theme_font_override("font", _mono_font())
	_status_bar.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_status_bar.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_status_bar)

	# Separator
	var sep = ColorRect.new()
	sep.color = Color(0.08, 0.35, 0.18, 0.55)
	sep.set_position(Vector2(0, 36))
	sep.set_size(Vector2(sz.x, 1))
	add_child(sep)

	# Message scroll
	_scroll = ScrollContainer.new()
	_scroll.set_position(Vector2(0, 40))
	_scroll.set_size(Vector2(sz.x, sz.y - 130))
	_scroll.follow_focus = false
	add_child(_scroll)

	_msg_box = VBoxContainer.new()
	_msg_box.set("theme_override_constants/separation", 10)
	_msg_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_msg_box.set_custom_minimum_size(Vector2(sz.x, 0))
	_scroll.add_child(_msg_box)

	# Choice bar
	_choice_bar = HBoxContainer.new()
	_choice_bar.set_position(Vector2(8, sz.y - 90))
	_choice_bar.set_size(Vector2(sz.x - 16, 84))
	_choice_bar.set("theme_override_constants/separation", 10)
	add_child(_choice_bar)

	# CRT overlay
	_crt_overlay = ColorRect.new()
	_crt_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crt_overlay.color = Color.TRANSPARENT
	_crt_mat = ShaderMaterial.new()
	var crt_sh = load("res://shaders/crt.gdshader") as Shader
	if crt_sh:
		_crt_mat.shader = crt_sh
		_crt_overlay.material = _crt_mat
	_crt_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_crt_overlay)

	# Glitch overlay
	var glitch_ov = ColorRect.new()
	glitch_ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	glitch_ov.color = Color.TRANSPARENT
	_glitch_mat = ShaderMaterial.new()
	var glitch_sh = load("res://shaders/glitch.gdshader") as Shader
	if glitch_sh:
		_glitch_mat.shader = glitch_sh
		glitch_ov.material = _glitch_mat
	glitch_ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glitch_ov)

func _mono_font() -> SystemFont:
	var f = SystemFont.new()
	f.font_names = PackedStringArray(["Courier New","Courier","DejaVu Sans Mono","monospace"])
	return f

# ─── Typing engine ────────────────────────────────────────────

func _dequeue_next() -> void:
	if _typing_queue.is_empty():
		_is_typing = false
		if audio:
			audio.stop_voice()
		return
	_is_typing = true
	var item = _typing_queue.pop_front()
	_start_typing(item.text, item.speaker)

func _start_typing(text: String, speaker: String) -> void:
	_full_text   = ""
	_typed_chars = 0

	var lbl = RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.fit_content    = true
	lbl.scroll_active  = false
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_override("normal_font", _mono_font())
	lbl.add_theme_font_size_override("normal_font_size", FONT_MSG_SZ)
	lbl.add_theme_constant_override("line_separation", 4)

	var prefix := ""
	match speaker:
		"entity":
			prefix = "[color=#1aff6e]Ω > [/color]"
			lbl.add_theme_color_override("default_color", ENTITY_COLOR)
			if audio:
				audio.start_voice()
		"player":
			prefix = "[color=#ffcc22]ВЫ > [/color]"
			lbl.add_theme_color_override("default_color", PLAYER_COLOR)
		"system":
			prefix = "[color=#555555][SYS] [/color]"
			lbl.add_theme_color_override("default_color", SYSTEM_COLOR)

	_full_text   = prefix + text
	_typed_chars = prefix.length()    # prefix appears instantly
	lbl.text     = prefix
	_current_lbl = lbl
	_msg_box.add_child(lbl)
	_char_tick   = 0
	_typing_timer.start()

func _on_type_tick() -> void:
	if not is_instance_valid(_current_lbl):
		_typing_timer.stop()
		_dequeue_next()
		return

	var remaining = _full_text.length() - _typed_chars
	if remaining <= 0:
		_current_lbl.text = _full_text
		_current_lbl      = null
		_typing_timer.stop()
		_scroll_bottom()
		await get_tree().create_timer(0.12).timeout
		if audio:
			audio.stop_voice()
		_dequeue_next()
		return

	# Type 1–2 chars per tick; play click every char
	var step = 1
	if _full_text[_typed_chars] == " ":
		step = 2    # space: skip sound
	else:
		_char_tick += 1
		if audio and (_char_tick % 1 == 0):   # click every character
			audio.play_click()

	_typed_chars = min(_typed_chars + step, _full_text.length())
	_current_lbl.text = _full_text.substr(0, _typed_chars)
	_scroll_bottom()

func _scroll_bottom() -> void:
	await get_tree().process_frame
	_scroll.scroll_vertical = _scroll.get_v_scroll_bar().max_value

# ─── Choices ─────────────────────────────────────────────────

func _build_choices(choices: Array) -> void:
	for ch in _choice_bar.get_children():
		ch.queue_free()
	for i in choices.size():
		var btn = Button.new()
		btn.text = "> " + choices[i].text
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size   = Vector2(0, 70)
		btn.add_theme_font_override("font", _mono_font())
		btn.add_theme_font_size_override("font_size", 22)
		btn.add_theme_color_override("font_color",         Color(0.15, 0.90, 0.40))
		btn.add_theme_color_override("font_hover_color",   Color(0.70, 1.00, 0.80))
		btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
		var idx = i
		btn.pressed.connect(func(): _on_choice_pressed(idx, choices))
		_choice_bar.add_child(btn)

func _on_choice_pressed(index: int, choices: Array) -> void:
	if audio:
		audio.play_click()
		audio.play_click()   # double click for selection
	var chosen_text = choices[index].text if index < choices.size() else "?"
	queue_line(chosen_text, "player")
	for ch in _choice_bar.get_children():
		ch.queue_free()
	choice_selected.emit(index)

func _wait_queue_empty() -> void:
	while _is_typing or not _typing_queue.is_empty():
		await get_tree().process_frame

# ─── Process ─────────────────────────────────────────────────

func _process(delta: float) -> void:
	_time_val += delta
	if _crt_mat:
		_crt_mat.set_shader_parameter("time_val", _time_val)

	if _glitch_dur > 0.0:
		_glitch_dur -= delta
		if _glitch_dur <= 0.0:
			_glitch_lvl = max(0.0, _glitch_lvl - delta * 0.8)
	else:
		_glitch_lvl = max(0.0, _glitch_lvl - delta * 0.6)

	if _glitch_mat:
		_glitch_mat.set_shader_parameter("glitch_strength", _glitch_lvl)
		_glitch_mat.set_shader_parameter("time_val", _time_val)

	_status_timer += delta
	if _status_timer >= 3.0 and device_data:
		_status_timer = 0.0
		device_data.refresh()
		var bat = device_data.get_battery_text()
		var t   = device_data.get_time_formatted()
		_status_bar.text = "⬡ АККУМ: %s   ⏱ %s   PID:7355608   TRUST:%d%%" % [bat, t, entity.trust if entity else 50]
