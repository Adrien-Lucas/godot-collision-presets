@tool
class_name CollisionPresetsConstants
extends RefCounted
## Shared constants and computed paths used throughout the Collision Presets plugin.
##
## This class is separate from the main plugin script to avoid circular dependencies 
## with the inspector plugin and runtime autoload.


## Metadata key used to store the preset name on a node.
const META_KEY: StringName = &"collision_preset_name"

## Metadata key used to store the preset ID on a node.
const META_ID_KEY: StringName = &"collision_preset_id"

## Name of the autoload singleton that applies presets at runtime.
const AUTOLOAD_NAME: String = "CollisionPresetRuntime"

static var AUTOLOAD_PATH: String: get = _get_autoload_path
static var PRESET_DATABASE_PATH: String: get = _get_preset_database_path
static var PRESET_NAMES_PATH: String: get = _get_preset_names_path
static var INSPECTOR_SCRIPT_PATH: String: get = _get_inspector_script_path


## Computes the base directory of the plugin for constructing other paths.
static func _get_base_dir() -> String:
	return (CollisionPresetsConstants as Script).resource_path.get_base_dir()


#region Getters
static func _get_autoload_path() -> String:
	return _get_base_dir().path_join("collision_presets_runtime.gd")


static func _get_preset_database_path() -> String:
	var base_dir: String = ProjectSettings.get_setting(
		"physics/collision_presets/collision_presets_directory", "res://collision_presets"
	)
	return base_dir.path_join("presets.tres")


static func _get_preset_names_path() -> String:
	var base_dir: String = ProjectSettings.get_setting(
		"physics/collision_presets/collision_presets_directory", "res://collision_presets"
	)
	return base_dir.path_join("preset_names.gd")


static func _get_inspector_script_path() -> String:
	return _get_base_dir().path_join("collision_presets_inspector.gd")
#endregion
