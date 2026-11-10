class_name Settings
## Opções do jogador (tela cheia, volumes, tremor de tela): guardadas no SaveData,
## seção "options", e aplicadas ao Godot com `Settings.apply()`.

const MAX_LEVEL := 10  # volumes vão de 0 (mudo) a 10 (máximo)

static var fullscreen := false
static var music_level := 8
static var sfx_level := 8
static var screen_shake := true
## Coop: pontos juntos (um placar do time) ou separados (um placar por jogador)
static var coop_shared_score := true

static var _loaded := false


## Carrega do arquivo (só na primeira vez) e aplica tudo. Chame no _ready das cenas.
static func load_and_apply() -> void:
	if not _loaded:
		_loaded = true
		fullscreen = SaveData.load_value("options", "fullscreen", fullscreen)
		music_level = SaveData.load_value("options", "music_level", music_level)
		sfx_level = SaveData.load_value("options", "sfx_level", sfx_level)
		screen_shake = SaveData.load_value("options", "screen_shake", screen_shake)
		coop_shared_score = SaveData.load_value("options", "coop_shared_score", coop_shared_score)
		Controls.load_saved()  # teclas/botões remapeados pelo jogador
	InputHint.watch()  # dicas na tela seguem o dispositivo em uso (teclado ou controle)
	apply()


static func apply() -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
	_set_bus_level(&"Music", music_level)
	_set_bus_level(&"SFX", sfx_level)
	Effects.shake_enabled = screen_shake


static func save() -> void:
	SaveData.save_value("options", "fullscreen", fullscreen)
	SaveData.save_value("options", "music_level", music_level)
	SaveData.save_value("options", "sfx_level", sfx_level)
	SaveData.save_value("options", "screen_shake", screen_shake)
	SaveData.save_value("options", "coop_shared_score", coop_shared_score)


static func toggle_fullscreen() -> void:
	fullscreen = not fullscreen
	apply()
	save()


static func _set_bus_level(bus_name: StringName, level: int) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus < 0:
		return
	AudioServer.set_bus_mute(bus, level <= 0)
	AudioServer.set_bus_volume_db(bus, linear_to_db(float(level) / MAX_LEVEL) if level > 0 else -80.0)
