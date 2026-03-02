@tool
class_name CollisionPresetsInspector
extends EditorInspectorPlugin
## Inspector plugin that injects the collision preset UI into the Collision section
## of any CollisionObject2D or CollisionObject3D node.


## Returns true for any 2D or 3D collision object so the plugin can inject its UI.
func _can_handle(object: Object) -> bool:
	return object is CollisionObject3D or object is CollisionObject2D


## Injects the preset editor UI when the Collision category is parsed.
func _parse_category(object: Object, category: String) -> void:
	var cat_lower: String = category.to_lower()
	if cat_lower == "collisionobject3d" or cat_lower == "collisionobject2d":
		var ui_script: Script = load(
			get_script().resource_path.get_base_dir().path_join("collision_presets_editor.gd")
		)
		var ui: Node = ui_script.new()
		ui.set_target(object)
		add_custom_control(ui)
