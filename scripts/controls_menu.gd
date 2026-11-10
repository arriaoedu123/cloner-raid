extends Control
## Tela de remapear controles (aberta pelo painel de opções). Tabela: uma linha por ação,
## colunas TECLADO e CONTROLE. ↑/↓ escolhem a linha, ←/→ a coluna, Enter/tiro começa a
## trocar ("APERTE..."), e a próxima tecla/botão/direção vira o novo comando. Esc cancela/volta.
## Os menus usam também ui_up/ui_down/ui_left/ui_right/ui_accept (setas e Enter fixos do
## Godot), então nunca dá para ficar preso mesmo remapeando tudo.

signal closed

const PANEL := Vector2(400, 244)
const ROW_H := 20.0
const EXTRA_ITEMS: Array[String] = ["RESTAURAR PADRÃO", "VOLTAR"]
const AXIS_DEADZONE := 0.6

var row := 0
var column := 0  # 0 = teclado, 1 = controle
var _waiting := false
var _ignore_frame := -1


func _ready() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func open() -> void:
	row = 0
	column = 0
	_waiting = false
	_ignore_frame = Engine.get_process_frames()
	show()


func _rows() -> int:
	return Controls.ACTIONS.size() + EXTRA_ITEMS.size()


## Captura o novo comando enquanto está esperando ("APERTE...").
func _input(event: InputEvent) -> void:
	if not visible or not _waiting:
		return
	var new_event: InputEvent = null
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			_stop_waiting()  # cancela sem trocar
		elif column == 0:
			var k := InputEventKey.new()
			k.physical_keycode = event.physical_keycode
			new_event = k
	elif column == 1 and event is InputEventJoypadButton and event.pressed:
		var b := InputEventJoypadButton.new()
		b.button_index = event.button_index
		new_event = b
	elif column == 1 and event is InputEventJoypadMotion and absf(event.axis_value) >= AXIS_DEADZONE:
		var m := InputEventJoypadMotion.new()
		m.axis = event.axis
		m.axis_value = signf(event.axis_value)
		new_event = m
	else:
		return
	get_viewport().set_input_as_handled()
	if new_event:
		Controls.bind(Controls.ACTIONS[row], new_event)
		Sfx.play("ui_select", -4.0)
		_stop_waiting()


func _stop_waiting() -> void:
	_waiting = false
	_ignore_frame = Engine.get_process_frames()  # o mesmo aperto não aciona o menu


func _process(_delta: float) -> void:
	if not visible:
		return
	queue_redraw()
	if _waiting or Engine.get_process_frames() == _ignore_frame:
		return
	if _pressed("speed_up", "ui_up"):
		row = posmod(row - 1, _rows())
		Sfx.play("ui_move", -6.0)
	elif _pressed("slow_down", "ui_down"):
		row = posmod(row + 1, _rows())
		Sfx.play("ui_move", -6.0)
	elif _pressed("move_left", "ui_left") or _pressed("move_right", "ui_right"):
		if row < Controls.ACTIONS.size():
			column = 1 - column
			Sfx.play("ui_move", -6.0)
	elif Input.is_action_just_pressed("toggle_fullscreen"):
		pass  # Alt+Enter não pode também confirmar
	elif _pressed("shoot", "ui_accept"):
		_confirm()
	elif _pressed("pause", "ui_cancel"):
		_close()


func _pressed(game_action: StringName, ui_action: StringName) -> bool:
	return InputHint.menu_pressed(game_action, ui_action)


func _confirm() -> void:
	if row < Controls.ACTIONS.size():
		_waiting = true
		Sfx.play("ui_move", -6.0)
		return
	match EXTRA_ITEMS[row - Controls.ACTIONS.size()]:
		"RESTAURAR PADRÃO":
			Controls.reset_defaults()
			Sfx.play("ui_select", -4.0)
		"VOLTAR":
			_close()


func _close() -> void:
	Sfx.play("ui_select", -4.0)
	hide()
	closed.emit()


func _draw() -> void:
	var screen := get_viewport_rect().size
	var top_left := ((screen - PANEL) / 2.0).floor()
	draw_rect(Rect2(Vector2.ZERO, screen), Color(Palette.OUTLINE, 0.55))
	draw_rect(Rect2(top_left, PANEL), Palette.OUTLINE)
	draw_rect(Rect2(top_left + Vector2.ONE, PANEL - Vector2(2, 2)), Palette.BLUE_DARK)

	var cx := screen.x / 2.0
	var col_x := [top_left.x + 205.0, top_left.x + 320.0]  # centro das colunas
	PixelText.draw_centered(self, "CONTROLES", cx, top_left.y + 10, 2)
	PixelText.draw_centered(self, "TECLADO", col_x[0], top_left.y + 38)
	PixelText.draw_centered(self, "CONTROLE", col_x[1], top_left.y + 38)
	draw_rect(Rect2(top_left.x + 14, top_left.y + 51, PANEL.x - 28, 1), Palette.BLUE)

	var blink := Time.get_ticks_msec() % 600 < 400
	for i in Controls.ACTIONS.size():
		var action := Controls.ACTIONS[i]
		var y := top_left.y + 58.0 + i * ROW_H
		PixelText.draw(self, Controls.LABELS[action], Vector2(top_left.x + 18, y))
		for c in 2:
			var text := Controls.binding_name(action, c == 0)
			if i == row and c == column:
				if _waiting:
					text = "APERTE..." if blink else ""
				elif blink:
					text = "> " + text + " <"
			PixelText.draw_centered(self, text, col_x[c], y)

	for j in EXTRA_ITEMS.size():
		var i := Controls.ACTIONS.size() + j
		var text := EXTRA_ITEMS[j]
		if i == row and blink:
			text = "> " + text + " <"
		PixelText.draw_centered(self, text, cx, top_left.y + 184.0 + j * ROW_H)

	PixelText.draw_centered(self, "[%s] TROCA   [%s] VOLTA" % [InputHint.confirm(), InputHint.back()],
			cx, top_left.y + PANEL.y - 16)
