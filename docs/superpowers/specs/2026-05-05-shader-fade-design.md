# Shader-Based Per-Pixel Truck Fade Design Specification

**Goal:** Implement a "portal-like" fade where the truck gradually slices away (per-pixel) as it enters and leaves the primary screen bounds.

**Context:** The truck is a `Sprite2D` inside a `Window` node. The `Window` moves horizontally across the screen.

## 1. Shader Architecture

### Logic
The shader will be a `CanvasItem` shader applied to the `Truck` (Sprite2D). It will calculate the alpha for each pixel based on its horizontal position relative to the window edges.

### Uniforms (Parameters)
- `fade_margin_pixels` (float): The width in pixels of the fade zone at the window edges.

### Fragment Function
The shader will use `UV` (texture coordinates) combined with the sprite's dimensions, OR we can use a simpler approach by ensuring the `Window` is the "canvas" and the truck is a child. 

Actually, the most robust way in Godot is to use the `UV` of the `Sprite2D` if the sprite fills the window, or pass the window size to the shader.

**Refined Logic:**
We will use `varying` to pass the local vertex position to the fragment shader, or just use `UV` if the truck sprite is the only thing we care about. 

```gdshader
shader_type canvas_item;

uniform float fade_margin = 0.2; // Percentage of width (0.0 to 0.5)

void fragment() {
    float alpha = 1.0;
    
    // Fade at left edge
    alpha *= smoothstep(0.0, fade_margin, UV.x);
    
    // Fade at right edge
    alpha *= (1.0 - smoothstep(1.0 - fade_margin, 1.0, UV.x));
    
    COLOR.a *= alpha;
}
```

## 2. Component Changes

### `Main.gd`
- **Window Sizing:** The `Window` size will be increased (e.g., Truck Width + 200px) to provide "padding" for the fade.
- **Positioning:** The movement logic will be adjusted so that `_current_x` represents the position of the *truck*, but the `Window` is offset so the truck is centered.
- **Bounds:** The "off-screen" check will now account for the extra window width, ensuring the truck is 100% faded before the window is moved or hidden.

### `Main.tscn`
- Create `ShaderMaterial` on the `Truck` node.
- Create/Assign `truck_fade.gdshader`.

## 3. Success Criteria
- Truck appears to "drive out of a fog" when entering.
- Truck "drives into a fog" when leaving.
- No flickering or glitching at screen boundaries.

## 4. Implementation Plan
1. Create `truck_fade.gdshader`.
2. Update `Main.tscn` to use the shader.
3. Update `Main.gd` to handle the wider window and padded bounds.
4. Validate with a test run.
