extends Node2D
## Tela de título: o rio rolando sozinho ao fundo, o avião balançando no meio da tela
## e o menu (JOGAR / OPÇÕES / SAIR). Setas ou W/S escolhem; tiro ou Enter confirma.

## Velocidade com que o rio passa no fundo (px/s)
@export var scroll_speed := 60.0
## Cena do jogo, aberta ao escolher JOGAR
@export_file("*.tscn") var game_scene := "res://scenes/main.tscn"

const OPTIONS: Array[String] = ["JOGAR", "OPÇÕES", "SAIR"]
const PLANE_FRAMES := {
	-2: preload("res://assets/sprites/player/plane_left_full.png"),
	-1: preload("res://assets/sprites/player/plane_left_half.png"),
	0: preload("res://assets/sprites/player/plane_center.png"),
	1: preload("res://assets/sprites/player/plane_right_half.png"),
	2: preload("res://assets/sprites/player/plane_right_full.png"),
}

var selected := 0
var high_score := 0
var _time := 0.0
var _starting := false

@onready var camera: Camera2D = $Camera2D
@onready var plane: Sprite2D = $Camera2D/Plane
@onready var plane_shadow: Sprite2D = $Camera2D/PlaneShadow
@onready var options_menu: Control = $UI/OptionsMenu


func _ready() -> void:
	Settings.load_and_apply()
	Sfx.warm_up()
	high_score = SaveData.load_value("records", "high_score", 0)
	camera.position = Vector2(get_viewport_rect().size.x / 2.0, 180.0)


func _process(delta: float) -> void:
	_time += delta
	camera.position.y -= scroll_speed * delta
	_sway_plane()
	if Input.is_action_just_pressed("toggle_fullscreen"):
		Settings.toggle_fullscreen()
		return  # Alt+Enter não pode também confirmar a opção do menu
	if _starting or is_options_open():
		return

	if InputHint.menu_pressed(&"speed_up", &"ui_up"):
		_move_selection(-1)
	elif InputHint.menu_pressed(&"slow_down", &"ui_down"):
		_move_selection(1)
	elif InputHint.menu_pressed(&"shoot", &"ui_accept"):
		_confirm()


## O avião desliza de um lado para o outro e inclina as asas para onde está indo.
func _sway_plane() -> void:
	var x := sin(_time * 0.8) * 60.0
	var speed := cos(_time * 0.8)  # derivada do seno: para onde e quão rápido está indo
	plane.position.x = roundf(x)
	var tilt := clampi(roundi(speed * 2.0), -2, 2)
	plane.texture = PLANE_FRAMES[tilt]
	plane_shadow.texture = plane.texture
	plane_shadow.position.x = plane.position.x + 6.0


func _move_selection(step: int) -> void:
	selected = posmod(selected + step, OPTIONS.size())
	Sfx.play("ui_move", -6.0)


func is_options_open() -> bool:
	return options_menu.visible


func _confirm() -> void:
	Sfx.play("ui_select", -4.0)
	match OPTIONS[selected]:
		"JOGAR":
			_starting = true
			await get_tree().create_timer(0.25).timeout  # deixa o som de confirmar tocar
			get_tree().change_scene_to_file(game_scene)
		"OPÇÕES":
			options_menu.open()
		"SAIR":
			get_tree().quit()
