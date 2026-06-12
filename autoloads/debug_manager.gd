extends Node
## Manages spawning of debug panel and linking viewports.

var _panel: Window = null
var _portal: Window = null
var _truck_win_ref: Window = null

func _ready() -> void:
	if not OS.is_debug_build():
		return
	# Spawns panel at startup. The panel positions and shows itself in its _ready.
	_panel = WindowManager.spawn_window("res://scenes/debug/debug_panel.tscn")
	if is_instance_valid(_panel):
		_panel.tree_exiting.connect(func(): _panel = null)

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
			# The portal positions and shows itself in its _ready.
			_portal = WindowManager.spawn_window("res://scenes/debug/debug_portal.tscn")
			if not is_instance_valid(_portal):
				return

			# Reset reference and sync UI button if closed directly
			_portal.tree_exiting.connect(func():
				_portal = null
				SignalBus.debug_portal_toggle_requested.emit(false)
			)

			# spawn_window adds deferred, so the portal is not in the tree yet.
			# Link its viewport to the truck's world once it is actually ready,
			# rather than relying on the order of _ready() vs this assignment.
			_portal.ready.connect(_link_portal_world, CONNECT_ONE_SHOT)
	else:
		if is_instance_valid(_portal):
			_portal.queue_free()
			_portal = null

## Connects the portal's viewport to the current truck's shared world. Safe to
## call only once the portal is in the tree and ready (see _on_portal_toggle).
func _link_portal_world() -> void:
	if is_instance_valid(_portal) and is_instance_valid(_truck_win_ref):
		_portal.connect_world(_truck_win_ref)
