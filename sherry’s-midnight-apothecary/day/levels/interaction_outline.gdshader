shader_type canvas_item;

// Draw a warm external outline around transparent sprite edges.
uniform vec4 outline_color : source_color = vec4(1.0, 0.84, 0.30, 0.95);
uniform float outline_width = 2.0;

void fragment() {
	vec4 sprite = texture(TEXTURE, UV);
	vec2 step_size = TEXTURE_PIXEL_SIZE * outline_width;
	float neighbor_alpha = 0.0;
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(step_size.x, 0.0)).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV - vec2(step_size.x, 0.0)).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(0.0, step_size.y)).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV - vec2(0.0, step_size.y)).a);
	vec4 outline = vec4(outline_color.rgb, outline_color.a * neighbor_alpha * (1.0 - sprite.a));
	COLOR = mix(outline, sprite, sprite.a);
}
