@tool
class_name CollisionPresetsDatabase
extends Resource
## A resource that holds all defined collision presets and tracks the default preset.


## All currently defined collision presets.
@export var presets: Array[CollisionPreset] = []

## The ID of the preset treated as the default when no preset is explicitly assigned.
@export var default_preset_id: String = ""
