shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float effect_strength : hint_range(0.0, 1.0) = 0.0;
uniform float depth_factor : hint_range(0.0, 1.0) = 0.0;
uniform float distortion_strength : hint_range(0.0, 0.01) = 0.002;

void fragment() {
	vec2 distortion;
	distortion.x = sin(UV.y * 14.0 + TIME * 0.7);
	distortion.y = cos(UV.x * 11.0 + TIME * 0.5);
	distortion += vec2(sin((UV.x + UV.y) * 21.0 - TIME * 0.35), cos((UV.x - UV.y) * 17.0 + TIME * 0.42)) * 0.3;
	distortion *= distortion_strength * effect_strength * mix(0.7, 1.0, depth_factor);
	vec3 source = textureLod(screen_texture, SCREEN_UV + distortion, 0.0).rgb;
	COLOR = vec4(source, effect_strength);
}
