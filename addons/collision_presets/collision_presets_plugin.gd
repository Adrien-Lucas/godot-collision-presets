@tool
extends EditorPlugin

var inspector_plugin

## Add inspector plugin on plugin enable
func _enter_tree():
	var inspector_path = get_script().resource_path.get_base_dir().path_join("collision_presets_inspector.gd")
	inspector_plugin = load(inspector_path).new()
	add_inspector_plugin(inspector_plugin)
	# Ensure the runtime applier is registered as an autoload so presets are applied when the game runs
	if not ProjectSettings.has_setting("autoload/%s" % CollisionPresetsConstants.AUTOLOAD_NAME):
		add_autoload_singleton(CollisionPresetsConstants.AUTOLOAD_NAME, CollisionPresetsConstants.AUTOLOAD_PATH)
	
	# Generate constants script on load to ensure it's up to date
	CollisionPresetsAPI.generate_preset_constants_script()

## Remove autoload singleton on plugin disable
func _exit_tree():
	remove_inspector_plugin(inspector_plugin)
	if ProjectSettings.has_setting("autoload/%s" % CollisionPresetsConstants.AUTOLOAD_NAME):
		remove_autoload_singleton(CollisionPresetsConstants.AUTOLOAD_NAME)

