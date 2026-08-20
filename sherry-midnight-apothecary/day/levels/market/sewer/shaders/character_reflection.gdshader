shader_type canvas_item;

// Applied only to the mirrored character copies. It breaks their silhouette
// into a subdued red-water reflection without affecting the playable sprites.
uniform float ripple_strength : hint_range(0.0, 0.08, 0.001) = 0.018;
uniform float ripple_speed : hint_range(0.0, 5.0, 0.05) = 1.2;
uniform vec4 water_tint : source_color = vec4(0.82, 0.18, 0.16, 1.0);
uniform float opacity : hint_range(0.0, 1.0, 0.01) = 0.3;
uniform sampler2D water_mask : source_color, filter_nearest, repeat_disable;
uniform vec2 water_mask_size = vec2(4314.0, 724.0);
uniform vec2 first_water_origin = vec2(0.0, 0.0);
uniform vec2 second_water_origin = vec2(2162.0, -2.0);

varying vec2 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float mask_alpha_at(vec2 origin) {
	vec2 mask_uv = (world_position - origin) / water_mask_size;
	float inside = step(0.0, mask_uv.x) * step(mask_uv.x, 1.0)
		* step(0.0, mask_uv.y) * step(mask_uv.y, 1.0);
	return texture(water_mask, mask_uv).a * inside;
}

void fragment() {
	vec2 uv = UV;
	uv.x += sin((uv.y * 34.0) + (TIME * ripple_speed)) * ripple_strength;
	uv.y += sin((uv.x * 22.0) - (TIME * ripple_speed * 0.7)) * ripple_strength * 0.35;
	vec4 reflection = texture(TEXTURE, uv);
	float depth_fade = 1.0 - smoothstep(0.18, 1.0, UV.y);
	float water_alpha = max(mask_alpha_at(first_water_origin), mask_alpha_at(second_water_origin));
	reflection.rgb = mix(reflection.rgb, water_tint.rgb, 0.58);
	reflection.a *= opacity * depth_fade * water_alpha;
	COLOR = reflection;
}
