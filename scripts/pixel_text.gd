class_name PixelText
## Escreve texto com a fonte pixel art do jogo (assets/sprites/hud/font.png).
## Use dentro de _draw(): PixelText.draw(self, "TEXTO", posicao, escala)
## Só maiúsculas, números, " -:.!><" e os acentuados Ç, Õ, Ã, Ó. Minúsculas viram maiúsculas.
## A posição `pos` é o topo do CORPO da letra (a altura de texto continua 9 px); o til sobe
## acima disso e a cedilha desce abaixo.
## Teclas: texto entre [ ] ganha uma "tecla" em volta (fundo escuro, borda clara arredondada e
## contorno k), ex.: "[ESC] PARA O MENU". Use em toda dica que cita um comando.
## A tecla ocupa 3 px acima e 4 abaixo do corpo (cabe a cedilha): linhas com tecla precisam
## de pelo menos 17 px entre si.

const CHARSET := "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ -:.!><ÇÕÃÓ"  # mesma ordem de tools/sprites/hud.py
const CELL := Vector2(7, 14)  # célula no atlas: 3 px de acento + corpo 9 px + 2 px de cedilha
const ASCENT := 3.0           # px da célula acima do corpo (onde fica o til)
const BODY_H := 9.0           # altura do corpo com contorno: use para alinhar texto
const ADVANCE := 6.0  # 5 px de glifo + 1 px de espaço (os contornos se sobrepõem)
const ATLAS := preload("res://assets/sprites/hud/font.png")
const KEY_SIDE := 3.0    # tecla: contorno k + borda clara + 1 px de folga, de cada lado
const KEY_TOP := 3.0     # px da tecla acima do corpo da letra
const KEY_BOTTOM := 4.0  # px abaixo (1 a mais para a cedilha de "ESPAÇO")


static func width(text: String, scale: int = 1) -> float:
	return _layout(text)[2] * scale


## `color` tinge as letras (o contorno k continua escuro); as teclas não mudam de cor.
static func draw(canvas: CanvasItem, text: String, pos: Vector2, scale: int = 1,
		color := Color.WHITE) -> void:
	var layout := _layout(text)
	for key: Vector2 in layout[1]:
		var box := Rect2(pos.x + key.x * scale, pos.y - KEY_TOP * scale,
				(key.y - key.x) * scale, (BODY_H + KEY_TOP + KEY_BOTTOM) * scale)
		canvas.draw_rect(box, Palette.OUTLINE)
		var rim := box.grow(-scale)
		canvas.draw_rect(rim, Palette.WHITE)
		canvas.draw_rect(rim.grow(-scale), Palette.OUTLINE)
		# cantos da borda clara arredondados
		for corner in [rim.position, rim.position + Vector2(rim.size.x - scale, 0),
				rim.position + Vector2(0, rim.size.y - scale), rim.end - Vector2(scale, scale)]:
			canvas.draw_rect(Rect2(corner, Vector2(scale, scale)), Palette.OUTLINE)
	for glyph in layout[0]:
		var src := Rect2(Vector2(glyph[0] * CELL.x, 0), CELL)
		# sobe ASCENT para o corpo da letra ficar em `pos.y` (o acento fica acima)
		var dest := Rect2(Vector2(pos.x + glyph[1] * scale, pos.y - ASCENT * scale), CELL * scale)
		canvas.draw_texture_rect_region(ATLAS, dest, src, color)


## Onde vai cada letra e cada tecla, em escala 1 a partir de x = 0:
## [ [índice no atlas, x] por letra, Vector2(início, fim) por tecla, largura total ].
static func _layout(text: String) -> Array:
	var glyphs := []
	var keys := []
	var x := 0.0
	var end := 0.0  # borda direita do texto até aqui (conta espaços, como antes)
	var key_start := 0.0
	var key_right := 0.0  # borda direita das letras dentro da tecla atual
	for ch in text.to_upper():
		if ch == "[":
			key_start = x
			x += KEY_SIDE
			key_right = x
			continue
		if ch == "]":
			var key_end := key_right + KEY_SIDE
			keys.append(Vector2(key_start, key_end))
			end = maxf(end, key_end)
			x = key_end - 1.0  # depois da tecla o espaçamento segue como depois de uma letra
			continue
		var index := CHARSET.find(ch)
		if index >= 0:
			glyphs.append([index, x])
		key_right = x + CELL.x
		end = maxf(end, x + CELL.x)
		x += ADVANCE
	return [glyphs, keys, end]


## Desenha centralizado horizontalmente em `center_x`.
static func draw_centered(canvas: CanvasItem, text: String, center_x: float, y: float,
		scale: int = 1, color := Color.WHITE) -> void:
	draw(canvas, text, Vector2(roundf(center_x - width(text, scale) / 2.0), y), scale, color)
