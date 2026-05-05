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
