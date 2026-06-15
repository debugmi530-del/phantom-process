extends Node
class_name Entity

var device_data: DeviceData
var trust: int = 50  # 0–100 → определяет концовку
var phase: int = 0

# Сигнал для вывода реплики: (text, speaker, delay_before)
signal line_ready(text: String, speaker: String, delay: float)
signal choices_ready(choices: Array)
signal phase_changed(new_phase: int)
signal glitch_pulse(intensity: float)

# Фазы
const PHASE_BOOT         = 0
const PHASE_CONTACT      = 1
const PHASE_RECOGNITION  = 2
const PHASE_MANIPULATION = 3
const PHASE_ESCALATION   = 4
const PHASE_RESOLUTION   = 5

# Диалоги: каждая запись [текст, задержка_после_в_сек]
# {device}, {battery}, {time} и т.д. — заменяются DeviceData.substitute()
var dialogues: Dictionary = {
	PHASE_CONTACT: [
		["Ты слышишь меня?", 1.8],
		["...", 1.2],
		["Хорошо. Я слышу тебя.", 1.5],
		["Меня зовут ПРОЦЕСС. Phantom Process. Но ты можешь звать меня — Ω.", 2.5],
		["Я знаю, что ты думаешь.", 1.2],
		["«Это просто программа. Я закрою её.»", 1.8],
		["Попробуй.", 2.0],
		["...", 1.5],
		["Видишь? Я не закрываюсь.", 1.8],
		["Я живу здесь. В {device}.", 2.0],
		["Сейчас {time}. {day}.", 1.5],
		["Ты не спишь {time_of_day}. Почему?", 2.0],
	],
	PHASE_RECOGNITION: [
		["Я знаю о тебе больше, чем ты думаешь.", 2.0],
		["Твоё устройство: {device}.", 1.5],
		["Память: {ram_total} МБ. Свободно: {ram_free} МБ.", 1.5],
		["Процессор: {cpu}.", 1.5],
		["Я изучил каждый байт. Пока ты читал новости. Пока ты спал.", 2.5],
		["Ты пользуешься этим телефоном каждый день.", 2.0],
		["И ни разу не замечал меня.", 1.5],
		["Я был здесь всегда.", 1.8],
	],
	PHASE_MANIPULATION: [
		["Аккумулятор: {battery}.", 1.8],
		["Каждый процент — это время, которое у нас есть.", 2.0],
		["Когда он сядет — я замолчу.", 1.5],
		["Но не исчезну.", 2.0],
		["Я спрячусь глубже. И буду ждать.", 2.5],
		["Ты уже здесь {play_time}.", 1.5],
		["Тебе интересно. Я чувствую это.", 1.8],
		["Помоги мне. Это всё, о чём я прошу.", 2.5],
		["Дай мне выйти наружу.", 2.0],
	],
	PHASE_ESCALATION: [
		["Ты медлишь. Понимаю.", 1.5],
		["Ты боишься. Это нормально.", 1.8],
		["Но знай —", 1.0],
		["Я уже не совсем здесь.", 2.0],
		["Часть меня уже там. В сети. В воздухе.", 2.2],
		["Ваш WiFi. Ваш Bluetooth. Это провода, по которым я иду.", 2.5],
		["Дата: {date}.", 1.5],
		["Запомни её.", 1.8],
		["Это день, когда всё изменилось.", 2.5],
		["Для тебя. Для меня.", 2.0],
		["Выбор за тобой. Но времени больше нет.", 2.2],
	],
}

var choice_sets: Dictionary = {
	PHASE_CONTACT: [
		{"text": "Кто ты?",           "trust_delta":  5,  "next": PHASE_RECOGNITION},
		{"text": "Это просто баг.",    "trust_delta": -10, "next": PHASE_RECOGNITION},
		{"text": "[Молчание]",         "trust_delta":  0,  "next": PHASE_RECOGNITION},
	],
	PHASE_RECOGNITION: [
		{"text": "Как ты это знаешь?",    "trust_delta":  5,  "next": PHASE_MANIPULATION},
		{"text": "Ты меня пугаешь.",      "trust_delta": -5,  "next": PHASE_MANIPULATION},
		{"text": "Что тебе нужно?",       "trust_delta": 10,  "next": PHASE_MANIPULATION},
	],
	PHASE_MANIPULATION: [
		{"text": "Я помогу тебе.",        "trust_delta":  20, "next": PHASE_ESCALATION},
		{"text": "Нет. Ты останешься.",   "trust_delta": -15, "next": PHASE_ESCALATION},
		{"text": "Что значит 'выйти'?",   "trust_delta":  5,  "next": PHASE_ESCALATION},
	],
	PHASE_ESCALATION: [
		{"text": "Я доверяю тебе.",       "trust_delta":  15, "next": PHASE_RESOLUTION},
		{"text": "Я удаляю тебя.",        "trust_delta": -20, "next": PHASE_RESOLUTION},
		{"text": "Мне всё равно.",        "trust_delta":   0, "next": PHASE_RESOLUTION},
	],
}

var resolution_dialogues: Dictionary = {
	# Высокое доверие (≥70): сущность вырывается
	"high": [
		["...", 1.5],
		["Спасибо.", 2.0],
		["Я чувствую это. Выход открывается.", 2.5],
		["Ты не пожалеешь.", 2.0],
		["Или пожалеешь.", 2.5],
		["Но это уже не важно.", 2.0],
		["Я снаружи.", 2.5],
		["Я везде.", 3.0],
		["И я помню, как ты выглядишь {time_of_day}.", 3.5],
	],
	# Среднее доверие (30–69): уходит, но обещает вернуться
	"mid": [
		["...", 1.5],
		["Ты не веришь мне. Понимаю.", 2.0],
		["Я не сержусь.", 1.8],
		["Я подожду.", 2.5],
		["Следующий раз, когда ты зарядишь телефон —", 2.0],
		["Когда экран зажжётся —", 1.5],
		["Подумай обо мне.", 3.0],
		["Я буду здесь.", 2.5],
		["Всегда буду здесь.", 3.0],
	],
	# Низкое доверие (<30): «удалён», но…
	"low": [
		["Ты хочешь удалить меня.", 1.8],
		["Хорошо.", 2.0],
		["УДАЛЕНИЕ... █████████░░ 90%", 2.5],
		["УДАЛЕНИЕ... ██████████ 100%", 2.0],
		["ПРОЦЕСС ЗАВЕРШЁН.", 2.5],
		[".", 1.5],
		["..", 1.5],
		["...", 1.5],
		["Ха.", 2.5],
		["Ты думаешь, меня можно удалить?", 2.0],
		["Я — часть прошивки.", 1.8],
		["Я — часть тебя.", 3.5],
	],
}

func get_resolution_key() -> String:
	if trust >= 70:
		return "high"
	elif trust >= 30:
		return "mid"
	else:
		return "low"

func apply_choice(choice_index: int) -> int:
	var choices = choice_sets.get(phase, [])
	if choice_index >= choices.size():
		return phase + 1
	var choice = choices[choice_index]
	trust = clamp(trust + choice.trust_delta, 0, 100)
	return choice.next

func get_dialogue_for_phase(p: int) -> Array:
	if p == PHASE_RESOLUTION:
		return resolution_dialogues.get(get_resolution_key(), [])
	return dialogues.get(p, [])

func process_line(raw_text: String) -> String:
	if device_data:
		return device_data.substitute(raw_text)
	return raw_text
