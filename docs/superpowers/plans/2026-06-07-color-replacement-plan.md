# Paint Job Color Replacement & Fade Toggle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand the truck's shader so we can replace any pure white pixel (`RGB = 1.0, 1.0, 1.0`) in the texture with a custom color, add an option to enable/disable the edge-fade effect, and update the test scene UI controls to test both features.

**Architecture:** We will modify `shaders/truck_fade.gdshader` to add `uniform vec4 paint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);` and `uniform bool enable_fade = true;`. We will wrap the alpha-fade calculation in a conditional `if (enable_fade)`. In `truck_entity.gd`, we randomize the shader parameter on color-randomization requests instead of using `self_modulate`. We will update `levels/shader_test_scene.tscn` to add a toggle CheckBox and update `levels/shader_test_scene.gd` to propagate it.

**Tech Stack:** Godot 4, GDScript, GDShader.

---

### Task 1: Update Shader & Entity Color Randomization

**Files:**
- Modify: `shaders/truck_fade.gdshader`
- Modify: `scenes/truck/truck_entity.gd`

- [ ] **Step 1: Modify the Shader**
  Add the uniforms and exact-match / fade-toggle condition to [truck_fade.gdshader](file:///d:/Projects/Godot-DesktopTruckSimulator/shaders/truck_fade.gdshader):
  ```glsl
  uniform vec4 paint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
  uniform bool enable_fade = true;
  ```
  And update `fragment()`:
  ```glsl
  void fragment() {
  	vec4 tex_color = texture(TEXTURE, UV);
  	
  	if (tex_color.rgb == vec3(1.0)) {
  		tex_color.rgb = paint_color.rgb;
  	}
  	
  	// Calculate the global X position of this pixel
  	float pixel_global_x = window_x + (SCREEN_UV.x * window_width);

  	float alpha = 1.0;

  	if (enable_fade) {
  		// Fade at screen left edge
  		alpha *= smoothstep(screen_left + safety_margin, screen_left + safety_margin + fade_margin, pixel_global_x);

  		// Fade at screen right edge
  		alpha *= (1.0 - smoothstep(screen_right - safety_margin - fade_margin, screen_right - safety_margin, pixel_global_x));
  	}

  	COLOR = tex_color * COLOR;
  	COLOR.a *= alpha;
  }
  ```

- [ ] **Step 2: Update TruckEntity script**
  Modify the randomize color handler in [truck_entity.gd](file:///d:/Projects/Godot-DesktopTruckSimulator/scenes/truck/truck_entity.gd) to target the shader parameter instead of modulating the entire sprite:
  ```gdscript
  func _on_color_randomize_requested() -> void:
  	if is_instance_valid(_truck_body):
  		var mat := _truck_body.material as ShaderMaterial
  		if mat:
  			var new_color = Color(
  				randf_range(0.2, 1.0),
  				randf_range(0.2, 1.0),
  				randf_range(0.2, 1.0),
  				1.0
  			)
  			mat.set_shader_parameter("paint_color", new_color)
  ```

- [ ] **Step 3: Run headless syntax verification**
  Run: `godot.exe --headless --path . -e -q`
  Expected: Success without compilation or parser errors.

---

### Task 2: Update Shader Test Scene

**Files:**
- Modify: `levels/shader_test_scene.tscn`
- Modify: `levels/shader_test_scene.gd`

- [ ] **Step 1: Update script `levels/shader_test_scene.gd`**
  ```gdscript
  extends Node2D

  @onready var _truck: TruckEntity = $TruckEntity
  @onready var _color_picker: ColorPickerButton = $CanvasLayer/ControlPanel/Margin/VBox/HBoxColor/ColorPickerButton
  @onready var _chk_fade: CheckBox = $CanvasLayer/ControlPanel/Margin/VBox/ChkFade

  func _ready() -> void:
  	# Reset window mode for interactive desktop testing
  	var win = get_window()
  	win.mode = Window.MODE_WINDOWED
  	win.size = Vector2i(1000, 600)
  	win.position = Vector2i(100, 100)
  	
  	await get_tree().process_frame
  	_update_truck_color(Color.WHITE)
  	_color_picker.color = Color.WHITE
  	_chk_fade.button_pressed = true
  	_update_fade_enabled(true)

  func _on_color_changed(color: Color) -> void:
  	_update_truck_color(color)

  func _on_btn_random_pressed() -> void:
  	var random_color = Color(
  		randf_range(0.2, 1.0),
  		randf_range(0.2, 1.0),
  		randf_range(0.2, 1.0),
  		1.0
  	)
  	_color_picker.color = random_color
  	_update_truck_color(random_color)

  func _on_btn_reset_pressed() -> void:
  	_color_picker.color = Color.WHITE
  	_update_truck_color(Color.WHITE)

  func _on_chk_fade_toggled(toggled_on: bool) -> void:
  	_update_fade_enabled(toggled_on)

  func _update_truck_color(color: Color) -> void:
  	if is_instance_valid(_truck):
  		var body_sprite = _truck.get_node_or_null("TruckBody") as Sprite2D
  		if body_sprite and body_sprite.material:
  			body_sprite.material.set_shader_parameter("paint_color", color)

  func _update_fade_enabled(enabled: bool) -> void:
  	if is_instance_valid(_truck):
  		var body_sprite = _truck.get_node_or_null("TruckBody") as Sprite2D
  		if body_sprite and body_sprite.material:
  			body_sprite.material.set_shader_parameter("enable_fade", enabled)
  ```

- [ ] **Step 2: Update scene file `levels/shader_test_scene.tscn`**
  ```tscn
  [gd_scene load_steps=3 format=3]

  [ext_resource type="PackedScene" path="res://scenes/truck/truck_entity.tscn" id="1_truck"]
  [ext_resource type="Script" path="res://levels/shader_test_scene.gd" id="2_script"]

  [node name="ShaderTestScene" type="Node2D"]
  script = ExtResource("2_script")

  [node name="TruckEntity" parent="." instance=ExtResource("1_truck")]
  position = Vector2(500, 300)

  [node name="CanvasLayer" type="CanvasLayer" parent="."]

  [node name="ControlPanel" type="PanelContainer" parent="CanvasLayer"]
  offset_left = 20.0
  offset_top = 20.0
  offset_right = 320.0
  offset_bottom = 240.0

  [node name="Margin" type="MarginContainer" parent="CanvasLayer/ControlPanel"]
  layout_mode = 2
  theme_override_constants/margin_left = 12
  theme_override_constants/margin_top = 12
  theme_override_constants/margin_right = 12
  theme_override_constants/margin_bottom = 12

  [node name="VBox" type="VBoxContainer" parent="CanvasLayer/ControlPanel/Margin"]
  layout_mode = 2
  theme_override_constants/separation = 10

  [node name="Title" type="Label" parent="CanvasLayer/ControlPanel/Margin/VBox"]
  layout_mode = 2
  text = "Shader Test Control"
  horizontal_alignment = 1

  [node name="HBoxColor" type="HBoxContainer" parent="CanvasLayer/ControlPanel/Margin/VBox"]
  layout_mode = 2

  [node name="Label" type="Label" parent="CanvasLayer/ControlPanel/Margin/VBox/HBoxColor"]
  layout_mode = 2
  text = "Paint Color: "

  [node name="ColorPickerButton" type="ColorPickerButton" parent="CanvasLayer/ControlPanel/Margin/VBox/HBoxColor"]
  layout_mode = 2
  size_flags_horizontal = 3
  edit_alpha = false

  [node name="ChkFade" type="CheckBox" parent="CanvasLayer/ControlPanel/Margin/VBox"]
  layout_mode = 2
  button_pressed = true
  text = "Enable Edge Fading"

  [node name="BtnRandom" type="Button" parent="CanvasLayer/ControlPanel/Margin/VBox"]
  layout_mode = 2
  text = "Randomize Color"

  [node name="BtnReset" type="Button" parent="CanvasLayer/ControlPanel/Margin/VBox"]
  layout_mode = 2
  text = "Reset to White"

  [connection signal="color_changed" from="CanvasLayer/ControlPanel/Margin/VBox/HBoxColor/ColorPickerButton" to="." method="_on_color_changed"]
  [connection signal="toggled" from="CanvasLayer/ControlPanel/Margin/VBox/ChkFade" to="." method="_on_chk_fade_toggled"]
  [connection signal="pressed" from="CanvasLayer/ControlPanel/Margin/VBox/BtnRandom" to="." method="_on_btn_random_pressed"]
  [connection signal="pressed" from="CanvasLayer/ControlPanel/Margin/VBox/BtnReset" to="." method="_on_btn_reset_pressed"]
  ```

- [ ] **Step 3: Verify scene headless**
  Run: `godot.exe --headless --path . -e -q`
  Expected: Success without compilation or parser errors.

- [ ] **Step 4: Launch and manually verify the test scene**
  Run: `godot_console.exe --path . res://levels/shader_test_scene.tscn`
  Expected: A window opens displaying the truck, allowing you to pick colors via the UI, toggle the edge fading checkbox, and verify the behaviors dynamically.
