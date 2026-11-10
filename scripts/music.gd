extends Node
## Trilha sonora em camadas (geradas por tools/audio/music.py), tocando sempre juntas:
## base o tempo todo, melodia a partir de `lead_from_section`, bateria a partir de
## `drums_from_section`. Cada camada entra/sai com o volume subindo/descendo aos poucos.
## No fim de jogo a música toda abaixa.

## Partida (para saber a seção atual e o fim de jogo)
@export var game: Game
## Volume geral da música (dB) — abaixo dos efeitos, para eles se destacarem
@export var volume_db := -8.0
## Seção em que entra a melodia (1 = depois da primeira ponte)
@export var lead_from_section := 1
## Seção em que entra a bateria
@export var drums_from_section := 4
## Quantos dB por segundo o volume de uma camada muda ao entrar/sair
@export var fade_db_per_second := 30.0

const LAYERS: Array[AudioStream] = [
	preload("res://assets/audio/music/theme_base.wav"),
	preload("res://assets/audio/music/theme_lead.wav"),
	preload("res://assets/audio/music/theme_drums.wav"),
]
const SILENT_DB := -60.0
const GAME_OVER_DUCK_DB := -12.0
const PAUSE_DUCK_DB := -10.0

var _stream := AudioStreamSynchronized.new()
var _player := AudioStreamPlayer.new()
var _layer_db: Array[float] = [0.0, SILENT_DB, SILENT_DB]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # continua tocando (mais baixo) com o jogo pausado
	_stream.stream_count = LAYERS.size()
	for i in LAYERS.size():
		_stream.set_sync_stream(i, LAYERS[i])
		_stream.set_sync_stream_volume(i, _layer_db[i])
	_player.stream = _stream
	_player.bus = &"Music"
	_player.volume_db = volume_db
	add_child(_player)
	_player.play()


func _process(delta: float) -> void:
	if game == null:
		return
	var section := game.current_section()
	var targets: Array[float] = [
		0.0,
		0.0 if section >= lead_from_section else SILENT_DB,
		0.0 if section >= drums_from_section else SILENT_DB,
	]
	for i in targets.size():
		_layer_db[i] = move_toward(_layer_db[i], targets[i], fade_db_per_second * delta)
		_stream.set_sync_stream_volume(i, _layer_db[i])
	var overall := volume_db + (GAME_OVER_DUCK_DB if game.is_game_over else 0.0)
	if get_tree().paused:
		overall += PAUSE_DUCK_DB
	_player.volume_db = move_toward(_player.volume_db, overall, fade_db_per_second * delta)


## Volume atual de cada camada (dB), para testes/depuração
func layer_volumes() -> Array[float]:
	return _layer_db.duplicate()
