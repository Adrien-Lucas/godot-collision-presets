@tool
class_name CollisionPresetsRuntime
extends Node
## Autoload singleton that applies collision presets to all nodes when the game starts.
##
## At runtime it walks the existing scene tree and then listens for any nodes
## added later, applying the stored preset to each collision object it finds.


## Applies presets to existing collision objects and connects to future additions.
func _ready() -> void:
	if Engine.is_editor_hint(): return

	# Apply presets to nodes already present in the scene tree.
	var root: Window = get_tree().get_root()
	if root:
		_process_branch(root)

	# Apply presets to any nodes added after startup.
	get_tree().node_added.connect(_on_node_added)


## Handles a newly added node by applying its preset or traversing its children.
func _on_node_added(n: Node) -> void:
	if n is CollisionObject3D or n is CollisionObject2D:
		_apply_node_preset(n)
	else:
		_process_branch(n)


## Recursively walks a node branch and applies presets to all collision objects found.
func _process_branch(n: Node) -> void:
	for child: Node in n.get_children():
		if child is CollisionObject3D or child is CollisionObject2D:
			_apply_node_preset(child)
		
		else:
			_process_branch(child)


## Reads the preset stored on a collision node and applies its layer and mask values.
func _apply_node_preset(n: Node) -> void:
	if not (n is CollisionObject3D or n is CollisionObject2D): return

	var preset_name: String = CollisionPresetsAPI.get_node_preset(n)

	# Custom nodes are under manual control, so leave them unchanged.
	if preset_name == "__custom__": return

	if not preset_name.is_empty():
		var p: CollisionPreset = CollisionPresetsAPI.get_preset(preset_name)
		if p:
			n.collision_layer = p.layer
			n.collision_mask = p.mask
