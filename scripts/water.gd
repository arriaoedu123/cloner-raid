extends ColorRect
## Fundo de água: um retângulo do tamanho da tela (com folga para o tremor) que segue a
## câmera. O desenho das ondinhas vem do shader (assets/shaders/water.gdshader), que usa a
## posição no mundo, então as ondas ficam "presas" no rio enquanto o avião voa.

const MARGIN := 16.0  # folga para o tremor de tela não mostrar a borda


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	# a altura visível muda ao entrar/sair da tela cheia (telas mais altas que 16:9)
	var view := get_viewport_rect().size
	size = view + Vector2(MARGIN, MARGIN) * 2.0
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var top_left := camera.get_screen_center_position() - view / 2.0
	global_position = (top_left - Vector2(MARGIN, MARGIN)).floor()
