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
## Coop online (ver online.gd): cada computador pilota o próprio avião (anfitrião = J1,
## amigo = J2); o outro é "remoto". Só o anfitrião decide acertos, pontos, vidas, quedas,
## recomeço e fim de jogo, e avisa o amigo por RPC (funções _net_*).
static var online := false
## Online com o menu de pausa aberto: o jogo segue, mas o avião deste computador não lê comandos
static var input_blocked := false
## Online: altura da tela do amigo (chega junto com o avião dele, em _net_player); 0 = sem amigo
static var partner_view_h := 0.0


## Online e este computador NÃO é o anfitrião (não decide acertos nem pontos).
static func is_online_client() -> bool:
	return online and not (Engine.get_main_loop() as SceneTree).get_multiplayer().is_server()


## Telas de alturas diferentes (16:9 = 360, 16:10 = 400, 4:3 = 480) no online: o rio é gerado
## e o tiro voa até o topo da tela MAIS ALTA dos dois, então o que um vê existe nos dois e o
## tiro chega igual. Fora do online é a própria tela.
static func view_h_max(node: CanvasItem) -> float:
	return maxf(node.get_viewport_rect().size.y, partner_view_h)


## ... e o avião da frente e o despertar dos inimigos usam a tela MAIS BAIXA (os dois veem e
## decidem igual). Fora do online é a própria tela.
static func view_h_min(node: CanvasItem) -> float:
	var own := node.get_viewport_rect().size.y
	return minf(own, partner_view_h) if partner_view_h > 0.0 else own

const PLAYER_SCENE := preload("res://scenes/player.tscn")
## Coop: distância de cada avião ao centro ao (re)começar uma seção (px)
const COOP_SPREAD := 30.0
## Renascer ao lado do outro: linhas à frente que precisam estar livres (~0,6 s em cruzeiro),
## folga mínima da terra nelas (ponta da asa 12 px + tempo de reagir) e quanto tempo, no
## máximo, esperar o rio abrir um lugar assim (gargalo em curva) antes de renascer mesmo assim
## Campo de minas: (x em px, linhas abaixo) de cada mina, em ordem (2 minas = as 2 primeiras).
## Separadas por ~16 px: menos que o raio da explosão (40), então explodem em cadeia.
const MINE_FIELD := [Vector2(0, 0), Vector2(-14, 3), Vector2(14, 3)]
## Torre: caminho do tiro que precisa estar livre embaixo dela (px de comprimento e de largura)
const TURRET_LANE := 96.0
const TURRET_LANE_W := 4
const RESPAWN_LOOKAHEAD_ROWS := 8
const RESPAWN_CLEARANCE := 20.0
const RESPAWN_MAX_WAIT := 3.0
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
@export var speedboat_scene: PackedScene
## Chance de surgir uma lancha (rápida, 1 tiro) em cada linha liberada do rio (0–1)
@export_range(0.0, 1.0) var speedboat_chance := 0.04
## Primeira seção com lancha
@export var speedboat_first_section := 3
@export var mine_scene: PackedScene
## Chance de surgir um campo de minas em cada linha liberada do rio (0–1)
@export_range(0.0, 1.0) var mine_chance := 0.03
## Primeira seção com minas
@export var mine_first_section := 4
## Minas por campo no começo (na dificuldade máxima: hard_mines_per_field)
@export var mines_per_field := 2
@export var submarine_scene: PackedScene
## Chance de surgir um submarino (mergulha e sobe) em cada linha liberada do rio (0–1)
@export_range(0.0, 1.0) var submarine_chance := 0.03
## Primeira seção com submarino
@export var submarine_first_section := 6
@export var hovercraft_scene: PackedScene
## Chance de surgir um aerobarco (atravessa o rio por cima da terra) em cada linha liberada (0–1)
@export_range(0.0, 1.0) var hovercraft_chance := 0.03
## Primeira seção com aerobarco
@export var hovercraft_first_section := 5
@export var turret_scene: PackedScene
## Chance de sortear uma torre (atira no avião) em cada linha liberada do rio (0–1). Cerca de
## metade não nasce (sem caminho livre para o tiro, numa curva), por isso o valor é o dobro.
@export_range(0.0, 1.0) var turret_chance := 0.05
## Primeira seção com torre
@export var turret_first_section := 8
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
@export_range(0.0, 1.0) var hard_speedboat_chance := 0.07
@export_range(0.0, 1.0) var hard_mine_chance := 0.06
@export var hard_mines_per_field := 3
@export_range(0.0, 1.0) var hard_submarine_chance := 0.05
@export_range(0.0, 1.0) var hard_hovercraft_chance := 0.05
@export_range(0.0, 1.0) var hard_turret_chance := 0.09
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
## Opção escolhida no fim de jogo (índice em game_over_items())
var game_over_selected := 0
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
	partner_view_h = 0.0  # fica valendo a do amigo quando o avião dele chegar
	if online:
		river.base_seed = Online.seed  # o mesmo rio (e os mesmos objetos) nos dois computadores
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
## e, com pontos separados, o 2º placar. Online: cada computador pilota o seu com qualquer
## teclado/controle (sem ações p1_/p2_) e o do outro fica "remoto".
func _add_second_player() -> void:
	if not online:
		Controls.setup_coop_actions(coop_devices)
	var p2: Player = PLAYER_SCENE.instantiate()
	p2.name = "Player2"
	add_child(p2)
	move_child(p2, player.get_index() + 1)  # processa antes da câmera, como o jogador 1
	player.setup_player(1, not online)
	p2.setup_player(2, not online)
	player.position = _player_start + Vector2(-COOP_SPREAD, 0)
	p2.position = _player_start + Vector2(COOP_SPREAD, 0)
	players.append(p2)
	if online:
		var mine := 1 if multiplayer.is_server() else 2
		player.remote = mine != 1
		p2.remote = mine != 2
		for p in players:
			if not p.remote:
				p.fired.connect(func(offsets: Array): _net_fire.rpc(p.number, offsets))
	var shared := Online.shared_score if online else Settings.coop_shared_score
	if not shared:
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


func _physics_process(delta: float) -> void:
	if players.size() < 2:
		return
	if online:
		_send_net_state(delta)
	var alive := _alive_players()
	if alive.is_empty():
		return
	# a câmera segue o avião de trás; o da frente não passa do topo da tela
	var rear := alive[0]
	for p in alive:
		if p.position.y > rear.position.y:
			rear = p
	camera.target = rear
	var top := camera.get_screen_center_position().y - view_h_min(self) / 2.0 + COOP_TOP_MARGIN
	for p in alive:
		if not p.remote:  # o remoto é segurado no computador dele
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
		if is_online_client():
			_net_life.rpc_id(1, p.number)  # as vidas são contadas pelo anfitrião
		else:
			p.lives += 1
	if power_up_hint(kind):
		_power_up_hints[kind] = false
		SaveData.save_value("progress", _power_up_key(kind), true)


## Chave no save.cfg (seção "progress"), ex.: "power_up_shield_seen".
## Opções do fim de jogo (desenhadas pelo HUD). O convidado online só pode sair: quem
## recomeça é o anfitrião.
func game_over_items() -> Array[String]:
	if is_online_client():
		return ["MENU PRINCIPAL"]
	return ["JOGAR DE NOVO", "MENU PRINCIPAL"]


## Fim de jogo: ↑/↓ escolhem, tiro/Enter confirmam (JOGAR DE NOVO já vem escolhido, então o
## tiro recomeça direto como antes); Esc/Start voltam ao título.
func _process_game_over_menu() -> void:
	var items := game_over_items()
	game_over_selected = mini(game_over_selected, items.size() - 1)
	if Input.is_action_just_pressed("toggle_fullscreen"):
		return  # Alt+Enter não pode também confirmar a opção
	if items.size() > 1 and (InputHint.menu_pressed(&"speed_up", &"ui_up")
			or InputHint.menu_pressed(&"slow_down", &"ui_down")):
		game_over_selected = 1 - game_over_selected
		Sfx.play("ui_move", -6.0)
	elif InputHint.menu_pressed(&"shoot", &"ui_accept"):
		Sfx.play("ui_select", -4.0)
		if items[game_over_selected] == "MENU PRINCIPAL":
			_leave_to_title()
		elif not online:
			get_tree().reload_current_scene()
		else:  # online: o anfitrião recomeça para os dois (rio novo)
			Online.node()._start_match.rpc(randi(), Online.shared_score)
	elif Input.is_action_just_pressed("pause") or Input.is_action_just_pressed("ui_cancel"):
		_leave_to_title()


func _leave_to_title() -> void:
	if online:
		Online.leave()  # o outro recebe "saiu da partida" e volta ao título também
	get_tree().change_scene_to_file("res://scenes/title.tscn")


static func _power_up_key(kind: PowerUp.Kind) -> String:
	return "power_up_%s_seen" % PowerUp.Kind.keys()[kind].to_lower()


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("toggle_fullscreen"):
		Settings.toggle_fullscreen()
	if _can_restart:
		_process_game_over_menu()
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
	# os novos vêm depois (só ocupam linhas que ficariam vazias) e só a partir da sua seção;
	# antes dela nem sorteiam, então as seções do começo saem iguais
	elif river.section_of(index) >= speedboat_first_section \
			and rng.randf() < lerpf(speedboat_chance, hard_speedboat_chance, d):
		_spawn_enemy(speedboat_scene, y, channels, d)
	elif river.section_of(index) >= mine_first_section \
			and rng.randf() < lerpf(mine_chance, hard_mine_chance, d):
		_spawn_mine_field(y, channels, d)
	elif river.section_of(index) >= submarine_first_section \
			and rng.randf() < lerpf(submarine_chance, hard_submarine_chance, d):
		_spawn_enemy(submarine_scene, y, channels, d)
	elif river.section_of(index) >= hovercraft_first_section \
			and rng.randf() < lerpf(hovercraft_chance, hard_hovercraft_chance, d):
		_spawn_hovercraft(y, left, right, d)
	elif river.section_of(index) >= turret_first_section \
			and rng.randf() < lerpf(turret_chance, hard_turret_chance, d):
		_spawn_turret(y, left, right)
	else:
		return
	_last_spawn_row = index


## Torre: plataforma de concreto construída na margem (lado sorteado), com o centro na linha
## da margem: metade na terra, metade na água. Só a metade sobre a água leva tiro (o tiro do
## jogador para na terra), então ela só nasce com caminho livre para o tiro (_turret_lane_free).
## Atira sozinha (nó Cannon).
func _spawn_turret(y: float, left: float, right: float) -> void:
	var on_left := river.rng.randf() < 0.5
	var x := left if on_left else right
	if _turret_lane_free(Vector2(x, y + River.ROW_H / 2.0), 1.0 if on_left else -1.0):
		_add_object(turret_scene.instantiate(), x, y)


## Tem uma faixa de água de TURRET_LANE_W px de largura, embaixo da metade da torre que fica na
## água (`side` = para que lado é a água), livre por TURRET_LANE px? Numa curva a margem logo
## abaixo avança sobre ela e o tiro bateria na terra (medido: ~metade das torres ficava assim).
func _turret_lane_free(center: Vector2, side: float) -> bool:
	var run := 0
	for dx in range(1, 12):
		var lane_x := center.x + side * dx
		var free := true
		var lane_y := center.y + 11.0  # borda de baixo da plataforma
		while lane_y <= center.y + 11.0 + TURRET_LANE:
			if not river.is_water(Vector2(lane_x, lane_y)):
				free = false
				break
			lane_y += River.ROW_H / 2.0
		run = run + 1 if free else 0
		if run >= TURRET_LANE_W:
			return true
	return false


## Aerobarco: parado na terra ao lado do rio (lado sorteado), virado para a água. Quando o
## avião chega perto (wake_screen_y sorteado, como os dorminhocos) atravessa de margem a
## margem por cima de tudo. O tiro para na terra: só dá para acertá-lo sobre a água.
func _spawn_hovercraft(y: float, left: float, right: float, difficulty: float) -> void:
	var rng := river.rng
	var hover: Enemy = hovercraft_scene.instantiate()
	hover.direction = 1 if rng.randf() < 0.5 else -1
	hover.speed *= lerpf(1.0, hard_enemy_speed_scale, difficulty)
	hover.wake_screen_y = rng.randf_range(wake_screen_y_range.x, wake_screen_y_range.y)
	var gap := hover.half_width + 6.0  # inteiro fora da água
	_add_object(hover, left - gap if hover.direction > 0 else right + gap, y)


## Campo de minas: 2 a 3 minas juntas em triângulo (MINE_FIELD), na linha sorteada e 3 linhas
## abaixo (já geradas: dá para conferir a água). Um tiro numa explode o campo todo em cadeia.
## Mina que cairia em terra (curva) não nasce.
func _spawn_mine_field(y: float, channels: Array, difficulty: float) -> void:
	var count := roundi(lerpf(mines_per_field, hard_mines_per_field, difficulty))
	var c: Vector2 = channels[river.rng.randi_range(0, channels.size() - 1)]
	var margin := 24.0  # meio campo (14) + meia mina (8) + folga
	var x := (c.x + c.y) / 2.0
	if c.y - c.x > 2.0 * margin:
		x = river.rng.randf_range(c.x + margin, c.y - margin)
	for i in mini(count, MINE_FIELD.size()):
		var spot: Vector2 = MINE_FIELD[i]
		var row_y := y + spot.y * River.ROW_H
		var center := Vector2(x + spot.x, row_y + River.ROW_H / 2.0)
		if river.is_water(center + Vector2(-9, 0)) and river.is_water(center + Vector2(9, 0)):
			_add_object(mine_scene.instantiate(), center.x, row_y, "m%d" % i)  # 2 minas na mesma linha


func _spawn_bridge(section: int, y: float, left: float, right: float) -> void:
	var bridge: Enemy = bridge_scene.instantiate()
	bridge.position = Vector2((left + right) / 2.0, y + River.ROW_H / 2.0)
	bridge.name = "bridge%d" % section  # mesmo nome nos dois computadores (online)
	if _gone.has(String(bridge.name)):  # o outro computador já destruiu
		bridge.free()
		return
	bridge.shot_down.connect(_on_enemy_shot_down.bind(bridge))
	bridge.shot_down.connect(func(_points: int): checkpoint_section = section)
	bridge.destroyed.connect(_on_object_destroyed.bind(bridge, true))
	bridge.hit_taken.connect(_on_object_hit.bind(bridge))
	objects.add_child(bridge)


func _spawn_enemy(scene: PackedScene, y: float, channels: Array, difficulty: float) -> void:
	var rng := river.rng
	var enemy: Enemy = scene.instantiate()
	enemy.direction = -1 if rng.randf() < 0.5 else 1
	enemy.speed *= lerpf(1.0, hard_enemy_speed_scale, difficulty)
	if not enemy.crosses_screen and rng.randf() < lerpf(sleeper_chance, hard_sleeper_chance, difficulty):
		enemy.sleeps_until_near = true
		enemy.wake_screen_y = rng.randf_range(wake_screen_y_range.x, wake_screen_y_range.y)
	if enemy.dives:  # cada submarino começa num ponto diferente do ciclo
		enemy.dive_t = rng.randf() * (enemy.surface_time + enemy.dive_time * 2.0 + enemy.under_time)
	_spawn(enemy, y, channels, enemy.half_width + 4.0)


## Coloca o objeto num dos canais (sorteado), a pelo menos `margin` px da terra
func _spawn(node: Node2D, y: float, channels: Array, margin: float) -> void:
	var c: Vector2 = channels[river.rng.randi_range(0, channels.size() - 1)]
	var x := (c.x + c.y) / 2.0  # canal estreito demais para a margem pedida: fica no meio
	if c.y - c.x > 2.0 * margin:
		x = river.rng.randf_range(c.x + margin, c.y - margin)
	_add_object(node, x, y)


## Põe o objeto no centro da linha do rio que começa em `y`, no x dado, e liga os sinais.
## `suffix` diferencia objetos na mesma linha (minas do campo): sem ele o Godot dá um nome
## automático ao repetido, diferente em cada computador, e o online perde a mina de vista.
func _add_object(node: Node2D, x: float, y: float, suffix := "") -> void:
	node.position = Vector2(x, y + River.ROW_H / 2.0)
	# nome pela linha do rio: igual nos dois computadores, para o online dizer "o objeto tal
	# explodiu"
	node.name = "o%d%s" % [roundi(-y / River.ROW_H), suffix]
	if _gone.has(String(node.name)):  # o outro computador já destruiu (os sorteios acima continuam iguais)
		node.free()
		return
	if node is FuelDepot:
		node.connect("shot_down", _on_depot_shot_down.bind(node))
	elif node.has_signal("shot_down"):
		node.connect("shot_down", _on_enemy_shot_down.bind(node))
	if node is PowerUp:
		node.destroyed.connect(func(exploded: bool): _on_object_destroyed(node, exploded))
	elif node.has_signal("destroyed"):
		node.connect("destroyed", _on_object_destroyed.bind(node, true))
	if node is Enemy:
		node.hit_taken.connect(_on_object_hit.bind(node))
	objects.add_child(node)


## Online: o anfitrião acertou um tiro sem derrubar: o amigo vê o brilho branco também.
func _on_object_hit(node: Node) -> void:
	if online:
		_net_hit.rpc(node.name)


## Online: um objeto sumiu aqui (tiro decidido pelo anfitrião, batida ou caixa pega pelo
## avião deste computador): o outro computador repete. O que chegou pela rede não volta.
func _on_object_destroyed(node: Node, exploded: bool) -> void:
	if online and not node.has_meta("from_network"):
		_net_destroy.rpc(node.name, exploded)


## Um avião caiu. Com vida sobrando ele gasta uma e espera para voltar; sem vida, fica fora.
## Se o outro avião (coop) está vivo, quem caiu renasce ao lado dele; se ninguém está vivo,
## a seção recomeça para todos; se todos estão fora, fim de jogo.
func _on_player_died(p: Player) -> void:
	if online:
		if not multiplayer.is_server():
			if not p.remote:
				_net_died.rpc_id(1, p.number)  # o anfitrião decide o que acontece
			return
		if not p.remote:
			_net_died.rpc(p.number)  # o amigo vê a explosão do jogador 1
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
		# se o outro também caiu nesse meio-tempo, o recomeço da seção traz os dois (sai do laço)
		var waited := 0.0
		while p.waiting_respawn and not _alive_players().is_empty():
			var spot := _spawn_point_near(_alive_players()[0])
			# sem lugar com folga (o outro num gargalo em curva): espera o rio abrir
			if _spawn_clearance(spot.x, _row_of(spot.y)) < RESPAWN_CLEARANCE and waited < RESPAWN_MAX_WAIT:
				await get_tree().create_timer(0.25).timeout
				waited += 0.25
				continue
			p.waiting_respawn = false
			if online:
				_net_respawn.rpc(p.number, spot)
			else:
				p.respawn(spot)
		return
	if players.all(func(o: Player) -> bool: return o.is_out):
		_game_over()
		return
	await get_tree().create_timer(respawn_delay).timeout
	if online:
		_net_restart.rpc(checkpoint_section, players.map(func(o: Player) -> bool: return o.is_out))
	else:
		restart_from_checkpoint()


func _game_over() -> void:
	if online and multiplayer.is_server():
		_net_game_over.rpc()
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
## Na mesma altura do `partner`, no x com MAIS folga da terra nas próximas linhas (o rio pode
## virar ou estreitar logo à frente: nascer colado na margem de uma curva é cair na hora).
## Folga acima de 40 px já basta; entre os lugares assim, o mais perto de 60 px do outro.
## Nunca em cima dele (menos de 24 px).
func _spawn_point_near(partner: Player) -> Vector2:
	var pos := partner.position
	var index := _row_of(pos.y)
	var best_score := -INF
	for x in range(8, 633, 2):
		var dx := absf(x - partner.position.x)
		if dx < 24.0:
			continue
		var score := minf(_spawn_clearance(float(x), index), 40.0) - absf(dx - COOP_SPREAD * 2.0) * 0.05
		if score > best_score:
			best_score = score
			pos.x = x
	return pos


## Menor distância de `x` até a terra da cauda do avião (2 linhas atrás) até
## RESPAWN_LOOKAHEAD_ROWS linhas à frente; negativa = cai em terra em alguma delas.
func _spawn_clearance(x: float, index: int) -> float:
	var worst := INF
	for i in range(index - 2, index + RESPAWN_LOOKAHEAD_ROWS + 1):
		var row_clear := -1.0
		for c: Vector2 in river.channels_at(i):
			if x >= c.x and x <= c.y:
				row_clear = minf(x - c.x, c.y - x)
		worst = minf(worst, row_clear)
	return worst


func _row_of(y: float) -> int:
	return int(floor((river.start_y - y) / River.ROW_H))


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
		objects.remove_child(child)  # sai já: os objetos recriados reusam os mesmos nomes
		child.queue_free()
	_gone.clear()  # a seção volta inteira nos dois computadores
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


# --- Online: mensagens entre os dois computadores --------------------------------------------
# Cada computador manda o estado do PRÓPRIO avião; o anfitrião manda placar, vidas e decide
# quedas, renascimentos, recomeço e fim de jogo. Objetos são achados pelo nome (igual nos dois).

var _net_state_timer := 0.0
## Objetos que o outro computador destruiu antes de eles nascerem aqui (nome -> true)
var _gone := {}
## Sinal de vida: cada computador manda um `_net_ping` a cada NET_PING_INTERVAL. Sem ouvir o
## outro por NET_TIMEOUT_MS, a conexão é dada como perdida. Só o aviso da rede demora 6–7 s na
## rede local (medido, matando o processo do outro) e pode demorar mais na Steam; nesse tempo o
## avião do outro fica congelado. Antes do 1º sinal a folga é NET_FIRST_TIMEOUT_MS (um
## computador pode demorar mais para carregar a partida).
const NET_PING_INTERVAL := 0.5
const NET_TIMEOUT_MS := 4000
const NET_FIRST_TIMEOUT_MS := 10000
var _ping_timer := 0.0
var _last_heard_ms := 0
var _heard_once := false


## Manda o estado do avião deste computador (todo quadro) e, no anfitrião, placar e vidas
## (10 vezes por segundo).
func _send_net_state(delta: float) -> void:
	_ping_timer -= delta
	if _ping_timer <= 0.0:
		_ping_timer = NET_PING_INTERVAL
		_net_ping.rpc()
	if _last_heard_ms == 0:
		_last_heard_ms = Time.get_ticks_msec()
	var limit := NET_TIMEOUT_MS if _heard_once else NET_FIRST_TIMEOUT_MS
	if Time.get_ticks_msec() - _last_heard_ms > limit:
		_last_heard_ms = Time.get_ticks_msec() + 3600000  # avisa uma vez só
		Online.node()._back_to_title.call_deferred("A CONEXÃO CAIU")
		return
	for p in players:
		if not p.remote and not p.is_dead:
			_net_player.rpc(p.number, p.position, p.sprite.animation, p.sprite.visible,
					p.shield_timer, p.double_shot_timer, p.fuel, p.forward_speed,
					get_viewport_rect().size.y)
	if multiplayer.is_server():
		_net_state_timer -= delta
		if _net_state_timer <= 0.0:
			_net_state_timer = 0.1
			var scores := []
			var combos := []
			var timers := []
			for board in boards:
				scores.append(board.score)
				combos.append(board.combo)
				timers.append(board.combo_timer)
			# inimigos que se mexem: [nome, x, direção, acordado, ponto do mergulho] em sequência
			# (os parados, como a ponte e a mina, não precisam)
			var enemies := []
			for node in objects.get_children():
				if node is Enemy and node.speed > 0.0 and not node.is_destroyed:
					enemies.append_array([node.name, node.position.x, node.direction, node.is_awake,
							node.dive_t])
			_net_state.rpc(scores, combos, timers, players.map(func(o: Player) -> int: return o.lives),
					checkpoint_section, enemies)


## Sinal de vida do outro computador (ver NET_TIMEOUT_MS).
@rpc("any_peer", "unreliable")
func _net_ping() -> void:
	_last_heard_ms = Time.get_ticks_msec()
	_heard_once = true


@rpc("any_peer", "unreliable_ordered")
func _net_player(number: int, pos: Vector2, anim: StringName, blink_visible: bool, shield: float,
		double_shot: float, fuel_left: float, speed: float, view_h: float) -> void:
	partner_view_h = view_h  # altura da tela do amigo (pode mudar se ele redimensionar a janela)
	var p := players[number - 1]
	if p.remote and not p.is_dead:
		p.apply_remote_state(pos, anim, blink_visible, shield, double_shot, fuel_left, speed)


@rpc("authority", "unreliable_ordered")
func _net_state(scores: Array, combos: Array, timers: Array, lives_list: Array, checkpoint: int,
		enemies: Array) -> void:
	for i in boards.size():
		boards[i].score = scores[i]
		boards[i].combo = combos[i]
		boards[i].combo_timer = timers[i]
	for i in players.size():
		players[i].lives = lives_list[i]
	checkpoint_section = checkpoint
	# inimigos no mesmo lugar do anfitrião (o convidado mira onde o acerto é decidido)
	for i in range(0, enemies.size(), 5):
		var node := objects.get_node_or_null(NodePath(enemies[i]))
		if node is Enemy and not node.is_destroyed:
			node.apply_remote_state(enemies[i + 1], enemies[i + 2], enemies[i + 3], enemies[i + 4])


@rpc("any_peer", "reliable")
func _net_fire(number: int, offsets: Array) -> void:
	var p := players[number - 1]
	if p.remote and not p.is_dead:
		p.fire_remote(offsets)


@rpc("any_peer", "reliable")
func _net_destroy(node_name: String, exploded: bool) -> void:
	var node := objects.get_node_or_null(NodePath(node_name))
	if node == null:
		# ainda não nasceu aqui (a tela do outro chegou antes nessa linha do rio): anota, e o
		# objeto já não nasce (_spawn / _spawn_bridge)
		_gone[node_name] = true
		return
	if node.is_destroyed:
		return
	node.set_meta("from_network", true)  # não manda de volta
	if node is PowerUp:
		node.vanish(exploded)
	else:
		node.destroy()


## Torre: o anfitrião acendeu o aviso (firing = false) ou disparou, mirando na direção `dir`
## (o cano aponta para ela); o convidado repete (o projétil sai igual nos dois; a batida cada
## um decide no próprio avião).
@rpc("authority", "reliable")
func _net_cannon(node_name: String, firing: bool, dir: Vector2) -> void:
	var node := objects.get_node_or_null(NodePath(node_name))
	if node is Enemy and not node.is_destroyed:
		var cannon := node.get_node_or_null("Cannon") as Cannon
		if cannon and firing:
			cannon.fire(dir)
		elif cannon:
			cannon.warn(dir)


@rpc("authority", "reliable")
func _net_hit(node_name: String) -> void:
	var node := objects.get_node_or_null(NodePath(node_name))
	if node is Enemy and not node.is_destroyed:
		node.flash()


## Avião caiu: do amigo para o anfitrião (o anfitrião decide o resto) e do anfitrião para o
## amigo (só a explosão do jogador 1 aparecer lá).
@rpc("any_peer", "reliable")
func _net_died(number: int) -> void:
	var p := players[number - 1]
	if not p.is_dead:
		p.invulnerable_timer = 0.0
		p.die()


@rpc("authority", "call_local", "reliable")
func _net_respawn(number: int, pos: Vector2) -> void:
	var p := players[number - 1]
	p.waiting_respawn = false
	p.respawn(pos)


@rpc("authority", "call_local", "reliable")
func _net_restart(checkpoint: int, outs: Array) -> void:
	checkpoint_section = checkpoint
	for i in players.size():
		players[i].is_out = outs[i]
	restart_from_checkpoint()


@rpc("authority", "reliable")
func _net_game_over() -> void:
	is_game_over = true
	await get_tree().create_timer(game_over_input_delay).timeout
	_can_restart = true  # o amigo só pode sair; quem recomeça é o anfitrião


## O amigo pegou uma caixa de vida: o anfitrião soma (as vidas são contadas lá).
@rpc("any_peer", "reliable")
func _net_life(number: int) -> void:
	if multiplayer.is_server():
		players[number - 1].lives += 1
