@tool
class_name CollisionPresetsConstants

## Key used to store preset names in the node's metadata.
const META_KEY: StringName = &"collision_preset_name"
## Key used to store preset IDs in the node's metadata.
const META_ID_KEY: StringName = &"collision_preset_id"
## Name of the autoload singleton that applies presets at runtime.
const AUTOLOAD_NAME := "CollisionPresetRuntime" 
## Path to the autoload singleton source file.
static var AUTOLOAD_PATH: String:
	get:
		return _get_base_dir().path_join("collision_presets_runtime.gd")
## Path to the preset database file.
static var PRESET_DATABASE_PATH: String:
	get:
		var base_dir = ProjectSettings.get_setting("physics/collision_presets/collision_presets_directory", "res://collision_presets")
		return base_dir.path_join("presets.tres")
## Path to the preset constants file.
static var PRESET_NAMES_PATH: String:
	get:
		var base_dir = ProjectSettings.get_setting("physics/collision_presets/collision_presets_directory", "res://collision_presets")
		return base_dir.path_join("preset_names.gd")
## Path to the custom inspector plugin file.
static var INSPECTOR_SCRIPT_PATH: String:
	get:
		return _get_base_dir().path_join("collision_presets_inspector.gd")

static func _get_base_dir() -> String:
	return (CollisionPresetsConstants as Script).resource_path.get_base_dir()