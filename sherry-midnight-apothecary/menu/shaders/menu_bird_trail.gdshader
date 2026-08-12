shader_type canvas_item;
render_mode unshaded;

uniform vec4 silhouette_color : source_color = vec4(0.09, 0.06, 0.15, 0.92);
uniform vec3 trail_offsets_px = vec3(18.0, 36.0, 54.0);
uniform vec3 trail_opacities = vec3(0.24, 0.13, 0.06);

void fragment() {
	float body_alpha = texture(TEXTURE, UV).a * silhouette_color.a;
	float trail_alpha = 0.0;
	trail_alpha = max(trail_alpha, texture(TEXTURE, UV - vec2(trail_offsets_px.x * TEXTURE_PIXEL_SIZE.x, 0.0)).a * trail_opacities.x);
	trail_alpha = max(trail_alpha, texture(TEXTURE, UV - vec2(trail_offsets_px.y * TEXTURE_PIXEL_SIZE.x, 0.0)).a * trail_opacities.y);
	trail_alpha = max(trail_alpha, texture(TEXTURE, UV - vec2(trail_offsets_px.z * TEXTURE_PIXEL_SIZE.x, 0.0)).a * trail_opacities.z);
	COLOR = vec4(silhouette_color.rgb, max(body_alpha, trail_alpha * silhouette_color.a));
}
