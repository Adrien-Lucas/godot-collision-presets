@tool
extends EditorPlugin

var inspector_plugin
var last_known_directory: String = ""

## Add inspector plugin on plugin enable
func _enter_tree():
	# Register project setting
	if not ProjectSettings.has_setting("physics/collision_presets/collision_presets_directory"):
		ProjectSettings.set_setting("physics/collision_presets/collision_presets_directory", "res://collision_presets")
	ProjectSettings.set_initial_value("physics/collision_presets/collision_presets_directory", "res://collision_presets")
	ProjectSettings.add_property_info({
		"name": "physics/collision_presets/collision_presets_directory",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_DIR,
	})
	
	last_known_directory = ProjectSettings.get_setting("physics/collision_presets/collision_presets_directory", "res://collision_presets")
	ProjectSettings.settings_changed.connect(_on_settings_changed)

	inspector_plugin = load(CollisionPresetsConstants.INSPECTOR_SCRIPT_PATH).new()
	add_inspector_plugin(inspector_plugin)
	# Ensure the runtime applier is registered as an autoload so presets are applied when the game runs
	if not ProjectSettings.has_setting("autoload/%s" % CollisionPresetsConstants.AUTOLOAD_NAME):
		add_autoload_singleton(CollisionPresetsConstants.AUTOLOAD_NAME, CollisionPresetsConstants.AUTOLOAD_PATH)
	
	# Generate constants script on load to ensure it's up to date
	CollisionPresetsAPI.generate_preset_constants_script()

## Remove autoload singleton on plugin disable
func _exit_tree():
	ProjectSettings.settings_changed.disconnect(_on_settings_changed)
	remove_inspector_plugin(inspector_plugin)
	if ProjectSettings.has_setting("autoload/%s" % CollisionPresetsConstants.AUTOLOAD_NAME):
		remove_autoload_singleton(CollisionPresetsConstants.AUTOLOAD_NAME)

func _on_settings_changed():
	var new_dir = ProjectSettings.get_setting("physics/collision_presets/collision_presets_directory", "res://collision_presets")
	if new_dir == last_known_directory:
		return
		
	# If the directory setting changed, we might need to migrate files or at least reload the static database
	# _load_static_presets handles migration if files are missing from the new path
	CollisionPresetsAPI.presets_db_static = null
	CollisionPresetsAPI._load_static_presets(last_known_directory)
	CollisionPresetsAPI.generate_preset_constants_script()
	
	last_known_directory = new_dir

