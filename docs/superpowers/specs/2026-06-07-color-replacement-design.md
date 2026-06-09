# Design Spec: Color Replacement Shader & Test Scene

This document details the design for expanding the truck edge-fade shader to support:
1. Replacing pure white color (`RGB = 1.0, 1.0, 1.0`) with a custom target color.
2. Toggling the edge-fade effect on or off.
3. Creating a test scene for manual validation of both features.

## Proposed Changes

### 1. Shader Modification
We will update [truck_fade.gdshader](file:///d:/Projects/Godot-DesktopTruckSimulator/shaders/truck_fade.gdshader) to include:
*   A new uniform `paint_color` of type `vec4` (using the `: source_color` hint) defaulting to white `(1.0, 1.0, 1.0, 1.0)`.
*   A new uniform `enable_fade` of type `bool` defaulting to `true`.
*   A conditional check inside `fragment()` that detects if the texture pixel color is exactly white (`vec3(1.0)`) and swaps its RGB values with `paint_color.rgb`.
*   A conditional wrapper around the alpha-fading math using `enable_fade`.

### 2. Main Game Truck Entity Support
We will update [truck_entity.gd](file:///d:/Projects/Godot-DesktopTruckSimulator/scenes/truck/truck_entity.gd):
*   Update the `_on_color_randomize_requested()` method to set the `paint_color` shader parameter on the material, instead of using `self_modulate`. This ensures we only colorize the white parts of the truck body and keep wheels/windows/lights unmodified.
*   Ensure that the material properties are set correctly using `set_shader_parameter("paint_color", new_color)`.

### 3. Test Scene Creation
We will update the test scene at `levels/shader_test_scene.tscn` and script `levels/shader_test_scene.gd` to test both features in isolation:
*   **Visual Nodes**:
    *   `Node2D` root.
    *   `Sprite2D` for the truck body, using the modified shader material.
    *   `Sprite2D` for the wheels.
    *   A clean background (solid color or standard grid).
*   **UI Controls**:
    *   A `ColorPickerButton` to select any color interactively.
    *   A `Button` to randomize the color.
    *   A `Button` to reset the color to white.
    *   A `CheckBox` to toggle the edge-fade effect on/off.
*   **Behavior**:
    *   The test scene script will listen to UI signals and call `set_shader_parameter("paint_color", color)` and `set_shader_parameter("enable_fade", boolean)` on the truck material.

## Spec Self-Review
*   **Placeholder scan**: Checked. No placeholders are used.
*   **Consistency**: Checked. The shader uniforms match what the scripts will interact with.
*   **Scope check**: Checked. A single iteration covers both the shader changes and the test scene update.
