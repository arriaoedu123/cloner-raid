class_name EnemyShot
extends Area2D
## Projétil da torre: voa em linha reta e derruba o avião que tocar (o escudo segura um). Não
## leva tiro. Como o tiro do avião, para na terra (margens e ilhas) deixando poeira. Some ao
## sair da tela ou depois de LIFETIME. Online, cada computador cria o mesmo projétil (o rio é
## igual, então ele para no mesmo lugar), mas só decide a batida do PRÓPRIO avião (a do outro
## chega pela rede, como as batidas em inimigos).

const LIFETIME := 4.0
## A torre fica na linha da margem: a boca do cano pode estar sobre a terra, então só começa a
## parar na terra depois de andar isto (px), já fora da plataforma
const LAND_GRACE := 10.0

## Poeira criada onde ele bate na terra
@export var dust_scene: PackedScene

## Velocidade (px/s, já com a direção)
var velocity := Vector2.ZERO
var river: River
var _age := 0.0
var _travelled := 0.0


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	$VisibleOnScreenNotifier2D.screen_exited.connect(queue_free)
	river = get_tree().get_first_node_in_group("river") as River


func _physics_process(delta: float) -> void:
	position += velocity * delta
	_travelled += velocity.length() * delta
	_age += delta
	if _age >= LIFETIME:
		queue_free()
	elif _travelled > LAND_GRACE and river and not river.is_water(position):
		Effects.spawn(dust_scene, position, get_parent())
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	var player := area as Player
	if player == null or player.remote or player.is_dead or player.is_invulnerable():
		return
	if player.has_shield():
		player.break_shield()
	else:
		player.die()
	queue_free()
