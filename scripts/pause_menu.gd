extends Control
## Pausa: Esc, P ou Start pausam/despausam o jogo (exceto no fim de jogo).
## Menu: CONTINUAR / OPÇÕES (o mesmo painel do título) / MENU PRINCIPAL.
## Roda com o jogo pausado (process_mode = sempre).
## Na cena, este nó precisa vir ANTES do OptionsMenu: assim o Esc que fecha as opções
## não fecha a pausa no mesmo frame.

## Partida (para não pausar no fim de jogo)
@export var game: Game
## Painel de opções reaproveitado
@export var options_menu: Control
## Tela de título, aberta por MENU PRINCIPAL
@export_file("*.tscn") var title_scene := "res://scenes/title.tscn"

const ITEMS: Array[String] = ["CONTINUAR", "OPÇÕES", "MENU PRINCIPAL"]
const PANEL := Vector2(220, 120)

var selected := 0
var _opened_frame := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()


func _process(_delta: float) -> void:
	if not visible:
		if Input.is_action_just_pressed("pause") and game and not game.is_game_over:
			_open()
		return
	queue_redraw()
	if options_menu.visible or Engine.get_process_frames() == _opened_frame:
		return  # as opções cuidam da entrada enquanto abertas

	if Input.is_action_just_pressed("pause") or Input.is_action_just_pressed("ui_cancel"):
		_resume()  # Start/Esc/P ou B do controle
	elif InputHint.menu_pressed(&"speed_up", &"ui_up"):
		selected = posmod(selected - 1, ITEMS.size())
		Sfx.play("ui_move", -6.0)
	elif InputHint.menu_pressed(&"slow_down", &"ui_down"):
		selected = posmod(selected + 1, ITEMS.size())
		Sfx.play("ui_move", -6.0)
	elif Input.is_action_just_pressed("toggle_fullscreen"):
		pass  # Alt+Enter não pode também confirmar a opção
	elif InputHint.menu_pressed(&"shoot", &"ui_accept"):
		_confirm()


## Online o jogo NÃO congela (o amigo continua jogando): o menu abre por cima e só os
## comandos do seu avião ficam travados (Game.input_blocked) enquanto ele está aberto.
func _open() -> void:
	selected = 0
	_opened_frame = Engine.get_process_frames()
	if Game.online:
		Game.input_blocked = true
	else:
		get_tree().paused = true
	Sfx.play("ui_select", -6.0)
	show()


func _resume() -> void:
	Sfx.play("ui_select", -6.0)
	hide()
	Game.input_blocked = false
	get_tree().paused = false


func _confirm() -> void:
	match ITEMS[selected]:
		"CONTINUAR":
			_resume()
		"OPÇÕES":
			Sfx.play("ui_select", -4.0)
			options_menu.open()
		"MENU PRINCIPAL":
			Sfx.play("ui_select", -4.0)
			get_tree().paused = false
			Game.input_blocked = false
			if Game.online:
				Online.leave()  # o amigo recebe "saiu da partida" e volta ao título
			get_tree().change_scene_to_file(title_scene)


func _draw() -> void:
	if options_menu.visible:
		return  # o painel de opções desenha por cima (com o próprio fundo escurecido)
	var top_left := MenuStyle.panel(self, PANEL, "PAUSA")
	for i in ITEMS.size():
		MenuStyle.item(self, ITEMS[i], top_left.x + PANEL.x / 2.0,
				top_left.y + MenuStyle.CONTENT_TOP + i * 22.0, i == selected)
