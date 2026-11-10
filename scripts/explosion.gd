extends AnimatedSprite2D
## Explosão: toca a animação uma vez, solta as faíscas e some quando as duas terminam.
## Usada pelo avião e pelos inimigos.

@onready var sparks: CPUParticles2D = $Sparks


func _ready() -> void:
	play(&"explode")
	# a bola de fogo some (self_modulate não afeta os filhos); as faíscas ainda voam
	animation_finished.connect(func(): self_modulate = Color.TRANSPARENT)
	sparks.emitting = true
	await get_tree().create_timer(maxf(sparks.lifetime, 0.5)).timeout
	queue_free()
