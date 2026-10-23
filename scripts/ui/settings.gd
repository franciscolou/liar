class_name Settings
extends RefCounted
## The player's preferences (volumes, language, fullscreen, name in a room), kept in
## user://settings.cfg.
## Every screen calls ensure_loaded() first, so they apply whichever scene
## the game starts on.

const TouchMode := preload("res://scripts/ui/touch_mode.gd")
const Cursors := preload("res://scripts/ui/cursors.gd")

const PATH := "user://settings.cfg"
const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"
## How loud the music is with its slider at 100%: the tracks sit over the
## sound effects otherwise.
const MUSIC_GAIN := 0.7

static var music := 1.0  # 0..1
static var sfx := 1.0  # 0..1
## Muted, a bus is silent but keeps its volume for when it is heard again.
static var music_muted := false
static var sfx_muted := false
static var language := Loc.DEFAULT
static var fullscreen := false
## Who the player is in a room, and the last room they joined.
static var player_name := "Player"
static var last_address := ""
## The house ranked matches are played on (ranked_api.gd): where it is, if
## not where the game says, and the member signed in there.
static var ranked_url := ""
static var ranked_token := ""
static var ranked_name := ""
static var _loaded := false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	TouchMode.decide()
	Cursors.install()
	var file := ConfigFile.new()
	if file.load(PATH) == OK:
		music = clampf(float(file.get_value("audio", "music", music)), 0.0, 1.0)
		sfx = clampf(float(file.get_value("audio", "sfx", sfx)), 0.0, 1.0)
		music_muted = bool(file.get_value("audio", "music_muted", music_muted))
		sfx_muted = bool(file.get_value("audio", "sfx_muted", sfx_muted))
		language = str(file.get_value("game", "language", language))
		fullscreen = bool(file.get_value("video", "fullscreen", fullscreen))
		player_name = str(file.get_value("room", "name", player_name))
		last_address = str(file.get_value("room", "address", last_address))
		ranked_url = str(file.get_value("ranked", "url", ranked_url))
		ranked_token = str(file.get_value("ranked", "token", ranked_token))
		ranked_name = str(file.get_value("ranked", "name", ranked_name))
	if not Loc.LANGUAGES.has(language):
		language = Loc.DEFAULT
	_apply_volume(MUSIC_BUS, music, music_muted, MUSIC_GAIN)
	_apply_volume(SFX_BUS, sfx, sfx_muted)
	Loc.set_language(language)
	# A window the player left windowed (or maximized) is not touched.
	if fullscreen:
		set_fullscreen(true)


static func set_fullscreen(on: bool) -> void:
	fullscreen = on
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		tree.root.mode = Window.MODE_FULLSCREEN if on else Window.MODE_WINDOWED


static func set_music(value: float) -> void:
	music = clampf(value, 0.0, 1.0)
	_apply_volume(MUSIC_BUS, music, music_muted, MUSIC_GAIN)


static func set_sfx(value: float) -> void:
	sfx = clampf(value, 0.0, 1.0)
	_apply_volume(SFX_BUS, sfx, sfx_muted)


static func set_music_muted(on: bool) -> void:
	music_muted = on
	_apply_volume(MUSIC_BUS, music, music_muted, MUSIC_GAIN)


static func set_sfx_muted(on: bool) -> void:
	sfx_muted = on
	_apply_volume(SFX_BUS, sfx, sfx_muted)


## Takes effect at once: every node in the tree gets
## NOTIFICATION_TRANSLATION_CHANGED.
static func set_language(code: String) -> void:
	language = code if Loc.LANGUAGES.has(code) else Loc.DEFAULT
	Loc.set_language(language)


static func save() -> void:
	var file := ConfigFile.new()
	file.set_value("audio", "music", music)
	file.set_value("audio", "sfx", sfx)
	file.set_value("audio", "music_muted", music_muted)
	file.set_value("audio", "sfx_muted", sfx_muted)
	file.set_value("game", "language", language)
	file.set_value("video", "fullscreen", fullscreen)
	file.set_value("room", "name", player_name)
	file.set_value("room", "address", last_address)
	if ranked_url != "":
		file.set_value("ranked", "url", ranked_url)
	file.set_value("ranked", "token", ranked_token)
	file.set_value("ranked", "name", ranked_name)
	file.save(PATH)


## The buses are created here instead of in a bus layout resource.
static func _apply_volume(bus: StringName, value: float, muted: bool, gain := 1.0) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index == -1:
		index = AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, bus)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value * gain, 0.001)))
	AudioServer.set_bus_mute(index, muted or value <= 0.0)
