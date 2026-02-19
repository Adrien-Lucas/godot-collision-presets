@tool
extends VBoxContainer

## Target node and database instance
var target: Node
var database: CollisionPresetsDatabase
var sorted_presets: Array[CollisionPreset] = []

## UI elements
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

## Called when plugin is added to scene tree
func _init():
	custom_minimum_size = Vector2(0, 80)
	_build_ui()
	_load_or_create()
	_refresh_dropdown()

## Called when target node is changed in scene tree
func set_target(obj):
	target = obj
	if is_instance_valid(target):
		# Default to current values on the node
		if "collision_layer" in target:
			layer_spin.value = target.collision_layer
		if "collision_mask" in target:
			mask_spin.value = target.collision_mask
		name_edit.text = ""
		# Try read stored preset name from metadata and reflect it in the UI without applying
		# Block signals while syncing UI to avoid applying to the node here
		preset_dropdown.set_block_signals(true)
		
		var stored_name := CollisionPresetsAPI.get_node_preset(target)
		var has_any_meta := target.has_meta(CollisionPresetsConstants.META_KEY) or target.has_meta(CollisionPresetsConstants.META_ID_KEY)
		
		if not has_any_meta:
			preset_dropdown.select(0) # Default
			edit_button.disabled = true
		elif stored_name == "__custom__":
			preset_dropdown.select(preset_dropdown.item_count - 1) # Custom
			edit_button.disabled = true
		else:
			# Find preset index by name (which now handles ID lookup internally)
			var found := -1
			for i in range(sorted_presets.size()):
				if sorted_presets[i].name == stored_name:
					found = i
					break
			if found >= 0:
				preset_dropdown.select(found + 1) # account for "Default"
				name_edit.text = stored_name
				var current_default = CollisionPresetsAPI.get_preset_by_id(database.default_preset_id)
				set_default_button.disabled = (current_default and current_default.name == stored_name)
				edit_button.disabled = false
			else:
				preset_dropdown.select(preset_dropdown.item_count - 1) # fallback to Custom if not found
				edit_button.disabled = true
		
		preset_dropdown.set_block_signals(false)

## Builds UI elements
func _build_ui():
	var top_hb := HBoxContainer.new()
	add_child(top_hb)
	
	top_hb.add_child(Label.new())
	top_hb.get_child(top_hb.get_child_count()-1).text = "Preset"
	
	preset_dropdown = OptionButton.new()
	preset_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preset_dropdown.item_selected.connect(_on_preset_selected)
	top_hb.add_child(preset_dropdown)
	
	edit_button = Button.new()
	edit_button.flat = true
	edit_button.toggle_mode = true
	edit_button.disabled = true
	# We will set the icon in _ready or when added to tree to ensure theme is available
	edit_button.toggled.connect(_on_edit_toggled)
	top_hb.add_child(edit_button)

	edit_container = VBoxContainer.new()
	edit_container.visible = false
	add_child(edit_container)
	
	new_button = Button.new()
	new_button.text = "Create New Preset"
	new_button.pressed.connect(_on_new_pressed)
	new_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_child(new_button)

	var grid := GridContainer.new()
	grid.columns = 2
	edit_container.add_child(grid)

	grid.add_child(Label.new())
	grid.get_child(grid.get_child_count()-1).text = "Name"
	name_edit = LineEdit.new()
	grid.add_child(name_edit)

	grid.add_child(Label.new())
	grid.get_child(grid.get_child_count()-1).text = "Layer (int)"
	layer_spin = SpinBox.new()
	layer_spin.min_value = 0
	layer_spin.max_value = 4294967295
	layer_spin.step = 1
	layer_spin.value_changed.connect(_on_values_changed)
	grid.add_child(layer_spin)

	grid.add_child(Label.new())
	grid.get_child(grid.get_child_count()-1).text = "Mask (int)"
	mask_spin = SpinBox.new()
	mask_spin.min_value = 0
	mask_spin.max_value = 4294967295
	mask_spin.step = 1
	mask_spin.value_changed.connect(_on_values_changed)
	grid.add_child(mask_spin)

	var buttons := HBoxContainer.new()
	edit_container.add_child(buttons)

	save_button = Button.new()
	save_button.text = "Save"
	save_button.pressed.connect(_on_save_pressed)
	buttons.add_child(save_button)

	delete_button = Button.new()
	delete_button.text = "Delete"
	delete_button.pressed.connect(_on_delete_pressed)
	buttons.add_child(delete_button)
	
	set_default_button = Button.new()
	set_default_button.text = "Set Default"
	set_default_button.pressed.connect(_on_set_default_pressed)
	buttons.add_child(set_default_button)
	

## Called when plugin is added to scene tree or when target node changes
func _notification(what):
	if what == NOTIFICATION_READY:
		if is_instance_valid(edit_button):
			edit_button.icon = get_theme_icon("Edit", "EditorIcons")
		set_process(true)

func _process(_delta):
	if not is_instance_valid(target):
		return
	
	var changed := false
	if "collision_layer" in target:
		var target_layer = int(target.collision_layer)
		if target_layer != int(layer_spin.value):
			layer_spin.set_block_signals(true)
			layer_spin.value = target_layer
			layer_spin.set_block_signals(false)
			changed = true
	
	if "collision_mask" in target:
		var target_mask = int(target.collision_mask)
		if target_mask != int(mask_spin.value):
			mask_spin.set_block_signals(true)
			mask_spin.value = target_mask
			mask_spin.set_block_signals(false)
			changed = true
	
	if changed:
		# If it was changed externally, we should reflect that it's now custom
		# But only if it's not already set to custom or something else
		# But when in edit mode, it should NEVER switch to custom
		if edit_container.visible:
			return
		
		var current_preset = CollisionPresetsAPI.get_node_preset(target)
		if current_preset != "__custom__":
			# Check if it matches any existing preset exactly
			var matched := false
			for p in database.presets:
				if p.layer == target.collision_layer and p.mask == target.collision_mask:
					# It matches a preset, but we might want to be careful about auto-selecting it
					# For now, let's just set it to custom to be safe, or we could try to find the match
					# The requirement just asked to update spinboxes.
					pass
			
			_set_to_custom()

## Called when edit button is toggled
func _on_edit_toggled(toggled_on: bool):
	edit_container.visible = toggled_on
	preset_dropdown.disabled = toggled_on

## Called when preset values are changed in UI
func _on_values_changed(_v):
	if is_instance_valid(target):
		var changed := false
		var new_layer := int(layer_spin.value)
		var new_mask := int(mask_spin.value)
		
		if "collision_layer" in target and target.collision_layer != new_layer:
			target.collision_layer = new_layer
			changed = true
		if "collision_mask" in target and target.collision_mask != new_mask:
			target.collision_mask = new_mask
			changed = true
		
		if changed:
			if not edit_container.visible:
				_set_to_custom()

func _set_to_custom():
	if not is_instance_valid(target):
		return
	
	target.set_meta(CollisionPresetsConstants.META_KEY, "__custom__")
	if target.has_meta(CollisionPresetsConstants.META_ID_KEY):
		target.remove_meta(CollisionPresetsConstants.META_ID_KEY)
	
	preset_dropdown.set_block_signals(true)
	preset_dropdown.select(preset_dropdown.item_count - 1) # Custom
	preset_dropdown.set_block_signals(false)
	edit_button.disabled = true
	set_default_button.disabled = true
		
## Called when preset is selected in dropdown
func _on_preset_selected(index):
	if index == 0: # Default
		edit_button.disabled = true
		if is_instance_valid(target):
			if target.has_meta(CollisionPresetsConstants.META_KEY):
				target.remove_meta(CollisionPresetsConstants.META_KEY)
			if target.has_meta(CollisionPresetsConstants.META_ID_KEY):
				target.remove_meta(CollisionPresetsConstants.META_ID_KEY)
		var p = CollisionPresetsAPI.get_preset_by_id(database.default_preset_id)
		if p:
			_apply_preset_values_to_ui(p)
			if is_instance_valid(target):
				if "collision_layer" in target:
					target.collision_layer = p.layer
				if "collision_mask" in target:
					target.collision_mask = p.mask
		return

	if index == preset_dropdown.item_count - 1: # Custom
		edit_button.disabled = true
		if is_instance_valid(target):
			target.set_meta(CollisionPresetsConstants.META_KEY, "__custom__")
			if target.has_meta(CollisionPresetsConstants.META_ID_KEY):
				target.remove_meta(CollisionPresetsConstants.META_ID_KEY)
		return
	
	edit_button.disabled = false
	var p := sorted_presets[index - 1]
	name_edit.text = p.name
	set_default_button.disabled = (database.default_preset_id == p.id)
	
	_apply_preset_values_to_ui(p)
	
	if is_instance_valid(target):
		CollisionPresetsAPI.apply_preset(target, p.name)

## Applies preset values from UI to target node
func _apply_preset_values_to_ui(p):
	# Block the _on_values_changed signal from switching back to "Custom" 
	# while we are intentionally applying a preset.
	layer_spin.set_block_signals(true)
	mask_spin.set_block_signals(true)
	layer_spin.value = p.layer
	mask_spin.value = p.mask
	layer_spin.set_block_signals(false)
	mask_spin.set_block_signals(false)

## Called when "New" button is pressed in UI
func _on_new_pressed():
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
		var new_name = name_input.text.strip_edges()
		if new_name == "":
			dialog.queue_free()
			return
		
		var new_layer := 1
		var new_mask := 1
		
		if is_instance_valid(target):
			if "collision_layer" in target:
				new_layer = target.collision_layer
			if "collision_mask" in target:
				new_mask = target.collision_mask
		
		layer_spin.value = new_layer
		mask_spin.value = new_mask
		set_default_button.disabled = false
		_save_preset(new_name, new_layer, new_mask)
		
		# Open edit section automatically
		edit_button.button_pressed = true
		_on_edit_toggled(true)
		
		dialog.queue_free()
	)
	
	name_input.text_submitted.connect(func(_text):
		dialog.confirmed.emit()
		dialog.hide()
	)
	
	dialog.canceled.connect(func():
		dialog.queue_free()
	)
	
	add_child(dialog)
	dialog.popup_centered()
	name_input.grab_focus()

## Called when "Save" button is pressed in UI
func _on_save_pressed():
	var new_name = name_edit.text.strip_edges()
	if new_name == "":
		return
	
	# Try to find an existing preset by name or dropdown selection to update it
	var p: CollisionPreset = null
	for existing in database.presets:
		if existing.name == new_name:
			p = existing
			break
	
	if p == null:
		var idx := preset_dropdown.selected
		if idx > 0 and (idx - 1) < sorted_presets.size():
			p = sorted_presets[idx - 1]
	
	_save_preset(new_name, int(layer_spin.value), int(mask_spin.value), p)
	
	# Close the edit panel
	edit_button.button_pressed = false
	_on_edit_toggled(false)

## Helper to save a preset to the database and update UI
func _save_preset(p_name: String, p_layer: int, p_mask: int, p: CollisionPreset = null):
	var old_name := ""
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
	
	# Select saved preset and update target metadata
	for i in range(sorted_presets.size()):
		if sorted_presets[i] == p:
			preset_dropdown.select(i + 1)
			if is_instance_valid(target):
				CollisionPresetsAPI.apply_preset(target, p.name)
			break
	
	# Update name edit if it was used for the rename
	name_edit.text = p.name
	set_default_button.disabled = (database.default_preset_id == p.id)

## Called when "Delete" button is pressed in UI
func _on_delete_pressed():
	var idx := preset_dropdown.selected
	if idx <= 0 or (idx - 1) >= sorted_presets.size():
		return
	
	var p = sorted_presets[idx - 1]
	
	var dialog := ConfirmationDialog.new()
	dialog.title = "Delete Preset"
	dialog.dialog_text = "Are you sure you want to delete preset '%s'?" % p.name
	
	dialog.confirmed.connect(func():
		if database.default_preset_id == p.id:
			database.default_preset_id = ""
		
		var actual_idx = database.presets.find(p)
		if actual_idx != -1:
			database.presets.remove_at(actual_idx)
		
		_save_database()
		_refresh_dropdown()
		CollisionPresetsAPI.generate_preset_constants_script(database)
		
		# Reset to Default (None)
		preset_dropdown.select(0)
		_on_preset_selected(0)
		
		# Close the edit panel
		edit_button.button_pressed = false
		_on_edit_toggled(false)
		
		dialog.queue_free()
	)
	
	dialog.canceled.connect(func():
		dialog.queue_free()
	)
	
	add_child(dialog)
	dialog.popup_centered()

func _on_set_default_pressed():
	var idx := preset_dropdown.selected
	if idx <= 0 or (idx - 1) >= sorted_presets.size():
		return
	
	var p = sorted_presets[idx - 1]

	var dialog := ConfirmationDialog.new()
	dialog.title = "Set Default?"
	dialog.dialog_text = "Are you sure you want to set preset '%s' as default?" % p.name
	
	dialog.confirmed.connect(func():
		database.default_preset_id = p.id
		_save_database()
		_refresh_dropdown()
		CollisionPresetsAPI.generate_preset_constants_script(database)
		
		dialog.queue_free()
	)
	
	dialog.canceled.connect(func():
		dialog.queue_free()
	)
	
	add_child(dialog)
	dialog.popup_centered()

## Refreshes preset dropdown with current list of presets
func _refresh_dropdown():
	preset_dropdown.clear()
	var default_p = CollisionPresetsAPI.get_preset_by_id(database.default_preset_id)
	if default_p == null:
		preset_dropdown.add_item("Default (None)")
	else:
		preset_dropdown.add_item("Default (%s)" % default_p.name)
	
	# Sorts the list in alphabetical order
	sorted_presets = []
	for p in database.presets:
		sorted_presets.append(p)
	
	sorted_presets.sort_custom(func(a, b):
		return a.name.to_lower() < b.name.to_lower())
	
	for p in sorted_presets:
		preset_dropdown.add_item(p.name)
	
	preset_dropdown.add_item("Custom")

## Loads or creates presets database from file
func _load_or_create():
	CollisionPresetsAPI._load_static_presets()
	if CollisionPresetsAPI.presets_db_static != null:
		database = CollisionPresetsAPI.presets_db_static
	else:
		database = CollisionPresetsDatabase.new()
		_save_database()
		CollisionPresetsAPI.presets_db_static = database
	
	# Migration: default_preset_name -> default_preset_id
	var migration_needed := false
	if database.has_method("get") and database.get("default_preset_name") != null:
		var old_name = database.get("default_preset_name")
		if typeof(old_name) == TYPE_STRING and not old_name.is_empty() and database.default_preset_id.is_empty():
			for p in database.presets:
				if p.name == old_name:
					database.default_preset_id = p.id
					migration_needed = true
					break
	
	# Ensure all presets have IDs for robustness
	var changed := false
	for p in database.presets:
		if p.id.is_empty():
			p.id = _generate_uid()
			changed = true
	if changed or migration_needed:
		_save_database()

## Saves presets database to file
func _save_database():
	ResourceSaver.save(database, CollisionPresetsConstants.PRESET_DATABASE_PATH)

func _generate_uid() -> String:
	return str(ResourceUID.create_id())

