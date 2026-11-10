class_name Controls
## Comandos remapeáveis: troca a tecla/botão de cada ação, dá nomes legíveis (na fonte
## do jogo), salva no SaveData (seção "controls") e restaura o padrão do projeto.
##
## Cada ação tem uma coluna de TECLADO e uma de CONTROLE. Remapear uma coluna troca TODOS
## os comandos daquele tipo da ação por um só (ex.: "move_left" deixa de ter Seta + A).

## Ações remapeáveis e o nome mostrado na tela, na ordem da tabela
const ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"speed_up", &"slow_down", &"shoot", &"pause"]
const LABELS := {
	&"move_left": "ESQUERDA", &"move_right": "DIREITA", &"speed_up": "ACELERAR",
	&"slow_down": "FREAR", &"shoot": "ATIRAR", &"pause": "PAUSA",
}

## Nomes de teclas comuns em português (o resto usa o nome do Godot em maiúsculas)
const KEY_NAMES := {
	KEY_LEFT: "SETA ESQ", KEY_RIGHT: "SETA DIR", KEY_UP: "SETA CIMA", KEY_DOWN: "SETA BAIXO",
	KEY_SPACE: "ESPAÇO", KEY_ESCAPE: "ESC", KEY_ENTER: "ENTER", KEY_KP_ENTER: "ENTER",
	KEY_SHIFT: "SHIFT", KEY_CTRL: "CTRL", KEY_ALT: "ALT", KEY_TAB: "TAB", KEY_BACKSPACE: "APAGAR",
}
const BUTTON_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "SELECT", JOY_BUTTON_START: "START", JOY_BUTTON_GUIDE: "HOME",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_DPAD_UP: "DPAD CIMA", JOY_BUTTON_DPAD_DOWN: "DPAD BAIXO",
	JOY_BUTTON_DPAD_LEFT: "DPAD ESQ", JOY_BUTTON_DPAD_RIGHT: "DPAD DIR",
}

## Comandos originais do projeto (para RESTAURAR PADRÃO), guardados antes de aplicar o salvo
static var _defaults := {}


## Guarda o padrão e aplica o que estiver salvo. Chamado uma vez pelo Settings.
static func load_saved() -> void:
	if _defaults.is_empty():
		for action in ACTIONS:
			_defaults[action] = InputMap.action_get_events(action).duplicate()
	var saved: Dictionary = SaveData.load_value("controls", "bindings", {})
	for action in saved:
		if InputMap.has_action(action):
			_set_events(action, (saved[action] as Array).map(_deserialize).filter(func(e): return e != null))


static func reset_defaults() -> void:
	for action in ACTIONS:
		_set_events(action, _defaults.get(action, []))
	SaveData.save_value("controls", "bindings", {})


## Liga `event` à ação, no lugar dos comandos do mesmo tipo (teclado ou controle).
## Se outra ação já usava esse comando, as duas TROCAM: a outra recebe o comando antigo
## desta (assim nenhuma ação fica sem tecla).
static func bind(action: StringName, event: InputEvent) -> void:
	event.device = -1  # vale para qualquer controle/teclado, igual aos padrões do projeto
	var keyboard := event is InputEventKey
	var same_kind := InputMap.action_get_events(action).filter(func(e): return (e is InputEventKey) == keyboard)
	var old: InputEvent = same_kind[0] if not same_kind.is_empty() else null
	for other in ACTIONS:
		if other == action:
			continue
		var others := InputMap.action_get_events(other)
		if not others.any(func(e): return _same_input(e, event)):
			continue
		var swapped := others.filter(func(e): return not _same_input(e, event))
		if old and not swapped.any(func(e): return _same_input(e, old)):
			swapped.append(old)
		_set_events(other, swapped)
	var events := InputMap.action_get_events(action).filter(func(e): return (e is InputEventKey) != keyboard)
	events.append(event)
	_set_events(action, events)
	_save()


## Nome do 1º comando de teclado (keyboard = true) ou de controle da ação; "-" se não houver.
static func binding_name(action: StringName, keyboard: bool) -> String:
	for e in InputMap.action_get_events(action):
		if keyboard and e is InputEventKey:
			return key_name(e)
		if not keyboard and (e is InputEventJoypadButton or e is InputEventJoypadMotion):
			return pad_name(e)
	return "-"


static func key_name(e: InputEventKey) -> String:
	var code := e.physical_keycode if e.physical_keycode != KEY_NONE else e.keycode
	if KEY_NAMES.has(code):
		return KEY_NAMES[code]
	return _font_safe(OS.get_keycode_string(code).to_upper())


static func pad_name(e: InputEvent) -> String:
	if e is InputEventJoypadButton:
		return BUTTON_NAMES.get(e.button_index, "BOTAO %d" % e.button_index)
	var m := e as InputEventJoypadMotion
	var neg := m.axis_value < 0.0
	match m.axis:
		JOY_AXIS_LEFT_X: return "ANALOG ESQ" if neg else "ANALOG DIR"
		JOY_AXIS_LEFT_Y: return "ANALOG CIMA" if neg else "ANALOG BAIXO"
		JOY_AXIS_TRIGGER_LEFT: return "LT"
		JOY_AXIS_TRIGGER_RIGHT: return "RT"
	return "EIXO %d" % m.axis


## Tira caracteres que a fonte do jogo não tem (para nunca sumir o nome inteiro).
static func _font_safe(text: String) -> String:
	var out := ""
	for ch in text:
		if PixelText.CHARSET.contains(ch):
			out += ch
	return out if out.strip_edges() != "" else "TECLA"


static func _same_input(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		return a.physical_keycode == b.physical_keycode and a.alt_pressed == b.alt_pressed \
				and a.ctrl_pressed == b.ctrl_pressed and a.meta_pressed == b.meta_pressed
	if a is InputEventJoypadButton and b is InputEventJoypadButton:
		return a.button_index == b.button_index
	if a is InputEventJoypadMotion and b is InputEventJoypadMotion:
		return a.axis == b.axis and signf(a.axis_value) == signf(b.axis_value)
	return false


static func _set_events(action: StringName, events: Array) -> void:
	InputMap.action_erase_events(action)
	for e in events:
		InputMap.action_add_event(action, e)


static func _save() -> void:
	var data := {}
	for action in ACTIONS:
		data[action] = InputMap.action_get_events(action).map(_serialize)
	SaveData.save_value("controls", "bindings", data)


static func _serialize(e: InputEvent) -> Dictionary:
	if e is InputEventKey:
		return {"type": "key", "code": e.physical_keycode, "alt": e.alt_pressed,
				"ctrl": e.ctrl_pressed, "meta": e.meta_pressed}
	if e is InputEventJoypadButton:
		return {"type": "button", "index": e.button_index}
	if e is InputEventJoypadMotion:
		return {"type": "axis", "axis": e.axis, "value": signf(e.axis_value)}
	return {}


## Coop local: teclas de cada jogador. Os comandos do jogo viram ações próprias
## ("p1_move_left", "p2_shoot"...), fixas (não remapeáveis).
const COOP_KEYS := {
	1: {&"move_left": [KEY_A], &"move_right": [KEY_D], &"speed_up": [KEY_W], &"slow_down": [KEY_S],
		&"shoot": [KEY_SPACE, KEY_J]},
	2: {&"move_left": [KEY_LEFT], &"move_right": [KEY_RIGHT], &"speed_up": [KEY_UP], &"slow_down": [KEY_DOWN],
		&"shoot": [KEY_ENTER, KEY_KP_ENTER]},
}
## No controle: [eixo, sentido, botão do direcional] de cada ação (eixo -1 = só botão)
const COOP_PAD := {
	&"move_left": [JOY_AXIS_LEFT_X, -1.0, JOY_BUTTON_DPAD_LEFT],
	&"move_right": [JOY_AXIS_LEFT_X, 1.0, JOY_BUTTON_DPAD_RIGHT],
	&"speed_up": [JOY_AXIS_LEFT_Y, -1.0, JOY_BUTTON_DPAD_UP],
	&"slow_down": [JOY_AXIS_LEFT_Y, 1.0, JOY_BUTTON_DPAD_DOWN],
	&"shoot": [-1, 0.0, JOY_BUTTON_A],
}


## Cria (ou recria) as ações do coop. `devices[0]`/`devices[1]` = de onde vem o comando do
## J1/J2: -1 = teclado, senão o número do controle (Input.get_connected_joypads()).
## Os dois no teclado: dividido (J1 = WASD + Espaço/J, J2 = setas + Enter). Só um no
## teclado: ele usa o teclado inteiro. Chamado no começo de cada partida a 2.
static func setup_coop_actions(devices: Array = [-1, -1]) -> void:
	var both_keyboard: bool = devices[0] < 0 and devices[1] < 0
	for p in [1, 2]:
		var device: int = devices[p - 1]
		for action: StringName in COOP_PAD:
			var name := StringName("p%d_%s" % [p, action])
			if InputMap.has_action(name):
				InputMap.erase_action(name)
			InputMap.add_action(name, 0.2)
			if device < 0:
				var keys: Array = COOP_KEYS[p][action] if both_keyboard \
						else COOP_KEYS[1][action] + COOP_KEYS[2][action]
				for key: Key in keys:
					var k := InputEventKey.new()
					k.physical_keycode = key
					InputMap.action_add_event(name, k)
				continue
			var pad: Array = COOP_PAD[action]
			if pad[0] >= 0:
				var m := InputEventJoypadMotion.new()
				m.device = device
				m.axis = pad[0]
				m.axis_value = pad[1]
				InputMap.action_add_event(name, m)
			var b := InputEventJoypadButton.new()
			b.device = device
			b.button_index = pad[2]
			InputMap.action_add_event(name, b)


static func _deserialize(d: Dictionary) -> InputEvent:
	var e := _deserialize_event(d)
	if e:
		e.device = -1  # qualquer controle, mesmo que reconecte com outro número
	return e


static func _deserialize_event(d: Dictionary) -> InputEvent:
	match d.get("type", ""):
		"key":
			var k := InputEventKey.new()
			k.physical_keycode = d["code"]
			k.alt_pressed = d.get("alt", false)
			k.ctrl_pressed = d.get("ctrl", false)
			k.meta_pressed = d.get("meta", false)
			return k
		"button":
			var b := InputEventJoypadButton.new()
			b.button_index = d["index"]
			return b
		"axis":
			var m := InputEventJoypadMotion.new()
			m.axis = d["axis"]
			m.axis_value = d["value"]
			return m
	return null
