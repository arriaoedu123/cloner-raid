extends Control
## Tela de opções (painel sobre a tela atual). Abra com `open()`; emite `closed` ao sair.
## ↑/↓ (ou W/S) escolhem, ←/→ (ou A/D) mudam o valor, tiro/Enter confirma, Esc volta.
## Cada mudança é aplicada na hora e salva.

signal closed

const ITEMS: Array[String] = ["TELA CHEIA", "MUSICA", "EFEITOS", "TREMOR DE TELA", "PONTOS NO COOP",
		"CONTROLES", "VOLTAR"]
const BUTTONS: Array[String] = ["CONTROLES", "VOLTAR"]  # itens sem valor (só confirmar)
const PANEL := Vector2(300, 214)

var selected := 0
var _opened_frame := -1
var _controls_menu: Control


func _ready() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# tela de remapear controles, aberta pelo item CONTROLES
	_controls_menu = preload("res://scripts/controls_menu.gd").new()
	_controls_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_controls_menu)


func open() -> void:
	selected = 0
	_opened_frame = Engine.get_process_frames()
	show()


func _process(_delta: float) -> void:
	if not visible:
		return
	queue_redraw()
	if _controls_menu.visible:
		return  # a tela de controles cuida da entrada enquanto aberta
	# o mesmo aperto que abriu as opções não pode já mudar a primeira delas
	if Engine.get_process_frames() == _opened_frame:
		return
	# Alt+Enter (tela cheia) não pode também confirmar a opção escolhida
	if Input.is_action_just_pressed("toggle_fullscreen"):
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
			"VOLTAR":
				_close()
			"CONTROLES":
				Sfx.play("ui_select", -4.0)
				_controls_menu.open()
			_:
				_change(1)
	elif Input.is_action_just_pressed("ui_cancel") or Input.is_action_just_pressed("pause"):
		_close()  # Esc, P ou Start do controle voltam


## Muda a opção escolhida: liga/desliga as de SIM/NAO e sobe/desce os volumes.
func _change(step: int) -> void:
	match ITEMS[selected]:
		"TELA CHEIA":
			Settings.fullscreen = not Settings.fullscreen
		"MUSICA":
			Settings.music_level = clampi(Settings.music_level + step, 0, Settings.MAX_LEVEL)
		"EFEITOS":
			Settings.sfx_level = clampi(Settings.sfx_level + step, 0, Settings.MAX_LEVEL)
		"TREMOR DE TELA":
			Settings.screen_shake = not Settings.screen_shake
			if Settings.screen_shake:
				Effects.shake_enabled = true
				Effects.shake(self, 3.0)  # mostra como fica
		"PONTOS NO COOP":
			Settings.coop_shared_score = not Settings.coop_shared_score
		_:
			return
	Settings.apply()
	Settings.save()
	Sfx.play("ui_select", -6.0)  # também serve para ouvir o volume dos efeitos


func _close() -> void:
	Sfx.play("ui_select", -4.0)
	hide()
	closed.emit()


func _draw() -> void:
	if _controls_menu.visible:
		return  # a tela de controles desenha por cima (com o próprio fundo escurecido)
	var top_left := MenuStyle.panel(self, PANEL, "OPÇÕES")
	var cx := top_left.x + PANEL.x / 2.0
	var right := top_left.x + PANEL.x - 18.0
	var y := top_left.y + MenuStyle.CONTENT_TOP
	for i in ITEMS.size():
		var label := ITEMS[i]
		var chosen := i == selected
		if BUTTONS.has(label):
			if label == BUTTONS[0]:  # divisória entre os ajustes e os botões
				MenuStyle.divider(self, top_left.x + 18.0, right, y - 4.0)
				y += 6.0
			MenuStyle.item(self, label, cx, y, chosen)
		else:
			PixelText.draw(self, label, Vector2(top_left.x + 18.0, y), 1,
					MenuStyle.SELECTED if chosen else Color.WHITE)
			_draw_value(label, right - MenuStyle.ARROW_ROOM, y, chosen)
		y += 22.0


## Valor numa caixinha terminando em `right_x`: SIM/NÃO, JUNTOS/SEPARADOS ou uma barra de
## 10 quadradinhos para os volumes.
func _draw_value(label: String, right_x: float, y: float, chosen: bool) -> void:
	var text := ""
	match label:
		"TELA CHEIA":
			text = "SIM" if Settings.fullscreen else "NÃO"
		"TREMOR DE TELA":
			text = "SIM" if Settings.screen_shake else "NÃO"
		"PONTOS NO COOP":
			text = "JUNTOS" if Settings.coop_shared_score else "SEPARADOS"
		_:
			var box := MenuStyle.value(self, "", right_x, y, chosen)
			var level := Settings.music_level if label == "MUSICA" else Settings.sfx_level
			var left := box.position.x + floorf((box.size.x - (Settings.MAX_LEVEL * 6.0 - 1.0)) / 2.0)
			for k in Settings.MAX_LEVEL:
				var pos := Vector2(left + k * 6.0, y + 1.0)
				draw_rect(Rect2(pos, Vector2(5, 7)), Palette.OUTLINE)
				var fill := Palette.YELLOW if k < level else Palette.GRAY_DARK
				draw_rect(Rect2(pos + Vector2.ONE, Vector2(3, 5)), fill)
			return
	MenuStyle.value(self, text, right_x, y, chosen)
