class_name Floating
extends Node2D
## Faz um objeto parecer flutuar na água (posto, caixa de power-up): o sprite sobe e desce
## 1 px a cada BOB_STEP_MS e uma espuma tracejada contorna o desenho na linha d'água.
## Vai como filho do objeto, DEPOIS da Shadow e ANTES do Sprite2D: assim a espuma fica por
## cima da sombra e por baixo do objeto. Sombra, espuma e colisão ficam paradas.

const BOB_STEP_MS := 500
## Espuma anda 1 px no mesmo ritmo da espuma das margens
const FOAM_STEP_MS := River.FOAM_STEP_MS

## Sprite que balança (a espuma segue o contorno da textura dele)
@export var sprite_path: NodePath = ^"../Sprite2D"

## Pixels de água colados em cada desenho (calculado uma vez por textura)
static var _foam_cache := {}

var _foam_points := PackedVector2Array()

@onready var sprite: Sprite2D = get_node(sprite_path)


func _ready() -> void:
	if not _foam_cache.has(sprite.texture):
		_foam_cache[sprite.texture] = _outline_points(sprite.texture)
	_foam_points = _foam_cache[sprite.texture]


func _process(_delta: float) -> void:
	# cada objeto com sua fase (pela posição), para não balançarem todos juntos
	var t := Time.get_ticks_msec() + int(global_position.x) * 37
	sprite.position.y = -1.0 if (t / BOB_STEP_MS) % 2 == 0 else 0.0
	queue_redraw()


func _draw() -> void:
	var phase := int(Time.get_ticks_msec() / FOAM_STEP_MS) % 4
	for p in _foam_points:
		if posmod(int(p.x + p.y) + phase, 4) < 2:
			draw_rect(Rect2(p, Vector2.ONE), Palette.BLUE_LIGHT)


## Pixels transparentes vizinhos (4 lados) de um pixel do desenho, em coordenadas locais
## do Sprite2D centralizado: é a "linha d'água" em volta do objeto.
static func _outline_points(texture: Texture2D) -> PackedVector2Array:
	var img := texture.get_image()
	var origin := -Vector2(img.get_size()) / 2.0
	var points := PackedVector2Array()
	for y in range(-1, img.get_height() + 1):
		for x in range(-1, img.get_width() + 1):
			if _opaque(img, x, y):
				continue
			for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
				if _opaque(img, x + d.x, y + d.y):
					points.append(origin + Vector2(x, y))
					break
	return points


static func _opaque(img: Image, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height() \
			and img.get_pixel(x, y).a > 0.5
