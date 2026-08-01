shader_type canvas_item;
uniform float distortion_strength = 0.0;
uniform float distortion_speed = 1.0;
uniform sampler2D distortion_mask;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
void fragment() {
	vec4 mask = texture(distortion_mask, UV);
	float wave = sin((UV.y * 42.0) + TIME * distortion_speed) * 0.004 * distortion_strength;
	vec2 offset = vec2(wave, 0.0) * mask.a;
	COLOR = texture(screen_texture, SCREEN_UV + offset) * COLOR;
}
