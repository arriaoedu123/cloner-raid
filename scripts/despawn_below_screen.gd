extends VisibleOnScreenNotifier2D
## Remove o nó pai quando ele sai pela parte de BAIXO da tela (o avião já passou por ele).
## Coloque como filho de inimigos e objetos do rio e ajuste o `rect` ao tamanho do sprite.


func _ready() -> void:
	screen_exited.connect(_on_screen_exited)


func _on_screen_exited() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera and global_position.y > camera.get_screen_center_position().y:
		get_parent().queue_free()
