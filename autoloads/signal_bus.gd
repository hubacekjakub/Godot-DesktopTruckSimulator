extends Node
## Decoupled Global Signal Bus.

# Truck window lifecycle
signal truck_spawned(truck_window: Window)
signal truck_pass_completed()

# Truck movement events
signal truck_movement_stop_triggered()
signal truck_movement_stop_finished()

signal truck_movement_resume_triggered()
signal truck_movement_resume_finished()

# Customization
signal customization_finished()

# Debug actions
signal debug_portal_toggle_requested(open: bool)
signal truck_color_randomize_requested()
