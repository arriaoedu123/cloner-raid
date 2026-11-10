extends Control
## Textos da tela de título, desenhados com a fonte pixel art do jogo.

## Tela de título (de onde vêm a opção selecionada e o recorde)
@export var title: Node

const TITLE_TEXT := "CLONER RAID"


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if title == null:
		return
	var screen := get_viewport_rect().size
	var cx := screen.x / 2.0

	# Nome do jogo, grande, com uma faixa escura atrás para ler bem sobre o rio
	draw_rect(Rect2(0, 44, screen.x, 52), Color(Palette.OUTLINE, 0.6))
	PixelText.draw_centered(self, TITLE_TEXT, cx, 52, 4)

	PixelText.draw_centered(self, "RECORDE %06d" % title.high_score, cx, 112)
	PixelText.draw_centered(self, InputHint.controls_line(), cx, screen.y - 18)
	if title.is_options_open():
		return  # o painel de opções fica por cima; o menu do título some

	# Menu: linhas com espaço igual; a escolhida fica maior e cresce igual para cima e para baixo
	PixelText.draw_menu(self, title.OPTIONS, title.selected, cx, 204.0, 30.0)
