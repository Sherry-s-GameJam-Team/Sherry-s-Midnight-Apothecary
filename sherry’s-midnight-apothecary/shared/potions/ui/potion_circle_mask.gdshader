shader_type canvas_item;

void fragment() {
	vec2 centered_uv = UV - vec2(0.5);
	if (length(centered_uv) > 0.5) {
		discard;
	}
	COLOR = texture(TEXTURE, UV) * COLOR;
}
