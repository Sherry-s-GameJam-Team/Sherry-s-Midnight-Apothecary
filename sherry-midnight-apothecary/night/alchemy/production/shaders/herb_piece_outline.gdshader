shader_type canvas_item;

uniform bool outline_enabled = false;
uniform vec4 outline_color : source_color = vec4(1.0, 0.86, 0.45, 0.95);
uniform float outline_width : hint_range(1.0, 8.0, 0.5) = 2.0;


void fragment() {
	COLOR = vec4(0.0);
	if (outline_enabled) {
		float center_alpha = texture(TEXTURE, UV).a;
		if (center_alpha <= 0.01) {
			vec2 offset = TEXTURE_PIXEL_SIZE * outline_width;
			float neighbor_alpha = 0.0;
			neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(offset.x, 0.0)).a);
			neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV - vec2(offset.x, 0.0)).a);
			neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(0.0, offset.y)).a);
			neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV - vec2(0.0, offset.y)).a);
			neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + offset).a);
			neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV - offset).a);
			neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(offset.x, -offset.y)).a);
			neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(-offset.x, offset.y)).a);
			COLOR = vec4(outline_color.rgb, outline_color.a * step(0.01, neighbor_alpha));
		}
	}
}
