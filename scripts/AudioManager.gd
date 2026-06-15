extends Node
class_name AudioManager

const CLICK_VARIATIONS  = 5
const SAMPLE_RATE       = 22050

var _click_players: Array[AudioStreamPlayer] = []
var _click_streams:  Array[AudioStreamWAV]    = []
var _voice_player:   AudioStreamPlayer
var _ambient_player: AudioStreamPlayer
var _click_idx:      int = 0
var _click_vol_db:   float = -8.0
var _voice_vol_db:   float = -20.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_build_clicks()
	_build_voice()
	_build_ambient()

# ─── Public API ───────────────────────────────────────────────

func play_click() -> void:
	var p = _click_players[_click_idx % CLICK_VARIATIONS]
	_click_idx += 1
	p.pitch_scale = _rng.randf_range(0.88, 1.14)
	p.stop()
	p.play()

func start_voice() -> void:
	if not _voice_player.playing:
		_voice_player.play()

func stop_voice() -> void:
	if _voice_player.playing:
		var tw = create_tween()
		tw.tween_property(_voice_player, "volume_db", _voice_vol_db - 40.0, 0.25)
		tw.tween_callback(_voice_player.stop)
		tw.tween_callback(func(): _voice_player.volume_db = _voice_vol_db)

func set_click_volume(db: float) -> void:
	_click_vol_db = db
	for p in _click_players:
		p.volume_db = db

func set_voice_volume(db: float) -> void:
	_voice_vol_db = db
	_voice_player.volume_db = db

# ─── Build procedures ─────────────────────────────────────────

func _build_clicks() -> void:
	for i in CLICK_VARIATIONS:
		var stream = _gen_click()
		_click_streams.append(stream)
		var p = AudioStreamPlayer.new()
		p.stream = stream
		p.volume_db = _click_vol_db
		add_child(p)
		_click_players.append(p)

func _build_voice() -> void:
	_voice_player = AudioStreamPlayer.new()
	_voice_player.stream = _gen_voice_hum()
	_voice_player.volume_db = _voice_vol_db
	add_child(_voice_player)

func _build_ambient() -> void:
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.stream = _gen_ambient_hum()
	_ambient_player.volume_db = -32.0
	add_child(_ambient_player)
	_ambient_player.play()

# ─── Sound generators ─────────────────────────────────────────

func _gen_click() -> AudioStreamWAV:
	var dur     = 0.048
	var samples = int(SAMPLE_RATE * dur)
	var data    = PackedByteArray()
	data.resize(samples * 2)

	var click_freq = _rng.randf_range(2800.0, 5200.0)

	for i in samples:
		var t   = float(i) / float(SAMPLE_RATE)
		var env = exp(-t * 130.0)

		var noise = (_rng.randf() - 0.5) * 2.0
		var tone  = sin(t * click_freq * TAU) * 0.25
		# Secondary "mechanical" low thump
		var thump = sin(t * 180.0 * TAU) * exp(-t * 200.0) * 0.4

		var sig = (noise * 0.65 + tone + thump) * env
		_write_s16(data, i, sig * 30000.0)

	var wav = AudioStreamWAV.new()
	wav.format    = AudioStreamWAV.FORMAT_16_BIT
	wav.mix_rate  = SAMPLE_RATE
	wav.stereo    = false
	wav.data      = data
	return wav

func _gen_voice_hum() -> AudioStreamWAV:
	var dur     = 0.6
	var samples = int(SAMPLE_RATE * dur)
	var data    = PackedByteArray()
	data.resize(samples * 2)

	for i in samples:
		var t = float(i) / float(SAMPLE_RATE)

		# Low robotic voice fundamental
		var f0  = sin(t * 155.0 * TAU) * 0.22
		var f1  = sin(t * 310.0 * TAU) * 0.10
		var f2  = sin(t * 465.0 * TAU) * 0.05
		# Amplitude modulation → "speaking" cadence
		var am  = (0.6 + sin(t * 8.5 * TAU) * 0.4)
		# Subtle noise
		var ns  = (_rng.randf() - 0.5) * 0.05
		# Rare digital artifact
		var art = 0.0
		if _rng.randf() < 0.004:
			art = (_rng.randf() - 0.5) * 0.35

		var sig = (f0 + f1 + f2 + ns + art) * am
		_write_s16(data, i, sig * 32767.0)

	var wav = AudioStreamWAV.new()
	wav.format      = AudioStreamWAV.FORMAT_16_BIT
	wav.mix_rate    = SAMPLE_RATE
	wav.stereo      = false
	wav.loop_mode   = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin  = 0
	wav.loop_end    = samples - 1
	wav.data        = data
	return wav

func _gen_ambient_hum() -> AudioStreamWAV:
	var dur     = 2.0
	var samples = int(SAMPLE_RATE * dur)
	var data    = PackedByteArray()
	data.resize(samples * 2)

	for i in samples:
		var t   = float(i) / float(SAMPLE_RATE)
		var hum = sin(t * 50.0 * TAU) * 0.04    # electrical hum
		var hm2 = sin(t * 100.0 * TAU) * 0.02   # harmonic
		var ns  = (_rng.randf() - 0.5) * 0.012  # white noise floor
		_write_s16(data, i, (hum + hm2 + ns) * 32767.0)

	var wav = AudioStreamWAV.new()
	wav.format      = AudioStreamWAV.FORMAT_16_BIT
	wav.mix_rate    = SAMPLE_RATE
	wav.stereo      = false
	wav.loop_mode   = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin  = 0
	wav.loop_end    = samples - 1
	wav.data        = data
	return wav

# ─── Helpers ─────────────────────────────────────────────────

func _write_s16(data: PackedByteArray, index: int, value: float) -> void:
	var v = int(clamp(value, -32768.0, 32767.0))
	data[index * 2]     = v & 0xFF
	data[index * 2 + 1] = (v >> 8) & 0xFF
