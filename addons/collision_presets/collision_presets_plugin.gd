@tool
class_name CollisionPresetsPlugin
extends EditorPlugin
## Editor plugin that registers the collision preset inspector UI and runtime autoload.
##
## This class will also track changes to the preset directory setting and trigger reloads of the preset database.


var inspector_plugin: EditorInspectorPlugin
var last_known_directory: String = ""


## Registers the inspector plugin, project settings, and runtime autoload on enable.
func _enter_tree() -> void:
	if not ProjectSettings.has_setting(CollisionPresetsConstants.SETTINGS_DIRECTORY_KEY):
		ProjectSettings.set_setting(
			CollisionPresetsConstants.SETTINGS_DIRECTORY_KEY,
			CollisionPresetsConstants.DEFAULT_PRESETS_DIRECTORY
		)
	
	ProjectSettings.set_initial_value(
		CollisionPresetsConstants.SETTINGS_DIRECTORY_KEY,
		CollisionPresetsConstants.DEFAULT_PRESETS_DIRECTORY
	)

	ProjectSettings.add_property_info({
		"name": CollisionPresetsConstants.SETTINGS_DIRECTORY_KEY,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_DIR,
	})

	last_known_directory = ProjectSettings.get_setting(
		CollisionPresetsConstants.SETTINGS_DIRECTORY_KEY,
		CollisionPresetsConstants.DEFAULT_PRESETS_DIRECTORY
	)
	ProjectSettings.settings_changed.connect(_on_settings_changed)

	inspector_plugin = load(CollisionPresetsConstants.INSPECTOR_SCRIPT_PATH).new()
	add_inspector_plugin(inspector_plugin)

	if not ProjectSettings.has_setting("autoload/%s" % CollisionPresetsConstants.AUTOLOAD_NAME):
		add_autoload_singleton(
			CollisionPresetsConstants.AUTOLOAD_NAME,
			CollisionPresetsConstants.AUTOLOAD_PATH
		)

	CollisionPresetsAPI.generate_preset_constants_script()


## Removes the inspector plugin and autoload on disable.
func _exit_tree() -> void:
	ProjectSettings.settings_changed.disconnect(_on_settings_changed)
	remove_inspector_plugin(inspector_plugin)
	if ProjectSettings.has_setting("autoload/%s" % CollisionPresetsConstants.AUTOLOAD_NAME):
		remove_autoload_singleton(CollisionPresetsConstants.AUTOLOAD_NAME)


## Reloads the preset database when the preset directory setting changes.
func _on_settings_changed() -> void:
	var new_dir: String = ProjectSettings.get_setting(
		CollisionPresetsConstants.SETTINGS_DIRECTORY_KEY,
		CollisionPresetsConstants.DEFAULT_PRESETS_DIRECTORY
	)
	
	if new_dir == last_known_directory: return

	CollisionPresetsAPI.presets_db_static = null
	CollisionPresetsAPI._load_static_presets(last_known_directory)
	CollisionPresetsAPI.generate_preset_constants_script()

	last_known_directory = new_dir

