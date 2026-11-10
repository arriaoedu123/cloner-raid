extends Control
## HUD: pontos (canto superior direito), aviões reserva (abaixo da barra de combustível)
## e a tela de fim de jogo. A barra de combustível é um nó à parte (fuel_gauge.gd).

## Partida de onde vêm pontos, vidas e fim de jogo
@export var game: Game

const LIFE_ICON := preload("res://assets/sprites/hud/life.png")
const MARGIN := 8.0


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if game == null:
		return
	var screen := get_viewport_rect().size

	# Pontos com 6 dígitos, alinhados à direita
	var score_text := "%06d" % game.score
	PixelText.draw(self, score_text, Vector2(screen.x - MARGIN - PixelText.width(score_text), MARGIN))

	# Recorde no topo, ao centro (acompanha a pontuação se ela passar do recorde)
	PixelText.draw_centered(self, "REC %06d" % maxi(game.high_score, game.score), screen.x / 2.0, MARGIN)

	_draw_combo(screen)

	# Aviões reserva, abaixo da barra de combustível
	for i in game.lives:
		draw_texture(LIFE_ICON, Vector2(MARGIN + i * 12.0, MARGIN + 11.0))

	_draw_power_up()

	# Alerta de pouco combustível, piscando ao lado da barra (que fica em x 8..104)
	var player := game.player
	if not player.is_dead and player.is_low_fuel() and Time.get_ticks_msec() % 250 < 125:
		PixelText.draw(self, "COMBUSTIVEL", Vector2(110, MARGIN))

	if not player.is_dead:
		_draw_hints()

	if game.is_game_over:
		_draw_game_over(screen)


## Power-ups ativos, abaixo dos aviões reserva: a caixa de cada um e uma barrinha do tempo
## que resta (igual à do combo), um embaixo do outro. Cada um pisca nos últimos 2 s.
func _draw_power_up() -> void:
	var player := game.player
	var active := []  # [tipo, tempo restante, duração, cor da barra]
	if player.double_shot_timer > 0.0:
		active.append([PowerUp.Kind.DOUBLE_SHOT, player.double_shot_timer, player.double_shot_time, Palette.ORANGE])
	if player.shield_timer > 0.0:
		active.append([PowerUp.Kind.SHIELD, player.shield_timer, player.shield_time, Palette.BLUE])
	const BAR := Vector2(34, 4)
	for i in active.size():
		var left: float = active[i][1]
		if left < 2.0 and Time.get_ticks_msec() % 300 >= 150:
			continue
		# 3 px abaixo dos aviões reserva (y 19..29), o mesmo vão entre a barra de combustível
		# e eles; cada power-up a mais fica 3 px abaixo do anterior (caixa de 16 px)
		var icon_pos := Vector2(MARGIN, MARGIN + 25.0 + i * 19.0)
		draw_texture(PowerUp.TEXTURES[active[i][0]], icon_pos)
		var bar_pos := icon_pos + Vector2(19, 6)
		draw_rect(Rect2(bar_pos, BAR), Palette.OUTLINE)
		draw_rect(Rect2(bar_pos + Vector2.ONE, BAR - Vector2(2, 2)), Palette.GRAY_DARK)
		var fill := floorf((BAR.x - 2.0) * clampf(left / active[i][2], 0.0, 1.0))
		draw_rect(Rect2(bar_pos + Vector2.ONE, Vector2(fill, BAR.y - 2.0)), active[i][3])


## Dicas para quem ainda não aprendeu, piscando e sem parar o jogo: "ABASTEÇA" no 1º posto
## à frente durante a introdução, e o nome do poder na caixa de um tipo ainda nunca pego.
func _draw_hints() -> void:
	if Time.get_ticks_msec() % 600 >= 400:
		return
	if game.intro_active:
		_draw_hint(_next_ahead(func(n: Node) -> bool: return n is FuelDepot), "ABASTEÇA", 9.0)
	var box: PowerUp = _next_ahead(func(n: Node) -> bool: return n is PowerUp and game.power_up_hint(n.kind))
	if box:
		_draw_hint(box, PowerUp.NAMES[box.kind], 8.0)


## Seta amarela para baixo e `text` em cima de `node` (que tem `half_height` px de meia altura).
func _draw_hint(node: Node2D, text: String, half_height: float) -> void:
	if node == null:
		return
	var p := (get_viewport().get_canvas_transform() * node.global_position).round()
	if p.y < 48.0:
		return  # ainda colado no topo: a dica sairia cortada (some em ~0,5 s)
	var tip := Vector2(p.x, p.y - half_height - 3.0)
	# seta para baixo: contorno k e miolo amarelo
	draw_colored_polygon([tip + Vector2(-6, -7), tip + Vector2(6, -7), tip + Vector2(0, 1)], Palette.OUTLINE)
	draw_colored_polygon([tip + Vector2(-4, -6), tip + Vector2(4, -6), tip], Palette.YELLOW)
	PixelText.draw_centered(self, text, p.x, tip.y - 9.0 - PixelText.BODY_H)


## Objeto mais perto à frente do avião (ou ao lado), na tela, que passe no teste `accept`.
func _next_ahead(accept: Callable) -> Node2D:
	var best: Node2D = null
	for node in game.objects.get_children():
		if not accept.call(node) or node.is_destroyed or node.position.y > game.player.position.y + 8.0:
			continue
		var screen_y: float = (get_viewport().get_canvas_transform() * node.global_position).y
		if screen_y < 0.0:
			continue
		if best == null or node.position.y > best.position.y:
			best = node
	return best


## Abaixo dos pontos: multiplicador ("X2"...) e barrinha do tempo que resta para o combo.
func _draw_combo(screen: Vector2) -> void:
	if game.combo <= 0:
		return
	var right := screen.x - MARGIN
	if game.multiplier() > 1:
		var text := "X%d" % game.multiplier()
		PixelText.draw(self, text, Vector2(right - PixelText.width(text, 2), MARGIN + 11.0), 2)
	const BAR := Vector2(34, 4)
	var bar_pos := Vector2(right - BAR.x, MARGIN + 31.0)
	draw_rect(Rect2(bar_pos, BAR), Palette.OUTLINE)
	draw_rect(Rect2(bar_pos + Vector2.ONE, BAR - Vector2(2, 2)), Palette.GRAY_DARK)
	var fill := floorf((BAR.x - 2.0) * clampf(game.combo_timer / game.combo_window, 0.0, 1.0))
	draw_rect(Rect2(bar_pos + Vector2.ONE, Vector2(fill, BAR.y - 2.0)), Palette.YELLOW)


func _draw_game_over(screen: Vector2) -> void:
	var cx := screen.x / 2.0
	var cy := screen.y / 2.0
	draw_rect(Rect2(0, cy - 44, screen.x, 108), Color(Palette.OUTLINE, 0.75))
	PixelText.draw_centered(self, "FIM DE JOGO", cx, cy - 34, 3)
	PixelText.draw_centered(self, "PONTOS %06d" % game.score, cx, cy)
	if game.is_new_record:
		if Time.get_ticks_msec() % 500 < 300:
			PixelText.draw_centered(self, "NOVO RECORDE!", cx, cy + 13)
	else:
		PixelText.draw_centered(self, "RECORDE %06d" % game.high_score, cx, cy + 13)
	# teclas com borda: linhas a 18 px uma da outra para as bordas não encostarem
	PixelText.draw_centered(self, "[%s] PARA JOGAR DE NOVO" % InputHint.name_of(&"shoot"), cx, cy + 30)
	PixelText.draw_centered(self, "[%s] PARA O MENU" % InputHint.back(), cx, cy + 48)
