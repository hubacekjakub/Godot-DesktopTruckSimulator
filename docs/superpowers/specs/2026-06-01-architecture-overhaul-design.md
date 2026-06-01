# Architecture Overhaul Design: Desktop Truck Simulator

This document defines the overhaul of the Desktop Truck Simulator architecture. The goals of this design are to break down the monolithic `main.gd` file, introduce a scalable structure, decouple components using a global Event Bus, and support clean window-to-entity separation.

## Proposed Directory Structure
The files are organized into distinct folders to group logic cleanly:

```
res://
├── assets/                  # Audio, font, and sprite textures
│   └── textures/
├── autoloads/               # Application-wide singletons
│   ├── config_manager.gd    # Settings file parser and copier
│   ├── global.gd            # Application lifecycle & state orchestrator
│   ├── signal_bus.gd        # Decoupled Event Bus
│   ├── window_manager.gd    # OS Window instances & monitor bounds controller
│   └── debug_manager.gd     # Controls Debug Panel/Portal windows
├── levels/                  # Application startup point
│   ├── main.tscn            # Invisible root scene containing Autoload triggers
│   └── main.gd              # Bootstraps the application settings
├── scenes/                  # Visual scenes & logic
│   ├── truck/
│   │   ├── truck_entity.tscn
│   │   ├── truck_entity.gd   # Physics movement logic, bobbing animation, particles
│   │   ├── truck_window.tscn
│   │   └── truck_window.gd   # Window wrapper hosting the viewport
│   └── debug/
│       ├── debug_panel.tscn
│       ├── debug_panel.gd    # GUI controllers panel (Open portal, stop truck, hello)
│       ├── debug_portal.tscn
│       └── debug_portal.gd   # Tracked 2D Camera viewport window
└── shaders/                 # Material shaders (edge fading)
    └── truck_fade.gdshader
```

---

## Core Autoloads

### 1. `SignalBus` (`res://autoloads/signal_bus.gd`)
A global router containing signals that decouple all features. Nodes connect to and emit from this bus to avoid hard references.

```gdscript
extends Node

# Truck Window Lifecycle
signal truck_spawn_requested(direction: int, speed: float)
signal truck_spawned(truck_window: Window)
signal truck_pass_completed()

# Debug Control Requests
signal movement_toggle_requested(is_moving: bool)
signal debug_portal_toggle_requested(open: bool)
signal hello_button_toggle_requested()
signal truck_color_randomize_requested()
```

### 2. `ConfigManager` (`res://autoloads/config_manager.gd`)
Loads settings from a physical configuration file sitting next to the compiled game `.exe`.
*   **Default Configuration Packaging**: A default `settings.cfg` is packaged inside the app binary at `res://settings.cfg`.
*   **Duplicate on Startup**: On boot, the manager checks if a file exists at `OS.get_executable_path().get_base_dir() + "/settings.cfg"`. If it is missing, it reads the packaged resource and writes a copy of it to the executable directory.
*   **Settings structure**:
    ```ini
    [TruckSettings]
    min_speed = 200.0
    max_speed = 600.0
    min_wait_time = 5.0
    max_wait_time = 15.0
    vertical_offset = -192
    ```

### 3. `WindowManager` (`res://autoloads/window_manager.gd`)
Manages OS Windows, applies the transparency fix, and queries display metrics.
*   Enforces `DisplayServer.window_set_flag` changes after wait frames.
*   Provides `spawn_window(scene_path: String, configuration_params: Dictionary) -> Window` wrapper.
*   Maintains references to active windows.
*   Queries usable monitor metrics (stays locked to the startup screen for now).

### 4. `Global` (`res://autoloads/global.gd`)
Orchestrates the active state of the simulator (e.g. driving vs waiting).
*   Owns the wait `Timer` that runs between passes.
*   Listens to `SignalBus.truck_pass_completed` to start the wait timer and free the current truck window.
*   On timer timeout, randomly decides direction and speed parameters, and emits `SignalBus.truck_spawn_requested`.

### 5. `DebugManager` (`res://autoloads/debug_manager.gd`)
Manages the lifetime of debug panels and overlays.
*   Automatically instantiates the `DebugPanel` window on application startup.
*   Listens to `debug_portal_toggle_requested`, `hello_button_toggle_requested`, and other debug events.
*   Spawns and links the `DebugPortal` window, configuring its shared `world_2d` to match the main viewport context.

---

## Game Entity Split: Viewport vs Entity

### `TruckWindow` (Wrapper)
*   **Extends**: `Window`
*   **Properties**: Borderless, transparent, unfocusable, `mouse_passthrough` enabled.
*   **Role**: Serves as the actual OS window viewport on the desktop screen. It stays locked to the screen boundaries using clamping logic.
*   **Edge Slide-off**: When the child `TruckEntity` approaches screen boundaries, the window stays clamped to the edge, but offset offsets are passed down to `TruckEntity` to draw it sliding out of frame.

### `TruckEntity` (Visual and Physics)
*   **Extends**: `Node2D`
*   **Contains**: `Sprite2D` body, `Sprite2D` wheels, `GPUParticles2D` dust emitters.
*   **Movement**: Multiplies speed, multiplier, and delta to calculate logical positioning. When it drives beyond the active screen boundaries, it triggers a call to `SignalBus.truck_pass_completed`.
