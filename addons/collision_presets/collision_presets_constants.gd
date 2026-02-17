@tool
class_name CollisionPresetsConstants

## Key used to store preset names in the node's metadata.
const META_KEY := "collision_preset_name"
## Key used to store preset IDs in the node's metadata.
const META_ID_KEY := "collision_preset_id"
## Name of the autoload singleton that applies presets at runtime.
const AUTOLOAD_NAME := "CollisionPresetRuntime" 
## Path to the autoload singleton source file.
const AUTOLOAD_PATH := "res://addons/collision_presets/collision_presets_runtime.gd"
## Path to the preset database file.
const PRESET_DATABASE_PATH := "res://addons/collision_presets/presets.tres"
## Path to the preset constants file.
const PRESET_NAMES_PATH := "res://addons/collision_presets/preset_names.gd"