shader_type canvas_item;

uniform vec4 top_color : source_color = vec4(0.09, 0.08, 0.21, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.44, 0.40, 0.66, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.89, 0.65, 0.60, 1.0);
// Kept for profile compatibility. The visible per-pixel grain was removed;
// authored overlay textures can provide controlled paper texture later.
uniform float noise_strength : hint_range(0.0, 0.2) = 0.0;

void fragment() {
	float y = UV.y;
	vec4 gradient = mix(top_color, horizon_color, smoothstep(0.0, 0.58, y));
	gradient = mix(gradient, bottom_color, smoothstep(0.56, 1.0, y));
	COLOR = gradient;
}
