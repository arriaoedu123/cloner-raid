class_name PowerUp
extends Area2D
## Caixa de power-up flutuando no rio: o avião que passa por cima ganha o poder por um tempo
## (Player.give_power_up). Levar um tiro destrói a caixa SEM dar pontos: perdeu o poder.
## A caixa de vida (LIFE, rara) dá +1 avião reserva na hora (somado pelo Game).
## Balanço e espuma vêm do filho Floating (floating.gd).

enum Kind { DOUBLE_SHOT, SHIELD, LIFE }

const TEXTURES := {
	Kind.DOUBLE_SHOT: preload("res://assets/sprites/powerup/powerup_double.png"),
	Kind.SHIELD: preload("res://assets/sprites/powerup/powerup_shield.png"),
	Kind.LIFE: preload("res://assets/sprites/powerup/powerup_life.png"),
}
## Nome mostrado na dica em cima da caixa (até o jogador pegar um daquele tipo)
const NAMES := {
	Kind.DOUBLE_SHOT: "TIRO DUPLO",
	Kind.SHIELD: "ESCUDO",
	Kind.LIFE: "VIDA EXTRA",
}

## Qual poder a caixa dá (troca o desenho da caixa e da sombra)
@export var kind := Kind.DOUBLE_SHOT:
	set(value):
		kind = value
		$Sprite2D.texture = TEXTURES[kind]
		$Shadow.texture = TEXTURES[kind]
## Cena criada no lugar da caixa quando ela leva um tiro
@export var explosion_scene: PackedScene

## Emitido quando some (pega ou explodida). Online: o outro computador repete.
signal destroyed(exploded: bool)

var is_destroyed := false


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area2D) -> void:
	if is_destroyed:
		return
	# online: a caixa pega pelo avião remoto é decidida no computador dele
	if area is Player and not (area as Player).is_dead and not (area as Player).remote:
		(area as Player).give_power_up(kind)
		Sfx.play("extra_life" if kind == Kind.LIFE else "power_up")
		vanish(false)
	elif area is PlayerBullet:
		area.queue_free()
		if Game.is_online_client():
			return  # online, só o anfitrião decide os acertos
		Effects.shake(self, 2.0, 0.25, (area as PlayerBullet).shooter)
		vanish(true)


## Some: pega (`exploded` falso) ou destruída por tiro (com explosão e som).
func vanish(exploded: bool) -> void:
	if is_destroyed:
		return
	is_destroyed = true
	if exploded:
		Effects.spawn(explosion_scene, global_position, get_parent())
		Sfx.play("explosion_small", 0.0, 1.0, 0.08)
	destroyed.emit(exploded)
	queue_free()
