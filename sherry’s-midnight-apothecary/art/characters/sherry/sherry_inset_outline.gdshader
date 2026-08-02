shader_type canvas_item;

// Draws only on sprite pixels adjacent to transparency.
// The line is inside the silhouette and does not enlarge the character.
uniform vec4 outline_color : source_color = vec4(0.12, 0.055, 0.19, 0.92);
uniform float outline_width = 1.0;

void fragment() {
	vec4 sprite = texture(TEXTURE, UV);
	if (sprite.a <= 0.0) {
		COLOR = vec4(0.0);
		return;
	}

	vec2 step_size = TEXTURE_PIXEL_SIZE * outline_width;
	float neighbor_alpha = 1.0;
	neighbor_alpha = min(neighbor_alpha, texture(TEXTURE, UV + vec2(step_size.x, 0.0)).a);
	neighbor_alpha = min(neighbor_alpha, texture(TEXTURE, UV - vec2(step_size.x, 0.0)).a);
	neighbor_alpha = min(neighbor_alpha, texture(TEXTURE, UV + vec2(0.0, step_size.y)).a);
	neighbor_alpha = min(neighbor_alpha, texture(TEXTURE, UV - vec2(0.0, step_size.y)).a);

	float inner_edge = 1.0 - smoothstep(0.0, 0.35, neighbor_alpha);
	float visible_sprite = smoothstep(0.1, 0.8, sprite.a);
	sprite.rgb = mix(sprite.rgb, outline_color.rgb, inner_edge * visible_sprite * outline_color.a);
	COLOR = sprite;
}
