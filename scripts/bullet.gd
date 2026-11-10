class_name PlayerBullet
extends Area2D
## Tiro do jogador: sobe em linha reta e some ao sair da tela ou ao encostar na terra
## (margens e ilhas não deixam o tiro passar).

## Velocidade (px/s); o avião soma a própria velocidade de avanço ao disparar
@export var speed := 320.0
## Poeira criada onde o tiro bate na terra
@export var dust_scene: PackedScene

## Ponta do tiro (o sprite tem 4x8 centralizado): é ela que encosta na terra
const TIP := Vector2(0, -4)

var river: River
## Avião que atirou (quem leva os pontos se o alvo cair)
var shooter: Player


func _ready() -> void:
	# online o tiro some no topo da tela MAIS ALTA dos dois (no _physics_process): assim ele
	# vai igualmente longe nos dois computadores e acerta o que o amigo de tela maior vê
	if not Game.online:
		$VisibleOnScreenNotifier2D.screen_exited.connect(queue_free)
	river = get_tree().get_first_node_in_group("river") as River


func _physics_process(delta: float) -> void:
	position.y -= speed * delta
	if Game.online:
		var camera := get_viewport().get_camera_2d()
		if camera and position.y < camera.global_position.y - Game.view_h_max(self) / 2.0 - 8.0:
			queue_free()
			return
	if river and not river.is_water(position + TIP):
		Effects.spawn(dust_scene, position + TIP, get_parent())
		queue_free()
