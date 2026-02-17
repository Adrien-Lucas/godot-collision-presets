@tool
extends EditorInspectorPlugin

func _can_handle(object):
	return object is CollisionObject3D or object is CollisionObject2D

func _parse_category(object, category):
	# Inject our UI into the "Collision" section of the inspector
	var cat_lower = String(category).to_lower()
	if cat_lower == "collisionobject3d" or cat_lower == "collisionobject2d":
		var ui_scene = load(get_script().resource_path.get_base_dir().path_join("collision_presets_editor.gd"))
		var ui = ui_scene.new()
		ui.set_target(object)
		add_custom_control(ui)
	return false
