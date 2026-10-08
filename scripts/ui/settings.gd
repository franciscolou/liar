class_name Settings
extends RefCounted
## The player's preferences (volumes, language, name in a room), kept in
## user://settings.cfg.
## Every screen calls ensure_loaded() first, so they apply whichever scene
## the game starts on.

const PATH := "user://settings.cfg"
const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"

static var music := 1.0  # 0..1
static var sfx := 1.0  # 0..1
static var language := Loc.DEFAULT
## Who the player is in a room, and the last room they joined.
static var player_name := "Player"
static var last_address := ""
static var _loaded := false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var file := ConfigFile.new()
	if file.load(PATH) == OK:
		music = clampf(float(file.get_value("audio", "music", music)), 0.0, 1.0)
		sfx = clampf(float(file.get_value("audio", "sfx", sfx)), 0.0, 1.0)
		language = str(file.get_value("game", "language", language))
		player_name = str(file.get_value("room", "name", player_name))
		last_address = str(file.get_value("room", "address", last_address))
	if not Loc.LANGUAGES.has(language):
		language = Loc.DEFAULT
	_apply_volume(MUSIC_BUS, music)
	_apply_volume(SFX_BUS, sfx)
	Loc.set_language(language)


static func set_music(value: float) -> void:
	music = clampf(value, 0.0, 1.0)
	_apply_volume(MUSIC_BUS, music)


static func set_sfx(value: float) -> void:
	sfx = clampf(value, 0.0, 1.0)
	_apply_volume(SFX_BUS, sfx)


## Takes effect at once: every node in the tree gets
## NOTIFICATION_TRANSLATION_CHANGED.
static func set_language(code: String) -> void:
	language = code if Loc.LANGUAGES.has(code) else Loc.DEFAULT
	Loc.set_language(language)


static func save() -> void:
	var file := ConfigFile.new()
	file.set_value("audio", "music", music)
	file.set_value("audio", "sfx", sfx)
	file.set_value("game", "language", language)
	file.set_value("room", "name", player_name)
	file.set_value("room", "address", last_address)
	file.save(PATH)


## The buses are created here instead of in a bus layout resource.
static func _apply_volume(bus: StringName, value: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index == -1:
		index = AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, bus)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.001)))
	AudioServer.set_bus_mute(index, value <= 0.0)
