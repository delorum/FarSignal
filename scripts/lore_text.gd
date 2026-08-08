extends RefCounted

const OBJECTIVE_TEXT := "Мы принимаем слабый сигнал с верхней стены - там есть выход.\n\nНайди его и проложи безопасный маршрут.\n\nСтанция расскажет подробности."
const NOTE_ONE_TEXT := "TODO"
const NOTE_TWO_TEXT := "TODO"
const NOTE_THREE_TEXT := "TODO"
const FINAL_TEXT := "TODO"
const STATION_INSTRUCTIONS := "1. Убивай охотников, забирай энергоядра и сдавай их на Станции 1.\n\n2. Исследуй клетки карты и сдавай накопленные очки исследования.\n\n3. Ищи мегаядра и возвращай их на Станцию 1.\n\n4. За ядра и исследование ты получаешь энергию. Чем опаснее враг или зона относительно твоего уровня, тем выше награда.\n\n5. На Станции 1 покупай здоровье, патроны, турели и башни.\n\n6. Колесом мыши выбирай режим установки башни, установки турели, стрельбы или предохранителя. Установка и демонтаж башни или турели правой кнопкой занимают две секунды.\n\n7. Башня подключается к двери Станции 1 или другой подключенной башне в прямой видимости. Желтые линии показывают сеть.\n\n8. Подключенная башня создает безопасную зону вокруг себя. Враги там не появляются, но могут войти и разрушить башню.\n\n9. Клавишей E можно передать башне здоровье, а турели - здоровье и патроны.\n\n10. Чем больше безопасная зона, тем меньше врагов остается на карте.\n\n11. Чем выше по карте, тем сильнее враги. Найди Станции 2 и 3: там за энергию можно улучшать урон, здоровье и боезапас."


static func objective_text() -> String:
	return TranslationServer.translate(OBJECTIVE_TEXT)


static func station_instructions() -> String:
	var instructions := TranslationServer.translate(STATION_INSTRUCTIONS)
	instructions = instructions.replace(
		TranslationServer.translate(
			"Клавишей E можно передать башне здоровье, а турели - здоровье и патроны."
		),
		TranslationServer.translate(
			"Клавишей E можно за энергию ремонтировать башни и пополнять здоровье и патроны турелей."
		)
	)
	return instructions.replace(
		TranslationServer.translate(
			"Чем выше по карте, тем сильнее враги. Найди Станции 2 и 3: там за энергию можно улучшать урон, здоровье и боезапас."
		),
		TranslationServer.translate(
			"Чем выше по карте, тем сильнее враги. Урон, здоровье и боезапас можно улучшать на Станции 1."
		)
	)


static func note_text(note_number: int) -> String:
	match note_number:
		0:
			return objective_text()
		1:
			return TranslationServer.translate(NOTE_ONE_TEXT)
		2:
			return TranslationServer.translate(NOTE_TWO_TEXT)
		3:
			return TranslationServer.translate(NOTE_THREE_TEXT)
	return ""


static func final_text() -> String:
	return TranslationServer.translate(FINAL_TEXT)
