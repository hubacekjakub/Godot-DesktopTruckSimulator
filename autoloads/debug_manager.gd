extends Node
## Manages spawning of debug panel and linking viewports.

var _panel: Window = null
var _portal: Window = null
var _truck_win_ref: Window = null

func _ready() -> void:
	# Spawns panel at startup
	_panel = load("res://scenes/debug/debug_panel.tscn").instantiate()
	get_tree().root.add_child.call_deferred(_panel)
	_panel.tree_exiting.connect(func(): _panel = null)
	
	# Position the panel lower (centered horizontally, shifted vertically)
	var rect := WindowManager.get_usable_rect()
	_panel.position = Vector2i(rect.position.x + 100, rect.position.y + 300)
	
	SignalBus.debug_portal_toggle_requested.connect(_on_portal_toggle)
	SignalBus.truck_spawned.connect(_on_truck_spawned)

func _on_truck_spawned(truck_win: Window) -> void:
	_truck_win_ref = truck_win
	# Feed window to debug portal if active
	if is_instance_valid(_portal):
		_portal.connect_world(truck_win)

func _on_portal_toggle(open: bool) -> void:
	if open:
		if not is_instance_valid(_portal):
			_portal = load("res://scenes/debug/debug_portal.tscn").instantiate()
			get_tree().root.add_child(_portal)
			
			# Position the portal lower
			var rect := WindowManager.get_usable_rect()
			_portal.position = Vector2i(rect.position.x + 400, rect.position.y + 300)
			
			# Reset reference and sync UI button if closed directly
			_portal.tree_exiting.connect(func():
				_portal = null
				SignalBus.debug_portal_toggle_requested.emit(false)
			)
			
			if is_instance_valid(_truck_win_ref):
				_portal.connect_world(_truck_win_ref)
	else:
		if is_instance_valid(_portal):
			_portal.queue_free()
			_portal = null
