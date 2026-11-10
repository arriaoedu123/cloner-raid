extends Control
## Tela JOGAR ONLINE (aberta pelo título). Usa a Steam (Online.init_steam); aberto com o
## argumento "lan" (godot ... -- lan) usa a rede local, só para testes.
##   MENU:  CRIAR SALA / ENTRAR COM CÓDIGO / VOLTAR
##   SALA:  código grande + "ESPERANDO O AMIGO..." / COPIAR CÓDIGO / CONVIDAR AMIGO / CANCELAR
##   CONVITE: amigos online da Steam (rola de 5 em 5) / VOLTAR; escolher manda o convite
##   CÓDIGO: 6 casas; teclado digita (Apagar volta, Enter entra); controle: ↑/↓ trocam a
##           letra, ←/→ a casa, A entra, B volta
##   AVISO: uma mensagem (Steam fechada, conexão perdida...) / VOLTAR
##   SAGUÃO (depois que o convidado entra): os dois jogadores; o anfitrião troca PONTOS
##           (juntos/separados) e escolhe COMEÇAR PARTIDA; o convidado espera. SAIR DA SALA.
## A partida só começa quando o anfitrião escolhe COMEÇAR PARTIDA (Online.start_match).

signal closed

enum Screen { MENU, ROOM, CODE, MESSAGE, LOBBY, INVITE }

const PANEL := Vector2(320, 188)
const MENU_ITEMS: Array[String] = ["CRIAR SALA", "ENTRAR COM CÓDIGO", "VOLTAR"]
const ROOM_ITEMS: Array[String] = ["COPIAR CÓDIGO", "CONVIDAR AMIGO", "CANCELAR"]
const LOBBY_HOST_ITEMS: Array[String] = ["PONTOS", "COMEÇAR PARTIDA", "SAIR DA SALA"]
const LOBBY_GUEST_ITEMS: Array[String] = ["SAIR DA SALA"]
const LIFE_ICONS := [preload("res://assets/sprites/hud/life.png"), preload("res://assets/sprites/hud/life_p2.png")]
## Quanto tempo o aviso "CÓDIGO COPIADO!" fica na tela (ms)
const COPIED_MS := 2000
## Amigos visíveis de uma vez na lista de convite
const INVITE_ROWS := 5

var screen := Screen.MENU
var selected := 0
var status := ""   # mensagem atual (CRIANDO SALA..., SALA NÃO ENCONTRADA...)
var code := ""     # código digitado
var cursor := 0    # casa do código (no controle)
var _opened_frame := -1
var _lan := false
var _copied_until := 0  # até quando mostrar "CÓDIGO COPIADO!" (Time.get_ticks_msec)
var _friends: Array = []  # lista de convite (Online.online_friends), lida ao abrir
var _scroll := 0          # primeiro amigo visível na lista


func _ready() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lan = OS.get_cmdline_user_args().has("lan")


## Abre no menu (ou direto no aviso, se a conexão caiu na partida anterior).
func open() -> void:
	var net := Online.node()
	net.status_changed.connect(_on_status, CONNECT_REFERENCE_COUNTED)
	net.lobby_ready.connect(_on_lobby_ready, CONNECT_REFERENCE_COUNTED)
	net.friend_left.connect(_on_friend_left, CONNECT_REFERENCE_COUNTED)
	net.room_closed.connect(_show_message, CONNECT_REFERENCE_COUNTED)
	_opened_frame = Engine.get_process_frames()
	show()
	if Online.last_message != "":
		_show_message(Online.last_message)
		Online.last_message = ""
	elif not _lan and not Online.init_steam():
		_show_message("ABRA A STEAM E TENTE DE NOVO")
	else:
		_go(Screen.MENU)


func _go(to: Screen) -> void:
	screen = to
	selected = 0
	status = ""


func _show_message(text: String) -> void:
	_go(Screen.MESSAGE)
	status = text


func _on_status(text: String) -> void:
	status = text


## Os dois se apresentaram: abre o saguão (nos dois computadores).
func _on_lobby_ready() -> void:
	_go(Screen.LOBBY)
	Sfx.play("ui_select", -4.0)


## O convidado saiu antes de começar: o anfitrião volta à sala, que continua aberta.
func _on_friend_left() -> void:
	_go(Screen.ROOM)
	status = "O AMIGO SAIU DA SALA"


func _items() -> Array[String]:
	match screen:
		Screen.MENU:
			return MENU_ITEMS
		Screen.ROOM:
			return ROOM_ITEMS
		Screen.MESSAGE:
			return ["VOLTAR"]
		Screen.LOBBY:
			return LOBBY_HOST_ITEMS if Online.is_host else LOBBY_GUEST_ITEMS
		Screen.INVITE:
			var names: Array[String] = []
			for f in _friends:
				names.append(f.name)
			names.append("VOLTAR")
			return names
	return []


## Teclado no campo do código: letras/números, Apagar e colar (Cmd+V / Ctrl+V).
func _input(event: InputEvent) -> void:
	if not visible or screen != Screen.CODE or not (event is InputEventKey) or not event.pressed:
		return
	if event.keycode == KEY_V and event.is_command_or_control_pressed():
		_paste_code()
		get_viewport().set_input_as_handled()
		return
	var ch := String.chr(event.unicode).to_upper() if event.unicode > 0 else ""
	if ch != "" and Online.CODE_CHARS.contains(ch) and code.length() < Online.CODE_LENGTH:
		code += ch
		cursor = mini(code.length(), Online.CODE_LENGTH - 1)
		Sfx.play("ui_move", -6.0)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_BACKSPACE and code.length() > 0:
		code = code.left(code.length() - 1)
		cursor = code.length()
		Sfx.play("ui_move", -6.0)
		get_viewport().set_input_as_handled()


## Cola o código copiado (ex.: do chat): pega só as letras/números válidos, até 6.
func _paste_code() -> void:
	var pasted := ""
	for ch in DisplayServer.clipboard_get().to_upper():
		if Online.CODE_CHARS.contains(ch) and pasted.length() < Online.CODE_LENGTH:
			pasted += ch
	if pasted == "":
		return
	code = pasted
	cursor = mini(code.length(), Online.CODE_LENGTH - 1)
	Sfx.play("ui_move", -6.0)


func _process(_delta: float) -> void:
	if not visible:
		return
	queue_redraw()
	if Engine.get_process_frames() == _opened_frame or Input.is_action_just_pressed("toggle_fullscreen"):
		return
	if screen == Screen.CODE:
		_process_code()
		return
	if InputHint.menu_pressed(&"speed_up", &"ui_up"):
		selected = posmod(selected - 1, _items().size())
		Sfx.play("ui_move", -6.0)
	elif InputHint.menu_pressed(&"slow_down", &"ui_down"):
		selected = posmod(selected + 1, _items().size())
		Sfx.play("ui_move", -6.0)
	elif screen == Screen.LOBBY and _items()[selected] == "PONTOS" and (InputHint.menu_pressed(&"move_left", &"ui_left")
			or InputHint.menu_pressed(&"move_right", &"ui_right")):
		_confirm("PONTOS")
	elif InputHint.menu_pressed(&"shoot", &"ui_accept"):
		Sfx.play("ui_select", -4.0)
		_confirm(_items()[selected])
	elif Input.is_action_just_pressed("ui_cancel") or Input.is_action_just_pressed("pause"):
		Sfx.play("ui_select", -4.0)
		_back()


func _confirm(item: String) -> void:
	if screen == Screen.INVITE:  # pelo índice: um amigo pode se chamar "VOLTAR"
		var friend: Dictionary = _friends[selected] if selected < _friends.size() else {}
		_back()
		if not friend.is_empty():
			var sent := Online.invite_friend(friend.id)
			status = ("CONVITE ENVIADO PARA %s" % _short_name(friend.name, 10)) if sent \
					else "NÃO FOI POSSÍVEL CONVIDAR"
		return
	match item:
		"CRIAR SALA":
			_go(Screen.ROOM)
			if _lan:
				Online.room_code = "LAN"
				Online.host_enet()
			else:
				Online.create_room()
		"ENTRAR COM CÓDIGO":
			_go(Screen.CODE)
			code = ""
			cursor = 0
			if _lan:
				Online.join_enet()  # na rede local não precisa de código
		"COPIAR CÓDIGO":
			if Online.room_code != "" and (Online.lobby_id != 0 or _lan):
				DisplayServer.clipboard_set(Online.room_code)
				_copied_until = Time.get_ticks_msec() + COPIED_MS
		"CONVIDAR AMIGO":
			if Online.lobby_id != 0:
				_friends = Online.online_friends()
				_scroll = 0
				screen = Screen.INVITE  # sem _go: o aviso da sala continua quando voltar
				selected = 0
		"PONTOS":  # saguão, só o anfitrião: juntos <-> separados (o convidado vê na hora)
			Online.set_shared_score(not Online.shared_score)
			Sfx.play("ui_move", -6.0)
		"COMEÇAR PARTIDA":
			Online.start_match()
		"CANCELAR", "VOLTAR", "SAIR DA SALA":
			_back()


## Volta um passo: da sala/código/aviso para o menu (saindo da sala); do menu, fecha.
func _back() -> void:
	if screen == Screen.INVITE:  # volta à sala, que continua aberta (o aviso dela fica)
		screen = Screen.ROOM
		selected = ROOM_ITEMS.find("CONVIDAR AMIGO")
		return
	if screen == Screen.MENU:
		Online.leave()
		hide()
		closed.emit()
		return
	Online.leave()
	_go(Screen.MENU)


func _process_code() -> void:
	var chars := Online.CODE_CHARS
	if Input.is_action_just_pressed("ui_cancel") or Input.is_action_just_pressed("pause"):
		Sfx.play("ui_select", -4.0)
		_back()
	elif InputHint.menu_pressed(&"move_left", &"ui_left"):
		cursor = maxi(cursor - 1, 0)
		Sfx.play("ui_move", -6.0)
	elif InputHint.menu_pressed(&"move_right", &"ui_right"):
		cursor = mini(cursor + 1, mini(code.length(), Online.CODE_LENGTH - 1))
		Sfx.play("ui_move", -6.0)
	elif InputHint.menu_pressed(&"speed_up", &"ui_up") or InputHint.menu_pressed(&"slow_down", &"ui_down"):
		# controle: troca a letra da casa escolhida
		var step := -1 if Input.is_action_just_pressed("speed_up") or Input.is_action_just_pressed("ui_up") else 1
		var current := chars.find(code[cursor]) if cursor < code.length() else -1
		var ch := chars[posmod(current + step, chars.length())]
		code = code.left(cursor) + ch + code.substr(cursor + 1)
		Sfx.play("ui_move", -6.0)
	elif InputHint.menu_pressed(&"shoot", &"ui_accept") and code.length() == Online.CODE_LENGTH:
		Sfx.play("ui_select", -4.0)
		Online.join_by_code(code)


func _draw() -> void:
	# altura conforme a tela (o código grande e o saguão precisam do painel todo)
	var size := PANEL
	if screen == Screen.MENU or screen == Screen.MESSAGE:
		size.y = 136.0
	elif screen == Screen.CODE:
		size.y = 150.0
	var top_left := MenuStyle.panel(self, size, "JOGAR ONLINE")
	var cx := top_left.x + PANEL.x / 2.0
	var blink := Time.get_ticks_msec() % 600 < 400
	var y := top_left.y + MenuStyle.CONTENT_TOP

	if screen == Screen.LOBBY:
		_draw_lobby(top_left, cx, y, blink)
		return
	if screen == Screen.INVITE:
		_draw_invite(top_left, cx, y)
		return
	if screen == Screen.ROOM:
		PixelText.draw_centered(self, "CÓDIGO DA SALA" if Online.room_code != "" else "", cx, y,
				1, MenuStyle.SOFT)
		# código 3x maior (27 px de altura), com 11 px livres acima e abaixo
		if Online.lobby_id != 0 or _lan:
			PixelText.draw_centered(self, Online.room_code, cx, y + 20.0, 3)
		y += 58.0
	elif screen == Screen.CODE:
		PixelText.draw_centered(self, "DIGITE O CÓDIGO DA SALA", cx, y, 1, MenuStyle.SOFT)
		_draw_code_boxes(cx, y + 16.0, blink)
		y += 50.0

	if screen == Screen.ROOM and Time.get_ticks_msec() < _copied_until:
		PixelText.draw_centered(self, "CÓDIGO COPIADO!", cx, y, 1, Palette.YELLOW_LIGHT)
	elif status != "":
		PixelText.draw_centered(self, status, cx, y, 1, MenuStyle.SOFT)
	y += 20.0

	if screen == Screen.CODE:
		var paste := "[%s V] COLA" % ("CMD" if OS.get_name() == "macOS" else "CTRL")
		var hint := ("[ENTER] ENTRA  %s  [ESC] VOLTA" % paste) if not InputHint.using_gamepad \
				else "[A] ENTRA   [B] VOLTA"
		PixelText.draw_centered(self, hint, cx, top_left.y + size.y - 22.0, 1, MenuStyle.SOFT)
		return
	var items := _items()
	for i in items.size():
		MenuStyle.item(self, items[i], cx, y + i * 20.0, i == selected)


## Saguão: código da sala, os dois jogadores (aviãozinho da cor de cada um + nome) e, no
## anfitrião, PONTOS (valor entre setas), COMEÇAR PARTIDA e SAIR DA SALA; no convidado, os
## pontos escolhidos e o aviso de espera.
func _draw_lobby(top_left: Vector2, cx: float, y: float, blink: bool) -> void:
	PixelText.draw_centered(self, "SALA %s" % Online.room_code, cx, y, 1, MenuStyle.SOFT)
	var names := [Online.host_name, Online.guest_name]
	for i in 2:
		var row_y := y + 20.0 + i * 16.0
		var left := cx - 80.0
		draw_texture(LIFE_ICONS[i], Vector2(left, row_y - 1.0))
		PixelText.draw(self, "J%d" % (i + 1), Vector2(left + 16.0, row_y), 1,
				Palette.YELLOW_LIGHT if i == 0 else Palette.LILAC_LIGHT)
		PixelText.draw(self, _short_name(names[i], 22), Vector2(left + 40.0, row_y))
	MenuStyle.divider(self, top_left.x + 20.0, top_left.x + PANEL.x - 20.0, y + 56.0)
	y += 66.0
	# "PONTOS" à esquerda e o valor numa caixinha à direita (só o anfitrião troca)
	var points := "JUNTOS" if Online.shared_score else "SEPARADOS"
	var points_right := top_left.x + PANEL.x - 40.0
	if not Online.is_host:
		PixelText.draw(self, "PONTOS", Vector2(top_left.x + 40.0, y))
		MenuStyle.value(self, points, points_right, y, false)
		PixelText.draw_centered(self, "ESPERANDO O ANFITRIÃO COMEÇAR..." if blink else "", cx, y + 20.0,
				1, MenuStyle.SOFT)
		y += 42.0
	var items := _items()
	for i in items.size():
		var row_y := y + i * 20.0
		var chosen := i == selected
		if items[i] == "PONTOS":
			PixelText.draw(self, "PONTOS", Vector2(top_left.x + 40.0, row_y), 1,
					MenuStyle.SELECTED if chosen else Color.WHITE)
			MenuStyle.value(self, points, points_right, row_y, chosen)
		else:
			MenuStyle.item(self, items[i], cx, row_y, chosen)


## Lista de convite: até INVITE_ROWS amigos (rola acompanhando a escolha, com setinhas quando
## há mais acima/abaixo), "NO JOGO" em quem já está com o jogo aberto e VOLTAR fixo embaixo.
func _draw_invite(top_left: Vector2, cx: float, y: float) -> void:
	var title := "ESCOLHA O AMIGO" if not _friends.is_empty() else "NENHUM AMIGO ONLINE"
	PixelText.draw_centered(self, title, cx, y, 1, MenuStyle.SOFT)
	if selected < _friends.size():
		_scroll = clampi(_scroll, selected - INVITE_ROWS + 1, selected)
	var right := top_left.x + PANEL.x - 20.0
	for row in mini(INVITE_ROWS, _friends.size() - _scroll):
		var i := _scroll + row
		var row_y := y + 20.0 + row * 18.0
		MenuStyle.item(self, _short_name(_friends[i].name, 18), cx, row_y, i == selected)
		if _friends[i].playing:
			PixelText.draw(self, "NO JOGO", Vector2(right - PixelText.width("NO JOGO"), row_y), 1,
					MenuStyle.SOFT)
	# setinhas de "tem mais" (triângulos de 5 px) à esquerda da lista
	var arrow_x := top_left.x + 20.0
	if _scroll > 0:
		_draw_triangle(Vector2(arrow_x, y + 20.0), true)
	if _scroll + INVITE_ROWS < _friends.size():
		_draw_triangle(Vector2(arrow_x, y + 20.0 + (INVITE_ROWS - 1) * 18.0 + 6.0), false)
	var back_y := y + 20.0 + INVITE_ROWS * 18.0 + 6.0
	MenuStyle.divider(self, top_left.x + 20.0, right, back_y - 8.0)
	MenuStyle.item(self, "VOLTAR", cx, back_y, selected == _friends.size())


## Triângulo de 5 px de largura apontando para cima ou para baixo, a partir de `pos` (topo).
func _draw_triangle(pos: Vector2, up: bool) -> void:
	for k in 3:
		var w := 1 + k * 2 if up else 5 - k * 2
		draw_rect(Rect2(pos.x + 2.0 - (w - 1) / 2.0, pos.y + k, w, 1), MenuStyle.SOFT)


## Nome para a tela: só o que a fonte tem (um "[" viraria tecla), cortado em `max_len`;
## sem nada legível vira "AMIGO".
func _short_name(text: String, max_len: int) -> String:
	const NO_ACCENT := {"Á": "A", "À": "A", "Â": "A", "Ä": "A", "É": "E", "È": "E", "Ê": "E",
			"Ë": "E", "Í": "I", "Ì": "I", "Î": "I", "Ï": "I", "Ò": "O", "Ô": "O", "Ö": "O",
			"Ú": "U", "Ù": "U", "Û": "U", "Ü": "U", "Ñ": "N"}
	var out := ""
	for ch in text.to_upper():
		ch = NO_ACCENT.get(ch, ch)  # acentos que a fonte não tem viram a letra sem acento
		if PixelText.CHARSET.contains(ch) and out.length() < max_len:
			out += ch
	return out.strip_edges() if out.strip_edges() != "" else "AMIGO"


## As 6 casas do código: letra digitada ou traço; a casa do cursor pisca (no controle).
func _draw_code_boxes(cx: float, y: float, blink: bool) -> void:
	const BOX := Vector2(16, 18)
	var total := Online.CODE_LENGTH * (BOX.x + 4.0) - 4.0
	for i in Online.CODE_LENGTH:
		var pos := Vector2(cx - total / 2.0 + i * (BOX.x + 4.0), y)
		draw_rect(Rect2(pos, BOX), Palette.OUTLINE)
		draw_rect(Rect2(pos + Vector2.ONE, BOX - Vector2(2, 2)), Palette.BLUE)
		if i == cursor and blink:  # casa do cursor com borda amarela piscando
			draw_rect(Rect2(pos + Vector2.ONE, BOX - Vector2(2, 2)), MenuStyle.SELECTED)
			draw_rect(Rect2(pos + Vector2(2, 2), BOX - Vector2(4, 4)), Palette.BLUE)
		var ch := code[i] if i < code.length() else "-"
		PixelText.draw_centered(self, ch, pos.x + BOX.x / 2.0, pos.y + 5.0)
