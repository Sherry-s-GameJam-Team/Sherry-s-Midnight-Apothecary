shader_type canvas_item;

uniform float snow_strength : hint_range(0.0, 1.0) = 0.0;
uniform float snow_speed : hint_range(0.1, 5.0) = 2.0;
uniform float snow_density : hint_range(0.2, 2.0) = 1.0;
uniform vec2 flow_direction = vec2(-0.5, 1.0);
uniform float front_layer : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}

void fragment() {
	vec2 direction = normalize(flow_direction);
	vec2 flow_uv = UV + direction * TIME * snow_speed;
	float large = value_noise(flow_uv * vec2(5.0, 3.0));
	float medium = value_noise(flow_uv * vec2(17.0, 11.0) + vec2(TIME * 0.7, 0.0));
	float small = hash(floor(flow_uv * vec2(73.0, 49.0)));
	float diagonal = 0.5 + 0.5 * sin((flow_uv.x * 22.0 + flow_uv.y * 13.0) * 6.28318);
	float body = smoothstep(0.28 / snow_density, 0.82, large * 0.58 + medium * 0.42);
	float streaks = smoothstep(0.78, 0.98, diagonal) * medium;
	float crystals = step(0.965 - snow_density * 0.012, small);
	float bottom_powder = smoothstep(0.66, 1.0, UV.y) * value_noise(vec2(flow_uv.x * 8.0, flow_uv.y * 2.0));
	float alpha = (body * 0.75 + streaks * 0.32 + crystals * 0.48 + bottom_powder * 0.48) * snow_strength;
	alpha *= mix(1.0, 0.62, front_layer);
	vec3 shadow = vec3(0.60, 0.86, 0.94);
	vec3 snow = vec3(0.92, 0.985, 1.0);
	vec3 color = mix(shadow, snow, clamp(body + streaks * 0.5, 0.0, 1.0));
	color += vec3(0.18, 0.56, 0.72) * crystals;
	COLOR = vec4(color, clamp(alpha, 0.0, 0.96));
}
