extends Node
## Loads and saves player progress to user://savegame.json.
## Emits SignalBus.save_loaded on boot; autosaves on customization_confirmed.

const SAVE_PATH := "user://savegame.json"
const SAVE_VERSION := 1

func _ready() -> void:
	SignalBus.customization_confirmed.connect(_on_customization_confirmed)
	_load()

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		SignalBus.save_loaded.emit("", "", [] as Array[String])
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_error("SaveManager: cannot open %s" % SAVE_PATH)
		SignalBus.save_loaded.emit("", "", [] as Array[String])
		return

	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_error("SaveManager: corrupt save file — resetting to defaults")
		SignalBus.save_loaded.emit("", "", [] as Array[String])
		return

	var cust: Dictionary = parsed.get("customization", {})
	var color_id: String = cust.get("color", "")
	var cabin_id: String = cust.get("cabin", "")
	var raw_unlocked = cust.get("unlocked_colors", [])
	var unlocked_colors: Array[String] = []
	unlocked_colors.assign(raw_unlocked)

	SignalBus.save_loaded.emit(color_id, cabin_id, unlocked_colors)

func _on_customization_confirmed(_color_id: String, _cabin_id: String) -> void:
	_save()

func _save() -> void:
	var data := {
		"version": SAVE_VERSION,
		"customization": {
			"color": Customization.current_color_id,
			"cabin": Customization.current_cabin_id,
			"unlocked_colors": Customization.get_unlocked_colors(),
		}
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_error("SaveManager: cannot write to %s" % SAVE_PATH)
		return

	file.store_string(JSON.stringify(data, "\t"))
	file.close()
