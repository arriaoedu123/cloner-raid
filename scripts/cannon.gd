class_name Cannon
extends Node2D
## Canhão da torre (filho do inimigo, no centro da torre). Com um avião num cone de ±45° para
## baixo (mais abaixo do que para o lado, a mais de `min_distance`) e a torre dentro da tela:
## espera `first_delay`, acende a luz por `warn_time` (o aviso para desviar) e dispara um
## EnemyShot mirado onde o avião está; depois repete a cada `fire_interval`. Fora do cone não
## atira, então o projétil nunca sai muito torto em relação ao cano. O cano aponta para baixo ou
## na diagonal, o que estiver mais perto da mira (animações "<estado>_<cano>": estado idle, warn
## ou fire; cano down, left ou right), e o projétil sai da ponta dele. Online: só o anfitrião
## decide e manda o aviso e o disparo, com a direção (Game._net_cannon); o convidado só repete.

@export var shot_scene: PackedScene
## Tempo entre disparos (s)
@export var fire_interval := 1.8
## Luz acesa antes de cada disparo (s)
@export var warn_time := 0.35
## Velocidade do projétil (px/s)
@export var shot_speed := 110.0
## Espera do 1º disparo depois que um avião entra no alcance (s)
@export var first_delay := 0.6
## Só atira com o avião pelo menos isto abaixo do centro da torre (px): depois que ele passa, para
@export var min_distance := 52.0
## Só atira com a torre pelo menos isto abaixo do topo da tela (px)
@export var screen_margin := 24.0

const FIRE_FRAME_TIME := 0.12  # quanto o clarão do disparo fica na tela
## Ponta de cada cano, a partir do centro da torre (px)
const MUZZLE := {&"down": Vector2(0, 12), &"right": Vector2(10, 9), &"left": Vector2(-10, 9)}
## Passou disto para o lado (tan 22,5°), o cano vira para a diagonal
const DIAGONAL_FROM := 0.414

var _timer := 0.0
var _armed := false    # tem avião no alcance (o relógio está correndo)
var _warning := false
var _fire_frame := 0.0
var _barrel := &"down"

@onready var enemy: Enemy = get_parent()


func _physics_process(delta: float) -> void:
	if _fire_frame > 0.0:
		_fire_frame -= delta
		if _fire_frame <= 0.0:
			_show(&"idle")
	if enemy.is_destroyed or Game.is_online_client():
		return  # online, o convidado só repete o que o anfitrião manda
	var target := _target()
	if target == null:
		_armed = false
		if _warning:
			_warning = false
			_show(&"idle")
		return
	var dir := (target.global_position - global_position).normalized()
	_aim(dir)  # o cano acompanha o avião enquanto ele está no cone
	if not _armed:
		_armed = true
		_timer = first_delay
	_timer -= delta
	if not _warning and _timer <= warn_time:
		_send(false, dir)
		warn(dir)
	if _timer <= 0.0:
		_timer = fire_interval
		_send(true, dir)
		fire(dir)


## Acende a luz de aviso, com o cano para o lado de `dir` (o disparo vem em `warn_time`).
func warn(dir: Vector2) -> void:
	_warning = true
	_aim(dir)
	_show(&"warn")


## Dispara um projétil na direção `dir`, saindo da ponta do cano.
func fire(dir: Vector2) -> void:
	_warning = false
	_aim(dir)
	var shot: EnemyShot = shot_scene.instantiate()
	shot.position = global_position + MUZZLE[_barrel]
	shot.velocity = dir * shot_speed
	enemy.get_parent().add_child(shot)  # junto dos objetos: some no recomeço da seção
	_show(&"fire")
	_fire_frame = FIRE_FRAME_TIME
	Sfx.play("cannon", -2.0, 1.0, 0.06)


## Avião mais perto no cone de ±45° abaixo da torre, com ela dentro da tela; null se não houver.
func _target() -> Player:
	var camera := get_viewport().get_camera_2d()
	var game := get_tree().current_scene as Game
	if camera == null or game == null:
		return null
	# online: mesma conta nos dois computadores (a tela mais baixa dos dois)
	var top := camera.global_position.y - Game.view_h_min(self) / 2.0
	if enemy.global_position.y < top + screen_margin:
		return null
	var best: Player = null
	for p in game.players:
		var d := p.global_position - global_position
		if p.is_dead or d.y <= min_distance or absf(d.x) > d.y:
			continue
		if best == null or d.length() < (best.global_position - global_position).length():
			best = p
	return best


## Vira o cano para baixo ou para a diagonal mais perto de `dir` (mantendo o estado atual).
func _aim(dir: Vector2) -> void:
	var barrel := &"down"
	if dir.x > dir.y * DIAGONAL_FROM:
		barrel = &"right"
	elif dir.x < -dir.y * DIAGONAL_FROM:
		barrel = &"left"
	if barrel != _barrel:
		_barrel = barrel
		_show(_state())


## Estado da animação atual ("idle", "warn" ou "fire").
func _state() -> StringName:
	var anim := String(enemy.sprite.animation)
	return StringName(anim.get_slice("_", 0))


func _send(firing: bool, dir: Vector2) -> void:
	if Game.online:
		(get_tree().current_scene as Game)._net_cannon.rpc(String(enemy.name), firing, dir)


func _show(state: StringName) -> void:
	var anim := StringName("%s_%s" % [state, _barrel])
	if enemy.sprite.animation != anim:
		enemy.sprite.play(anim)
