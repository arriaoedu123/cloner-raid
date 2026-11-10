class_name Enemy
extends Area2D
## Inimigo que patrulha de um lado para o outro do rio (helicóptero, navio...).
## Vira ao chegar na margem, aguenta `max_hits` tiros (piscando a cada tiro)
## e destrói o avião se encostar nele. Cada tipo é uma cena com este script.

## Velocidade lateral (px/s)
@export var speed := 60.0
## Distância total da patrulha (px), centrada na posição inicial. 0 = vai de margem a margem
@export var patrol_distance := 0.0
## Direção inicial: 1 = direita, -1 = esquerda
@export_enum("Esquerda:-1", "Direita:1") var direction: int = 1
## Distância do centro até a ponta da frente (para virar antes de encostar na margem)
@export var half_width := 12.0
## Tiros necessários para destruir
@export var max_hits := 1
## Pontos ganhos ao derrubá-lo com tiros
@export var points := 100
## Cena criada quando ele é destruído
@export var explosion_scene: PackedScene
## Onde nascem as explosões (relativo ao centro); mais de uma para inimigos grandes
@export var explosion_offsets: PackedVector2Array = [Vector2.ZERO]
## Tremor de tela ao ser destruído (px) e congelamento no impacto (s)
@export var destroy_shake := 2.0
@export var destroy_hit_stop := 0.03
## Som ao ser destruído (nome em Sfx.SOUNDS)
@export var destroy_sound := "explosion_small"

@export_group("Acordar")
## Fica parado até o avião se aproximar (quando chega a `wake_screen_y` na tela)
@export var sleeps_until_near := false
## Altura na tela (px a partir do topo) em que ele acorda; o jato usa para começar a cruzar
@export var wake_screen_y := 110.0
## Se a animação roda enquanto dorme (hélice girando: sim; esteira do navio: não)
@export var animate_while_asleep := true

@export_group("Atravessar a tela")
## Em vez de patrulhar o rio, espera fora da tela e cruza de um lado ao outro uma vez,
## por cima de tudo (ignora margens). Sempre espera até `wake_screen_y`. Usado pelo jato.
@export var crosses_screen := false

## Emitido quando é derrubado por tiros (batida com o avião não dá pontos)
signal shot_down(points: int)

const FLASH_TIME := 0.08

var hits := 0
var is_destroyed := false
var start_x := 0.0
var river: River
var is_awake := true
var _flash_timer := 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
## Rastro opcional (CPUParticles2D chamado "Trail", posicionado na traseira com o inimigo
## olhando para a direita): troca de lado quando ele vira e só sai com ele andando
@onready var trail: CPUParticles2D = get_node_or_null("Trail")


func _ready() -> void:
	river = get_tree().get_first_node_in_group("river") as River
	area_entered.connect(_on_area_entered)
	if crosses_screen:
		# começa escondido do lado de onde vem
		var screen_w := get_viewport_rect().size.x
		position.x = -half_width - 8.0 if direction > 0 else screen_w + half_width + 8.0
	start_x = position.x
	is_awake = not (sleeps_until_near or crosses_screen)
	if not is_awake and not animate_while_asleep:
		sprite.pause.call_deferred()  # depois do autoplay
	_update_facing()


func _physics_process(delta: float) -> void:
	if not is_awake:
		_check_wake_up()
	elif crosses_screen:
		_move_across(delta)
	else:
		_move_patrol(delta)

	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			sprite.modulate = Color.WHITE

	if trail:
		trail.emitting = is_awake and speed > 0.0


func _move_patrol(delta: float) -> void:
	position.x += direction * speed * delta
	if _hit_bank() or _patrol_limit_reached():
		turn_around()


func _check_wake_up() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var screen_top := camera.global_position.y - get_viewport_rect().size.y / 2.0
	if global_position.y >= screen_top + wake_screen_y:
		is_awake = true
		sprite.play()


func _move_across(delta: float) -> void:
	position.x += direction * speed * delta
	var screen_w := get_viewport_rect().size.x
	if (direction > 0 and position.x > screen_w + half_width + 16.0) \
			or (direction < 0 and position.x < -half_width - 16.0):
		queue_free()  # chegou do outro lado


func _hit_bank() -> bool:
	if river == null:
		return false
	return not river.is_water(Vector2(position.x + direction * half_width, position.y))


func _patrol_limit_reached() -> bool:
	if patrol_distance <= 0.0:
		return false
	var offset := position.x - start_x
	var limit := patrol_distance / 2.0
	return (direction > 0 and offset >= limit) or (direction < 0 and offset <= -limit)


func turn_around() -> void:
	direction = -direction
	_update_facing()


func _update_facing() -> void:
	# Os sprites de inimigos são desenhados olhando para a direita
	sprite.flip_h = direction < 0
	if trail:
		# traseira fica do lado oposto ao movimento, e as partículas saem para trás
		trail.position.x = absf(trail.position.x) * -direction
		trail.direction = Vector2(-direction, trail.direction.y)


func _on_area_entered(area: Area2D) -> void:
	# A máscara de colisão só enxerga "player" e "player_shot"
	if area is Player:
		var player := area as Player
		if player.is_invulnerable():
			return
		if player.has_shield():
			player.break_shield()  # o escudo absorve a batida; o inimigo explode (sem pontos)
		else:
			player.die()
		destroy()
	elif area is PlayerBullet:
		area.queue_free()
		take_hit()


func take_hit() -> void:
	if is_destroyed:
		return
	hits += 1
	if hits >= max_hits:
		shot_down.emit(points)
		destroy()
	else:
		# pisca claro e faz "tink" para mostrar que levou o tiro
		sprite.modulate = Color(2.5, 2.5, 2.5)
		_flash_timer = FLASH_TIME
		Sfx.play("hit", -4.0, 1.0, 0.05)


func destroy() -> void:
	if is_destroyed:
		return
	is_destroyed = true
	for offset in explosion_offsets:
		Effects.spawn(explosion_scene, global_position + offset, get_parent())
	Effects.shake(self, destroy_shake)
	Effects.hit_stop(self, destroy_hit_stop)
	Sfx.play(destroy_sound, 0.0, 1.0, 0.08)
	queue_free()
