## Finds the game's sounds by name. They live in assets/sounds/, in a folder
## per character or concept (the ones used in more than one place at the
## root), and the game asks for them by the file name alone: "fx_dig", not
## "gravedigger/fx_dig.wav". Moving a sound to another folder needs no change
## in the code.

const ROOT := "res://assets/sounds/"
## Tried in this order when two files share a name.
const EXTENSIONS: Array[String] = ["wav", "mp3"]
## How far below the others (in dB) a sound is played. The .wav of
## tools/gen_sfx.py are levelled as they are made; a recording dropped in as
## it came is brought down here instead of being edited.
const LEVELS := {
	# The Necromancer's voices, under the skull and the soul.
	"retaliation": -6.0,
	"drain": -7.0,
	# The cord of blood shooting out and torn through.
	"carnage": -4.0,
	"carnage2": -4.0,
}

static var _paths: Dictionary = {}


## The path of the sound called `sound`, or "" if there is none.
static func path(sound: String) -> String:
	if _paths.is_empty():
		_index(ROOT)
	return _paths.get(sound, "")


## The sound called `sound`, or null. A .wav the editor has not imported yet
## is read from the file directly.
static func stream(sound: String) -> AudioStream:
	var at := path(sound)
	if at == "":
		return null
	if ResourceLoader.exists(at):
		return load(at)
	if at.get_extension() == "wav" and FileAccess.file_exists(at):
		return AudioStreamWAV.load_from_file(at)
	return null


static func _index(dir: String) -> void:
	for file: String in DirAccess.get_files_at(dir):
		# In an exported build only the .import (or .remap) is left of the file.
		file = file.trim_suffix(".import").trim_suffix(".remap")
		var rank := EXTENSIONS.find(file.get_extension())
		if rank < 0:
			continue
		var sound := file.get_basename()
		var known: String = _paths.get(sound, "")
		if known == "" or rank < EXTENSIONS.find(known.get_extension()):
			_paths[sound] = dir + file
	for folder: String in DirAccess.get_directories_at(dir):
		_index(dir + folder + "/")


## The volume, in dB, to play the sound called `sound` at (see LEVELS).
static func level(sound: String) -> float:
	return LEVELS.get(sound, 0.0)
