shader_type canvas_item;

uniform float warning_strength : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 grid = floor(vec2(UV.x * 58.0, (UV.y + TIME * 0.18) * 34.0));
	float flake_seed = hash(grid);
	vec2 cell = fract(vec2(UV.x * 58.0, (UV.y + TIME * 0.18) * 34.0));
	float flake = step(0.88 - warning_strength * 0.08, flake_seed) * (1.0 - smoothstep(0.04, 0.18, length(cell - 0.5)));
	float streak = pow(max(0.0, sin((UV.y + UV.x * 0.14 + TIME * 0.24) * 110.0)), 22.0);
	float ground = smoothstep(0.72, 1.0, UV.y) * (0.55 + 0.45 * sin(UV.x * 42.0 - TIME * 8.0));
	float side_fade = smoothstep(0.0, 0.08, UV.x) * smoothstep(0.0, 0.08, 1.0 - UV.x);
	float alpha = (flake * 0.62 + streak * 0.12 + ground * 0.34) * warning_strength * side_fade;
	vec3 color = mix(vec3(0.48, 0.82, 0.94), vec3(0.92, 0.99, 1.0), UV.y);
	COLOR = vec4(color, alpha);
}
