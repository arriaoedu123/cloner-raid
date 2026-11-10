class_name SaveData
## Dados salvos no computador do jogador: recorde (e, depois, as opções do menu).
## Arquivo: user://save.cfg — no macOS fica em
## ~/Library/Application Support/Godot/app_userdata/<nome do projeto>/save.cfg

## Caminho do arquivo (os testes trocam por outro para não mexer no recorde de verdade)
static var path := "user://save.cfg"


static func load_value(section: String, key: String, default: Variant) -> Variant:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return default  # ainda não existe (primeira vez jogando)
	return cfg.get_value(section, key, default)


static func save_value(section: String, key: String, value: Variant) -> void:
	var cfg := ConfigFile.new()
	cfg.load(path)  # mantém o que já estava salvo
	cfg.set_value(section, key, value)
	var err := cfg.save(path)
	if err != OK:
		push_warning("Não consegui salvar em %s (erro %d)" % [path, err])
