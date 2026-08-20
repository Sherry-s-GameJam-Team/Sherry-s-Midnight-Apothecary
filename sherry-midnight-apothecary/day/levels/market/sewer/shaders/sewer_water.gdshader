shader_type canvas_item;

// The source art already contains the wall reflection.  This shader keeps that
// painted look while giving the blood water a slow, living surface.
uniform float ripple_strength : hint_range(0.0, 0.03, 0.001) = 0.008;
uniform float ripple_speed : hint_range(0.0, 4.0, 0.05) = 0.75;
uniform float reflection_strength : hint_range(0.0, 1.0, 0.01) = 0.38;
uniform vec4 reflection_tint : source_color = vec4(0.85, 0.20, 0.18, 1.0);

void fragment() {
	vec2 uv = UV;
	float wave_a = sin((uv.x * 41.0) + (TIME * ripple_speed));
	float wave_b = sin((uv.x * 19.0) - (TIME * ripple_speed * 0.63) + (uv.y * 13.0));
	float ripple = (wave_a + wave_b) * 0.5;
	uv.y += ripple * ripple_strength;
	uv.x += sin((UV.y * 29.0) + (TIME * ripple_speed * 0.8)) * ripple_strength * 0.45;

	vec4 water = texture(TEXTURE, uv);
	// Bright, broken horizontal glints make the reflected masonry shimmer rather
	// than slide as one flat image.
	float glint = smoothstep(0.72, 0.98, sin((UV.x * 103.0) - (TIME * 1.1)) * 0.5 + 0.5);
	float reflection_mask = smoothstep(0.38, 0.82, UV.y) * water.a;
	water.rgb += reflection_tint.rgb * glint * reflection_mask * reflection_strength * 0.12;
	COLOR = water;
}
