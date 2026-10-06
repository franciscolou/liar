class_name Loc
extends RefCounted
## Languages and text lookup. The English text in the code is also the
## translation key, so an untranslated string simply shows up in English.
##
## A language is a script with a MESSAGES dictionary (English -> translated).
## Text shown as-is by a Label or Button is translated by Godot itself; text
## that gets formatted or goes into BBCode has to pass through Loc.t() first:
## Loc.t("%s buys %s.") % [...]. A placeholder order can't change between
## languages, so word the translation around it.

const DEFAULT := "en"
## code -> name shown in the settings screen.
const LANGUAGES := {"en": "English", "pt_BR": "Português"}
const TABLES := {"pt_BR": "res://scripts/locale/pt_br.gd"}

static var _current := DEFAULT
static var _registered: Dictionary = {}


static func t(text: String) -> String:
	return String(TranslationServer.translate(text))


static func language() -> String:
	return _current


static func set_language(code: String) -> void:
	if not LANGUAGES.has(code):
		code = DEFAULT
	if TABLES.has(code) and not _registered.has(code):
		_registered[code] = true
		var messages: Dictionary = (load(TABLES[code]) as GDScript).get_script_constant_map()["MESSAGES"]
		var translation := Translation.new()
		translation.locale = code
		for key: String in messages:
			translation.add_message(key, messages[key])
		TranslationServer.add_translation(translation)
	_current = code
	TranslationServer.set_locale(code)
