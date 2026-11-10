extends Control
## HUD: pontos, recorde, aviões reserva (abaixo da barra de combustível), power-ups ativos,
## dicas e a tela de fim de jogo. A barra de combustível é um nó à parte (fuel_gauge.gd).
## 1 jogador: pontos e combo no canto superior direito, recorde no centro.
## Coop: J1 à esquerda e J2 espelhado à direita (barra, vidas, power-ups); pontos, combo e
## recorde no centro (um placar, ou um de cada lado do centro com pontos separados).

## Partida de onde vêm pontos, vidas e fim de jogo
@export var game: Game

const LIFE_ICONS := {
	1: preload("res://assets/sprites/hud/life.png"),
	2: preload("res://assets/sprites/hud/life_p2.png"),
}
const MARGIN := 8.0
const BAR := Vector2(34, 4)  # barrinhas de tempo (combo e power-ups)
const GAME_OVER_PANEL := Vector2(260, 146)  # pontos + recorde, divisória e 2 opções


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if game == null:
		return
	var screen := get_viewport_rect().size
	var coop := game.players.size() > 1

	if not coop:
		# Pontos com 6 dígitos, alinhados à direita; recorde no topo, ao centro
		var score_text := "%06d" % game.score
		PixelText.draw(self, score_text, Vector2(screen.x - MARGIN - PixelText.width(score_text), MARGIN))
		PixelText.draw_centered(self, "REC %06d" % maxi(game.high_score, game.score), screen.x / 2.0, MARGIN)
		_draw_combo(screen)
	else:
		_draw_coop_scores(screen)

	for p in game.players:
		var right := p.number == 2  # J2 espelhado no canto direito
		_draw_lives(p, right, screen)
		_draw_power_up(p, right, screen)
		# Alerta de pouco combustível, piscando ao lado da barra (que fica em x 8..104)
		if not p.is_dead and p.is_low_fuel() and Time.get_ticks_msec() % 250 < 125:
			var x := 110.0 if not right else screen.x - 110.0 - PixelText.width("COMBUSTIVEL")
			PixelText.draw(self, "COMBUSTIVEL", Vector2(x, MARGIN))

	if not game.players.all(func(p: Player) -> bool: return p.is_dead):
		_draw_hints()

	if game.is_game_over:
		_draw_game_over(screen)


## Aviões reserva, abaixo da barra de combustível (no J2, alinhados pela direita).
func _draw_lives(p: Player, right: bool, screen: Vector2) -> void:
	for i in p.lives:
		var x := MARGIN + i * 12.0
		if right:
			x = screen.x - MARGIN - 11.0 - i * 12.0
		draw_texture(LIFE_ICONS[p.number], Vector2(x, MARGIN + 11.0))


## Coop: pontos no centro. Juntos: um placar, o recorde do time na 2ª linha e o combo
## embaixo. Separados (sem recorde): J1 à esquerda do centro e J2 à direita, cada um com o
## próprio combo logo abaixo.
func _draw_coop_scores(screen: Vector2) -> void:
	var cx := screen.x / 2.0
	if game.boards.size() == 1:
		PixelText.draw_centered(self, "%06d" % game.score, cx, MARGIN)
		PixelText.draw_centered(self, "REC %06d" % maxi(game.high_score, game.score), cx, MARGIN + 11.0)
		_draw_combo_at(game.boards[0], cx - BAR.x / 2.0, MARGIN + 24.0)
		return
	# aviãozinho da cor de cada jogador do lado de fora do placar dele
	var left_text := "%06d" % game.boards[0].score
	var left_x := cx - 8.0 - PixelText.width(left_text)
	PixelText.draw(self, left_text, Vector2(left_x, MARGIN))
	draw_texture(LIFE_ICONS[1], Vector2(left_x - 14.0, MARGIN - 1.0))
	var right_text := "%06d" % game.boards[1].score
	PixelText.draw(self, right_text, Vector2(cx + 8.0, MARGIN))
	draw_texture(LIFE_ICONS[2], Vector2(cx + 8.0 + PixelText.width(right_text) + 3.0, MARGIN - 1.0))
	_draw_combo_at(game.boards[0], cx - 8.0 - BAR.x - 30.0, MARGIN + 13.0)
	_draw_combo_at(game.boards[1], cx + 38.0, MARGIN + 13.0)


## Combo pequeno do coop: "X2" + barrinha do tempo a partir de `left`.
func _draw_combo_at(board: Game.ScoreBoard, left: float, y: float) -> void:
	if board.combo <= 0:
		return
	var mult := game.multiplier(board)
	if mult > 1:
		PixelText.draw(self, "X%d" % mult, Vector2(left - 20.0, y - 2.0))
	var bar_pos := Vector2(left, y + 1.0)
	draw_rect(Rect2(bar_pos, BAR), Palette.OUTLINE)
	draw_rect(Rect2(bar_pos + Vector2.ONE, BAR - Vector2(2, 2)), Palette.GRAY_DARK)
	var fill := floorf((BAR.x - 2.0) * clampf(board.combo_timer / game.combo_window, 0.0, 1.0))
	draw_rect(Rect2(bar_pos + Vector2.ONE, Vector2(fill, BAR.y - 2.0)), Palette.YELLOW)


## Power-ups ativos, abaixo dos aviões reserva: a caixa de cada um e uma barrinha do tempo
## que resta (igual à do combo), um embaixo do outro. Cada um pisca nos últimos 2 s.
## No J2 (`right`), espelhado: caixa encostada na direita e a barrinha à esquerda dela.
func _draw_power_up(player: Player, right: bool, screen: Vector2) -> void:
	var active := []  # [tipo, tempo restante, duração, cor da barra]
	if player.double_shot_timer > 0.0:
		active.append([PowerUp.Kind.DOUBLE_SHOT, player.double_shot_timer, player.double_shot_time, Palette.ORANGE])
	if player.shield_timer > 0.0:
		active.append([PowerUp.Kind.SHIELD, player.shield_timer, player.shield_time, Palette.BLUE])
	for i in active.size():
		var left: float = active[i][1]
		if left < 2.0 and Time.get_ticks_msec() % 300 >= 150:
			continue
		# 3 px abaixo dos aviões reserva (y 19..29), o mesmo vão entre a barra de combustível
		# e eles; cada power-up a mais fica 3 px abaixo do anterior (caixa de 16 px)
		var icon_pos := Vector2(MARGIN, MARGIN + 25.0 + i * 19.0)
		var bar_pos := icon_pos + Vector2(19, 6)
		if right:
			icon_pos.x = screen.x - MARGIN - 16.0
			bar_pos = Vector2(icon_pos.x - 3.0 - BAR.x, icon_pos.y + 6.0)
		draw_texture(PowerUp.TEXTURES[active[i][0]], icon_pos)
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
## No coop, "à frente" é em relação ao avião que a câmera segue (o de trás).
func _next_ahead(accept: Callable) -> Node2D:
	var best: Node2D = null
	var ref := game.camera.target if is_instance_valid(game.camera.target) else game.player
	for node in game.objects.get_children():
		if not accept.call(node) or node.is_destroyed or node.position.y > ref.position.y + 8.0:
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
	var bar_pos := Vector2(right - BAR.x, MARGIN + 31.0)
	draw_rect(Rect2(bar_pos, BAR), Palette.OUTLINE)
	draw_rect(Rect2(bar_pos + Vector2.ONE, BAR - Vector2(2, 2)), Palette.GRAY_DARK)
	var fill := floorf((BAR.x - 2.0) * clampf(game.combo_timer / game.combo_window, 0.0, 1.0))
	draw_rect(Rect2(bar_pos + Vector2.ONE, Vector2(fill, BAR.y - 2.0)), Palette.YELLOW)


## Fim de jogo: painel de madeira como os menus, com os pontos (e o recorde, ou os pontos de cada
## um no coop com pontos separados) e as opções de game.game_over_items().
func _draw_game_over(_screen: Vector2) -> void:
	var top_left := MenuStyle.panel(self, GAME_OVER_PANEL, "FIM DE JOGO")
	var cx := top_left.x + GAME_OVER_PANEL.x / 2.0
	var y := top_left.y + MenuStyle.CONTENT_TOP
	if game.boards.size() > 1:
		# pontos separados: sem recorde, só o placar de cada um, na cor de cada avião
		PixelText.draw_centered(self, "J1 %06d" % game.boards[0].score, cx, y, 1, Palette.YELLOW_LIGHT)
		PixelText.draw_centered(self, "J2 %06d" % game.boards[1].score, cx, y + 18.0, 1, Palette.LILAC_LIGHT)
	else:
		PixelText.draw_centered(self, "PONTOS %06d" % game.score, cx, y)
		if game.is_new_record:
			if Time.get_ticks_msec() % 500 < 300:
				PixelText.draw_centered(self, "NOVO RECORDE!", cx, y + 18.0, 1, MenuStyle.SELECTED)
		else:
			PixelText.draw_centered(self, "RECORDE %06d" % game.high_score, cx, y + 18.0, 1, MenuStyle.SOFT)
	MenuStyle.divider(self, top_left.x + 20.0, top_left.x + GAME_OVER_PANEL.x - 20.0, y + 36.0)
	var items := game.game_over_items()
	var row_y := y + 46.0
	if items.size() == 1:  # convidado online: quem recomeça é o anfitrião
		PixelText.draw_centered(self, "ESPERANDO O ANFITRIÃO...", cx, row_y, 1, MenuStyle.SOFT)
		row_y += 22.0
	for i in items.size():
		MenuStyle.item(self, items[i], cx, row_y + i * 22.0, i == game.game_over_selected)
