extends Node
## Decoupled Global Signal Bus.

# Truck window lifecycle
signal truck_spawned(truck_window: Window)
signal truck_pass_completed()

# Debug actions
signal movement_toggle_requested(is_moving: bool)
signal debug_portal_toggle_requested(open: bool)
signal truck_color_randomize_requested()
