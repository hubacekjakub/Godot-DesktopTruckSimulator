shader_type canvas_item;

uniform float window_x;      // Global X position of the window
uniform float window_width;  // Total width of the window
uniform float screen_width;  // Total width of the screen
uniform float fade_margin;   // Width of the fade zone in pixels
uniform float safety_margin; // Distance from screen edge where truck must be 0 alpha

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);

	// Calculate the global X position of this pixel
	float pixel_global_x = window_x + (SCREEN_UV.x * window_width);

	float alpha = 1.0;

	// Fade at screen left edge
	// 0.0 alpha at safety_margin, 1.0 alpha at (safety_margin + fade_margin)
	alpha *= smoothstep(safety_margin, safety_margin + fade_margin, pixel_global_x);

	// Fade at screen right edge
	// 1.0 alpha at (screen_width - safety_margin - fade_margin), 0.0 alpha at (screen_width - safety_margin)
	alpha *= (1.0 - smoothstep(screen_width - safety_margin - fade_margin, screen_width - safety_margin, pixel_global_x));

	COLOR = tex_color;
	COLOR.a *= alpha;
}

