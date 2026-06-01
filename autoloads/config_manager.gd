extends Node
## Manages application settings loaded from a file sitting next to the EXE.

const CONFIG_NAME = "settings.cfg"
var _config: ConfigFile = ConfigFile.new()
var _settings: Dictionary = {}

func _ready() -> void:
	var exe_dir = OS.get_executable_path().get_base_dir()
	# If running inside editor, fall back to project directory
	if OS.has_feature("editor"):
		exe_dir = "res://"
	
	var dest_path = exe_dir.path_join(CONFIG_NAME)
	
	# Verify if config file is present in the target directory
	if not FileAccess.file_exists(dest_path):
		_copy_default_config(dest_path)
		
	var err = _config.load(dest_path)
	if err == OK:
		_load_settings()
	else:
		push_error("Failed to load settings file: %d" % err)

func get_setting(section: String, key: String, default: Variant) -> Variant:
	if _settings.has(section) and _settings[section].has(key):
		return _settings[section][key]
	return default

func _copy_default_config(dest_path: String) -> void:
	var default_file = FileAccess.open("res://settings.cfg", FileAccess.READ)
	if default_file:
		var content = default_file.get_as_text()
		default_file.close()
		var new_file = FileAccess.open(dest_path, FileAccess.WRITE)
		if new_file:
			new_file.store_string(content)
			new_file.close()
			print("ConfigManager: Duplicated default settings.cfg to: ", dest_path)
		else:
			push_error("ConfigManager: Cannot write configuration to: " + dest_path)
	else:
		push_error("ConfigManager: Package template res://settings.cfg is missing!")

func _load_settings() -> void:
	for section in _config.get_sections():
		_settings[section] = {}
		for key in _config.get_section_keys(section):
			_settings[section][key] = _config.get_value(section, key)
