@tool
class_name CollisionPreset
extends Resource
## A named collision preset storing layer and mask bitmask values.
##
## Represents a single preset entry, containing a display name,
## a persistent unique ID, and the bitmask values for both the collision layer and mask.


## The display name for this preset.
@export var name: String = ""
## A persistent unique identifier used for rename-resilient lookups.
@export var id: String = ""
## The collision layer bitmask assigned by this preset.
@export var layer: int = 1
## The collision mask bitmask assigned by this preset.
@export var mask: int = 1
