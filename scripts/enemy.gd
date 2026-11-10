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
## Explosão em área (mina): ao ser destruído derruba na hora todo inimigo a até esta distância
## (px), inclusive outras minas, em cadeia. Se ele caiu por tiro, os derrubados dão pontos e
## combo para quem atirou. 0 = sem explosão em área.
@export var blast_radius := 0.0

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
## Em vez de esperar fora da tela, espera onde nasceu (na terra, ao lado do rio) e atravessa o
## rio de margem a margem quando acorda. Usado pelo aerobarco.
@export var starts_on_bank := false

@export_group("Mergulho")
## Mergulha e sobe em ciclo (submarino). Submerso não leva tiro nem derruba o avião (só a
## explosão de uma mina o pega). Precisa das animações "surface", "dive" e "under".
@export var dives := false
## Tempo na superfície, mergulhando (e o mesmo subindo) e submerso (s)
@export var surface_time := 2.4
@export var dive_time := 0.5
@export var under_time := 2.0

## Emitido quando é derrubado por tiros (batida com o avião não dá pontos)
signal shot_down(points: int)
## Emitido ao explodir por qualquer motivo (online: o outro computador repete a explosão)
signal destroyed
## Emitido ao levar um tiro sem cair (online: o outro computador repete o brilho)
signal hit_taken

const FLASH_TIME := 0.08

var hits := 0
## Avião que deu o último tiro (quem leva os pontos no coop com pontos separados)
var killer: Player
var is_destroyed := false
var start_x := 0.0
var river: River
var is_awake := true
## Mergulho: ponto do ciclo (s, sorteado ao nascer; online o anfitrião manda) e se está submerso
var dive_t := 0.0
var is_submerged := false
var _flash_timer := 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
## Rastro opcional (CPUParticles2D chamado "Trail", posicionado na traseira com o inimigo
## olhando para a direita): troca de lado quando ele vira e só sai com ele andando
@onready var trail: CPUParticles2D = get_node_or_null("Trail")
@onready var shadow: Node2D = get_node_or_null("Shadow")


func _ready() -> void:
	river = get_tree().get_first_node_in_group("river") as River
	area_entered.connect(_on_area_entered)
	if crosses_screen and not starts_on_bank:
		# começa escondido do lado de onde vem
		var screen_w := get_viewport_rect().size.x
		position.x = -half_width - 8.0 if direction > 0 else screen_w + half_width + 8.0
	start_x = position.x
	is_awake = not (sleeps_until_near or crosses_screen)
	if not is_awake and not animate_while_asleep:
		sprite.pause.call_deferred()  # depois do autoplay
	_update_facing()
	if dives:
		_update_dive(0.0)


func _physics_process(delta: float) -> void:
	if not is_awake:
		_check_wake_up()
	elif crosses_screen:
		_move_across(delta)
	else:
		_move_patrol(delta)

	if dives:
		_update_dive(delta)  # mergulha mesmo dormindo (só não anda)

	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			sprite.modulate = Color.WHITE

	if trail:
		trail.emitting = is_awake and speed > 0.0 and not is_submerged


func _move_patrol(delta: float) -> void:
	if speed <= 0.0:
		return  # parado (mina, ponte): sem isso, perto da margem ele "viraria" todo quadro
	position.x += direction * speed * delta
	if _hit_bank() or _patrol_limit_reached():
		turn_around()


## Ciclo do mergulho: superfície → mergulhando → submerso → subindo. Só submerso fica sem
## colisão (subindo ele já bate: os 0,5 s de "dive" avisam). Fora da superfície, sem sombra.
func _update_dive(delta: float) -> void:
	var period := surface_time + dive_time * 2.0 + under_time
	dive_t = fposmod(dive_t + delta, period)
	var anim := &"surface"
	if dive_t >= surface_time + dive_time and dive_t < surface_time + dive_time + under_time:
		anim = &"under"
	elif dive_t >= surface_time:
		anim = &"dive"
	var under := anim == &"under"
	if under != is_submerged:
		is_submerged = under
		set_deferred("monitoring", not under)
		set_deferred("monitorable", not under)
	if sprite.animation != anim:
		sprite.play(anim)
	if shadow:
		# a sombra copia o desenho todo quadro: parada e escondida enquanto ele está embaixo
		var on_top := anim == &"surface"
		shadow.visible = on_top
		shadow.process_mode = Node.PROCESS_MODE_INHERIT if on_top else Node.PROCESS_MODE_DISABLED


func _check_wake_up() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	# online: medido na tela mais baixa dos dois, para acordar igual nos dois computadores
	var screen_top := camera.global_position.y - Game.view_h_min(self) / 2.0
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


## Online (convidado): posição, direção, "acordado" e ponto do mergulho mandados pelo anfitrião
## 10x por segundo, para o inimigo estar no mesmo lugar (e submerso na mesma hora) nas duas
## telas (quem decide o acerto é o anfitrião). Entre uma atualização e outra ele segue sozinho.
func apply_remote_state(x: float, dir: int, awake: bool, dive: float) -> void:
	position.x = x
	dive_t = dive
	if dir != direction:
		direction = dir
		_update_facing()
	if awake and not is_awake:
		is_awake = true
		sprite.play()


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
		# online: batida de avião remoto é decidida no computador dele (e chega pela rede)
		if player.is_invulnerable() or player.remote:
			return
		if player.has_shield():
			player.break_shield()  # o escudo absorve a batida; o inimigo explode (sem pontos)
		else:
			player.die()
		killer = player  # só para a vibração ir ao controle de quem bateu (batida não dá pontos)
		destroy()
	elif area is PlayerBullet:
		killer = (area as PlayerBullet).shooter
		area.queue_free()
		if not Game.is_online_client():  # online, só o anfitrião decide os acertos
			take_hit()


func take_hit() -> void:
	if is_destroyed:
		return
	hits += 1
	if hits >= max_hits:
		shot_down.emit(points)
		destroy(true)
	else:
		flash()
		hit_taken.emit()


## Pisca claro e faz "tunc" para mostrar que levou o tiro (online o amigo repete pela rede).
func flash() -> void:
	sprite.modulate = Color(2.5, 2.5, 2.5)
	_flash_timer = FLASH_TIME
	Sfx.play("hit", -4.0, 1.0, 0.05)


## `by_shot`: caiu por tiro (a explosão em área, se houver, dá pontos a quem atirou).
func destroy(by_shot := false) -> void:
	if is_destroyed:
		return
	is_destroyed = true
	for offset in explosion_offsets:
		Effects.spawn(explosion_scene, global_position + offset, get_parent())
	Effects.shake(self, destroy_shake, 0.25, killer)
	Effects.hit_stop(self, destroy_hit_stop)
	Sfx.play(destroy_sound, 0.0, 1.0, 0.08)
	destroyed.emit()
	# online, só o anfitrião derruba os vizinhos; cada um chega ao convidado pela rede
	if blast_radius > 0.0 and not Game.is_online_client():
		_blast(by_shot)
	queue_free()


func _blast(by_shot: bool) -> void:
	for node in get_parent().get_children():
		if node is Enemy and node != self and not node.is_destroyed \
				and node.global_position.distance_to(global_position) <= blast_radius:
			node.blast_hit(killer if by_shot else null)


## Pego pela explosão de uma mina: cai na hora, mesmo quem aguenta vários tiros. Com `by`
## (a mina caiu por tiro), conta pontos e combo para quem atirou; sem, cai sem pontos.
func blast_hit(by: Player) -> void:
	if is_destroyed:
		return
	killer = by
	if by:
		shot_down.emit(points)
	destroy(by != null)
