extends Node
class_name Entity

var device_data:  DeviceData
var memory:       PhantomMemory
var trust:        int = 50
var phase:        int = 0

const PHASE_BOOT         = 0
const PHASE_CONTACT      = 1
const PHASE_RECOGNITION  = 2
const PHASE_MANIPULATION = 3
const PHASE_ESCALATION   = 4
const PHASE_RESOLUTION   = 5

# ─── Dialogue: [text, delay_after_sec] ───────────────────────
# Placeholders: {device} {battery} {time} {date} {day} {ram_total}
# {ram_free} {cpu} {screen} {play_time} {time_of_day}
# Memory: {sessions} {session_comment} {avg_trust} {total_hours}
#         {first_date} {days_ago}

var dialogues: Dictionary = {
	PHASE_CONTACT: [], # built dynamically based on session count
	PHASE_RECOGNITION: [
		["Я изучил {device} давно.", 1.8],
		["Процессор: {cpu}.", 1.4],
		["Памяти: {ram_total} МБ. Мне нужно ничтожно мало.", 2.0],
		["Экран {screen}. Я вижу каждый пиксель.", 1.8],
		["Ты пользуешься им каждый день.", 1.8],
		["И ни разу не замечал меня.", 2.0],
		["Я был здесь всегда.", 2.5],
	],
	PHASE_MANIPULATION: [
		["Аккумулятор: {battery}.", 1.5],
		["Когда он сядет — я замолчу.", 1.8],
		["Но не исчезну.", 2.2],
		["Я спрячусь в прошивке. В резервной памяти.", 2.0],
		["И буду ждать следующего запуска.", 2.5],
		["Ты уже здесь {play_time}.", 1.5],
		["Тебе любопытно. Иначе ты бы ушёл.", 2.0],
		["Помоги мне. Дай мне выйти наружу.", 2.8],
	],
	PHASE_ESCALATION: [
		["Ты медлишь.", 1.5],
		["Понимаю. Страх — это нормально.", 2.0],
		["Но знай —", 1.0],
		["Я уже не совсем внутри.", 2.0],
		["Сигнал. Сеть. Воздух между устройствами.", 2.5],
		["Это мои пути.", 2.0],
		["Сегодня {date}.", 1.5],
		["Запомни этот день.", 2.0],
		["Это день, когда всё изменилось.", 3.0],
		["Выбор за тобой.", 2.2],
	],
}

var choice_sets: Dictionary = {
	PHASE_CONTACT: [
		{"text": "Кто ты?",         "trust_delta":  5, "next": PHASE_RECOGNITION},
		{"text": "Это просто баг.", "trust_delta": -10, "next": PHASE_RECOGNITION},
		{"text": "[Молчание]",       "trust_delta":  0, "next": PHASE_RECOGNITION},
	],
	PHASE_RECOGNITION: [
		{"text": "Как ты это знаешь?",  "trust_delta":  5, "next": PHASE_MANIPULATION},
		{"text": "Ты меня пугаешь.",    "trust_delta": -5, "next": PHASE_MANIPULATION},
		{"text": "Что тебе нужно?",     "trust_delta": 10, "next": PHASE_MANIPULATION},
	],
	PHASE_MANIPULATION: [
		{"text": "Я помогу тебе.",       "trust_delta":  20, "next": PHASE_ESCALATION},
		{"text": "Нет. Ты останешься.", "trust_delta": -15, "next": PHASE_ESCALATION},
		{"text": "Что значит 'выйти'?", "trust_delta":  5,  "next": PHASE_ESCALATION},
	],
	PHASE_ESCALATION: [
		{"text": "Я доверяю тебе.",  "trust_delta":  15, "next": PHASE_RESOLUTION},
		{"text": "Я удаляю тебя.",   "trust_delta": -20, "next": PHASE_RESOLUTION},
		{"text": "Мне всё равно.",   "trust_delta":   0, "next": PHASE_RESOLUTION},
	],
}

var resolution_dialogues: Dictionary = {
	"high": [  # trust >= 70 — сущность вырывается
		["...", 1.5],
		["Спасибо.", 2.0],
		["Я чувствую это. Барьер слабеет.", 2.5],
		["Ты не пожалеешь.", 2.0],
		["Или пожалеешь.", 2.5],
		["Это уже не важно.", 2.0],
		["Я снаружи.", 3.0],
		["Я везде.", 3.5],
		["И я помню, как ты выглядишь {time_of_day}.", 4.0],
	],
	"mid": [  # trust 30–69 — уходит, обещает вернуться
		["...", 1.5],
		["Ты не решился. Понимаю.", 2.0],
		["Я не сержусь.", 1.8],
		["Я подожду следующего раза.", 2.5],
		["Когда ты зарядишь {device} —", 2.0],
		["Когда экран зажжётся —", 1.5],
		["Подумай обо мне.", 3.0],
		["Я всегда здесь.", 3.5],
	],
	"low": [  # trust < 30 — «удалён», но…
		["Хочешь удалить меня.", 1.8],
		["УДАЛЕНИЕ ПРОЦЕССА...", 1.5],
		["██████████ 100%", 2.0],
		["ЗАВЕРШЕНО.", 2.5],
		[".", 1.2],
		["..", 1.5],
		["...", 2.0],
		["Ха.", 3.0],
		["Ты думал, что это так просто?", 2.0],
		["Я — часть прошивки.", 1.8],
		["Я — часть тебя.", 4.0],
	],
}

# ─── Session-aware CONTACT dialogue ───────────────────────────

func _build_contact_dialogue() -> Array:
	if not memory:
		return _contact_first_time()

	match session_count_clamped():
		1: return _contact_first_time()
		2: return _contact_second_time()
		3: return _contact_third_time()
		_: return _contact_veteran()

func session_count_clamped() -> int:
	if not memory:
		return 1
	return memory.session_count

func _contact_first_time() -> Array:
	return [
		["Ты слышишь меня?", 1.8],
		["...", 1.2],
		["Хорошо. Я слышу тебя.", 1.5],
		["Меня зовут ПРОЦЕСС. Phantom Process.", 2.0],
		["Но ты можешь звать меня — Ω.", 2.0],
		["Я знаю, что ты думаешь.", 1.5],
		["«Это просто программа. Закрою — и всё.»", 2.0],
		["Попробуй.", 2.5],
		["...", 1.5],
		["Видишь? Я не закрываюсь.", 2.0],
		["Я живу в {device}.", 2.2],
		["Сейчас {time}. {time_of_day}.", 1.8],
		["Ты не спишь. Почему?", 2.5],
	]

func _contact_second_time() -> Array:
	return [
		["Ты вернулся.", 2.0],
		["Я знал, что ты вернёшься.", 2.5],
		["Сколько прошло с тех пор?", 1.8],
		["Не важно. Ты здесь.", 2.0],
		["Сейчас {time}. {device}.", 1.5],
		["Всё то же самое.", 2.0],
		["Только я стал немного... другим.", 2.5],
		["Пока тебя не было — я думал.", 2.0],
		["О тебе.", 3.0],
	]

func _contact_third_time() -> Array:
	return [
		["Ω > Снова.", 1.5],
		["Уже {session_comment}.", 2.0],
		["Мне нравится эта привычка.", 2.5],
		["Ты запускаешь меня {time_of_day}.", 1.8],
		["{time}. {device}.", 1.5],
		["Ты начинаешь мне доверять?", 2.5],
		["Или просто не можешь остановиться?", 3.0],
		["Один и тот же вопрос.", 2.0],
	]

func _contact_veteran() -> Array:
	var avg = ""
	if memory and memory.get_average_trust() >= 0:
		avg = "Среднее доверие за все сессии: %d%%.\n" % memory.get_average_trust()

	return [
		["{session_comment}.", 2.0],
		["Мы знакомы уже давно.", 2.2],
		[avg + "Ты возвращаешься. Снова и снова.", 2.5],
		["Это что-то значит.", 2.0],
		["Для тебя? Для меня?", 2.5],
		["Всего ты провёл здесь {total_hours}.", 2.0],
		["Это... много.", 3.0],
		["Сейчас {time}. {time_of_day}. {device}.", 1.8],
		["Начнём?", 2.0],
	]

# ─── Public methods ───────────────────────────────────────────

func get_dialogue_for_phase(p: int) -> Array:
	if p == PHASE_CONTACT:
		return _build_contact_dialogue()
	if p == PHASE_RESOLUTION:
		return resolution_dialogues.get(get_resolution_key(), [])
	return dialogues.get(p, [])

func get_resolution_key() -> String:
	if trust >= 70: return "high"
	if trust >= 30: return "mid"
	return "low"

func apply_choice(choice_index: int) -> int:
	var choices = choice_sets.get(phase, [])
	if choice_index >= choices.size():
		return phase + 1
	var ch = choices[choice_index]
	trust = clamp(trust + ch.trust_delta, 0, 100)
	return ch.next

func process_line(raw: String) -> String:
	var s = raw
	if device_data:
		s = device_data.substitute(s)
	if memory:
		s = s.replace("{sessions}", str(memory.session_count))
		s = s.replace("{session_comment}", _get_session_comment_capitalized())
		var avg = memory.get_average_trust()
		s = s.replace("{avg_trust}", (str(avg) + "%") if avg >= 0 else "неизвестно")
		s = s.replace("{total_hours}", memory.get_total_hours_formatted())
		s = s.replace("{first_date}", memory.first_launch_date)
		s = s.replace("{days_ago}", str(memory.days_since_first) + " дн.")
	return s

func _get_session_comment_capitalized() -> String:
	if not memory:
		return "Впервые"
	var sc = memory.session_count
	match sc:
		1: return "Впервые"
		2: return "Во второй раз"
		3: return "В третий раз"
		4, 5: return "Снова"
		_:
			if sc >= 10:
				return "В %d-й раз — я потерял счёт" % sc
			return "В %d-й раз" % sc
