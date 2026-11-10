extends Control
## Tela de opções (painel sobre a tela atual). Abra com `open()`; emite `closed` ao sair.
## ↑/↓ (ou W/S) escolhem, ←/→ (ou A/D) mudam o valor, tiro/Enter confirma, Esc volta.
## Cada mudança é aplicada na hora e salva.

signal closed

const ITEMS: Array[String] = ["TELA CHEIA", "MUSICA", "EFEITOS", "TREMOR DE TELA", "PONTOS NO COOP",
		"CONTROLES", "VOLTAR"]
const BUTTONS: Array[String] = ["CONTROLES", "VOLTAR"]  # itens sem valor (só confirmar)
const PANEL := Vector2(300, 214)
const ARROW_GAP := 11.0  # largura da seta (7 px) + 4 px de espaço até o valor

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
	var screen := get_viewport_rect().size
	var top_left := ((screen - PANEL) / 2.0).floor()
	draw_rect(Rect2(Vector2.ZERO, screen), Color(Palette.OUTLINE, 0.55))
	draw_rect(Rect2(top_left, PANEL), Palette.OUTLINE)
	draw_rect(Rect2(top_left + Vector2.ONE, PANEL - Vector2(2, 2)), Palette.BLUE_DARK)

	var cx := screen.x / 2.0
	PixelText.draw_centered(self, "OPÇÕES", cx, top_left.y + 12, 2)
	var arrows_on := Time.get_ticks_msec() % 600 < 400
	for i in ITEMS.size():
		var y := top_left.y + 46.0 + i * 22.0
		var label := ITEMS[i]
		var show_arrows := i == selected and arrows_on
		if BUTTONS.has(label):
			var text := ("> " + label + " <") if show_arrows else ("  " + label + "  ")
			PixelText.draw_centered(self, text, cx, y)
			continue
		PixelText.draw(self, label, Vector2(top_left.x + 18, y))
		# valor à direita, com espaço reservado para uma seta de cada lado (o valor não "pula")
		var right := top_left.x + PANEL.x - 18
		var value_left := _draw_value(label, right - ARROW_GAP, y)
		if show_arrows:
			PixelText.draw(self, "<", Vector2(value_left - ARROW_GAP, y))
			PixelText.draw(self, ">", Vector2(right - PixelText.CELL.x, y))


## Valor terminando em `right_x`: SIM/NAO ou uma barra de 10 quadradinhos para os volumes.
## Retorna o x onde o valor começa (para encostar a seta da esquerda).
func _draw_value(label: String, right_x: float, y: float) -> float:
	var text := ""
	match label:
		"TELA CHEIA":
			text = "SIM" if Settings.fullscreen else "NÃO"
		"TREMOR DE TELA":
			text = "SIM" if Settings.screen_shake else "NÃO"
		"PONTOS NO COOP":
			text = "JUNTOS" if Settings.coop_shared_score else "SEPARADOS"
		_:
			var level := Settings.music_level if label == "MUSICA" else Settings.sfx_level
			var left := right_x - (Settings.MAX_LEVEL * 6.0 - 1.0)
			for k in Settings.MAX_LEVEL:
				var pos := Vector2(left + k * 6.0, y + 1.0)
				draw_rect(Rect2(pos, Vector2(5, 7)), Palette.OUTLINE)
				var fill := Palette.YELLOW if k < level else Palette.GRAY_DARK
				draw_rect(Rect2(pos + Vector2.ONE, Vector2(3, 5)), fill)
			return left
	var text_left := right_x - PixelText.width(text)
	PixelText.draw(self, text, Vector2(text_left, y))
	return text_left
