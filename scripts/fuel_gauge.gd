extends Control
## Barra de combustível do HUD, desenhada no padrão pixel art:
## contorno de 1 px, 3 tons (claro em cima, escuro embaixo) e marcas a cada 1/4.

## Avião cujo combustível é mostrado (o limite de "pouco combustível" vem dele)
@export var player: Player

const BAR_SIZE := Vector2(96, 8)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var ratio := 0.0
	if is_instance_valid(player):
		ratio = clampf(player.fuel / player.max_fuel, 0.0, 1.0)

	var inner := Rect2(Vector2.ONE, BAR_SIZE - Vector2(2, 2))  # 94 x 6
	draw_rect(Rect2(Vector2.ZERO, BAR_SIZE), Palette.OUTLINE)
	draw_rect(inner, Palette.GRAY_DARK)

	var width := floorf(inner.size.x * ratio)
	if width > 0.0:
		var low := player.is_low_fuel()
		var base := Palette.RED if low else Palette.ORANGE
		var light := Palette.RED_LIGHT if low else Palette.ORANGE_LIGHT
		draw_rect(Rect2(inner.position, Vector2(width, inner.size.y)), base)
		draw_rect(Rect2(inner.position, Vector2(width, 2)), light)
		draw_rect(Rect2(inner.position + Vector2(0, 4), Vector2(width, 2)), Palette.RED_DARK)

	for quarter: float in [0.25, 0.5, 0.75]:
		var x := inner.position.x + floorf(inner.size.x * quarter)
		draw_rect(Rect2(x, inner.position.y, 1, inner.size.y), Palette.OUTLINE)
