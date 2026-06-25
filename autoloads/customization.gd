extends Node
## Handles skin customization to the truck. Owns the color + cabin catalogs and
## current selection. Persists across sessions via SaveManager.

const DEFAULT_COLOR_ID := "#ebede9"
const DEFAULT_CABIN_ID := "cabin_eu_basic"

# Always available — never saved, never locked.
var _default_colors: Array[String] = [
	"#ebede9",
	"#e8c170",
	"#a4dddb",
	"#df84a5",
	"#4f8fba",
	"#cf573c",
	"#3c5e8b",
	"#7a4841",
	"#25562e",
	"#a23e8c",
	"#411d31",
	"#253a5e",
]

# Hidden until unlocked through gameplay or manually added to save file.
var _unlockable_colors: Array[String] = [
	"#73bed3",
	"#577277",
	"#a8ca58",
	"#468232",
	"#de9e41",
	"#a53030",
	"#c65197",
	"#7a367b",
	"#be772b",
	"#602c2c",
	"#da863e",
	"#e7d5b3",
	"#ad7757",
	"#819796",
]

# Populated from save on boot. Subset of _unlockable_colors + any custom player hex strings.
var _unlocked_colors: Array[String] = []

# All cabins start unlocked. Held as base Resource — autoload must not reference
# TruckBodyResource class_name statically (class-registry rule).
var _cabin_catalog: Dictionary = {
	"cabin_eu_basic": preload("res://resources/truck_bodies/eu_truck_basic.tres"),
	"cabin_us_basic": preload("res://resources/truck_bodies/us_truck_basic.tres"),
}

var _garage_window_resource: String = "res://scenes/garage/garage_window.tscn"
var _garage_window_instance: Window = null

var current_color_id: String = DEFAULT_COLOR_ID
var current_cabin_id: String = DEFAULT_CABIN_ID

func _ready() -> void:
	SignalBus.truck_spawned.connect(_on_truck_spawned)
	SignalBus.truck_movement_stop_finished.connect(_on_truck_movement_stop_finished)
	SignalBus.truck_movement_resume_triggered.connect(_on_truck_movement_resume_triggered)
	SignalBus.customization_confirmed.connect(_on_customization_confirmed)
	SignalBus.customization_finished.connect(_on_customization_finished)
	SignalBus.save_loaded.connect(_on_save_loaded)
	SignalBus.tray_visibility_changed.connect(_on_tray_visibility_changed)
	SignalBus.tray_customization_requested.connect(_on_tray_customization_requested)

func get_available_colors() -> Array[String]:
	var result: Array[String] = _default_colors.duplicate()
	for hex in _unlocked_colors:
		if not result.has(hex):
			result.append(hex)
	return result

func get_bodies() -> Dictionary:
	return _cabin_catalog

func get_unlocked_colors() -> Array[String]:
	return _unlocked_colors

func is_color_unlockable(hex: String) -> bool:
	return _unlockable_colors.has(hex)

func _on_save_loaded(color_id: String, cabin_id: String, unlocked_colors: Array[String]) -> void:
	if not color_id.is_empty():
		current_color_id = color_id
	if not cabin_id.is_empty():
		current_cabin_id = cabin_id
	_unlocked_colors.assign(unlocked_colors)

func _on_truck_spawned(_truck_window: Window) -> void:
	SignalBus.customization_color_changed.emit(Color(current_color_id))
	if _cabin_catalog.has(current_cabin_id):
		SignalBus.customization_cabin_changed.emit(_cabin_catalog[current_cabin_id])

func _on_truck_movement_stop_finished() -> void:
	if _garage_window_resource.is_empty():
		return
	_garage_window_instance = WindowManager.spawn_window(_garage_window_resource)

func _on_truck_movement_resume_triggered() -> void:
	if is_instance_valid(_garage_window_instance):
		_garage_window_instance.queue_free()
		_garage_window_instance = null

func _on_customization_confirmed(color_id: String, cabin_id: String) -> void:
	current_color_id = color_id
	current_cabin_id = cabin_id
	SignalBus.customization_finished.emit()

func _on_customization_finished() -> void:
	if is_instance_valid(_garage_window_instance):
		_garage_window_instance.queue_free()
		_garage_window_instance = null

func _on_tray_visibility_changed(visible: bool) -> void:
	if not visible and is_instance_valid(_garage_window_instance):
		_garage_window_instance.queue_free()
		_garage_window_instance = null

func _on_tray_customization_requested() -> void:
	if is_instance_valid(_garage_window_instance):
		return
	SignalBus.truck_movement_stop_triggered.emit()
