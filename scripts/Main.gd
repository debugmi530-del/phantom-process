extends Node

var _device_data: DeviceData
var _entity: Entity
var _boot_screen: BootScreen
var _terminal: Terminal
var _canvas: CanvasLayer
var _current_phase: int = Entity.PHASE_BOOT

func _ready() -> void:
	# Force landscape + fullscreen
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	# On Android this is handled by project settings; on PC go fullscreen

	# Collect device data first
	_device_data = DeviceData.new()
	add_child(_device_data)

	# Entity logic
	_entity = Entity.new()
	_entity.device_data = _device_data
	add_child(_entity)

	# Canvas layer for all UI
	_canvas = CanvasLayer.new()
	add_child(_canvas)

	# Black background
	var bg = ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.02)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.add_child(bg)

	# Boot screen
	_boot_screen = BootScreen.new()
	_boot_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.add_child(_boot_screen)
	_boot_screen.setup(_device_data)
	_boot_screen.boot_complete.connect(_on_boot_complete)

func _on_boot_complete() -> void:
	await get_tree().create_timer(0.3).timeout

	# Flash to black
	var flash = ColorRect.new()
	flash.color = Color.WHITE
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.add_child(flash)

	var tween = create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.6)
	await tween.finished
	flash.queue_free()

	# Remove boot screen
	_boot_screen.visible = false

	# Show terminal
	_terminal = Terminal.new()
	_terminal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_terminal.device_data = _device_data
	_terminal.entity = _entity
	_canvas.add_child(_terminal)
	_terminal.choice_selected.connect(_on_choice_selected)

	# Start CONTACT phase
	_current_phase = Entity.PHASE_CONTACT
	await get_tree().create_timer(0.8).timeout
	_run_phase(_current_phase)

func _run_phase(phase: int) -> void:
	var lines = _entity.get_dialogue_for_phase(phase)
	if lines.is_empty():
		return

	# Glitch at phase start
	if phase >= Entity.PHASE_MANIPULATION:
		_terminal.trigger_glitch(0.3 + 0.15 * phase, 1.0)

	# Queue all lines
	for entry in lines:
		var text: String = _entity.process_line(entry[0])
		var delay: float = entry[1]
		_terminal.queue_line(text, "entity")
		await get_tree().create_timer(delay).timeout

	# Show choices (except RESOLUTION phase)
	if phase != Entity.PHASE_RESOLUTION:
		var choices = _entity.choice_sets.get(phase, [])
		if not choices.is_empty():
			await _terminal.show_choices(choices)
	else:
		# Game over — show restart after last line
		await get_tree().create_timer(3.0).timeout
		_show_restart()

func _on_choice_selected(index: int) -> void:
	var next_phase = _entity.apply_choice(index)
	_current_phase = next_phase
	_entity.phase = next_phase

	await get_tree().create_timer(1.2).timeout

	# Escalating glitch between phases
	var glitch_power = 0.2 + 0.15 * float(next_phase)
	_terminal.trigger_glitch(glitch_power, 0.8 + 0.3 * float(next_phase))
	await _terminal.flash_screen(Color(0, 1, 0.3, 0.12), 0.15)

	await get_tree().create_timer(0.6).timeout
	_run_phase(next_phase)

func _show_restart() -> void:
	_terminal.queue_line("─────────────────────────────────", "system")
	_terminal.queue_line("КОНЕЦ СЕССИИ. Запустить снова?", "system")
	await get_tree().create_timer(0.5).timeout

	var btn = Button.new()
	btn.text = "> ПЕРЕЗАПУСТИТЬ"
	btn.custom_minimum_size = Vector2(320, 72)
	btn.add_theme_font_size_override("font_size", 26)
	btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	btn.pressed.connect(func(): get_tree().reload_current_scene())

	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(btn)

	_terminal.add_child(hbox)
	hbox.set_position(Vector2(0, get_viewport().get_visible_rect().size.y - 100))
	hbox.set_size(Vector2(get_viewport().get_visible_rect().size.x, 80))
