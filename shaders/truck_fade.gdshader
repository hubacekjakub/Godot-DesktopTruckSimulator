shader_type canvas_item;

uniform float window_x = 0.0;        // Global X position of the window
uniform float window_width = 1.0;    // Total width of the window (default to 1.0 to avoid div by zero)
uniform float screen_left = 0.0;     // Global X position of the screen's left edge
uniform float screen_right = 1920.0; // Global X position of the screen's right edge
uniform float fade_margin = 200.0;   // Width of the fade zone in pixels
uniform float safety_margin = 60.0;  // Distance from screen edge where truck must be 0 alpha

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	
	// Calculate the global X position of this pixel
	// SCREEN_UV.x is 0.0 to 1.0 within the window viewport
	float pixel_global_x = window_x + (SCREEN_UV.x * window_width);

	float alpha = 1.0;

	// Fade at screen left edge
	// 0.0 alpha at (screen_left + safety_margin), 1.0 alpha at (screen_left + safety_margin + fade_margin)
	alpha *= smoothstep(screen_left + safety_margin, screen_left + safety_margin + fade_margin, pixel_global_x);

	// Fade at screen right edge
	// 1.0 alpha at (screen_right - safety_margin - fade_margin), 0.0 alpha at (screen_right - safety_margin)
	alpha *= (1.0 - smoothstep(screen_right - safety_margin - fade_margin, screen_right - safety_margin, pixel_global_x));

	COLOR = tex_color * COLOR;
	COLOR.a *= alpha;
}

