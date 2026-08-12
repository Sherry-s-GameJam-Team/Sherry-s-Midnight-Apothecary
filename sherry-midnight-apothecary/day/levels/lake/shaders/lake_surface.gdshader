shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform vec4 water_color : source_color = vec4(0.05, 0.58, 0.67, 0.55);
uniform vec4 highlight_color : source_color = vec4(0.55, 1.0, 0.95, 0.75);
uniform float wave_strength : hint_range(0.0, 0.04) = 0.012;
uniform float wave_speed = 0.6;
uniform float frequency = 8.0;
uniform float flow_speed = 0.04;
uniform float refraction_strength : hint_range(0.0, 0.02) = 0.004;
uniform float opacity : hint_range(0.0, 1.0) = 0.7;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}

void fragment() {
	float travelling = UV.x * frequency + TIME * wave_speed;
	float wave = sin(travelling) + 0.45 * sin(travelling * 1.73 - TIME * wave_speed * 0.7);
	float n = noise(vec2(UV.x * 18.0 + TIME * flow_speed, UV.y * 5.0));
	vec2 refract_uv = SCREEN_UV + vec2((wave + n - 0.5) * refraction_strength, 0.0);
	vec3 behind = textureLod(screen_texture, refract_uv, 0.0).rgb;
	float crest = smoothstep(0.45, 0.95, wave * 0.35 + n);
	vec3 color = mix(behind, water_color.rgb, water_color.a);
	color = mix(color, highlight_color.rgb, crest * highlight_color.a);
	COLOR = vec4(color, opacity);
}
