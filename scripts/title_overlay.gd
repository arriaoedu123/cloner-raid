extends Control
## Tela de título por cima do rio, no estilo madeira dos menus (MenuStyle): placa com o nome do
## jogo e o recorde, painel com as opções e régua com os comandos no rodapé.

## Tela de título (de onde vêm a opção selecionada e o recorde)
@export var title: Node

const TITLE_TEXT := "CLONER RAID"
const MENU_PANEL := Vector2(200, 138)  # 5 opções a cada 22 px, com 14 px de folga em cima e embaixo
const PLAQUE := Vector2(320, 84)  # placa do nome do jogo + faixa do recorde (termina em y = 112)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if title == null:
		return
	var screen := get_viewport_rect().size
	var cx := screen.x / 2.0

	# Placa de madeira (mesma moldura dos menus) com o nome do jogo, com sombra, e o recorde
	# numa faixa de madeira escura embaixo
	var plaque := Rect2(cx - PLAQUE.x / 2.0, 28.0, PLAQUE.x, PLAQUE.y)
	MenuStyle.frame(self, plaque)
	PixelText.draw_centered(self, TITLE_TEXT, cx + 2.0, 43.0, 4, Palette.SHADOW)
	PixelText.draw_centered(self, TITLE_TEXT, cx, 40.0, 4)
	var inner := plaque.grow(-MenuStyle.FRAME)
	var band := Rect2(inner.position.x, inner.end.y - 20.0, inner.size.x, 20.0)
	draw_rect(Rect2(band.position.x, band.position.y - 1.0, band.size.x, 1.0), Palette.OUTLINE)
	draw_rect(band, Palette.TERRACOTTA_DARK)
	PixelText.draw_centered(self, "RECORDE %06d" % title.high_score, cx, band.position.y + 6.0, 1,
			Palette.YELLOW_LIGHT)

	# Régua de madeira com os comandos, em pixel inteiro (senão a madeira fica mais grossa de um
	# lado): 7 px livres de cada lado das teclas e 1 px acima e abaixo delas
	var line := InputHint.controls_line()
	var text_left := roundf(cx - PixelText.width(line) / 2.0)
	var pad := MenuStyle.FRAME + 7.0
	var bar := Rect2(text_left - pad, screen.y - 38.0, PixelText.width(line) + pad * 2.0,
			PixelText.KEY_TOP + PixelText.BODY_H + PixelText.KEY_BOTTOM + 2.0 + MenuStyle.FRAME * 2.0)
	MenuStyle.frame(self, bar)
	PixelText.draw(self, line, Vector2(text_left, bar.position.y + MenuStyle.FRAME + 1.0 + PixelText.KEY_TOP))
	if title.is_options_open():
		return  # o painel de opções fica por cima; o menu do título some

	# Menu num painel de madeira como os outros menus (sem faixa: o nome do jogo é o título),
	# logo abaixo do recorde; termina em y = 270, longe do rodapé com as teclas
	var panel := Rect2(cx - MENU_PANEL.x / 2.0, 132.0, MENU_PANEL.x, MENU_PANEL.y)
	MenuStyle.frame(self, panel)
	for i in title.OPTIONS.size():
		MenuStyle.item(self, title.OPTIONS[i], cx, panel.position.y + 20.0 + i * 22.0,
				i == title.selected)
