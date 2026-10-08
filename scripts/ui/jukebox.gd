extends Node
## The music. One node hung on the root, so a track keeps playing across
## scene changes and one track can fade into the next instead of being cut.
## Every screen says what it wants on entering: `Jukebox.play(Jukebox.LOBBY)`.
## Asking for the track that is already on does nothing.
##
## No class_name: use preload.

const NODE_NAME := "Jukebox"
## Everything before the cards are dealt.
const LOBBY := &"lobby"
## The end screen.
const ENDING := &"ending"
## The match.
const MATCH := &"match"
## Nothing: fades out whatever is on.
const SILENCE := &""
const TRACKS := {
	LOBBY: {"path": "res://assets/sounds/ES_Five Miles High - Guto Lucena.mp3", "db": -8.0},
	ENDING: {"path": "res://assets/sounds/ES_Epic Triumph - Elm Lake.mp3", "db": -8.0},
	MATCH: {"path": "res://assets/sounds/background.mp3", "db": -10.0},
}
## Seconds one track takes to give way to the next.
const FADE := 2.0

var _players: Dictionary = {}  # track -> AudioStreamPlayer
var _fades: Dictionary = {}  # track -> Tween
var _current := SILENCE
var _fade := FADE


## Fades to `track` over `fade` seconds.
static func play(track: StringName, fade := FADE) -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var box: Node = root.get_node_or_null(NODE_NAME)
	if box == null:
		box = new()
		box.name = NODE_NAME
		# The root is busy while a scene is on its way in.
		root.add_child.call_deferred(box)
	box._switch(track, fade)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var wanted := _current
	_current = SILENCE
	_switch(wanted, _fade)


func _switch(track: StringName, fade: float) -> void:
	if not is_inside_tree():
		_current = track
		_fade = fade
		return
	if track == _current:
		return
	_current = track
	if track != SILENCE and not _players.has(track):
		_players[track] = _load(track)
	for id: StringName in _players:
		var player: AudioStreamPlayer = _players[id]
		if player == null:
			continue
		if _fades.has(id):
			_fades[id].kill()
		var tween := create_tween()
		# The table slows time for the last blow; the fades keep their pace.
		tween.set_ignore_time_scale(true)
		_fades[id] = tween
		if id == track:
			if not player.playing:
				player.volume_linear = 0.0
				player.play()
			tween.tween_property(player, "volume_linear", db_to_linear(TRACKS[id].db), fade) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		elif player.playing:
			tween.tween_property(player, "volume_linear", 0.0, fade) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			tween.tween_callback(player.stop)


func _load(track: StringName) -> AudioStreamPlayer:
	var path: String = TRACKS[track].path
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path)
	elif FileAccess.file_exists(path):
		# Not imported yet (the editor has not rescanned): read the file directly.
		stream = AudioStreamMP3.load_from_file(path)
	if stream == null:
		return null
	if stream is AudioStreamMP3:
		stream.loop = true
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = Settings.MUSIC_BUS
	add_child(player)
	return player
