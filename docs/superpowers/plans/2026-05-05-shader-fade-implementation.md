# Shader-Based Per-Pixel Truck Fade Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a smooth per-pixel "slicing" fade for the truck as it enters and leaves the screen.

**Architecture:** Use a `CanvasItem` shader on the truck sprite that calculates transparency based on `UV.x`. The `Window` size will be increased to provide a buffer for the fade, ensuring the truck is invisible before the window crosses monitor boundaries.

**Tech Stack:** GDScript, Godot Shader Language (Godot 4.x)

---

### Task 1: Create the Fade Shader

**Files:**
- Create: `shaders/truck_fade.gdshader`

- [ ] **Step 1: Create the shader file**

```gdshader
shader_type canvas_item;

uniform float fade_margin : hint_range(0.0, 0.5) = 0.1;

void fragment() {
	float alpha = 1.0;
	
	// Fade at left edge (0.0 to fade_margin)
	alpha *= smoothstep(0.0, fade_margin, UV.x);
	
	// Fade at right edge (1.0 - fade_margin to 1.0)
	alpha *= (1.0 - smoothstep(1.0 - fade_margin, 1.0, UV.x));
	
	COLOR.a *= alpha;
}
```

- [ ] **Step 2: Commit shader**

```bash
git add shaders/truck_fade.gdshader
git commit -m "feat: add truck fade shader"
```

### Task 2: Apply Shader to Truck Sprite

**Files:**
- Modify: `levels/main.tscn`

- [ ] **Step 1: Add ShaderMaterial to Truck Sprite**

Load `levels/main.tscn` and update the `Truck` node to use the new shader.

```tscn
[node name="Truck" type="Sprite2D" parent="Window" unique_id=312345669]
material = SubResource("ShaderMaterial_fade")
...

[sub_resource type="ShaderMaterial" id="ShaderMaterial_fade"]
shader = ExtResource("4_shader")
shader_parameter/fade_margin = 0.1
```
*(Note: I will use `replace` to surgically add the material and ext_resource)*

- [ ] **Step 2: Commit scene changes**

```bash
git add levels/main.tscn
git commit -m "feat: apply fade shader material to truck"
```

### Task 3: Update Main.gd for Padded Movement

**Files:**
- Modify: `scripts/Main.gd`

- [ ] **Step 1: Update window sizing and centering**

We need to make the window wider and ensure the truck stays centered in it.

```gdscript
# In _ready() or a setup function:
var truck_width = _truck_sprite.get_rect().size.x * _truck_sprite.scale.x
var fade_padding = 100 # Pixels of padding on EACH side
_sub_window.size = Vector2i(int(truck_width + (fade_padding * 2)), int(_sub_window.size.y))
_truck_sprite.position = Vector2(_sub_window.size.x / 2.0, _sub_window.size.y / 2.0)
```

- [ ] **Step 2: Update bounds check**

Adjust the "off-screen" logic so the truck is fully invisible before the window moves.

- [ ] **Step 3: Commit script changes**

```bash
git add scripts/Main.gd
git commit -m "feat: update movement logic for padded window fade"
```

### Task 4: Final Validation

- [ ] **Step 1: Run the project**

Run: `godot --path .`

- [ ] **Step 2: Verify effect**

Verify: The truck "slices" away at the screen edges and doesn't flicker when crossing monitors.
