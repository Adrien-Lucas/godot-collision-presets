@tool
class_name CollisionPresetsAPI
extends Node
## Static API for loading, querying, and applying collision presets.
##
## All methods are static and safe to call from both editor and game code.
## The database is loaded lazily on first access and re-read whenever the file changes on disk.


static var presets_db_static: CollisionPresetsDatabase
static var _last_modified_time: int = 0
static var _is_checking: bool = false


## Loads the preset database from disk, migrating from legacy locations if needed.
static func _load_static_presets(previous_path: String = "") -> void:
	var path: String = CollisionPresetsConstants.PRESET_DATABASE_PATH

	if presets_db_static == null or FileAccess.get_modified_time(path) > _last_modified_time:
		_is_checking = true

		if not ResourceLoader.exists(path):
			# Check legacy locations and migrate if found.
			var migration_paths: Array[String] = [
				(CollisionPresetsConstants as Script).resource_path.get_base_dir().path_join("presets.tres"),
				"res://collision_presets/presets.tres",
			]

			if not previous_path.is_empty():
				migration_paths.append(previous_path.path_join("presets.tres"))

			var found_old_path: String = ""
			for p: String in migration_paths:
				if p != path and ResourceLoader.exists(p):
					found_old_path = p
					break

			if not found_old_path.is_empty():
				var dir: String = path.get_base_dir()
				if not DirAccess.dir_exists_absolute(dir):
					DirAccess.make_dir_recursive_absolute(dir)

				print("CollisionPresets: Migrating database from ", found_old_path, " to ", path)

				var err: Error = DirAccess.rename_absolute(found_old_path, path)
				if err != OK:
					printerr("CollisionPresets: Failed to migrate database: ", err)
					return

				# Also migrate the generated constants script from the same old directory.
				var old_names_path: String = found_old_path.get_base_dir().path_join("preset_names.gd")
				var new_names_path: String = CollisionPresetsConstants.PRESET_NAMES_PATH
				if FileAccess.file_exists(old_names_path) and old_names_path != new_names_path:
					print("CollisionPresets: Migrating constants script from ", old_names_path, " to ", new_names_path)
					DirAccess.rename_absolute(old_names_path, new_names_path)
			
			else:
				# Ensure the target directory exists for a fresh installation.
				var dir: String = path.get_base_dir()
				if not DirAccess.dir_exists_absolute(dir):
					DirAccess.make_dir_recursive_absolute(dir)

	if ResourceLoader.exists(path):
		presets_db_static = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
		_last_modified_time = FileAccess.get_modified_time(path)
	_is_checking = false


## Checks if the database file was modified externally and reloads it if so.
static func check_for_external_changes() -> bool:
	var path: String = CollisionPresetsConstants.PRESET_DATABASE_PATH
	if not ResourceLoader.exists(path):
		return false

	var current_modified_time: int = FileAccess.get_modified_time(path)
	if current_modified_time > _last_modified_time:
		_load_static_presets()
		return true
	
	return false


## Returns the preset with the given display name, or null if not found.
static func get_preset(name: String) -> CollisionPreset:
	if Engine.is_editor_hint():
		check_for_external_changes()
	
	if presets_db_static == null:
		_load_static_presets()
	
	for p: CollisionPreset in presets_db_static.presets:
		if p.name == name: return p

	return null


## Returns the preset with the given unique ID, or null if not found.
static func get_preset_by_id(id: String) -> CollisionPreset:
	if id.is_empty(): return null
	
	if Engine.is_editor_hint():
		check_for_external_changes()
	
	if presets_db_static == null:
		_load_static_presets()
	
	for p: CollisionPreset in presets_db_static.presets:
		if p.id == id: return p
	
	return null


## Applies the named preset's layer and mask to the given node and stores metadata on it.
static func apply_preset(object: Node, name: String) -> bool:
	var p: CollisionPreset = get_preset(name)

	if p:
		if CollisionPresetsConstants.PROP_COLLISION_LAYER in object:
			object.collision_layer = p.layer

		if CollisionPresetsConstants.PROP_COLLISION_MASK in object:
			object.collision_mask = p.mask
		
		# Store both name and ID for robustness across renames.
		object.set_meta(CollisionPresetsConstants.META_KEY, p.name as StringName)

		if not p.id.is_empty():
			object.set_meta(CollisionPresetsConstants.META_ID_KEY, p.id as StringName)
		
		return true
	
	return false


## Returns the collision layer bitmask of the named preset, or 0 if not found.
static func get_preset_layer(name: String) -> int:
	var p: CollisionPreset = get_preset(name)
	return p.layer if p else 0


## Returns the collision mask bitmask of the named preset, or 0 if not found.
static func get_preset_mask(name: String) -> int:
	var p: CollisionPreset = get_preset(name)
	return p.mask if p else 0


## Returns the display names of all currently defined presets.
static func get_preset_names() -> Array[String]:
	if Engine.is_editor_hint():
		check_for_external_changes()
	
	if presets_db_static == null:
		_load_static_presets()
	
	var names: Array[String] = []
	for p: CollisionPreset in presets_db_static.presets:
		names.append(p.name)
	
	return names


## Returns the combined collision layer of all named presets using bitwise OR.
static func get_combined_presets_layer(names: Array[String]) -> int:
	var layer: int = 0
	for name: String in names:
		layer |= get_preset_layer(name)
	return layer


## Returns the combined collision mask of all named presets using bitwise OR.
static func get_combined_presets_mask(names: Array[String]) -> int:
	var mask: int = 0
	for name: String in names:
		mask |= get_preset_mask(name)
	return mask


## Returns the active preset name on the given node, resolved by ID when possible.
static func get_node_preset(node: Node) -> String:
	if Engine.is_editor_hint():
		check_for_external_changes()
	if presets_db_static == null:
		_load_static_presets()

	# Prefer ID-based lookup to survive preset renames.
	if node.has_meta(CollisionPresetsConstants.META_ID_KEY):
		var id: String = str(node.get_meta(CollisionPresetsConstants.META_ID_KEY))
		var p: CollisionPreset = get_preset_by_id(id)
		if p: return p.name

	# Fall back to the stored name metadata.
	if node.has_meta(CollisionPresetsConstants.META_KEY):
		return str(node.get_meta(CollisionPresetsConstants.META_KEY))

	# Fall back to the default preset when no metadata is present.
	var def: CollisionPreset = get_preset_by_id(presets_db_static.default_preset_id)
	if def: return def.name

	return ""


## Sets a preset on a node by name, updating its collision values and metadata.
static func set_node_preset(node: Node, preset_name: String) -> bool:
	if Engine.is_editor_hint():
		check_for_external_changes()
	
	if presets_db_static == null:
		_load_static_presets()

	if preset_name.is_empty():
		# Remove stored metadata and apply the default preset values.
		if node.has_meta(CollisionPresetsConstants.META_KEY):
			node.remove_meta(CollisionPresetsConstants.META_KEY)
		
		if node.has_meta(CollisionPresetsConstants.META_ID_KEY):
			node.remove_meta(CollisionPresetsConstants.META_ID_KEY)
		
		var p: CollisionPreset = get_preset_by_id(presets_db_static.default_preset_id)

		if p:
			if "collision_layer" in node:
				node.collision_layer = p.layer
			
			if "collision_mask" in node:
				node.collision_mask = p.mask
		
		return true

	if preset_name == CollisionPresetsConstants.CUSTOM_PRESET_VALUE:
		# Mark the node as manually controlled and clear the ID reference.
		node.set_meta(CollisionPresetsConstants.META_KEY, CollisionPresetsConstants.CUSTOM_PRESET_VALUE)
		if node.has_meta(CollisionPresetsConstants.META_ID_KEY):
			node.remove_meta(CollisionPresetsConstants.META_ID_KEY)
		return true

	for preset: CollisionPreset in presets_db_static.presets:
		if preset.name == preset_name:
			return apply_preset(node, preset_name)

	return false


## Writes or refreshes the auto-generated GDScript file with preset name constants.
static func generate_preset_constants_script(db: CollisionPresetsDatabase = null) -> void:
	if not db:
		if Engine.is_editor_hint():
			check_for_external_changes()
		_load_static_presets()
		db = presets_db_static

	if not db: return

	var used: Dictionary = {}
	var idents: Array[String] = []
	var lines: Array[String] = []
	lines.append("# This file is auto-generated by the Collision Presets editor plugin.\n# Do not edit manually.\n")
	lines.append("class_name CollisionPresets\n")

	for p: CollisionPreset in db.presets:
		var ident: String = get_identifier(p.name, used)
		idents.append(ident)
		lines.append("const %s := \"%s\"\n" % [ident, p.name])
	lines.append("\nstatic func all() -> PackedStringArray:\n")
	lines.append("\treturn PackedStringArray([\n")

	for i: int in range(idents.size()):
		lines.append("\t\t%s%s\n" % [idents[i], "," if i < idents.size() - 1 else ""])
	lines.append("\t])\n")

	var content: String = "".join(lines)

	# Only write when the content differs to avoid unnecessary VCS noise.
	var existing: String = ""
	if FileAccess.file_exists(CollisionPresetsConstants.PRESET_NAMES_PATH):
		var f: FileAccess = FileAccess.open(CollisionPresetsConstants.PRESET_NAMES_PATH, FileAccess.READ)
		if f:
			existing = f.get_as_text()
			f.close()

	if existing != content:
		var f: FileAccess = FileAccess.open(CollisionPresetsConstants.PRESET_NAMES_PATH, FileAccess.WRITE)
		if f:
			f.store_string(content)
			f.flush()
			f.close()


## Converts an arbitrary preset name into a valid, unique GDScript constant identifier.
static func get_identifier(name: String, used: Dictionary = {}) -> String:
	var s: String = name.strip_edges()
	if s.is_empty():
		s = "Preset"

	# Replace any character that is not alphanumeric or underscore.
	var out: String = ""
	for ch: String in s:
		if (ch >= "A" and ch <= "Z") or (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "_":
			out += ch
		else:
			out += "_"

	# Identifiers cannot start with a digit.
	if out.length() > 0 and out[0] >= "0" and out[0] <= "9":
		out = "_" + out

	# Collapse consecutive underscores into one.
	while out.find("__") != -1:
		out = out.replace("__", "_")

	if out.is_empty():
		out = "Preset"

	# Resolve name collisions by appending a numeric suffix.
	if not used.is_empty():
		var base: String = out
		var n: int = 1

		while used.has(out):
			out = "%s_%d" % [base, n]
			n += 1
		used[out] = true

	return out