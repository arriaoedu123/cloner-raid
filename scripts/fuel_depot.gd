class_name FuelDepot
extends Area2D
## Posto de combustível flutuante: reabastece o avião que passa por cima
## e explode se levar um tiro. O balanço e a espuma vêm do filho Floating (floating.gd).

## Combustível por segundo enquanto o avião está em cima
## (passando em velocidade de cruzeiro dá ~30; freando em cima, o dobro)
@export var refuel_rate := 70.0
## Cena criada no lugar do posto quando ele é destruído
@export var explosion_scene: PackedScene
## Pontos ganhos ao destruí-lo (pouco: destruir combustível costuma ser má ideia)
@export var points := 50

## Emitido quando é destruído por um tiro
signal shot_down(points: int)
## Emitido ao explodir (online: o outro computador repete a explosão)
signal destroyed

var is_destroyed := false
## Avião que destruiu o posto (no coop com pontos separados, o combo quebrado é o dele)
var killer: Player


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	for area in get_overlapping_areas():
		# online: o combustível do avião remoto é contado no computador dele
		if area is Player and not (area as Player).remote:
			(area as Player).add_fuel(refuel_rate * delta)


func _on_area_entered(area: Area2D) -> void:
	if area is PlayerBullet:
		killer = (area as PlayerBullet).shooter
		area.queue_free()
		if Game.is_online_client():
			return  # online, só o anfitrião decide os acertos
		if not is_destroyed:
			shot_down.emit(points)
		destroy()


func destroy() -> void:
	if is_destroyed:
		return
	is_destroyed = true
	Effects.spawn(explosion_scene, global_position, get_parent())
	Effects.shake(self, 2.0, 0.25, killer)
	Effects.hit_stop(self, 0.03)
	Sfx.play("explosion_small", 0.0, 1.0, 0.08)
	destroyed.emit()
	queue_free()
