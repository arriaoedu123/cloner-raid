class_name FollowCamera
extends Camera2D
## Câmera do jogo: acompanha o avanço (eixo Y) do alvo e fica parada no eixo X.

## Nó que a câmera acompanha (o avião do jogador)
@export var target: Node2D
## Onde o alvo fica na tela, medido do centro para baixo (px)
@export var target_offset_y := 136.0

var _shake_strength := 0.0
var _shake_time := 0.0
var _shake_duration := 0.0


func _ready() -> void:
	position.x = get_viewport_rect().size.x / 2.0
	follow()


func _physics_process(_delta: float) -> void:
	follow()


func _process(delta: float) -> void:
	if _shake_time <= 0.0:
		return
	_shake_time -= delta
	if _shake_time <= 0.0:
		offset = Vector2.ZERO
		return
	# tremor diminui até zero; arredondado para não borrar a pixel art
	var s := _shake_strength * (_shake_time / _shake_duration)
	offset = Vector2(randf_range(-s, s), randf_range(-s, s)).round()


## Treme a tela; um tremor mais forte substitui um mais fraco que já está acontecendo.
func shake(strength: float, duration: float) -> void:
	var current := _shake_strength * (_shake_time / _shake_duration) if _shake_time > 0.0 else 0.0
	if strength < current:
		return
	_shake_strength = strength
	_shake_duration = duration
	_shake_time = duration


## Pula direto para a posição do alvo (também usado ao recomeçar uma seção).
func follow() -> void:
	if is_instance_valid(target):
		position.y = target.global_position.y - target_offset_y
