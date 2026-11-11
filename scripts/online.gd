class_name Online
extends Node
## Coop online: pela Steam (GodotSteam, AppID 480 "Spacewar", sem publicar o jogo) ou, só para
## testes, pela rede local (ENet). Fluxo: o anfitrião cria a sala (lobby INVISÍVEL da Steam:
## não aparece em listas, mas é achado por quem sabe o código curto) → o amigo entra pelo
## código ou pelo convite da Steam → o anfitrião (peer 1 = jogador 1) manda a semente do rio
## e os dois abrem a partida.
##
## A Steam só é ligada quando alguém escolhe JOGAR ONLINE (offline ninguém vira "Spacewar").
## Tudo é estático; o nó /root/Online (criado por `Online.node()`) existe para ter sinais e
## RPCs no mesmo caminho nos dois computadores. A Steam é acessada pelo singleton "Steam" via
## Object, para o jogo abrir mesmo se o plug-in faltar numa plataforma.

## Mensagem para a tela da sala ("" = sem mensagem)
signal status_changed(text: String)
## A partida começou (a cena já está trocando)
signal match_started
## Saguão: os dois se apresentaram (nome e pontos já chegaram); a tela mostra o saguão
signal lobby_ready
## Saguão: o anfitrião trocou pontos juntos/separados (o convidado atualiza a tela)
signal lobby_changed
## Saguão: o convidado saiu antes de começar (o anfitrião volta a esperar na sala)
signal friend_left
## Saguão: o anfitrião fechou a sala antes de começar (o convidado vê o aviso)
signal room_closed(message: String)

const APP_ID := 480
const GAME_TAG := "clonerraid"
## Os dois precisam rodar a mesma versão: o rio sai igual pela semente só com o mesmo código
const VERSION := "1.2.0"
## Letras do código da sala (sem I, O, 0 e 1, que se confundem)
const CODE_CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const CODE_LENGTH := 6
const ENET_PORT := 24680

# Constantes da Steam (números, para não depender do plug-in na hora de ler o script)
const LOBBY_TYPE_INVISIBLE := 3
const LOBBY_COMPARISON_EQUAL := 0
const LOBBY_DISTANCE_WORLDWIDE := 3
const ENTER_RESPONSE_SUCCESS := 1
const FRIEND_FLAG_IMMEDIATE := 4  # amigos de verdade (não pedidos, bloqueados etc.)
const PERSONA_OFFLINE := 0

## Em partida online agora
static var active := false
static var is_host := false
## Semente do rio e pontos juntos/separados da partida (escolhas do anfitrião)
static var seed := 0
static var shared_score := true
## Aviso para mostrar no título depois de a conexão cair ("" = nada)
static var last_message := ""
## Nomes no saguão: J1 = anfitrião, J2 = convidado (nome da Steam, ou "JOGADOR 1/2" na rede local)
static var host_name := ""
static var guest_name := ""
static var room_code := ""
static var lobby_id := 0
static var steam_ready := false
static var _steam_tried := false
static var _node: Online
## Pediu para entrar numa sala (por código ou convite): só aí "entrou na sala" vira conexão
static var _joining := false
## A Steam leva alguns segundos para uma sala nova aparecer na busca: tenta de novo algumas vezes
const SEARCH_TRIES := 6
const SEARCH_RETRY_DELAY := 1.5
static var _search_tries := 0


## O nó /root/Online (cria na primeira vez).
static func node() -> Online:
	if not is_instance_valid(_node):
		_node = Online.new()
		_node.name = "Online"
		_node.process_mode = Node.PROCESS_MODE_ALWAYS
		(Engine.get_main_loop() as SceneTree).root.add_child(_node)
	return _node


static func steam() -> Object:
	return Engine.get_singleton("Steam") if Engine.has_singleton("Steam") else null


## Liga a Steam com o AppID 480 (uma vez). false = Steam fechada ou plug-in ausente.
static func init_steam() -> bool:
	if _steam_tried:
		return steam_ready
	_steam_tried = true
	var s := steam()
	if s == null:
		return false
	var result: Dictionary = s.call("steamInitEx", APP_ID, true)  # true: callbacks automáticos
	steam_ready = result.get("status", 1) == 0
	if steam_ready:
		node()._connect_steam_signals()
	return steam_ready


## Cria a sala na Steam: o código aparece quando a Steam confirmar (status_changed).
static func create_room() -> void:
	is_host = true
	room_code = ""
	for i in CODE_LENGTH:
		room_code += CODE_CHARS[randi() % CODE_CHARS.length()]
	node().status_changed.emit("CRIANDO SALA...")
	steam().call("createLobby", LOBBY_TYPE_INVISIBLE, 2)


## Procura a sala com esse código e entra nela.
static func join_by_code(code: String) -> void:
	is_host = false
	_joining = true
	room_code = code.to_upper()
	_search_tries = 0
	node().status_changed.emit("PROCURANDO SALA...")
	_request_lobby_list()


static func _request_lobby_list() -> void:
	_search_tries += 1
	var s := steam()
	s.call("addRequestLobbyListStringFilter", "game", GAME_TAG, LOBBY_COMPARISON_EQUAL)
	s.call("addRequestLobbyListStringFilter", "code", room_code, LOBBY_COMPARISON_EQUAL)
	s.call("addRequestLobbyListDistanceFilter", LOBBY_DISTANCE_WORLDWIDE)
	s.call("addRequestLobbyListResultCountFilter", 1)
	s.call("requestLobbyList")


## Amigos da Steam que estão online, para a lista de convite: [{id, name, playing}], quem está
## com o jogo aberto (AppID 480) primeiro, depois por nome. Não usa a janela da Steam por cima
## do jogo: ela só funciona se a Steam abrir o jogo, e o Cloner Raid é aberto direto.
static func online_friends() -> Array:
	var list := []
	if not steam_ready:
		return list
	var s := steam()
	for i in int(s.call("getFriendCount", FRIEND_FLAG_IMMEDIATE)):
		var id: int = s.call("getFriendByIndex", i, FRIEND_FLAG_IMMEDIATE)
		if int(s.call("getFriendPersonaState", id)) == PERSONA_OFFLINE:
			continue
		var game: Dictionary = s.call("getFriendGamePlayed", id)
		list.append({"id": id, "name": str(s.call("getFriendPersonaName", id)).to_upper(),
				"playing": int(game.get("id", 0)) == APP_ID})
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.playing if a.playing != b.playing else a.name < b.name)
	return list


## Manda o convite da sala para o amigo (ele recebe no chat da Steam; aceitando com o jogo
## aberto, entra direto pelo `join_requested`).
static func invite_friend(friend_id: int) -> bool:
	if steam_ready and lobby_id != 0:
		return steam().call("inviteUserToLobby", lobby_id, friend_id)
	return false


## Testes na rede local (sem Steam): um jogo é o anfitrião, o outro conecta em `address`.
static func host_enet() -> void:
	is_host = true
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(ENET_PORT, 1)
	node()._use_peer(peer)
	node().status_changed.emit("ESPERANDO O AMIGO...")


static func join_enet(address: String = "127.0.0.1") -> void:
	is_host = false
	var peer := ENetMultiplayerPeer.new()
	peer.create_client(address, ENET_PORT)
	node()._use_peer(peer)
	node().status_changed.emit("CONECTANDO...")


## Sai da sala/partida e desliga a rede (volta ao modo offline).
static func leave() -> void:
	_joining = false
	host_name = ""
	guest_name = ""
	if steam_ready and lobby_id != 0:
		steam().call("leaveLobby", lobby_id)
	lobby_id = 0
	active = false
	Game.online = false
	var tree := Engine.get_main_loop() as SceneTree
	if tree.get_multiplayer().multiplayer_peer:
		tree.get_multiplayer().multiplayer_peer.close()
	tree.get_multiplayer().multiplayer_peer = null


# --- Nó: sinais da Steam, conexão e início da partida ---------------------------------------

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.connection_failed.connect(func(): status_changed.emit("NÃO CONSEGUIU CONECTAR"))


func _connect_steam_signals() -> void:
	var s := steam()
	s.connect("lobby_created", _on_lobby_created)
	s.connect("lobby_match_list", _on_lobby_match_list)
	s.connect("lobby_joined", _on_lobby_joined)
	s.connect("join_requested", _on_join_requested)


func _use_peer(peer: MultiplayerPeer) -> void:
	multiplayer.multiplayer_peer = peer


func _on_lobby_created(result: int, new_lobby_id: int) -> void:
	if result != 1:
		status_changed.emit("ERRO AO CRIAR SALA")
		return
	lobby_id = new_lobby_id
	var s := steam()
	s.call("setLobbyData", lobby_id, "game", GAME_TAG)
	s.call("setLobbyData", lobby_id, "code", room_code)
	s.call("setLobbyData", lobby_id, "version", VERSION)
	var peer: MultiplayerPeer = ClassDB.instantiate("SteamMultiplayerPeer")
	peer.call("create_host", 0)
	_use_peer(peer)
	status_changed.emit("ESPERANDO O AMIGO...")


func _on_lobby_match_list(lobbies: Array) -> void:
	if not _joining:
		return
	if lobbies.is_empty():
		if _search_tries < SEARCH_TRIES:
			await get_tree().create_timer(SEARCH_RETRY_DELAY).timeout
			if _joining:
				_request_lobby_list()
			return
		_joining = false
		status_changed.emit("SALA NÃO ENCONTRADA")
		return
	steam().call("joinLobby", lobbies[0])


## Aceitou um convite pela Steam com o jogo aberto.
func _on_join_requested(new_lobby_id: int, _friend_id: int) -> void:
	is_host = false
	_joining = true
	status_changed.emit("ENTRANDO NA SALA...")
	steam().call("joinLobby", new_lobby_id)


func _on_lobby_joined(joined_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if is_host or not _joining:
		return  # o anfitrião também "entra" na própria sala
	_joining = false
	if response != ENTER_RESPONSE_SUCCESS:
		status_changed.emit("NÃO CONSEGUIU ENTRAR")
		return
	lobby_id = joined_id
	var s := steam()
	if s.call("getLobbyData", lobby_id, "version") != VERSION:
		s.call("leaveLobby", lobby_id)
		lobby_id = 0
		status_changed.emit("VERSÃO DIFERENTE DO JOGO")
		return
	room_code = s.call("getLobbyData", lobby_id, "code")
	var peer: MultiplayerPeer = ClassDB.instantiate("SteamMultiplayerPeer")
	peer.call("create_client", s.call("getLobbyOwner", lobby_id), 0)
	_use_peer(peer)
	status_changed.emit("CONECTANDO...")


## Nome deste jogador para o saguão (o da Steam, em maiúsculas; na rede local, "JOGADOR n").
static func my_name() -> String:
	if steam_ready:
		return str(steam().call("getPersonaName")).to_upper()
	return "JOGADOR 1" if is_host else "JOGADOR 2"


## Saguão: o anfitrião troca pontos juntos/separados e avisa o convidado.
static func set_shared_score(value: bool) -> void:
	shared_score = value
	Settings.coop_shared_score = value  # vira também a preferência salva do anfitrião
	Settings.save()
	node()._lobby_settings.rpc(value)


## Saguão: o anfitrião manda começar (semente nova para o rio).
static func start_match() -> void:
	node()._start_match.rpc(randi(), shared_score)


## Conectou: o convidado se apresenta ao anfitrião (a partida só começa no COMEÇAR PARTIDA).
func _on_peer_connected(id: int) -> void:
	if not multiplayer.is_server() and id == 1:
		_hello.rpc_id(1, my_name())


## Convidado → anfitrião: o nome dele. O anfitrião responde com o próprio nome e os pontos.
@rpc("any_peer", "reliable")
func _hello(name_of_guest: String) -> void:
	guest_name = name_of_guest
	host_name = my_name()
	shared_score = Settings.coop_shared_score
	_welcome.rpc_id(multiplayer.get_remote_sender_id(), host_name, shared_score, room_code)
	lobby_ready.emit()


@rpc("authority", "reliable")
func _welcome(name_of_host: String, shared: bool, code: String) -> void:
	host_name = name_of_host
	guest_name = my_name()
	shared_score = shared
	room_code = code  # na rede local o convidado não sabe o código sozinho
	lobby_ready.emit()


@rpc("authority", "reliable")
func _lobby_settings(shared: bool) -> void:
	shared_score = shared
	lobby_changed.emit()


@rpc("authority", "call_local", "reliable")
func _start_match(match_seed: int, shared_score_choice: bool) -> void:
	seed = match_seed
	shared_score = shared_score_choice
	active = true
	Game.two_players = true
	Game.online = true
	match_started.emit()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


## Os avisos de desconexão chegam no meio do processamento da rede: fechar a conexão ali
## dentro derruba o jogo. Por isso a saída é adiada para depois (call_deferred).
## Antes de a partida começar (saguão) ninguém volta ao título: o anfitrião continua com a
## sala aberta esperando outro amigo, e o convidado vê o aviso na tela online.
func _on_peer_disconnected(_id: int) -> void:
	if active:
		_back_to_title.call_deferred("O AMIGO SAIU DA PARTIDA")
	else:
		guest_name = ""
		friend_left.emit()


func _on_server_disconnected() -> void:
	if active:
		_back_to_title.call_deferred("O ANFITRIÃO SAIU DA PARTIDA")
	else:
		_close_room.call_deferred("O ANFITRIÃO FECHOU A SALA")


func _close_room(message: String) -> void:
	leave()
	room_closed.emit(message)


## Conexão perdida: volta ao título com o aviso (mostrado pela tela da sala).
func _back_to_title(message: String) -> void:
	last_message = message
	leave()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/title.tscn")
