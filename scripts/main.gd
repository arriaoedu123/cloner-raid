class_name Game
extends Node2D
## Cena principal: coloca inimigos, postos e pontes nas linhas novas do rio,
## conta pontos e vidas, recomeça da última ponte destruída e controla o fim de jogo.
##
## Todo sorteio de objetos usa `river.rng` (re-semeado a cada seção do rio), para que
## recomeçar uma seção recrie exatamente os mesmos objetos nos mesmos lugares.
##
## Coop local (`two_players`): dois aviões, cada um com combustível e vidas. A câmera segue o
## de TRÁS e o da frente não passa do topo da tela. Quem cai renasce ao lado do outro; se os
## dois caírem, a seção recomeça. Pontos juntos (1 placar) ou separados (1 por jogador).

## Modo da próxima partida, escolhido no título (variável estática sobrevive à troca de cena)
static var two_players := false
## Coop: de onde vem o comando do J1 e do J2 (-1 = teclado, senão o número do controle);
## escolhido na tela do coop (coop_menu.gd). Os dois -1 = teclado dividido.
static var coop_devices: Array = [-1, -1]

const PLAYER_SCENE := preload("res://scenes/player.tscn")
## Coop: distância de cada avião ao centro ao (re)começar uma seção (px)
const COOP_SPREAD := 30.0
## Coop: o avião da frente não passa desta distância do topo da tela (px)
const COOP_TOP_MARGIN := 48.0
## Coop: velocidade máxima da câmera ao trocar de avião seguido (px/s), sem "pulo" na tela
const COOP_CAMERA_SPEED := 400.0


## Placar: pontos, combo e vidas extras por pontos. Um só (1 jogador ou coop com pontos
## juntos) ou um por jogador (coop com pontos separados).
class ScoreBoard:
	var score := 0
	var combo := 0
	var combo_timer := 0.0
	var next_bonus := 0  # pontuação em que vem a próxima vida extra
	var bonus_gap := 0   # intervalo até ela (cresce bonus_life_step a cada vida)


@export_group("Partida")
## Aviões reserva no começo (além do que está voando)
@export var starting_lives := 3
## Pontos para o 1º avião reserva extra
@export var bonus_life_every := 5000
## Cada vida extra seguinte custa isto a mais que a anterior (5000 => vidas aos 5k, 15k, 30k,
## 50k, 75k...). Com vida fixa a cada 5k, no fim do jogo vinha ~1 vida por seção.
@export var bonus_life_step := 5000
## Espera entre a queda e o avião renascer (s)
@export var respawn_delay := 1.5
## No fim de jogo, espera antes de aceitar o botão para jogar de novo (s)
@export var game_over_input_delay := 1.0

@export_group("Introdução")
## Na 1ª partida (até o primeiro reabastecimento) o tanque começa nesta fração (0–1), para o
## alerta aparecer cedo; o HUD mostra "ABASTEÇA" em cima do primeiro posto à frente.
## O 1º posto nasce a até ~4,6 s de cruzeiro (medido em 30 partidas); 0,4 = 10 s de voo.
@export_range(0.0, 1.0) var intro_start_fuel := 0.4

@export_group("Combo")
## Tempo para derrubar o próximo inimigo sem perder o combo (s)
@export var combo_window := 3.0
## Abates seguidos para subir cada nível do multiplicador (3 => x2 no 3º, x3 no 6º...)
@export var combo_per_level := 3
## Multiplicador máximo
@export var max_multiplier := 4

@export_group("Inimigos")
@export var helicopter_scene: PackedScene
## Chance de surgir um helicóptero em cada linha liberada do rio (0–1)
@export_range(0.0, 1.0) var helicopter_chance := 0.08
@export var ship_scene: PackedScene
## Chance de surgir um navio em cada linha liberada do rio (0–1)
@export_range(0.0, 1.0) var ship_chance := 0.05
@export var jet_scene: PackedScene
## Chance de surgir um jato em cada linha liberada do rio (0–1)
@export_range(0.0, 1.0) var jet_chance := 0.03
## Fração dos inimigos de patrulha que nascem parados e só acordam com o avião perto
@export_range(0.0, 1.0) var sleeper_chance := 0.5
## Faixa de altura na tela (px do topo) em que os dorminhocos acordam: varia para surpreender
@export var wake_screen_y_range := Vector2(80, 190)

@export_group("Pontes")
@export var bridge_scene: PackedScene

@export_group("Combustível")
@export var fuel_depot_scene: PackedScene
## Chance de surgir um posto em cada linha liberada do rio (0–1)
@export_range(0.0, 1.0) var fuel_chance := 0.03
## Máximo de linhas sem posto: passou disso, o próximo objeto é sempre um posto
@export var max_rows_without_fuel := 90

@export_group("Power-ups")
@export var power_up_scene: PackedScene
## Chance de uma seção ter caixa de power-up (no máximo uma por seção)
@export_range(0.0, 1.0) var power_up_chance := 0.6
## Primeira seção que pode ter caixa (o começo do jogo fica como está)
@export var power_up_first_section := 2
## Das caixas sorteadas, fração que é de vida extra (o resto é meio a meio tiro duplo/escudo)
@export_range(0.0, 1.0) var life_box_chance := 0.15
## Primeira seção que pode ter caixa de vida (prêmio para quem chega longe)
@export var life_box_first_section := 4

@export_group("Espaçamento")
## Linhas mínimas entre dois objetos quaisquer (evita amontoados)
@export var min_rows_between_spawns := 14
## Água mínima para caber um objeto (px)
@export var min_water_for_spawn := 64.0
## Linhas sem inimigos logo depois do gargalo de cada ponte (onde o avião passa e renasce).
## 40 linhas = 320 px, quase uma tela inteira à frente do avião. Postos podem aparecer.
@export var enemy_free_rows_after_bridge := 40

@export_group("Dificuldade máxima")
## Valores usados na seção mais difícil (ver River.difficulty_ramp_sections).
## No começo valem os valores normais acima; entre os dois, a mudança é gradual.
@export_range(0.0, 1.0) var hard_helicopter_chance := 0.13
@export_range(0.0, 1.0) var hard_ship_chance := 0.08
@export_range(0.0, 1.0) var hard_jet_chance := 0.06
@export_range(0.0, 1.0) var hard_fuel_chance := 0.02
@export var hard_max_rows_without_fuel := 120
@export var hard_min_rows_between_spawns := 8
## Multiplica a velocidade dos inimigos
@export var hard_enemy_speed_scale := 1.4
## Menos dorminhocos: mais inimigos já chegam se mexendo
@export_range(0.0, 1.0) var hard_sleeper_chance := 0.3

## Aviões na partida (1 ou 2); `player` é sempre o jogador 1
var players: Array[Player] = []
## Placares: 1 (pontos juntos) ou 1 por jogador (pontos separados)
var boards: Array[ScoreBoard] = [ScoreBoard.new()]

## Atalhos para o jogador 1 / 1º placar (é tudo que existe no modo de 1 jogador)
var score: int:
	get: return boards[0].score
	set(value): boards[0].score = value
var combo: int:
	get: return boards[0].combo
	set(value): boards[0].combo = value
var combo_timer: float:
	get: return boards[0].combo_timer
	set(value): boards[0].combo_timer = value
var lives: int:  # aviões reserva do jogador 1
	get: return player.lives
	set(value): player.lives = value

var is_game_over := false
## Maior pontuação já feita neste computador (carregada do SaveData)
var high_score := 0
## Se a partida que acabou de terminar bateu o recorde
var is_new_record := false

## Introdução ligada: só até o jogador reabastecer pela 1ª vez (fica salvo no save.cfg)
var intro_active := false
## Tipos de power-up que ainda mostram dica na caixa (o jogador nunca pegou um desses)
var _power_up_hints := {}

## Seção em que o avião recomeça depois de cair (avança ao destruir cada ponte)
var checkpoint_section := 0

var _can_restart := false
var _last_spawn_row := -1000
var _last_fuel_row := 0
var _power_up_row := -1  # a caixa da seção atual nasce no 1º lugar livre a partir desta linha
var _power_up_kind := PowerUp.Kind.DOUBLE_SHOT
var _player_start := Vector2.ZERO

@onready var river: River = $River
@onready var objects: Node2D = $Objects  # inimigos, postos e pontes colocados no rio
@onready var player: Player = $Player
@onready var camera: FollowCamera = $Camera2D


func _ready() -> void:
	Settings.load_and_apply()
	Sfx.warm_up()
	_player_start = player.position
	players = [player]
	if two_players:
		_add_second_player()
	for board in boards:
		board.bonus_gap = bonus_life_every
		board.next_bonus = bonus_life_every
	for p in players:
		p.lives = starting_lives
		p.died.connect(_on_player_died.bind(p))
		p.power_up_taken.connect(_on_power_up_taken.bind(p))
	high_score = SaveData.load_value("records", _record_key(), 0)
	river.row_created.connect(_on_river_row_created)
	# a introdução do combustível é só para quem joga sozinho pela 1ª vez
	intro_active = not two_players and not SaveData.load_value("progress", "intro_done", false)
	if intro_active:
		player.fuel = player.max_fuel * intro_start_fuel
		player.refueled.connect(_end_intro, CONNECT_ONE_SHOT)
	for kind in PowerUp.Kind.values():
		_power_up_hints[kind] = not SaveData.load_value("progress", _power_up_key(kind), false)


## Coop: cria o avião do jogador 2 (lilás), as ações de cada um, a 2ª barra de combustível
## e, com pontos separados, o 2º placar.
func _add_second_player() -> void:
	Controls.setup_coop_actions(coop_devices)
	var p2: Player = PLAYER_SCENE.instantiate()
	p2.name = "Player2"
	add_child(p2)
	move_child(p2, player.get_index() + 1)  # processa antes da câmera, como o jogador 1
	player.setup_player(1, true)
	p2.setup_player(2, true)
	player.position = _player_start + Vector2(-COOP_SPREAD, 0)
	p2.position = _player_start + Vector2(COOP_SPREAD, 0)
	players.append(p2)
	if not Settings.coop_shared_score:
		boards.append(ScoreBoard.new())
	camera.max_follow_speed = COOP_CAMERA_SPEED
	# 2ª barra de combustível, no canto superior direito
	var gauge: Control = $HUD/FuelGauge.duplicate()
	gauge.player = p2
	$HUD.add_child(gauge)
	gauge.position.x = get_viewport_rect().size.x - $HUD/FuelGauge.position.x - gauge.size.x


## Chave do recorde no save.cfg: um para 1 jogador e outro para o coop.
func _record_key() -> String:
	return "high_score_2p" if two_players else "high_score"


func _physics_process(_delta: float) -> void:
	if players.size() < 2:
		return
	var alive := _alive_players()
	if alive.is_empty():
		return
	# a câmera segue o avião de trás; o da frente não passa do topo da tela
	var rear := alive[0]
	for p in alive:
		if p.position.y > rear.position.y:
			rear = p
	camera.target = rear
	var top := camera.get_screen_center_position().y - get_viewport_rect().size.y / 2.0 + COOP_TOP_MARGIN
	for p in alive:
		p.position.y = maxf(p.position.y, top)


func _alive_players() -> Array[Player]:
	var alive: Array[Player] = []
	for p in players:
		if not p.is_dead:
			alive.append(p)
	return alive


## Primeiro reabastecimento: o jogador aprendeu, a introdução não volta mais.
func _end_intro() -> void:
	intro_active = false
	SaveData.save_value("progress", "intro_done", true)


## Se a caixa desse tipo ainda mostra a dica com o nome do poder.
func power_up_hint(kind: PowerUp.Kind) -> bool:
	return _power_up_hints.get(kind, false)


## Pegou um power-up: a caixa de vida dá +1 avião reserva a quem pegou, e a dica daquele
## tipo não volta mais.
func _on_power_up_taken(kind: PowerUp.Kind, p: Player) -> void:
	if kind == PowerUp.Kind.LIFE:
		p.lives += 1
	if power_up_hint(kind):
		_power_up_hints[kind] = false
		SaveData.save_value("progress", _power_up_key(kind), true)


## Chave no save.cfg (seção "progress"), ex.: "power_up_shield_seen".
static func _power_up_key(kind: PowerUp.Kind) -> String:
	return "power_up_%s_seen" % PowerUp.Kind.keys()[kind].to_lower()


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("toggle_fullscreen"):
		Settings.toggle_fullscreen()
	if _can_restart and Input.is_action_just_pressed("shoot"):
		get_tree().reload_current_scene()
	elif _can_restart and (Input.is_action_just_pressed("pause") or Input.is_action_just_pressed("ui_cancel")):
		get_tree().change_scene_to_file("res://scenes/title.tscn")
	for board in boards:
		if board.combo > 0:
			board.combo_timer -= delta
			if board.combo_timer <= 0.0:
				board.combo = 0


## Placar de quem fez a jogada (com pontos juntos, ou sem saber quem foi, é o 1º).
func board_of(p: Player) -> ScoreBoard:
	if boards.size() == 1 or p == null:
		return boards[0]
	return boards[p.number - 1]


## Multiplicador atual: x1, depois +1 a cada `combo_per_level` abates seguidos.
func multiplier(board: ScoreBoard = null) -> int:
	if board == null:
		board = boards[0]
	return mini(1 + board.combo / combo_per_level, max_multiplier)


## Inimigo (ou ponte) derrubado: soma ao combo de quem atirou e ganha os pontos multiplicados.
func _on_enemy_shot_down(points: int, node: Node) -> void:
	var board := board_of(node.killer)
	board.combo += 1
	board.combo_timer = combo_window
	add_score(points * multiplier(board), board)


## Posto destruído: dá os poucos pontos dele, mas quebra o combo de quem atirou.
func _on_depot_shot_down(points: int, node: Node) -> void:
	var board := board_of(node.killer)
	board.combo = 0
	add_score(points, board)


func add_score(points: int, board: ScoreBoard = null) -> void:
	if board == null:
		board = boards[0]
	board.score += points
	while board.score >= board.next_bonus:
		_bonus_life_receiver(board).lives += 1
		Sfx.play("extra_life")
		board.bonus_gap += bonus_life_step
		board.next_bonus += board.bonus_gap


## Quem ganha a vida extra por pontos: o dono do placar (pontos separados) ou, com pontos
## juntos, quem estiver com menos vidas entre os que ainda estão no jogo.
func _bonus_life_receiver(board: ScoreBoard) -> Player:
	if boards.size() > 1:
		return players[boards.find(board)]
	var best := player
	for p in players:
		if not p.is_out and (best.is_out or p.lives < best.lives):
			best = p
	return best


func _on_river_row_created(index: int, y: float, left: float, right: float) -> void:
	if river.local_of(index) == 0:
		# começo de seção: zera os contadores para a seção sair igual se for recriada
		_last_spawn_row = index
		_last_fuel_row = index
		# caixa de power-up: sorteada aqui com river.rng, então a seção recriada sai igual
		_power_up_row = -1
		if river.section_of(index) >= power_up_first_section and river.rng.randf() < power_up_chance:
			_power_up_row = index + river.rng.randi_range(60, river.section_rows - 100)
			if river.section_of(index) >= life_box_first_section and river.rng.randf() < life_box_chance:
				_power_up_kind = PowerUp.Kind.LIFE
			elif river.rng.randf() < 0.5:
				_power_up_kind = PowerUp.Kind.DOUBLE_SHOT
			else:
				_power_up_kind = PowerUp.Kind.SHIELD
	if river.is_bridge_row(index):
		var section := river.section_of(index)
		if section > checkpoint_section:  # pontes já destruídas não voltam
			_spawn_bridge(section, y, left, right)
		return
	var d := river.difficulty(river.section_of(index))
	var spacing := roundi(lerpf(min_rows_between_spawns, hard_min_rows_between_spawns, d))
	if not river.allows_spawn(index) or index - _last_spawn_row < spacing:
		return
	# Canais de água da linha (dois quando há ilha) que têm espaço para um objeto
	var channels := river.channels_at(index).filter(
		func(c: Vector2): return c.y - c.x >= min_water_for_spawn)
	if channels.is_empty():
		return

	var rng := river.rng
	var fuel_gap := roundi(lerpf(max_rows_without_fuel, hard_max_rows_without_fuel, d))
	var needs_fuel := index - _last_fuel_row >= fuel_gap
	# Logo depois de uma ponte não nasce inimigo (o avião pode estar renascendo ali)
	var after_bridge := river.section_of(index) > 0 \
			and river.local_of(index) < River.NECK_ROWS + enemy_free_rows_after_bridge
	if _power_up_row >= 0 and index >= _power_up_row and not needs_fuel:
		var box: PowerUp = power_up_scene.instantiate()
		box.kind = _power_up_kind
		_spawn(box, y, channels, 20.0)
		_power_up_row = -1
	elif needs_fuel or rng.randf() < lerpf(fuel_chance, hard_fuel_chance, d):
		# Longe da margem: o avião precisa passar por cima sem raspar a asa na terra
		_spawn(fuel_depot_scene.instantiate(), y, channels, 28.0)
		_last_fuel_row = index
	elif after_bridge:
		return
	elif rng.randf() < lerpf(helicopter_chance, hard_helicopter_chance, d):
		_spawn_enemy(helicopter_scene, y, channels, d)
	elif rng.randf() < lerpf(ship_chance, hard_ship_chance, d):
		_spawn_enemy(ship_scene, y, channels, d)
	elif rng.randf() < lerpf(jet_chance, hard_jet_chance, d):
		_spawn_enemy(jet_scene, y, channels, d)  # o jato se reposiciona fora da tela sozinho
	else:
		return
	_last_spawn_row = index


func _spawn_bridge(section: int, y: float, left: float, right: float) -> void:
	var bridge: Enemy = bridge_scene.instantiate()
	bridge.position = Vector2((left + right) / 2.0, y + River.ROW_H / 2.0)
	bridge.shot_down.connect(_on_enemy_shot_down.bind(bridge))
	bridge.shot_down.connect(func(_points: int): checkpoint_section = section)
	objects.add_child(bridge)


func _spawn_enemy(scene: PackedScene, y: float, channels: Array, difficulty: float) -> void:
	var rng := river.rng
	var enemy: Enemy = scene.instantiate()
	enemy.direction = -1 if rng.randf() < 0.5 else 1
	enemy.speed *= lerpf(1.0, hard_enemy_speed_scale, difficulty)
	if not enemy.crosses_screen and rng.randf() < lerpf(sleeper_chance, hard_sleeper_chance, difficulty):
		enemy.sleeps_until_near = true
		enemy.wake_screen_y = rng.randf_range(wake_screen_y_range.x, wake_screen_y_range.y)
	_spawn(enemy, y, channels, enemy.half_width + 4.0)


## Coloca o objeto num dos canais (sorteado), a pelo menos `margin` px da terra
func _spawn(node: Node2D, y: float, channels: Array, margin: float) -> void:
	var c: Vector2 = channels[river.rng.randi_range(0, channels.size() - 1)]
	var x := (c.x + c.y) / 2.0  # canal estreito demais para a margem pedida: fica no meio
	if c.y - c.x > 2.0 * margin:
		x = river.rng.randf_range(c.x + margin, c.y - margin)
	node.position = Vector2(x, y + River.ROW_H / 2.0)
	if node is FuelDepot:
		node.connect("shot_down", _on_depot_shot_down.bind(node))
	elif node.has_signal("shot_down"):
		node.connect("shot_down", _on_enemy_shot_down.bind(node))
	objects.add_child(node)


## Um avião caiu. Com vida sobrando ele gasta uma e espera para voltar; sem vida, fica fora.
## Se o outro avião (coop) está vivo, quem caiu renasce ao lado dele; se ninguém está vivo,
## a seção recomeça para todos; se todos estão fora, fim de jogo.
func _on_player_died(p: Player) -> void:
	board_of(p).combo = 0
	if p.lives > 0:
		p.lives -= 1
		p.waiting_respawn = true
	else:
		p.is_out = true
	if not _alive_players().is_empty():
		if not p.waiting_respawn:
			return
		await get_tree().create_timer(respawn_delay).timeout
		var partners := _alive_players()
		# se o outro também caiu nesse meio-tempo, o recomeço da seção traz os dois
		if p.waiting_respawn and not partners.is_empty():
			p.waiting_respawn = false
			p.respawn(_spawn_point_near(partners[0]))
		return
	if players.all(func(o: Player) -> bool: return o.is_out):
		_game_over()
		return
	await get_tree().create_timer(respawn_delay).timeout
	restart_from_checkpoint()


func _game_over() -> void:
	is_game_over = true
	# com pontos separados não há recorde (é disputa entre os dois, não placar do time)
	if boards.size() == 1 and score > high_score:
		high_score = score
		is_new_record = true
		SaveData.save_value("records", _record_key(), high_score)
	await get_tree().create_timer(game_over_input_delay).timeout
	_can_restart = true


## Coop: onde quem caiu renasce: na altura do parceiro, no mesmo canal de água, um pouco ao
## lado dele (do lado com mais espaço).
func _spawn_point_near(partner: Player) -> Vector2:
	var pos := partner.position
	var index := int(floor((river.start_y - pos.y) / River.ROW_H))
	for c: Vector2 in river.channels_at(index):
		if pos.x >= c.x and pos.x <= c.y:
			var side := 1.0 if c.y - pos.x > pos.x - c.x else -1.0
			pos.x = clampf(pos.x + side * COOP_SPREAD * 2.0, c.x + 24.0, c.y - 24.0)
	return pos


## Seção do rio em que o jogo está (0 = começo; sobe a cada ponte passada): a do avião mais
## à frente.
func current_section() -> int:
	var y := player.position.y
	for p in players:
		y = minf(y, p.position.y)
	return river.section_of(int(floor((river.start_y - y) / River.ROW_H)))


## Recomeça logo depois da última ponte destruída (ou do início), com a seção recriada igual.
## Volta todo avião que ainda está no jogo (no coop, lado a lado).
func restart_from_checkpoint() -> void:
	for child in objects.get_children():
		child.queue_free()
	for child in get_children():
		if child is PlayerBullet:
			child.queue_free()
	var start := river.section_start_position(checkpoint_section, _player_start)
	for p in players:
		if p.is_out:
			continue
		p.waiting_respawn = false
		var spread := 0.0 if players.size() == 1 else (COOP_SPREAD if p.number == 2 else -COOP_SPREAD)
		p.respawn(start + Vector2(spread, 0))
	camera.target = player if not player.is_out else players[-1]
	camera.follow()
	river.reset_to_section(checkpoint_section)
