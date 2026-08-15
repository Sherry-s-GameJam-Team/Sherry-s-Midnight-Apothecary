shader_type canvas_item;

uniform vec4 outer_color : source_color = vec4(0.18, 0.78, 1.0, 0.68);
uniform vec4 core_color : source_color = vec4(0.86, 0.99, 1.0, 0.95);
uniform float intensity : hint_range(0.0, 2.0) = 1.0;
uniform float travel_direction = 1.0;

void fragment() {
	vec2 p = UV - vec2(0.5);
	float direction = sign(travel_direction);
	float ripple = sin((UV.x * 18.0 - TIME * 7.0 * direction) * 6.28318);
	float ripple_high = sin((UV.x * 37.0 - TIME * 10.5 * direction) * 6.28318);
	float curved_center = 0.5 + ripple * 0.055 + ripple_high * 0.018;
	float distance_to_wave = abs(UV.y - curved_center);
	float outer_band = 1.0 - smoothstep(0.12, 0.32, distance_to_wave);
	float core_band = 1.0 - smoothstep(0.025, 0.095, distance_to_wave);
	float front = smoothstep(0.02, 0.32, UV.x);
	float tail = smoothstep(0.0, 0.9, UV.x) * (1.0 - smoothstep(0.88, 1.0, UV.x));
	float sparks = step(0.91, fract(sin(dot(floor(UV * vec2(42.0, 12.0)), vec2(12.9898, 78.233))) * 43758.5453 + TIME * 1.7));
	vec3 color = mix(outer_color.rgb, core_color.rgb, core_band);
	color += vec3(0.15, 0.45, 0.62) * sparks * outer_band;
	float alpha = (outer_band * 0.72 + core_band * 0.72) * tail * front * intensity;
	COLOR = vec4(color, clamp(alpha, 0.0, 1.0));
}
