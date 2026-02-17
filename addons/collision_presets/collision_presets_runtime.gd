@tool
extends Node

## Called when autoload is added to scene tree
func _ready():
	if Engine.is_editor_hint():
		return
	
	# Process already existing nodes in the active scene(s)
	var root := get_tree().get_root()
	if root:
		_process_branch(root)
	# Listen for future nodes being added while game runs
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(n: Node):
	if n is CollisionObject3D or n is CollisionObject2D:
		_apply_node_preset(n)
	else:
		_process_branch(n)

func _process_branch(n: Node):
	for child in n.get_children():
		if child is CollisionObject3D or child is CollisionObject2D:
			_apply_node_preset(child)
		else:
			_process_branch(child)

func _apply_node_preset(n: Node):
	if not (n is CollisionObject3D or n is CollisionObject2D):
		return
	
	var preset_name = CollisionPresetsAPI.get_node_preset(n)
	if preset_name == "__custom__":
		# __custom__ metadata -> Do nothing (manual control).
		return

	if preset_name != "":
		# Apply preset.
		var p = CollisionPresetsAPI.get_preset(preset_name)
		if p:
			n.collision_layer = p.layer
			n.collision_mask = p.mask
