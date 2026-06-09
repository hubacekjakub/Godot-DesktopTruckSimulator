shader_type canvas_item;

uniform float window_x = 0.0;        // Global X position of the window
uniform float window_width = 1.0;    // Total width of the window (default to 1.0 to avoid div by zero)
uniform float screen_left = 0.0;     // Global X position of the screen's left edge
uniform float screen_right = 1920.0; // Global X position of the screen's right edge
uniform float fade_margin = 200.0;   // Width of the fade zone in pixels

uniform vec4 target_color : source_color = vec4(1.0, 1.0, 1.0, 1.0); // The color to be replaced
uniform vec4 paint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);  // The new replacement color

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);

	// Check if this pixel is close to our target color (with tolerance to handle floating-point precision)
	if (distance(tex_color.rgb, target_color.rgb) < 0.005) {
		tex_color.rgb = paint_color.rgb;
	}

	// Calculate the global X position of this pixel
	// SCREEN_UV.x is 0.0 to 1.0 within the window viewport
	float pixel_global_x = window_x + (SCREEN_UV.x * window_width);

	// Fade at screen left edge
	// 0.0 alpha at screen_left, 1.0 alpha at screen_left + fade_margin
	float alpha = smoothstep(screen_left, screen_left + fade_margin, pixel_global_x);

	// Fade at screen right edge
	// 1.0 alpha at screen_right - fade_margin, 0.0 alpha at screen_right
	alpha *= (1.0 - smoothstep(screen_right - fade_margin, screen_right, pixel_global_x));

	COLOR = tex_color * COLOR;
	COLOR.a *= alpha;
}
