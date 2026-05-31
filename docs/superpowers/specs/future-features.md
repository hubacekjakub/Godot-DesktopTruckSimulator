# Future Architecture Features: Progression, Customization & Jobs

This document details the progression, save, customization, and job systems planned for future implementation. The architecture is pre-configured to easily adopt these components.

---

## 1. Local Save System

### Save Path
To prevent user save corruption and separate user files on Windows, the save file will be placed in the user's standard application data directory.
*   **Path**: `user://save.tres`
*   **Resolved Windows Path**: `%APPDATA%/Godot/app_userdata/Godot-DesktopTruckSimulator/save.tres`

### `SaveData` Resource (`res://resources/save_data.gd`)
A Custom Resource that holds persistent player progression.
```gdscript
extends Resource
class_name SaveData

@export var cash: int = 0
@export var unlocked_skin_ids: Array[String] = ["default"]
@export var equipped_body_skin: String = "default"
@export var equipped_wheel_skin: String = "default"
@export var active_job_id: String = ""
@export var active_job_remaining_time: float = 0.0
```

### `SaveManager` Autoload (`res://autoloads/save_manager.gd`)
*   Provides `save_game()` and `load_game()` wrappers using `ResourceSaver` and `ResourceLoader`.
*   Automatically initializes a fresh `SaveData` resource if the file is missing or corrupted.
*   Triggers an autosave whenever a job is completed or cosmetics are purchased.

---

## 2. Job System

### Toggleable Integration
*   The job system is toggleable inside `settings.cfg` (`job_system_enabled = true`). If disabled, the job panel menu is hidden and the truck is never loaded with cargo.

### `JobResource` (`res://resources/job_resource.gd`)
Defines the parameters of a job:
```gdscript
extends Resource
class_name JobResource

@export var job_id: String
@export var title: String
@export var duration_seconds: float
@export var reward_cash: int
@export var reward_skin_unlock: String # Skin ID unlocked on completion (optional)
@export var cargo_texture: Texture2D   # Visual sprite attached to the truck
```

### `JobManager` Autoload (`res://autoloads/job_manager.gd`)
*   Maintains the active timer for the current job.
*   **Visual Integration with Truck**:
    *   When a job is active, `JobManager` emits `SignalBus.job_state_changed(is_active, cargo_texture)`.
    *   The `TruckEntity` listens to this signal. If a job is active, it attaches the `cargo_texture` to its trailer/cargo sprite slot.
*   **Job Completion**:
    *   When the timer expires, `JobManager` calls `SaveManager` to add cash, unlock skins, and clears the active job.
    *   Emits `SignalBus.job_completed()`.

---

## 3. Customization Parts

### `TruckPartResource` (`res://resources/truck_part_resource.gd`)
A Resource representing a purchasable/unlockable skin cosmetic:
```gdscript
extends Resource
class_name TruckPartResource

@export var skin_id: String
@export var part_type: String # "body" or "wheels"
@export var texture: Texture2D
@export var color_modulate: Color = Color.WHITE
@export var scale_offset: Vector2 = Vector2.ONE
```

### Applying Customizations
*   The `TruckEntity` reads resources of this type to swap out textures at runtime.
*   The player changes these equipped parts inside the customizer menu UI in the Job Panel.
