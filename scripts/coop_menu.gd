extends Control
## Tela do coop (2 JOGADORES com controle conectado): quem joga no teclado e quem no
## controle. ↑/↓ escolhem a linha, ←/→ trocam o dispositivo do jogador, COMEÇAR inicia.
## Um mesmo controle não fica com os dois: se o outro já usava, eles trocam. Os dois no
## teclado = teclado dividido. Ao começar, grava a escolha em Game.coop_devices.

signal confirmed  ## escolheu e mandou começar
signal closed     ## voltou sem começar

const ITEMS: Array[String] = ["JOGADOR 1", "JOGADOR 2", "COMEÇAR", "VOLTAR"]
const PANEL := Vector2(300, 150)
const LIFE_ICONS := {
	0: preload("res://assets/sprites/hud/life.png"),
	1: preload("res://assets/sprites/hud/life_p2.png"),
}

var selected := 0
var devices: Array = [-1, -1]  # -1 = teclado, senão o número do controle
var _choices: Array = []       # dispositivos disponíveis: teclado + controles conectados
var _opened_frame := -1


func _ready() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Abre com uma sugestão: com 1 controle, J1 no teclado e J2 no controle; com 2 ou mais,
## cada um com um controle.
func open() -> void:
	_choices = [-1] + Array(Input.get_connected_joypads())
	match _choices.size():
		1:
			devices = [-1, -1]  # nenhum controle: os dois no teclado
		2:
			devices = [-1, _choices[1]]
		_:
			devices = [_choices[1], _choices[2]]
	selected = 0
	_opened_frame = Engine.get_process_frames()
	show()


func _process(_delta: float) -> void:
	if not visible:
		return
	queue_redraw()
	# o mesmo aperto que abriu a tela não pode já escolher algo
	if Engine.get_process_frames() == _opened_frame or Input.is_action_just_pressed("toggle_fullscreen"):
		return
	if InputHint.menu_pressed(&"speed_up", &"ui_up"):
		selected = posmod(selected - 1, ITEMS.size())
		Sfx.play("ui_move", -6.0)
	elif InputHint.menu_pressed(&"slow_down", &"ui_down"):
		selected = posmod(selected + 1, ITEMS.size())
		Sfx.play("ui_move", -6.0)
	elif InputHint.menu_pressed(&"move_left", &"ui_left"):
		_change(-1)
	elif InputHint.menu_pressed(&"move_right", &"ui_right"):
		_change(1)
	elif InputHint.menu_pressed(&"shoot", &"ui_accept"):
		match ITEMS[selected]:
			"COMEÇAR":
				Game.coop_devices = devices.duplicate()
				Sfx.play("ui_select", -4.0)
				hide()
				confirmed.emit()
			"VOLTAR":
				_close()
			_:
				_change(1)
	elif Input.is_action_just_pressed("ui_cancel") or Input.is_action_just_pressed("pause"):
		_close()


## Troca o dispositivo do jogador da linha escolhida. Controle já usado pelo outro jogador:
## os dois trocam (o outro fica com o que este tinha).
func _change(step: int) -> void:
	if selected > 1:
		return
	var other := 1 - selected
	var old: int = devices[selected]
	var value: int = _choices[posmod(_choices.find(old) + step, _choices.size())]
	if value >= 0 and devices[other] == value:
		devices[other] = old
	devices[selected] = value
	Sfx.play("ui_move", -6.0)


func _close() -> void:
	Sfx.play("ui_select", -4.0)
	hide()
	closed.emit()


## Nome do dispositivo: TECLADO, CONTROLE (se só há um) ou CONTROLE 1, CONTROLE 2...
func _device_name(device: int) -> String:
	if device < 0:
		return "TECLADO"
	if _choices.size() == 2:
		return "CONTROLE"
	return "CONTROLE %d" % _choices.find(device)


func _draw() -> void:
	var top_left := MenuStyle.panel(self, PANEL, "2 JOGADORES")
	var cx := top_left.x + PANEL.x / 2.0
	var right := top_left.x + PANEL.x - 18.0
	var y := top_left.y + MenuStyle.CONTENT_TOP
	for i in ITEMS.size():
		var label := ITEMS[i]
		var chosen := i == selected
		if i > 1:  # botões, separados dos jogadores por uma divisória
			if i == 2:
				MenuStyle.divider(self, top_left.x + 18.0, right, y - 4.0)
				y += 6.0
			MenuStyle.item(self, label, cx, y, chosen)
		else:
			# aviãozinho da cor do jogador + nome; dispositivo à direita, numa caixinha
			draw_texture(LIFE_ICONS[i], Vector2(top_left.x + 18, y - 1.0))
			PixelText.draw(self, label, Vector2(top_left.x + 34, y), 1,
					MenuStyle.SELECTED if chosen else Color.WHITE)
			MenuStyle.value(self, _device_name(devices[i]), right - MenuStyle.ARROW_ROOM, y, chosen)
		y += 22.0
