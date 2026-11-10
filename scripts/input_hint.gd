class_name InputHint
extends Node
## Sabe se o jogador está usando teclado ou controle (o último que ele mexeu) e monta os
## textos de dica com o nome certo de cada comando — já respeitando o que foi remapeado.
## Como o Sfx, cria sozinho um nó invisível (`watch()`) que observa a entrada.

static var using_gamepad := false
static var _watcher: InputHint

const STICK_DEADZONE := 0.5


## Começa a observar teclado/controle. Chamado pelo Settings ao abrir cada cena.
static func watch() -> void:
	if is_instance_valid(_watcher):
		return
	_watcher = InputHint.new()
	_watcher.name = "InputHint"
	_watcher.process_mode = Node.PROCESS_MODE_ALWAYS
	(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(_watcher)


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		using_gamepad = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) >= STICK_DEADZONE:
		using_gamepad = true
	elif event is InputEventKey and event.pressed:
		using_gamepad = false


## Para menus: true no frame em que a ação do jogo OU a ui_* equivalente começou a ser
## apertada, desde que nenhuma das duas já estivesse apertada antes. O analógico passa pela
## zona morta das duas em frames diferentes (0,2 nas do jogo, 0,5 nas ui_*); sem isso, um
## empurrão no analógico andava 2 opções.
static func menu_pressed(game_action: StringName, ui_action: StringName) -> bool:
	var game_just := Input.is_action_just_pressed(game_action)
	var ui_just := Input.is_action_just_pressed(ui_action)
	var held_before := (Input.is_action_pressed(game_action) and not game_just) \
			or (Input.is_action_pressed(ui_action) and not ui_just)
	return (game_just or ui_just) and not held_before


## Nome do comando de uma ação no dispositivo em uso (ex.: "ESPAÇO" ou "A").
static func name_of(action: StringName) -> String:
	return Controls.binding_name(action, not using_gamepad)


## Botões fixos dos menus (não remapeáveis)
static func confirm() -> String:
	return "A" if using_gamepad else "ENTER"


static func back() -> String:
	return "B" if using_gamepad else "ESC"


## Linha de controles do rodapé do título (teclas entre [ ] ganham borda no PixelText).
static func controls_line() -> String:
	if using_gamepad:
		return "[ANALOG] OU [DPAD] MOVE   [%s] ATIRA   [%s] PAUSA" % [name_of(&"shoot"), name_of(&"pause")]
	return "[SETAS] OU [WASD] MOVEM   [%s] ATIRA   [ALT] [ENTER] TELA CHEIA" % name_of(&"shoot")
