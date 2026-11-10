class_name Effects
## Atalhos para efeitos no mundo: criar explosões, tremer a tela e congelar no impacto.

## Liga/desliga o tremor de tela e a vibração do controle (opção TREMOR DE TELA)
static var shake_enabled := true
## Velocidade do jogo durante o congelamento no impacto
const HIT_STOP_TIME_SCALE := 0.05

static var _hit_stops := 0  # congelamentos acontecendo ao mesmo tempo


## Treme a câmera atual por `duration` segundos, até `strength` px para cada lado, e vibra o
## controle de `by` (o avião que causou o impacto) com força proporcional (6 px = máxima).
## No coop só vibra o controle do jogador responsável (quem atirou, caiu ou bateu); quem joga
## no teclado não faz controle nenhum vibrar. Sem `by` (ex.: prévia nas opções), vibra como
## no modo de 1 jogador: todos os controles, se o jogador estiver usando controle.
static func shake(node: Node, strength: float, duration: float = 0.25, by: Player = null) -> void:
	if not shake_enabled or strength <= 0.0 or not node.is_inside_tree():
		return
	var camera := node.get_viewport().get_camera_2d()
	if camera and camera.has_method("shake"):
		camera.shake(strength, duration)
	var power := clampf(strength / 6.0, 0.15, 1.0)
	for pad in _pads_of(by):
		Input.start_joy_vibration(pad, power * 0.6, power, duration)


## Controles que vibram por algo que `by` fez.
static func _pads_of(by: Player) -> Array:
	if by != null and by.input_prefix != "":  # coop: só o controle desse jogador
		var device: int = Game.coop_devices[by.number - 1]
		return [device] if device >= 0 else []
	return Input.get_connected_joypads() if InputHint.using_gamepad else []


## Quase para o jogo por `duration` segundos de tempo REAL (dá peso aos impactos).
static func hit_stop(node: Node, duration: float) -> void:
	if duration <= 0.0 or not node.is_inside_tree():
		return
	var tree := node.get_tree()
	_hit_stops += 1
	Engine.time_scale = HIT_STOP_TIME_SCALE
	# timer que ignora o time_scale, senão o próprio congelamento duraria 20x mais
	await tree.create_timer(duration, true, false, true).timeout
	_hit_stops -= 1
	if _hit_stops <= 0:
		_hit_stops = 0
		Engine.time_scale = 1.0


## Cria `scene` em `position` (coordenadas do mundo) como filho de `parent`.
## O add_child é adiado porque costuma ser chamado no meio de colisões.
static func spawn(scene: PackedScene, position: Vector2, parent: Node) -> void:
	if scene == null or parent == null:
		return
	var effect: Node2D = scene.instantiate()
	effect.position = position
	parent.add_child.call_deferred(effect)
