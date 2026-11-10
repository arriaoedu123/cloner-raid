class_name Game
extends Node2D
## Cena principal: coloca inimigos, postos e pontes nas linhas novas do rio,
## conta pontos e vidas, recomeça da última ponte destruída e controla o fim de jogo.
##
## Todo sorteio de objetos usa `river.rng` (re-semeado a cada seção do rio), para que
## recomeçar uma seção recrie exatamente os mesmos objetos nos mesmos lugares.

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

var score := 0
var lives := 0  # aviões reserva
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
## Abates seguidos e quanto tempo falta para o combo acabar
var combo := 0
var combo_timer := 0.0

var _next_bonus := 0  # pontuação em que vem a próxima vida extra
var _bonus_gap := 0   # intervalo até ela (cresce bonus_life_step a cada vida)
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
	lives = starting_lives
	_bonus_gap = bonus_life_every
	_next_bonus = bonus_life_every
	high_score = SaveData.load_value("records", "high_score", 0)
	_player_start = player.position
	river.row_created.connect(_on_river_row_created)
	player.died.connect(_on_player_died)
	intro_active = not SaveData.load_value("progress", "intro_done", false)
	if intro_active:
		player.fuel = player.max_fuel * intro_start_fuel
		player.refueled.connect(_end_intro, CONNECT_ONE_SHOT)
	for kind in PowerUp.Kind.values():
		_power_up_hints[kind] = not SaveData.load_value("progress", _power_up_key(kind), false)
	player.power_up_taken.connect(_on_power_up_taken)


## Primeiro reabastecimento: o jogador aprendeu, a introdução não volta mais.
func _end_intro() -> void:
	intro_active = false
	SaveData.save_value("progress", "intro_done", true)


## Se a caixa desse tipo ainda mostra a dica com o nome do poder.
func power_up_hint(kind: PowerUp.Kind) -> bool:
	return _power_up_hints.get(kind, false)


## Pegou um power-up: a caixa de vida dá +1 avião reserva, e a dica daquele tipo não volta mais.
func _on_power_up_taken(kind: PowerUp.Kind) -> void:
	if kind == PowerUp.Kind.LIFE:
		lives += 1
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
	if combo > 0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo = 0


## Multiplicador atual: x1, depois +1 a cada `combo_per_level` abates seguidos.
func multiplier() -> int:
	return mini(1 + combo / combo_per_level, max_multiplier)


## Inimigo (ou ponte) derrubado: soma ao combo e ganha os pontos multiplicados.
func _on_enemy_shot_down(points: int) -> void:
	combo += 1
	combo_timer = combo_window
	add_score(points * multiplier())


## Posto destruído: dá os poucos pontos dele, mas quebra o combo.
func _on_depot_shot_down(points: int) -> void:
	combo = 0
	add_score(points)


func add_score(points: int) -> void:
	score += points
	while score >= _next_bonus:
		lives += 1
		Sfx.play("extra_life")
		_bonus_gap += bonus_life_step
		_next_bonus += _bonus_gap


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
	bridge.shot_down.connect(_on_enemy_shot_down)
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
		node.connect("shot_down", _on_depot_shot_down)
	elif node.has_signal("shot_down"):
		node.connect("shot_down", _on_enemy_shot_down)
	objects.add_child(node)


func _on_player_died() -> void:
	combo = 0
	if lives <= 0:
		is_game_over = true
		if score > high_score:
			high_score = score
			is_new_record = true
			SaveData.save_value("records", "high_score", high_score)
		await get_tree().create_timer(game_over_input_delay).timeout
		_can_restart = true
		return

	lives -= 1
	await get_tree().create_timer(respawn_delay).timeout
	restart_from_checkpoint()


## Seção do rio em que o avião está agora (0 = começo; sobe a cada ponte passada).
func current_section() -> int:
	return river.section_of(int(floor((river.start_y - player.position.y) / River.ROW_H)))


## Recomeça logo depois da última ponte destruída (ou do início), com a seção recriada igual.
func restart_from_checkpoint() -> void:
	for child in objects.get_children():
		child.queue_free()
	for child in get_children():
		if child is PlayerBullet:
			child.queue_free()
	player.respawn(river.section_start_position(checkpoint_section, _player_start))
	camera.follow()
	river.reset_to_section(checkpoint_section)
