@tool
class_name CollisionPresetsEditor
extends VBoxContainer
## Editor UI injected into the Inspector Collision section for collision objects.
##
## Displays a preset dropdown and an optional editing panel for creating,
## renaming, and deleting presets, as well as setting the default.


var target: Node
var database: CollisionPresetsDatabase
var sorted_presets: Array[CollisionPreset] = []

var preset_dropdown: OptionButton
var edit_button: Button
var edit_container: VBoxContainer
var name_edit: LineEdit
var layer_spin: SpinBox
var mask_spin: SpinBox
var save_button: Button
var new_button: Button
var delete_button: Button
var set_default_button: Button


## Builds the UI, loads the database, and initializes the dropdown.
func _init() -> void:
	_build_ui()
	_load_or_create()
	_refresh_dropdown()


## Sets the edit button icon once the theme is ready and wires up event-driven signals.
func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		if is_instance_valid(new_button):
			new_button.icon = get_theme_icon("Add", "EditorIcons")
		if is_instance_valid(edit_button):
			edit_button.icon = get_theme_icon("Edit", "EditorIcons")

		# Reload the database whenever a project file changes on disk.
		EditorInterface.get_resource_filesystem().filesystem_changed.connect(_on_filesystem_changed)
		# Detect property edits made via the built-in inspector widgets.
		EditorInterface.get_inspector().property_edited.connect(_on_inspector_property_edited)
		# Re-sync after undo/redo operations.
		EditorInterface.get_editor_undo_redo().history_changed.connect(_on_undo_redo_history_changed)

	elif what == NOTIFICATION_EXIT_TREE:
		var fs := EditorInterface.get_resource_filesystem()
		if fs.filesystem_changed.is_connected(_on_filesystem_changed):
			fs.filesystem_changed.disconnect(_on_filesystem_changed)

		var inspector := EditorInterface.get_inspector()
		if inspector.property_edited.is_connected(_on_inspector_property_edited):
			inspector.property_edited.disconnect(_on_inspector_property_edited)

		var undo_redo := EditorInterface.get_editor_undo_redo()
		if undo_redo.history_changed.is_connected(_on_undo_redo_history_changed):
			undo_redo.history_changed.disconnect(_on_undo_redo_history_changed)


## Reloads the database when any project file changes on disk.
func _on_filesystem_changed() -> void:
	if CollisionPresetsAPI.check_for_external_changes():
		_load_or_create()
		_refresh_dropdown()
		if is_instance_valid(target):
			set_target(target)


## Updates the spinners and preset state when the inspector edits collision_layer or collision_mask.
func _on_inspector_property_edited(property: StringName) -> void:
	if not is_instance_valid(target): return
	if (
		property != CollisionPresetsConstants.PROP_COLLISION_LAYER
		and property != CollisionPresetsConstants.PROP_COLLISION_MASK
	):
		return

	var changed: bool = false

	if (
		property == CollisionPresetsConstants.PROP_COLLISION_LAYER
		and CollisionPresetsConstants.PROP_COLLISION_LAYER in target
	):
		var target_layer: int = int(target.collision_layer)
		if target_layer != int(layer_spin.value):
			layer_spin.set_block_signals(true)
			layer_spin.value = target_layer
			layer_spin.set_block_signals(false)
			changed = true

	if (
		property == CollisionPresetsConstants.PROP_COLLISION_MASK
		and CollisionPresetsConstants.PROP_COLLISION_MASK in target
	):
		var target_mask: int = int(target.collision_mask)
		if target_mask != int(mask_spin.value):
			mask_spin.set_block_signals(true)
			mask_spin.value = target_mask
			mask_spin.set_block_signals(false)
			changed = true

	if changed and not edit_container.visible:
		var current_preset: String = CollisionPresetsAPI.get_node_preset(target)
		if current_preset != CollisionPresetsConstants.CUSTOM_PRESET_VALUE:
			_set_to_custom()


## Re-syncs the UI after an undo or redo operation changes node state.
func _on_undo_redo_history_changed() -> void:
	if is_instance_valid(target):
		set_target(target)


## Syncs the UI and target node to reflect the given collision object.
func set_target(obj: Node) -> void:
	target = obj

	if is_instance_valid(target):
		if CollisionPresetsConstants.PROP_COLLISION_LAYER in target:
			layer_spin.set_block_signals(true)
			layer_spin.value = target.collision_layer
			layer_spin.set_block_signals(false)
		
		if CollisionPresetsConstants.PROP_COLLISION_MASK in target:
			mask_spin.set_block_signals(true)
			mask_spin.value = target.collision_mask
			mask_spin.set_block_signals(false)

		# Skip preset enforcement in edit mode, because the spinboxes hold the working values.
		if edit_container.visible: return

		name_edit.text = ""

		# Block signals while syncing the UI to avoid re-applying changes.
		preset_dropdown.set_block_signals(true)

		var stored_name: String = CollisionPresetsAPI.get_node_preset(target)
		var has_any_meta: bool = (
			target.has_meta(CollisionPresetsConstants.META_KEY) 
			or target.has_meta(CollisionPresetsConstants.META_ID_KEY)
		)

		# Default
		if not has_any_meta:
			preset_dropdown.select(0)
			edit_button.disabled = true

			var def: CollisionPreset = CollisionPresetsAPI.get_preset_by_id(database.default_preset_id)
			if def:
				if (
					CollisionPresetsConstants.PROP_COLLISION_LAYER in target
					and target.collision_layer != def.layer
				):
					target.collision_layer = def.layer
					layer_spin.set_block_signals(true)
					layer_spin.value = def.layer
					layer_spin.set_block_signals(false)

				if (
					CollisionPresetsConstants.PROP_COLLISION_MASK in target
					and target.collision_mask != def.mask
				):
					target.collision_mask = def.mask
					mask_spin.set_block_signals(true)
					mask_spin.value = def.mask
					mask_spin.set_block_signals(false)
		
		# Custom
		elif stored_name == CollisionPresetsConstants.CUSTOM_PRESET_VALUE:
			preset_dropdown.select(preset_dropdown.item_count - 1)
			edit_button.disabled = true
		
		else:
			# Locate the preset in the sorted list.
			var found: int = -1
			for i: int in range(sorted_presets.size()):
				if sorted_presets[i].name == stored_name:
					found = i
					break
			
			if found >= 0:
				# +1 accounts for the "Default" item
				preset_dropdown.select(found + 1)
				name_edit.text = stored_name
				var current_default: CollisionPreset = CollisionPresetsAPI.get_preset_by_id(database.default_preset_id)
				set_default_button.disabled = (current_default and current_default.name == stored_name)
				edit_button.disabled = false

				var p: CollisionPreset = sorted_presets[found]
				if (
					CollisionPresetsConstants.PROP_COLLISION_LAYER in target
					and target.collision_layer != p.layer
				):
					target.collision_layer = p.layer
					layer_spin.set_block_signals(true)
					layer_spin.value = p.layer
					layer_spin.set_block_signals(false)
				
				if (
					CollisionPresetsConstants.PROP_COLLISION_MASK in target
					and target.collision_mask != p.mask
				):
					target.collision_mask = p.mask
					mask_spin.set_block_signals(true)
					mask_spin.value = p.mask
					mask_spin.set_block_signals(false)
			
			# Custom (preset not found)
			else:
				preset_dropdown.select(preset_dropdown.item_count - 1)
				edit_button.disabled = true

		preset_dropdown.set_block_signals(false)


## Builds and attaches all UI elements for the preset editor.
func _build_ui() -> void:
	custom_minimum_size = Vector2(0, 48)

	var top_hb := HBoxContainer.new()
	add_child(top_hb)

	top_hb.add_child(Label.new())
	top_hb.get_child(top_hb.get_child_count() - 1).text = "Preset"

	preset_dropdown = OptionButton.new()
	preset_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preset_dropdown.item_selected.connect(_on_preset_selected)
	top_hb.add_child(preset_dropdown)

	new_button = Button.new()
	new_button.text = "New Preset"
	new_button.flat = true
	new_button.tooltip_text = "Create a new collision preset and save it to be used later."
	new_button.pressed.connect(_on_new_pressed)
	top_hb.add_child(new_button)

	edit_button = Button.new()
	edit_button.flat = true
	edit_button.toggle_mode = true
	edit_button.disabled = true
	edit_button.tooltip_text = "Toggle edit mode to manage the selected preset."

	# The icons are assigned in _notification once the theme is available.
	edit_button.toggled.connect(_on_edit_toggled)
	top_hb.add_child(edit_button)

	edit_container = VBoxContainer.new()
	edit_container.visible = false
	add_child(edit_container)

	var edit_label := Label.new()
	edit_label.text = "Edit Preset"
	edit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit_container.add_child(edit_label)

	var name_hb := HBoxContainer.new()
	name_hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_hb.tooltip_text = "The unique identifier name for this collision preset."
	edit_container.add_child(name_hb)
	var name_label := Label.new()
	name_label.text = "Name"
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_hb.add_child(name_label)
	name_edit = LineEdit.new()
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_hb.add_child(name_edit)

	var layer_hb := HBoxContainer.new()
	layer_hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layer_hb.tooltip_text = "Collision layer bitmask (integer). Each bit represents a physics layer this object belongs to."
	edit_container.add_child(layer_hb)
	var layer_label := Label.new()
	layer_label.text = "Layer"
	layer_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layer_hb.add_child(layer_label)
	layer_spin = SpinBox.new()
	layer_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layer_spin.min_value = 0
	layer_spin.max_value = CollisionPresetsConstants.BITMASK_MAX
	layer_spin.step = 1
	layer_spin.value_changed.connect(_on_values_changed)
	layer_hb.add_child(layer_spin)

	var mask_hb := HBoxContainer.new()
	mask_hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mask_hb.tooltip_text = "Collision mask bitmask (integer). Each bit represents a physics layer this object interacts with."
	edit_container.add_child(mask_hb)
	var mask_label := Label.new()
	mask_label.text = "Mask"
	mask_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mask_hb.add_child(mask_label)
	mask_spin = SpinBox.new()
	mask_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mask_spin.max_value = CollisionPresetsConstants.BITMASK_MAX
	mask_spin.step = 1
	mask_spin.value_changed.connect(_on_values_changed)
	mask_hb.add_child(mask_spin)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	edit_container.add_child(buttons)

	save_button = Button.new()
	save_button.text = "Save"
	save_button.tooltip_text = "Save changes to this preset."
	save_button.pressed.connect(_on_save_pressed)
	buttons.add_child(save_button)

	delete_button = Button.new()
	delete_button.text = "Delete"
	delete_button.tooltip_text = "Permanently delete this preset."
	delete_button.pressed.connect(_on_delete_pressed)
	buttons.add_child(delete_button)

	set_default_button = Button.new()
	set_default_button.text = "Set Default"
	set_default_button.tooltip_text = "Make this preset the default applied to new collision nodes."
	set_default_button.pressed.connect(_on_set_default_pressed)
	buttons.add_child(set_default_button)

	var separator := HSeparator.new()
	edit_container.add_child(separator)


## Toggles the edit panel visibility and locks the dropdown while editing.
func _on_edit_toggled(toggled_on: bool) -> void:
	edit_container.visible = toggled_on
	preset_dropdown.disabled = toggled_on


## Applies the current spinner values to the target node and switches to custom if they changed.
func _on_values_changed(_v: float) -> void:
	if is_instance_valid(target):
		var changed: bool = false
		var new_layer: int = int(layer_spin.value)
		var new_mask: int = int(mask_spin.value)

		if (
			CollisionPresetsConstants.PROP_COLLISION_LAYER in target
			and target.collision_layer != new_layer
		):
			target.collision_layer = new_layer
			changed = true
		if (
			CollisionPresetsConstants.PROP_COLLISION_MASK in target
			and target.collision_mask != new_mask
		):
			target.collision_mask = new_mask
			changed = true

		if changed:
			if not edit_container.visible:
				_set_to_custom()


## Marks the target node as custom-controlled and selects the Custom dropdown item.
func _set_to_custom() -> void:
	if not is_instance_valid(target): return

	target.set_meta(CollisionPresetsConstants.META_KEY, CollisionPresetsConstants.CUSTOM_PRESET_VALUE)
	if target.has_meta(CollisionPresetsConstants.META_ID_KEY):
		target.remove_meta(CollisionPresetsConstants.META_ID_KEY)

	preset_dropdown.set_block_signals(true)
	preset_dropdown.select(preset_dropdown.item_count - 1) # Custom
	preset_dropdown.set_block_signals(false)
	edit_button.disabled = true
	set_default_button.disabled = true


## Applies the selected dropdown entry to the target node and updates the editor UI.
func _on_preset_selected(index: int) -> void:
	# Default
	if index == 0:
		edit_button.disabled = true

		if is_instance_valid(target):
			if target.has_meta(CollisionPresetsConstants.META_KEY):
				target.remove_meta(CollisionPresetsConstants.META_KEY)
			if target.has_meta(CollisionPresetsConstants.META_ID_KEY):
				target.remove_meta(CollisionPresetsConstants.META_ID_KEY)
		var p: CollisionPreset = CollisionPresetsAPI.get_preset_by_id(database.default_preset_id)

		if p:
			_apply_preset_values_to_ui(p)
			if is_instance_valid(target):
				if CollisionPresetsConstants.PROP_COLLISION_LAYER in target:
					target.collision_layer = p.layer
				if CollisionPresetsConstants.PROP_COLLISION_MASK in target:
					target.collision_mask = p.mask
		return

	# Custom
	if index == preset_dropdown.item_count - 1:
		edit_button.disabled = true

		if is_instance_valid(target):
			target.set_meta(
				CollisionPresetsConstants.META_KEY,
				CollisionPresetsConstants.CUSTOM_PRESET_VALUE
			)
			if target.has_meta(CollisionPresetsConstants.META_ID_KEY):
				target.remove_meta(CollisionPresetsConstants.META_ID_KEY)
		return

	edit_button.disabled = false
	var p: CollisionPreset = sorted_presets[index - 1]
	name_edit.text = p.name
	set_default_button.disabled = (database.default_preset_id == p.id)

	_apply_preset_values_to_ui(p)

	if is_instance_valid(target):
		CollisionPresetsAPI.apply_preset(target, p.name)


## Assigns a preset's layer and mask to the spinboxes without triggering the custom switch.
func _apply_preset_values_to_ui(p: CollisionPreset) -> void:
	# Block signals to prevent switching back to custom while applying a preset.
	layer_spin.set_block_signals(true)
	mask_spin.set_block_signals(true)
	layer_spin.value = p.layer
	mask_spin.value = p.mask
	layer_spin.set_block_signals(false)
	mask_spin.set_block_signals(false)


## Opens a dialog to name and create a new preset from the current node's values.
func _on_new_pressed() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Create New Preset"
	dialog.size = Vector2i(350, 100)

	var vbox := VBoxContainer.new()
	dialog.add_child(vbox)

	var label := Label.new()
	label.text = "Preset Name:"
	vbox.add_child(label)

	var name_input := LineEdit.new()
	name_input.name = "NameInput"
	name_input.placeholder_text = "Enter name here..."
	vbox.add_child(name_input)
	
	dialog.confirmed.connect(func():
		var new_name: String = name_input.text.strip_edges()
		if new_name.is_empty():
			dialog.queue_free()
			return

		var new_layer: int = 1
		var new_mask: int = 1

		if is_instance_valid(target):
			if CollisionPresetsConstants.PROP_COLLISION_LAYER in target:
				new_layer = target.collision_layer
			
			if CollisionPresetsConstants.PROP_COLLISION_MASK in target:
				new_mask = target.collision_mask

		layer_spin.value = new_layer
		mask_spin.value = new_mask
		set_default_button.disabled = false
		_save_preset(new_name, new_layer, new_mask)

		# Open the edit section automatically after creating.
		edit_button.button_pressed = true
		_on_edit_toggled(true)

		dialog.queue_free()
	)
	
	name_input.text_submitted.connect(func(_text: String) -> void:
		dialog.confirmed.emit()
		dialog.hide()
	)

	dialog.canceled.connect(func() -> void:
		dialog.queue_free()
	)
	
	add_child(dialog)
	dialog.popup_centered()
	name_input.grab_focus()


## Saves the current edit form to the database and refreshes the UI.
func _on_save_pressed() -> void:
	var new_name: String = name_edit.text.strip_edges()
	if new_name.is_empty(): return

	# Find an existing preset by name or by what is selected in the dropdown.
	var p: CollisionPreset = null
	for existing: CollisionPreset in database.presets:
		if existing.name == new_name:
			p = existing
			break

	if p == null:
		var idx: int = preset_dropdown.selected
		if idx > 0 and (idx - 1) < sorted_presets.size():
			p = sorted_presets[idx - 1]

	_save_preset(new_name, int(layer_spin.value), int(mask_spin.value), p)

	edit_button.button_pressed = false
	_on_edit_toggled(false)


## Saves or updates a preset record in the database and refreshes the UI.
func _save_preset(p_name: String, p_layer: int, p_mask: int, p: CollisionPreset = null) -> void:
	var old_name: String = ""
	if p:
		old_name = p.name
	
	else:
		p = CollisionPreset.new()
		p.id = _generate_uid()
		database.presets.append(p)
	
	p.name = p_name
	p.layer = p_layer
	p.mask = p_mask
	
	_save_database()
	_refresh_dropdown()
	CollisionPresetsAPI.generate_preset_constants_script(database)

	for i: int in range(sorted_presets.size()):
		if sorted_presets[i] == p:
			preset_dropdown.select(i + 1)
			if is_instance_valid(target):
				CollisionPresetsAPI.apply_preset(target, p.name)
			break

	name_edit.text = p.name
	set_default_button.disabled = (database.default_preset_id == p.id)


## Opens a confirmation dialog to delete the currently selected preset.
func _on_delete_pressed() -> void:
	var idx: int = preset_dropdown.selected
	if idx <= 0 or (idx - 1) >= sorted_presets.size():
		return

	var p: CollisionPreset = sorted_presets[idx - 1]

	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = "Delete Preset"
	dialog.dialog_text = "Are you sure you want to delete preset '%s'?" % p.name

	dialog.confirmed.connect(func() -> void:
		if database.default_preset_id == p.id:
			database.default_preset_id = ""

		var actual_idx: int = database.presets.find(p)
		if actual_idx != -1:
			database.presets.remove_at(actual_idx)

		_save_database()
		_refresh_dropdown()
		CollisionPresetsAPI.generate_preset_constants_script(database)

		preset_dropdown.select(0)
		_on_preset_selected(0)

		edit_button.button_pressed = false
		_on_edit_toggled(false)

		dialog.queue_free()
	)

	dialog.canceled.connect(func() -> void:
		dialog.queue_free()
	)

	add_child(dialog)
	dialog.popup_centered()


## Opens a confirmation dialog to set the currently selected preset as the default.
func _on_set_default_pressed() -> void:
	var idx: int = preset_dropdown.selected
	if idx <= 0 or (idx - 1) >= sorted_presets.size():
		return

	var p: CollisionPreset = sorted_presets[idx - 1]

	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = "Set Default?"
	dialog.dialog_text = "Are you sure you want to set preset '%s' as default?" % p.name

	dialog.confirmed.connect(func() -> void:
		database.default_preset_id = p.id
		_save_database()
		_refresh_dropdown()
		CollisionPresetsAPI.generate_preset_constants_script(database)

		dialog.queue_free()
	)

	dialog.canceled.connect(func() -> void:
		dialog.queue_free()
	)

	add_child(dialog)
	dialog.popup_centered()


## Rebuilds the preset dropdown reflecting the current database state.
func _refresh_dropdown() -> void:
	preset_dropdown.clear()
	var default_p: CollisionPreset = CollisionPresetsAPI.get_preset_by_id(database.default_preset_id)
	
	if default_p == null:
		preset_dropdown.add_item("Default (None)")
	
	else:
		preset_dropdown.add_item("Default (%s)" % default_p.name)

	# Populate the sorted list in alphabetical order.
	sorted_presets = []
	for p: CollisionPreset in database.presets:
		sorted_presets.append(p)

	sorted_presets.sort_custom(func(a: CollisionPreset, b: CollisionPreset) -> bool:
		return a.name.to_lower() < b.name.to_lower())

	for p: CollisionPreset in sorted_presets:
		preset_dropdown.add_item(p.name)

	preset_dropdown.add_item("Custom")


## Loads the preset database from disk, or creates a new one if it does not exist.
func _load_or_create() -> void:
	CollisionPresetsAPI._load_static_presets()
	if CollisionPresetsAPI.presets_db_static != null:
		database = CollisionPresetsAPI.presets_db_static
	
	else:
		database = CollisionPresetsDatabase.new()
		_save_database()
		CollisionPresetsAPI.presets_db_static = database

	# Migrate the legacy default_preset_name property to default_preset_id.
	var migration_needed: bool = false
	if (
		database.has_method("get")
		and database.get(CollisionPresetsConstants.LEGACY_DEFAULT_NAME_PROP) != null
	):
		var old_name: Variant = database.get(CollisionPresetsConstants.LEGACY_DEFAULT_NAME_PROP)
		if (
			typeof(old_name) == TYPE_STRING
			and not (old_name as String).is_empty()
			and database.default_preset_id.is_empty()
		):
			for p: CollisionPreset in database.presets:
				if p.name == old_name:
					database.default_preset_id = p.id
					migration_needed = true
					break

	# Ensure every preset has an ID assigned.
	var changed: bool = false
	for p: CollisionPreset in database.presets:
		if p.id.is_empty():
			p.id = _generate_uid()
			changed = true
	
	if changed or migration_needed:
		_save_database()


## Saves the preset database to disk and refreshes the modification timestamp.
func _save_database() -> void:
	ResourceSaver.save(database, CollisionPresetsConstants.PRESET_DATABASE_PATH)
	CollisionPresetsAPI.check_for_external_changes()


## Generates a new unique ID string using the engine's UID system.
func _generate_uid() -> String:
	return str(ResourceUID.create_id())
