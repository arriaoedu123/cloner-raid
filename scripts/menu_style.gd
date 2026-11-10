class_name MenuStyle
## Visual comum dos painéis de menu (opções, controles, pausa, coop, online): moldura de
## madeira terracota como as caixas de power-up, faixa de título, miolo azul-escuro.
## Use dentro de _draw(): `var top_left := MenuStyle.panel(self, PANEL, "TÍTULO")` e escreva o
## conteúdo a partir de `top_left.y + MenuStyle.CONTENT_TOP`.
## Opção escolhida = texto amarelo (com aviõezinhos dos lados nos botões, `item`); valor que muda
## com ←/→ fica numa caixinha azul (`value`), com setas amarelas quando escolhido.

const PLANE := preload("res://assets/sprites/hud/life.png")
const FRAME := 6.0         # largura da moldura de madeira (o miolo começa aqui)
const HEADER_H := 26.0     # altura da faixa do título (abaixo dela, 1 px de contorno)
const CONTENT_TOP := 48.0  # y do primeiro texto do conteúdo, a partir do topo do painel
const VALUE_W := 72.0      # largura da caixinha de valor
const ARROW_ROOM := 9.0    # espaço de cada lado da caixinha para as setas
const SELECTED := Palette.YELLOW
const SOFT := Palette.BLUE_LIGHT  # textos de apoio (subtítulos, cabeçalhos de coluna)


## Escurece a tela e desenha o painel centralizado com o título. Retorna o canto de cima.
static func panel(canvas: CanvasItem, size: Vector2, title: String) -> Vector2:
	var view := canvas.get_viewport_rect().size
	canvas.draw_rect(Rect2(Vector2.ZERO, view), Color(Palette.OUTLINE, 0.6))
	var top_left := ((view - size) / 2.0).floor()
	frame(canvas, Rect2(top_left, size), title)
	return top_left


## Só a moldura em `r` (sombra, madeira, pregos e miolo), sem escurecer a tela. Com `title`,
## também a faixa do título; sem, o miolo começa logo depois da madeira (menu da tela de título).
static func frame(canvas: CanvasItem, r: Rect2, title := "") -> void:
	canvas.draw_rect(Rect2(r.position + Vector2(5, 5), r.size), Palette.SHADOW)
	# madeira em relevo: contorno k, luz em cima/esquerda, sombra embaixo/direita
	canvas.draw_rect(r, Palette.OUTLINE)
	var wood := r.grow(-1)
	canvas.draw_rect(wood, Palette.TERRACOTTA_DARK)
	canvas.draw_rect(Rect2(wood.position, wood.size - Vector2(2, 2)), Palette.TERRACOTTA_LIGHT)
	canvas.draw_rect(wood.grow(-2), Palette.TERRACOTTA)
	for x in [r.position.x + 3, r.end.x - 4]:  # pregos nos cantos
		for y in [r.position.y + 3, r.end.y - 4]:
			canvas.draw_rect(Rect2(x, y, 1, 1), Palette.GRAY)
	# miolo azul com contorno, e a faixa do título por cima dele
	var inner := r.grow(-FRAME)
	canvas.draw_rect(inner.grow(1), Palette.OUTLINE)
	canvas.draw_rect(inner, Palette.BLUE_DARK)
	if title == "":
		return
	var band := Rect2(inner.position, Vector2(inner.size.x, HEADER_H))
	canvas.draw_rect(band, Palette.TERRACOTTA_DARK)
	canvas.draw_rect(Rect2(band.position.x, band.end.y, band.size.x, 1), Palette.OUTLINE)
	PixelText.draw_centered(canvas, title, r.get_center().x, r.position.y + 10.0, 2)


## Botão centralizado: escolhido fica amarelo, com um aviãozinho de cada lado.
static func item(canvas: CanvasItem, text: String, center_x: float, y: float, chosen: bool) -> void:
	PixelText.draw_centered(canvas, text, center_x, y, 1, SELECTED if chosen else Color.WHITE)
	if chosen:
		var half := PixelText.width(text) / 2.0
		canvas.draw_texture(PLANE, Vector2(roundf(center_x - half) - 18.0, y - 1.0))
		canvas.draw_texture(PLANE, Vector2(roundf(center_x + half) + 7.0, y - 1.0))


## Caixinha de valor terminando em `right_x` (deixe ARROW_ROOM livre à direita para a seta).
## Texto vazio = quem chamou desenha o conteúdo (ex.: barra de volume). Retorna a caixinha.
static func value(canvas: CanvasItem, text: String, right_x: float, y: float, chosen: bool) -> Rect2:
	var box := Rect2(right_x - VALUE_W, y - 3.0, VALUE_W, 15.0)
	canvas.draw_rect(box, Palette.OUTLINE)
	canvas.draw_rect(box.grow(-1), Palette.BLUE)
	if text != "":
		PixelText.draw_centered(canvas, text, box.get_center().x, y)
	if chosen:
		PixelText.draw(canvas, "<", Vector2(box.position.x - ARROW_ROOM, y), 1, SELECTED)
		PixelText.draw(canvas, ">", Vector2(box.end.x + 2.0, y), 1, SELECTED)
	return box


## Linha divisória fina dentro do painel.
static func divider(canvas: CanvasItem, left: float, right: float, y: float) -> void:
	canvas.draw_rect(Rect2(left, y, right - left, 1), Palette.BLUE)
