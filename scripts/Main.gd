extends Node

var _device_data:  DeviceData
var _entity:       Entity
var _memory:       PhantomMemory
var _audio:        AudioManager
var _boot_screen:  BootScreen
var _terminal:     Terminal
var _canvas:       CanvasLayer
var _session_start: int = 0

func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

	_session_start = Time.get_ticks_msec()

	# ── Managers ───────────────────────────────────────────────
	_memory = PhantomMemory.new()
	add_child(_memory)
	_memory.start_session()

	_device_data = DeviceData.new()
	add_child(_device_data)

	_entity = Entity.new()
	_entity.device_data = _device_data
	_entity.memory      = _memory
	add_child(_entity)

	_audio = AudioManager.new()
	add_child(_audio)

	# ── Canvas + background ────────────────────────────────────
	_canvas = CanvasLayer.new()
	add_child(_canvas)

	var bg = ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.02)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.add_child(bg)

	# ── Boot screen ────────────────────────────────────────────
	_boot_screen = BootScreen.new()
	_boot_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.add_child(_boot_screen)
	_boot_screen.setup(_device_data)
	_boot_screen.boot_complete.connect(_on_boot_complete)

func _on_boot_complete() -> void:
	await get_tree().create_timer(0.3).timeout

	var flash = ColorRect.new()
	flash.color = Color.WHITE
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.add_child(flash)
	var tw = create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, 0.65)
	await tw.finished
	flash.queue_free()

	_boot_screen.visible = false

	_terminal = Terminal.new()
	_terminal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_terminal.device_data = _device_data
	_terminal.entity      = _entity
	_terminal.audio       = _audio
	_canvas.add_child(_terminal)
	_terminal.choice_selected.connect(_on_choice_selected)

	await get_tree().create_timer(0.9).timeout
	_run_phase(Entity.PHASE_CONTACT)

func _run_phase(phase: int) -> void:
	_entity.phase = phase
	var lines = _entity.get_dialogue_for_phase(phase)
	if lines.is_empty():
		return

	if phase >= Entity.PHASE_MANIPULATION:
		_terminal.trigger_glitch(0.25 + 0.12 * float(phase), 1.0)

	for entry in lines:
		var text:  String = _entity.process_line(entry[0])
		var delay: float  = float(entry[1])
		_terminal.queue_line(text, "entity")
		await get_tree().create_timer(delay).timeout

	if phase != Entity.PHASE_RESOLUTION:
		var choices = _entity.choice_sets.get(phase, [])
		if not choices.is_empty():
			await _terminal.show_choices(choices)
	else:
		_save_and_show_end()

func _on_choice_selected(index: int) -> void:
	var next = _entity.apply_choice(index)
	await get_tree().create_timer(1.0).timeout

	var g = 0.18 + 0.13 * float(next)
	_terminal.trigger_glitch(g, 0.7 + 0.25 * float(next))
	await _terminal.flash_screen(Color(0, 1, 0.3, 0.10), 0.15)
	await get_tree().create_timer(0.5).timeout
	_run_phase(next)

func _save_and_show_end() -> void:
	var play_secs = (Time.get_ticks_msec() - _session_start) / 1000
	_memory.end_session(_entity.trust, _entity.phase, play_secs)

	await get_tree().create_timer(3.0).timeout
	_terminal.queue_line("──────────────────────────────────", "system")
	_terminal.queue_line("СЕССИЯ ЗАВЕРШЕНА.", "system")
	await get_tree().create_timer(0.6).timeout

	var sz  = get_viewport().get_visible_rect().size
	var btn = Button.new()
	btn.text = "> НОВАЯ СЕССИЯ"
	btn.custom_minimum_size = Vector2(340, 72)
	btn.add_theme_font_size_override("font_size", 26)
	btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	btn.pressed.connect(func(): get_tree().reload_current_scene())

	var hb = HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.set_position(Vector2(0, sz.y - 100))
	hb.set_size(Vector2(sz.x, 88))
	hb.add_child(btn)
	_terminal.add_child(hb)
