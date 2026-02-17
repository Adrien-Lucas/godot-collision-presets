# Godot Collision Presets
<img width="150" height="150" alt="collision_presets_logo" src="https://github.com/user-attachments/assets/8d2c40ce-2669-4fe1-8083-37110eb11f43" />

Turn messy fiddling with collision layers and masks into presets that you can easily apply to your nodes.

### Overview
Godot already provides 32 collision layers, but managing them across large projects quickly becomes error-prone.

**Collision Presets** is a Godot 4 editor plugin designed to simplify physics management in 2D or 3D projects. Instead of manually memorizing bitmask integers or ticking boxes for every `CollisionObject3D`, you can define named presets (e.g., "Player", "Enemy", "Trigger") and apply them with a single click. The plugin keeps layers and masks in sync at runtime and exposes a small, clean API for code usage.

| BEFORE | AFTER |
|---|---|
| ![godot windows editor dev x86_64_n4lsLj8fD1](https://github.com/user-attachments/assets/cb8f55e3-90ce-4657-a0f9-1b8364b36cbe) | ![godot windows editor dev x86_64_DiAuice1ji-00 00 00 000-00 00 08 701](https://github.com/user-attachments/assets/0323e0a5-dbfd-4168-9c8f-4f02073c2c59) |


### Minimal Examples
Once a preset is defined in the editor, you can apply it in your scripts using the generated constants:

```gdscript
# Setting a node's preset is supported in @tool mode. Uncomment to try it out!
# @tool
extends CharacterBody3D

func _ready():
    # Automatically apply the "Player" preset
    CollisionPresetsAPI.set_node_preset(self, CollisionPresets.Player)
```

Or check a preset's mask value for raycasting:
```gdscript
var query := PhysicsRayQueryParameters3D.create(from, to)

var collision_preset_list = [CollisionPresets.WorldStatic, CollisionPresets.Player]
for preset_name in collision_preset_list:
    var preset_layer = CollisionPresetsAPI.get_preset_layer(preset_name)
    query.collision_mask |= preset_layer # Combine multiple layer bitmasks
var result := space_state.intersect_ray(query)
```

### Features
*   **Inspector Integration**: A custom UI appears directly in the `CollisionObject` inspector.
*   **Default Collision Preset**: Define a project-wide default preset automatically applied to any CollisionObject without a preset.
*   **Metadata Based**: The selected preset is stored in the node’s metadata. This makes it source control friendly and fully compatible with scene inheritance.
*   **Centralized Database**: All collision presets are saved automatically in a single `.tres` resource.
*   **Type-Safe Constants**: Automatically generates a `CollisionPresets` class with constants for all your preset names, enabling autocomplete and preventing typos.
*   **Runtime Sync**: An autoload ensures that any node with a preset assigned in the editor gets the correct layer and mask values when the game starts.
*   **ID-Based Robustness**: Presets use unique IDs internally, so renaming a preset won't break your existing node assignments.

### Short Documentation

#### API Reference (`CollisionPresetsAPI`)
*   `get_preset_layer(name)` / `get_preset_mask(name)`: Retrieves the raw integer values for a specific preset.
*   `set_node_preset(node, preset_name)`: Sets a preset and updates the node's metadata (safe for `@tool` scripts).
*   `get_node_preset(node)`: Returns the name of the preset currently assigned to a node.

#### Generated Constants (`CollisionPresets`)
The plugin generates a script at `res://addons/collision_presets/preset_names.gd` containing:
*   `CollisionPresets.YOUR_PRESET_NAME`: A string constant for each preset.
*   `CollisionPresets.all()`: Returns a `PackedStringArray` of all available preset names.

### Installation
1.  Download or clone this repository into your project's `addons/` folder.
2.  Go to **Project Settings > Plugins** and enable **Collision Presets**.
3.  The plugin will automatically:
    *   Create a `presets.tres` file in the plugin folder.
    *   Register a `CollisionPresetRuntime` autoload.
    *   Generate the `CollisionPresets` constants script.
4.  Select any `CollisionObject` (StaticBody, CharacterBody, etc.) and look for the **Preset** dropdown in the Inspector.

### AI Disclaimer
This plugin was mainly vibe-coded using Junie by JetBrain. 
It was then cleaned and refined by hand to reach release quality.
