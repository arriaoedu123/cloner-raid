class_name Player
extends Area2D
## Avião do jogador: avança sempre para cima (a câmera acompanha), move na horizontal
## e inclina conforme a direção. Acelerar/frear muda a velocidade de avanço.

@export_group("Movimento lateral")
## Velocidade lateral máxima (px/s)
@export var side_speed := 180.0
## Aceleração/desaceleração lateral (px/s²); deixa o movimento menos "duro"
@export var side_acceleration := 1100.0
## Distância mínima das bordas da tela (px)
@export var screen_margin := 16.0

@export_group("Avanço")
## Velocidade de avanço sem apertar nada (px/s)
@export var cruise_speed := 100.0
## Velocidade segurando acelerar (px/s)
@export var max_speed := 190.0
## Velocidade segurando frear (px/s)
@export var min_speed := 50.0
## Quão rápido a velocidade de avanço muda (px/s²)
@export var forward_acceleration := 200.0

@export_group("Combustível")
## Capacidade do tanque
@export var max_fuel := 100.0
## Consumo por segundo (tanque cheio dura max_fuel / fuel_burn_rate segundos)
@export var fuel_burn_rate := 4.0
## Abaixo desta fração do tanque: fumaça no avião, barra vermelha e alerta no HUD
@export_range(0.0, 1.0) var low_fuel_ratio := 0.25

@export_group("Colisão")
## Pontos do avião (relativos ao centro) que não podem tocar a terra
@export var hull_points: PackedVector2Array = [
	Vector2(0, -14), Vector2(-12, 2), Vector2(12, 2), Vector2(-6, 12), Vector2(6, 12),
]

@export_group("Tiro")
## Cena instanciada a cada disparo
@export var bullet_scene: PackedScene
## Tempo mínimo entre tiros (s); segurar o botão dispara em sequência
@export var fire_cooldown := 0.18

@export_group("Power-ups")
## Duração do tiro duplo (s); a cadência continua a mesma, só saem dois tiros lado a lado
@export var double_shot_time := 10.0
## Distância de cada tiro ao centro do nariz no tiro duplo (px)
@export var double_shot_spread := 5.0
## Duração do escudo (s). Ele absorve UMA batida em inimigo; não protege da margem nem da
## falta de combustível
@export var shield_time := 15.0
## Tempo piscando (invencível) depois de o escudo absorver uma batida, para não bater de novo
@export var shield_break_invulnerability := 1.0

@export_group("Efeitos")
## Cena criada no lugar do avião quando ele é destruído
@export var explosion_scene: PackedScene
## Tempo piscando após renascer, em que inimigos não destroem o avião (s)
@export var respawn_invulnerability := 2.0

## Emitido quando o avião é destruído
signal died
## Emitido a cada frame em que um posto põe combustível no avião
signal refueled
## Emitido ao pegar uma caixa de power-up
signal power_up_taken(kind: PowerUp.Kind)
## Emitido a cada disparo, com o deslocamento x de cada tiro (online: o outro computador repete)
signal fired(offsets: Array)

## Jogador dono do avião: 1 (amarelo) ou 2 (lilás, só no coop). Ver setup_player().
var number := 1
## Prefixo das ações lidas: "" no modo de 1 jogador (todas as teclas e controles); no coop
## "p1_"/"p2_" (ver Controls.setup_coop_actions)
var input_prefix := ""
## Aviões reserva deste jogador
var lives := 0
## Caiu sem vida sobrando: fica fora até o fim da partida (no coop o outro continua)
var is_out := false
## Caiu e já gastou uma vida: espera a hora de renascer
var waiting_respawn := false
## Online: avião pilotado pelo OUTRO computador. Não lê comandos nem testa margem/combustível;
## posição, animação e power-ups chegam pela rede (apply_remote_state).
var remote := false

var is_dead := false
var invulnerable_timer := 0.0
var velocity_x := 0.0
var forward_speed := 0.0
var fire_timer := 0.0
var fuel := 0.0
## Tempo que ainda resta de tiro duplo (0 = desligado). Perde ao cair.
var double_shot_timer := 0.0
## Tempo que ainda resta de escudo (0 = sem escudo). Perde ao cair ou ao absorver uma batida.
var shield_timer := 0.0
var river: River  # opcional: sem rio na cena, não há colisão com margem

var _refuel_beep_timer := 0.0
var _low_fuel_alert_timer := 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var muzzle: Marker2D = $Muzzle
@onready var engine_trail: CPUParticles2D = $EngineTrail
@onready var low_fuel_smoke: CPUParticles2D = $LowFuelSmoke
@onready var shield_ring: AnimatedSprite2D = $ShieldRing


func _ready() -> void:
	forward_speed = cruise_speed
	fuel = max_fuel
	river = get_tree().get_first_node_in_group("river") as River


## Coop: define o jogador (1 ou 2). O jogador 2 lê as ações "p2_*" e usa os sprites lilás
## (mesmos desenhos com "_p2" no nome, gerados por tools/sprites/player.py).
func setup_player(player_number: int, coop: bool) -> void:
	number = player_number
	input_prefix = "p%d_" % number if coop else ""
	if number == 2:
		var frames: SpriteFrames = sprite.sprite_frames.duplicate()  # não muda o do jogador 1
		for anim in frames.get_animation_names():
			for i in frames.get_frame_count(anim):
				var path := frames.get_frame_texture(anim, i).resource_path
				frames.set_frame(anim, i, load(path.replace(".png", "_p2.png")))
		sprite.sprite_frames = frames


## Nome da ação deste jogador (ex.: "shoot" vira "p2_shoot" no coop).
func _action(base: String) -> StringName:
	return StringName(input_prefix + base)


## Eixo de comando (-1..1). Online com o menu de pausa aberto: 0 (o avião segue sem comandos).
func _axis(negative: String, positive: String) -> float:
	if Game.input_blocked:
		return 0.0
	return Input.get_axis(_action(negative), _action(positive))


## Online: estado do avião remoto, mandado pelo computador dono dele.
func apply_remote_state(pos: Vector2, anim: StringName, blink_visible: bool, shield: float,
		double_shot: float, fuel_left: float, speed: float) -> void:
	position = pos
	forward_speed = speed  # os tiros dele somam essa velocidade
	if sprite.animation != anim:
		sprite.play(anim)
	sprite.visible = blink_visible
	shield_timer = shield
	double_shot_timer = double_shot
	fuel = fuel_left


## Online: o avião remoto atirou no outro computador; aqui só aparecem os tiros.
func fire_remote(offsets: Array) -> void:
	_spawn_bullets(offsets)


func _physics_process(delta: float) -> void:
	if remote:
		# só a parte visual: rastro do motor, fumaça e anel do escudo
		_update_exhaust()
		shield_ring.visible = shield_timer > 3.0 or (shield_timer > 0.0 and int(shield_timer * 8.0) % 2 == 0)
		return
	_move_forward(delta)
	_move_sideways(delta)

	fuel = maxf(fuel - fuel_burn_rate * delta, 0.0)
	if fuel <= 0.0 or _touching_land():
		die()
		return
	_update_exhaust()
	_update_fuel_sounds(delta)

	double_shot_timer = maxf(double_shot_timer - delta, 0.0)
	shield_timer = maxf(shield_timer - delta, 0.0)
	# anel do escudo; pisca nos últimos 3 s para avisar que vai acabar
	shield_ring.visible = shield_timer > 3.0 or (shield_timer > 0.0 and int(shield_timer * 8.0) % 2 == 0)
	fire_timer -= delta
	if not Game.input_blocked and Input.is_action_pressed(_action("shoot")) and fire_timer <= 0.0:
		_shoot()

	if invulnerable_timer > 0.0:
		invulnerable_timer -= delta
		# pisca a cada 0,1 s enquanto invencível
		sprite.visible = invulnerable_timer <= 0.0 or int(invulnerable_timer * 10.0) % 2 == 0


func add_fuel(amount: float) -> void:
	fuel = minf(fuel + amount, max_fuel)
	refueled.emit()
	# bipe do reabastecimento, mais agudo conforme o tanque enche
	if _refuel_beep_timer <= 0.0:
		_refuel_beep_timer = 0.1
		Sfx.play("refuel", -8.0, 0.8 + 0.7 * fuel / max_fuel)


func _update_fuel_sounds(delta: float) -> void:
	_refuel_beep_timer -= delta
	if is_low_fuel():
		_low_fuel_alert_timer -= delta
		if _low_fuel_alert_timer <= 0.0:
			_low_fuel_alert_timer = 1.2
			Sfx.play("low_fuel", -6.0)
	else:
		_low_fuel_alert_timer = 0.0  # toca na hora assim que o combustível ficar baixo


## Chamado pela caixa de power-up ao passar por cima dela.
func give_power_up(kind: PowerUp.Kind) -> void:
	match kind:
		PowerUp.Kind.DOUBLE_SHOT:
			double_shot_timer = double_shot_time
		PowerUp.Kind.SHIELD:
			shield_timer = shield_time
		PowerUp.Kind.LIFE:
			pass  # as vidas ficam no Game, que soma ao receber power_up_taken
	power_up_taken.emit(kind)


func has_shield() -> bool:
	return shield_timer > 0.0


## Um inimigo bateu no avião com escudo: o escudo some no lugar do avião.
func break_shield() -> void:
	shield_timer = 0.0
	shield_ring.hide()
	invulnerable_timer = shield_break_invulnerability
	Sfx.play("shield_break")
	Effects.shake(self, 3.0, 0.25, self)


func is_invulnerable() -> bool:
	return invulnerable_timer > 0.0


func is_low_fuel() -> bool:
	return fuel / max_fuel <= low_fuel_ratio


## Rastro do motor com chama maior acelerando; fumaça com pouco combustível.
func _update_exhaust() -> void:
	engine_trail.emitting = true
	engine_trail.scale_amount_max = 2.0 if forward_speed > cruise_speed + 10.0 else 1.0
	low_fuel_smoke.emitting = is_low_fuel()


## Traz o avião de volta em `pos` com tanque cheio e alguns segundos de invencibilidade.
func respawn(pos: Vector2) -> void:
	position = pos
	is_dead = false
	velocity_x = 0.0
	forward_speed = cruise_speed
	fuel = max_fuel
	fire_timer = 0.0
	double_shot_timer = 0.0  # power-ups se perdem ao cair
	shield_timer = 0.0
	shield_ring.hide()
	invulnerable_timer = respawn_invulnerability
	sprite.play(&"center")
	engine_trail.restart()  # sem fumaça "voando" do lugar da queda até aqui
	show()
	set_deferred("monitorable", true)
	set_deferred("monitoring", true)
	set_physics_process(true)


func die() -> void:
	if is_dead:
		return
	is_dead = true
	double_shot_timer = 0.0
	shield_timer = 0.0
	set_physics_process(false)
	engine_trail.emitting = false
	low_fuel_smoke.emitting = false
	Sfx.play("explosion_big")
	hide()
	# Desliga a colisão para nada mais "bater" no avião destruído
	set_deferred("monitorable", false)
	set_deferred("monitoring", false)
	Effects.spawn(explosion_scene, global_position, get_parent())
	Effects.shake(self, 6.0, 0.4, self)
	Effects.hit_stop(self, 0.12)
	died.emit()


func _touching_land() -> bool:
	if river == null:
		return false
	for p in hull_points:
		if not river.is_water(global_position + p):
			return true
	return false


func _move_forward(delta: float) -> void:
	var throttle := _axis("slow_down", "speed_up")
	var target := cruise_speed
	if throttle > 0.0:
		target = lerpf(cruise_speed, max_speed, throttle)
	elif throttle < 0.0:
		target = lerpf(cruise_speed, min_speed, -throttle)

	forward_speed = move_toward(forward_speed, target, forward_acceleration * delta)
	position.y -= forward_speed * delta


func _move_sideways(delta: float) -> void:
	var direction := _axis("move_left", "move_right")

	velocity_x = move_toward(velocity_x, direction * side_speed, side_acceleration * delta)
	position.x += velocity_x * delta

	# A câmera não se move na horizontal, então x do mundo = x da tela
	var screen_width := get_viewport_rect().size.x
	position.x = clampf(position.x, screen_margin, screen_width - screen_margin)

	_update_animation(direction)


func _shoot() -> void:
	fire_timer = fire_cooldown
	var offsets := [0.0]
	if double_shot_timer > 0.0:
		offsets = [-double_shot_spread, double_shot_spread]
	_spawn_bullets(offsets)
	fired.emit(offsets)


func _spawn_bullets(offsets: Array) -> void:
	for dx: float in offsets:
		var bullet: PlayerBullet = bullet_scene.instantiate()
		bullet.global_position = muzzle.global_position + Vector2(dx, 0)
		bullet.shooter = self  # para os pontos irem para quem atirou (coop com pontos separados)
		# Soma a velocidade do avião, para o tiro sempre se afastar na mesma velocidade na tela
		bullet.speed += forward_speed
		# O tiro vai para o mesmo nível do avião, para não acompanhar o movimento dele
		get_parent().add_child(bullet)
	Sfx.play("shoot", -8.0, 1.0, 0.06)


func _update_animation(direction: float) -> void:
	var anim := &"center"
	if direction < 0.0:
		anim = &"left"
	elif direction > 0.0:
		anim = &"right"

	if sprite.animation != anim:
		sprite.play(anim)
