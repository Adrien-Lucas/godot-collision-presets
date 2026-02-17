@tool
extends Resource
class_name CollisionPresetsDatabase

@export var presets: Array[CollisionPreset] = []
@export var default_preset_id: String = ""
