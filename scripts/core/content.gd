class_name Content
extends RefCounted
## Registry of characters and items. Content is discovered by scanning the
## two folders below, so adding a character or item is adding one script.

const CHARACTER_DIR := "res://scripts/content/characters"
const ITEM_DIR := "res://scripts/content/items"

static var characters: Dictionary = {}  # id -> CharacterDef
static var abilities: Dictionary = {}  # id -> Ability
static var items: Dictionary = {}  # id -> ItemDef
static var statuses: Dictionary = {}  # id -> {name, description, color}
static var counters: Dictionary = {}  # id -> {name, description, icon}
static var _loaded := false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	for def in _instantiate_all(CHARACTER_DIR):
		if def is CharacterDef:
			characters[def.id] = def
			for ability in def.abilities:
				ability.character_id = def.id
				abilities[ability.id] = ability
			statuses.merge(def.status_defs)
			counters.merge(def.counter_defs)
	for def in _instantiate_all(ITEM_DIR):
		if def is ItemDef:
			items[def.id] = def
			statuses.merge(def.status_defs)


static func character_list() -> Array:
	ensure_loaded()
	var list := characters.values()
	list.sort_custom(func(a, b): return a.order < b.order if a.order != b.order else String(a.id) < String(b.id))
	return list


static func item_list() -> Array:
	ensure_loaded()
	var list := items.values()
	# Ties go by id, not by name: the name is translated, and every machine of
	# a room has to list the items in the same order whatever its language.
	list.sort_custom(func(a, b): return a.price < b.price if a.price != b.price else String(a.id) < String(b.id))
	return list


static func character(character_id: StringName) -> CharacterDef:
	ensure_loaded()
	return characters.get(character_id)


static func _instantiate_all(dir: String) -> Array:
	var out := []
	var files := Array(ResourceLoader.list_directory(dir))
	files.sort()
	for file in files:
		if not file.ends_with(".gd"):
			continue
		var script := load(dir + "/" + file) as GDScript
		if script != null:
			out.append(script.new())
	return out
