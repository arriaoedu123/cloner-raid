class_name Sfx
extends Node
## Efeitos sonoros: `Sfx.play("shoot")` de qualquer lugar.
## Os sons são gerados por tools/audio/sfx.py e tocam no canal de áudio "SFX".
## Na primeira vez que é usado, cria sozinho um nó com um grupo de players que se revezam
## (vários sons ao mesmo tempo). Não é autoload de propósito: assim funciona também nos
## testes rodados com --script.

const SOUNDS := {
	"shoot": preload("res://assets/audio/sfx/shoot.wav"),
	"hit": preload("res://assets/audio/sfx/hit.wav"),
	"explosion_small": preload("res://assets/audio/sfx/explosion_small.wav"),
	"explosion_big": preload("res://assets/audio/sfx/explosion_big.wav"),
	"refuel": preload("res://assets/audio/sfx/refuel.wav"),
	"low_fuel": preload("res://assets/audio/sfx/low_fuel.wav"),
	"extra_life": preload("res://assets/audio/sfx/extra_life.wav"),
	"ui_move": preload("res://assets/audio/sfx/ui_move.wav"),
	"ui_select": preload("res://assets/audio/sfx/ui_select.wav"),
	"power_up": preload("res://assets/audio/sfx/power_up.wav"),
	"shield_break": preload("res://assets/audio/sfx/shield_break.wav"),
}
const VOICES := 12  # sons que podem tocar ao mesmo tempo

static var _instance: Sfx

var _players: Array[AudioStreamPlayer] = []
var _next := 0


## Toca um som. `pitch` muda o tom (1 = normal); `jitter` sorteia uma variação em volta dele
## (evita que sons repetidos, como o tiro, fiquem cansativos).
static func play(sound: String, volume_db: float = 0.0, pitch: float = 1.0, jitter: float = 0.0) -> void:
	var inst := _get_instance()
	if inst:
		inst._play(sound, volume_db, pitch, jitter)


## Cria o nó de áudio já no começo da partida, para o primeiro som não se perder.
static func warm_up() -> void:
	_get_instance()


static func _get_instance() -> Sfx:
	if not is_instance_valid(_instance):
		_instance = Sfx.new()
		_instance.name = "Sfx"
		var tree := Engine.get_main_loop() as SceneTree
		tree.root.add_child.call_deferred(_instance)
	# no primeiro frame ele ainda está entrando na árvore: esse som é ignorado
	return _instance if _instance.is_inside_tree() else null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # continua tocando durante o congelamento/pausa
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_players.append(p)


func _play(sound: String, volume_db: float, pitch: float, jitter: float) -> void:
	var stream: AudioStream = SOUNDS.get(sound)
	if stream == null:
		push_warning("Som desconhecido: %s" % sound)
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch * (1.0 + randf_range(-jitter, jitter))
	p.play()
