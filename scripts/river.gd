class_name River
extends Node2D
## Rio infinito gerado à frente da câmera, linha por linha, dividido em SEÇÕES.
##
## Cada linha tem ROW_H px de altura e guarda onde termina a margem esquerda (left)
## e onde começa a margem direita (right); entre elas é água. As margens mudam no
## máximo um degrau por linha, formando "escadinhas" como nos jogos do gênero.
## Outros scripts perguntam `is_water(ponto)` em vez de usar física.
##
## Seções: cada uma tem `section_rows` linhas e termina num gargalo reto com uma ponte
## (a ponte fica na 1ª linha da seção seguinte). O sorteio de cada seção usa uma semente
## própria, então `reset_to_section(s)` recria a seção IGUAL (formato e objetos), e é
## isso que permite recomeçar da última ponte depois de uma queda.

## Emitido para cada linha nova; usado para colocar inimigos e objetos no rio.
signal row_created(index: int, y: float, left: float, right: float)

const ROW_H := 8.0
const STEP := 8.0  # quanto uma margem anda de uma linha para a outra (px)
## Largura do gargalo reto onde fica a ponte (px)
const NECK_WIDTH := 160.0
## Linhas de gargalo reto antes e depois de cada ponte
const NECK_ROWS := 12
## Linhas antes do gargalo em que o rio já vai se ajeitando para ele. Precisa dar tempo de
## a margem andar até 208 px mesmo andando só a cada 2 linhas: 56 / 2 * 8 = 224 px.
const NECK_APPROACH := 56
## Linhas sem ilhas depois de cada ponte (e do começo seguro), para quem acabou de renascer
const ISLAND_CALM_ROWS := 30
## A cada quantos ms o tracejado da espuma anda 1 px
const FOAM_STEP_MS := 250
## Base da linha 0 no mundo. FIXA, não depende da altura da tela: no online os dois
## computadores precisam do rio nas mesmas coordenadas (uma tela 16:10 tem 400 px de altura
## e uma 16:9, 360). 440 cobre o fundo da tela no começo até telas 4:3.
const START_Y := 440.0
## Sombra da terra na água (luz de cima: cai para a direita e para baixo; margem é baixa)
const LAND_SHADOW := Vector2(2, 3)

## Largura mínima e máxima da água (px)
@export var min_width := 176.0
@export var max_width := 448.0
## A cada quantas linhas as margens andam um degrau: 2 = curvas suaves (metade da inclinação)
@export var bank_move_every := 2
## Distância mínima entre a margem e a borda da tela (px)
@export var edge_margin := 32.0
## Linhas retas e largas no começo da partida, para o jogador se situar
@export var safe_rows := 50
## Quantas linhas (mín/máx) o rio mantém um mesmo "alvo" de formato
@export var hold_rows_min := 10
@export var hold_rows_max := 36
## Tamanho de cada seção, de ponte a ponte (linhas). 320 linhas = 2560 px ≈ 26 s em cruzeiro
@export var section_rows := 320

@export_group("Ilhas")
## Chance, por linha, de começar uma ilha quando o rio está largo o bastante
@export_range(0.0, 1.0) var island_chance := 0.02
## Largura mínima de cada canal ao lado da ilha (px): o avião precisa passar folgado
@export var min_channel := 72.0
## Meia-largura mínima de uma ilha (px)
@export var min_island_half := 24.0
## Quantas linhas (mín/máx) a ilha fica no tamanho cheio antes de encolher
@export var island_rows_min := 16
@export var island_rows_max := 50

@export_group("Dificuldade")
## Em quantas seções a dificuldade vai de 0 (seção 0) até o máximo
@export var difficulty_ramp_sections := 12
## Largura mínima e máxima da água na dificuldade máxima (px) — o rio vai ficando mais estreito
@export var hard_min_width := 112.0
@export var hard_max_width := 280.0
## Margens andando a cada linha na dificuldade máxima: curvas de 45°
@export var hard_bank_move_every := 1
## Linhas (mín/máx) de cada "alvo" de formato na dificuldade máxima — mais curvas
@export var hard_hold_rows_min := 6
@export var hard_hold_rows_max := 20

@export_group("Decoração")
## Chance, por linha e por trecho de terra, de colocar um enfeite (árvore, casa...)
@export_range(0.0, 1.0) var decor_chance := 0.14

## Enfeites das margens (mesma ordem de tools/sprites/decorations.py) e o peso de cada um
const DECOR_TEXTURES: Array[Texture2D] = [
	preload("res://assets/sprites/decorations/tree_round.png"),
	preload("res://assets/sprites/decorations/tree_pine.png"),
	preload("res://assets/sprites/decorations/bush.png"),
	preload("res://assets/sprites/decorations/rock.png"),
	preload("res://assets/sprites/decorations/house.png"),
]
const DECOR_WEIGHTS: Array[float] = [40.0, 25.0, 20.0, 7.0, 8.0]
## Linhas de atraso para decidir os enfeites de uma linha: as linhas de cima (que o enfeite
## também cobre) precisam já existir para conferir que ele cai todo em terra
const DECOR_DELAY := 3

## Sorteio do rio E dos objetos (main.gd usa este mesmo gerador): re-semeado a cada seção
var rng := RandomNumberGenerator.new()
var base_seed := 0

var lefts: Array[float] = []
var rights: Array[float] = []
## Ilha no meio da linha: terra entre island_ls e island_rs (iguais = sem ilha)
var island_ls: Array[float] = []
var island_rs: Array[float] = []
## Enfeites de cada linha: lista de Vector2(tipo, x)
var decors: Array[Array] = []
var first_index := 0  # índice da linha guardada em lefts[0]
var start_y := START_Y  # base (y de baixo) da linha 0

var _target_left := 0.0
var _target_right := 0.0
var _hold := 0
var _island_half := 0.0
var _island_target_half := 0.0
var _island_rows := 0
var _section := 0  # seção da última linha gerada
var _min_width_now := 0.0   # largura mínima da seção atual (depende da dificuldade)
var _move_every_now := 1    # a cada quantas linhas as margens andam na seção atual
var _screen_w := 640.0


func _ready() -> void:
	add_to_group("river")
	_screen_w = get_viewport_rect().size.x
	base_seed = randi()
	_update_rows.call_deferred()


func _process(_delta: float) -> void:
	_update_rows()
	queue_redraw()


## true se o ponto (coordenadas do mundo) está sobre a água.
func is_water(point: Vector2) -> bool:
	var i := _index_at(point.y) - first_index
	if i < 0 or i >= lefts.size():
		return true  # fora do trecho conhecido: não bloqueia
	if point.x >= island_ls[i] and point.x < island_rs[i]:
		return false
	return point.x >= lefts[i] and point.x < rights[i]


## Trechos de água da linha `index` como Vector2(início, fim): um canal, ou dois com ilha.
func channels_at(index: int) -> Array[Vector2]:
	var i := index - first_index
	if i < 0 or i >= lefts.size():
		return []
	if island_rs[i] > island_ls[i]:
		return [Vector2(lefts[i], island_ls[i]), Vector2(island_rs[i], rights[i])]
	return [Vector2(lefts[i], rights[i])]


## Faixa de água (x da margem esquerda, x da margem direita) livre em TODAS as linhas
## entre y - half_height e y + half_height. Útil para posicionar algo sem tocar a terra.
func water_span(y: float, half_height: float = 16.0) -> Vector2:
	var span := Vector2(-INF, INF)
	for i in range(_index_at(y + half_height), _index_at(y - half_height) + 1):
		var k := i - first_index
		if k >= 0 and k < lefts.size():
			span.x = maxf(span.x, lefts[k])
			span.y = minf(span.y, rights[k])
	if is_inf(span.x) or is_inf(span.y):
		return Vector2(0, _screen_w)
	return span


func row_top(index: int) -> float:
	return start_y - (index + 1) * ROW_H


func section_of(index: int) -> int:
	return floori(float(index) / section_rows)


func local_of(index: int) -> int:
	return index - section_of(index) * section_rows


## Dificuldade da seção, de 0.0 (começo) a 1.0 (depois de `difficulty_ramp_sections` pontes).
func difficulty(section: int) -> float:
	return clampf(float(section) / difficulty_ramp_sections, 0.0, 1.0)


## A ponte fica na 1ª linha de cada seção (menos na seção 0, que é o começo da partida).
func is_bridge_row(index: int) -> bool:
	return index > 0 and local_of(index) == 0


## Onde podem nascer inimigos e postos: fora do começo seguro e dos gargalos das pontes.
func allows_spawn(index: int) -> bool:
	var s := section_of(index)
	var l := local_of(index)
	if s == 0 and l < safe_rows:
		return false
	if s > 0 and l < NECK_ROWS:
		return false
	return l < section_rows - NECK_ROWS


## Onde o avião renasce ao recomeçar a seção `s` (logo depois da ponte dela).
func section_start_position(s: int, player_start: Vector2) -> Vector2:
	if s == 0:
		return player_start
	return Vector2(_screen_w / 2.0, row_top(s * section_rows + 6) + ROW_H / 2.0)


## Apaga o rio e gera de novo a partir do começo da seção `s` (com o gargalo da ponte
## logo abaixo). Chame DEPOIS de mover o avião e a câmera para o começo da seção.
func reset_to_section(s: int) -> void:
	lefts.clear()
	rights.clear()
	island_ls.clear()
	island_rs.clear()
	decors.clear()
	first_index = 0 if s == 0 else s * section_rows - NECK_ROWS
	_update_rows()


func _index_at(y: float) -> int:
	return int(floor((start_y - y) / ROW_H))


func _update_rows() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var view_h := Game.view_h_max(self)  # online: a tela mais alta dos dois (os objetos nascem juntos)
	# global_position (e não get_screen_center_position) porque no 1º frame o centro
	# da tela ainda não foi atualizado e as linhas de baixo seriam descartadas
	var top := camera.global_position.y - view_h / 2.0
	var bottom := top + view_h

	# Gera linhas até um pouco acima do topo da tela
	while row_top(first_index + lefts.size()) > top - 64.0:
		_add_row()

	# Descarta linhas que já ficaram bem abaixo da tela
	while lefts.size() > 0 and row_top(first_index) > bottom + 64.0:
		lefts.pop_front()
		rights.pop_front()
		island_ls.pop_front()
		island_rs.pop_front()
		decors.pop_front()
		first_index += 1


func _add_row() -> void:
	var index := first_index + lefts.size()
	var s := section_of(index)
	var l := local_of(index)
	if l == 0:
		_begin_section(s)

	var center := _screen_w / 2.0
	var left: float
	var right: float
	if s == 0 and l < safe_rows:
		left = _snap(center - max_width / 2.0)
		right = _snap(center + max_width / 2.0)
	elif (s > 0 and l < NECK_ROWS) or l >= section_rows - NECK_ROWS:
		left = _snap(center - NECK_WIDTH / 2.0)
		right = _snap(center + NECK_WIDTH / 2.0)
	else:
		var approaching_bridge := l >= section_rows - NECK_ROWS - NECK_APPROACH
		if approaching_bridge:
			# chegando na ponte: vai fechando até o gargalo
			_target_left = _snap(center - NECK_WIDTH / 2.0)
			_target_right = _snap(center + NECK_WIDTH / 2.0)
		else:
			_hold -= 1
			if _hold <= 0:
				_pick_new_target()
		left = lefts.back()
		right = rights.back()
		# As margens só andam a cada `_move_every_now` linhas (curvas mais suaves no começo)
		if l % _move_every_now == 0:
			left = move_toward(left, _target_left, STEP)
			right = move_toward(right, _target_right, STEP)
		# Nunca deixa a passagem ESTREITAR abaixo do mínimo durante a transição
		# (alargar pode, por exemplo saindo do gargalo de uma ponte). Na chegada à ponte
		# não vale: o alvo é o próprio gargalo, que pode ser mais estreito que o mínimo.
		if not approaching_bridge and right - left < _min_width_now \
				and right - left < rights.back() - lefts.back():
			left = lefts.back()
			right = rights.back()

	# Ilha: só no trecho livre da seção, e some antes de chegar no gargalo da ponte.
	# Também não nasce logo depois da ponte/começo seguro: é onde o avião renasce (no meio).
	var calm_rows := (safe_rows if s == 0 else NECK_ROWS) + ISLAND_CALM_ROWS
	var island_allowed := allows_spawn(index) and l >= calm_rows \
			and l < section_rows - NECK_ROWS - NECK_APPROACH - 24
	var island := _update_island(left, right, island_allowed)

	lefts.append(left)
	rights.append(right)
	island_ls.append(island.x)
	island_rs.append(island.y)
	decors.append([])
	_place_decorations(index - DECOR_DELAY)
	row_created.emit(index, row_top(index), left, right)


## Sorteia os enfeites da linha `index` (em cada trecho de terra: margens e ilha).
## Usa um sorteio próprio por linha, separado de `rng`: enfeite não muda rio nem inimigos.
func _place_decorations(index: int) -> void:
	var k := index - first_index
	if k < 0 or k >= decors.size():
		return
	var r := RandomNumberGenerator.new()
	r.seed = hash([base_seed, index, "decor"])
	var cy := row_top(index) + ROW_H / 2.0
	for seg in _land_segments(k):
		if r.randf() >= decor_chance:
			continue
		var type := r.rand_weighted(PackedFloat32Array(DECOR_WEIGHTS))
		var half := DECOR_TEXTURES[type].get_size() / 2.0
		var lo := seg.x + half.x + 4.0
		var hi := seg.y - half.x - 4.0
		if lo > hi:
			continue
		var x := roundf(r.randf_range(lo, hi))
		if _decor_fits(index, x, cy, half):
			decors[k].append(Vector2(type, x))


## O enfeite cabe se cai todo em terra (com 3 px de folga da água), longe da estrada das
## pontes e sem encostar em outro enfeite.
func _decor_fits(index: int, x: float, cy: float, half: Vector2) -> bool:
	for i in range(index - 2, index + 3):
		if is_bridge_row(i):
			return false
	var pad := half + Vector2(3, 3)
	for dy in [-pad.y, 0.0, pad.y - 1.0]:
		for dx in [-pad.x, 0.0, pad.x - 1.0]:
			if is_water(Vector2(x + dx, cy + dy)) or _index_at(cy + dy) - first_index >= lefts.size():
				return false
	for i in range(index - 3, index + 1):
		var k := i - first_index
		if k < 0 or k >= decors.size():
			continue
		for d in decors[k]:
			if absf(d.y - x) < half.x + 10.0:
				return false
	return true


## Avança a ilha uma linha: nasce no meio do rio, cresce um degrau por linha, fica um tempo
## e encolhe. Sempre deixa `min_channel` px de água de cada lado. Retorna (início, fim).
func _update_island(left: float, right: float, allowed: bool) -> Vector2:
	var max_half := (right - left) / 2.0 - min_channel
	if not allowed or max_half < min_island_half:
		_island_rows = 0  # sem espaço (ou chegando na ponte): encolhe
	elif _island_half == 0.0 and _island_rows == 0 and rng.randf() < island_chance:
		_island_rows = rng.randi_range(island_rows_min, island_rows_max)
		_island_target_half = _snap(rng.randf_range(min_island_half, max_half))

	if _island_rows > 0:
		_island_half = move_toward(_island_half, _island_target_half, STEP)
		if _island_half == _island_target_half:
			_island_rows -= 1
	else:
		_island_half = move_toward(_island_half, 0.0, STEP)
	# nunca aperta os canais, mesmo se as margens se mexerem
	_island_half = minf(_island_half, floorf(maxf(max_half, 0.0) / STEP) * STEP)

	if _island_half <= 0.0:
		return Vector2.ZERO
	var center := _snap((left + right) / 2.0)
	return Vector2(center - _island_half, center + _island_half)


## Começo de seção: mesma semente => mesmo rio e mesmos objetos sempre que for gerada.
func _begin_section(s: int) -> void:
	rng.seed = hash([base_seed, s])
	_section = s
	var d := difficulty(s)
	_min_width_now = _snap(lerpf(min_width, hard_min_width, d))
	_move_every_now = maxi(1, roundi(lerpf(bank_move_every, hard_bank_move_every, d)))
	_hold = 0
	_island_half = 0.0
	_island_rows = 0


func _pick_new_target() -> void:
	var d := difficulty(_section)
	var hold_min := roundi(lerpf(hold_rows_min, hard_hold_rows_min, d))
	var hold_max := roundi(lerpf(hold_rows_max, hard_hold_rows_max, d))
	_hold = rng.randi_range(hold_min, hold_max)
	var width := rng.randf_range(_min_width_now, lerpf(max_width, hard_max_width, d))
	var half := width / 2.0
	var center := rng.randf_range(edge_margin + half, _screen_w - edge_margin - half)
	_target_left = _snap(center - half)
	_target_right = _snap(center + half)


func _snap(x: float) -> float:
	return roundf(x / STEP) * STEP


# --- Desenho -------------------------------------------------------------------
# Terra verde, faixa clara de 2 px junto à água e contorno de 1 px (padrão dos sprites).
# Cada linha vira uma lista de trechos de terra e de água, então margens e ilhas usam
# exatamente o mesmo desenho.

func _draw() -> void:
	# Sombra: a própria terra deslocada, desenhada antes; a terra por cima esconde o que não
	# cai na água. Linhas deslocadas não se sobrepõem, então a sombra nunca fica mais escura.
	for i in lefts.size():
		var y := row_top(first_index + i)
		for seg in _land_segments(i):
			draw_rect(Rect2(seg.x + LAND_SHADOW.x, y + LAND_SHADOW.y, seg.y - seg.x, ROW_H), Palette.SHADOW)
	for i in lefts.size():
		var y := row_top(first_index + i)
		for seg in _land_segments(i):
			draw_rect(Rect2(seg.x, y, seg.y - seg.x, ROW_H), Palette.GREEN)
	for pass_color in [Palette.GREEN_LIGHT, Palette.OUTLINE]:
		for i in lefts.size():
			_draw_edges(i, pass_color)
	var foam_phase := int(Time.get_ticks_msec() / FOAM_STEP_MS) % 4
	for i in lefts.size():
		_draw_foam(i, foam_phase)
	for i in decors.size():
		var cy := row_top(first_index + i) + ROW_H / 2.0
		for d: Vector2 in decors[i]:
			var tex := DECOR_TEXTURES[int(d.x)]
			draw_texture(tex, (Vector2(d.y, cy) - tex.get_size() / 2.0).floor())
	for i in lefts.size():
		if is_bridge_row(first_index + i):
			_draw_road(row_top(first_index + i) + ROW_H / 2.0, lefts[i], rights[i])


func _land_segments(i: int) -> Array[Vector2]:
	var segs: Array[Vector2] = [Vector2(0, lefts[i]), Vector2(rights[i], _screen_w)]
	if island_rs[i] > island_ls[i]:
		segs.append(Vector2(island_ls[i], island_rs[i]))
	return segs


func _water_segments(i: int) -> Array[Vector2]:
	return channels_at(first_index + i)


func _draw_edges(i: int, color: Color) -> void:
	var is_outline: bool = color == Palette.OUTLINE
	var width := 1.0 if is_outline else 2.0
	var inset := 0.0 if is_outline else 1.0  # a faixa clara fica logo atrás do contorno
	var y := row_top(first_index + i)

	# bordas verticais: dentro da terra, encostadas em cada trecho de água
	for w in _water_segments(i):
		draw_rect(Rect2(w.x - inset - width, y, width, ROW_H), color)
		draw_rect(Rect2(w.y + inset, y, width, ROW_H), color)

	# degraus: terra desta linha que fica em cima de água da linha de baixo / de cima
	for neighbor in [i - 1, i + 1]:
		if neighbor < 0 or neighbor >= lefts.size():
			continue
		var edge_y: float = y + ROW_H - inset - width if neighbor == i - 1 else y + inset
		for land in _land_segments(i):
			for water in _water_segments(neighbor):
				var a := maxf(land.x, water.x)
				var b := minf(land.y, water.y)
				if a >= b:
					continue
				# estende 1 px para emendar com o contorno vertical da linha vizinha
				if water.x > land.x:
					a -= 1.0
				if water.y < land.y:
					b += 1.0
				draw_rect(Rect2(a, edge_y, b - a, width), color)


## Espuma: tracejado de 1 px (azul bem claro) do lado da água, colado em toda borda de terra.
## O tracejado anda 1 px a cada FOAM_STEP_MS, como água batendo na margem.
func _draw_foam(i: int, phase: int) -> void:
	var y := row_top(first_index + i)
	# bordas verticais: primeira e última coluna de cada trecho de água
	for w in _water_segments(i):
		for py in int(ROW_H):
			if posmod(int(y) + py + phase, 4) < 2:
				draw_rect(Rect2(w.x, y + py, 1, 1), Palette.BLUE_LIGHT)
				draw_rect(Rect2(w.y - 1, y + py, 1, 1), Palette.BLUE_LIGHT)
	# degraus: água da linha vizinha logo abaixo/acima da terra desta linha
	for neighbor in [i - 1, i + 1]:
		if neighbor < 0 or neighbor >= lefts.size():
			continue
		var foam_y: float = y + ROW_H if neighbor == i - 1 else y - 1.0
		for land in _land_segments(i):
			for water in _water_segments(neighbor):
				for x in range(int(maxf(land.x, water.x)), int(minf(land.y, water.y))):
					if posmod(x + phase, 4) < 2:
						draw_rect(Rect2(x, foam_y, 1, 1), Palette.BLUE_LIGHT)


## Estrada que chega na ponte pelos dois lados (mesmo padrão do asfalto do sprite da ponte):
## contorno em cima/embaixo, asfalto cinza escuro e faixa central tracejada.
func _draw_road(center_y: float, left: float, right: float) -> void:
	var top := center_y - 8.0
	for seg in [Vector2(0, left), Vector2(right, _screen_w)]:
		var w: float = seg.y - seg.x
		draw_rect(Rect2(seg.x, top, w, 16), Palette.OUTLINE)
		draw_rect(Rect2(seg.x, top + 1, w, 14), Palette.GRAY_DARK)
		var x: float = seg.x
		while x < seg.y:
			if int(x) % 12 < 6:
				draw_rect(Rect2(x, center_y - 1, minf(1.0, seg.y - x), 2), Palette.ORANGE_LIGHT)
			x += 1.0
