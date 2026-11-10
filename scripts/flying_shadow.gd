class_name FlyingShadow
extends Sprite2D
## Sombra de algo que voa (avião, helicóptero, jato) ou flutua (barco). Fica como filho do objeto,
## com a posição = deslocamento da sombra (a luz vem de cima, então ela cai para baixo).
## A cada frame copia o desenho atual do AnimatedSprite2D (inclinação, hélice, espelhado).
## A cor vem do material (assets/shaders/shadow_material.tres).

## Sprite que a sombra copia
@export var source_path: NodePath = ^"../AnimatedSprite2D"

@onready var source: AnimatedSprite2D = get_node(source_path)


func _ready() -> void:
	show_behind_parent = true  # desenha antes do próprio objeto
	_copy_source()


func _process(_delta: float) -> void:
	_copy_source()


func _copy_source() -> void:
	texture = source.sprite_frames.get_frame_texture(source.animation, source.frame)
	flip_h = source.flip_h
	visible = source.visible  # acompanha o piscar do avião invencível
