shader_type canvas_item;
render_mode unshaded, blend_add;

uniform sampler2D ripple_mask_next : filter_nearest, repeat_disable;
uniform float frame_blend : hint_range(0.0, 1.0) = 0.0;
uniform float highlight_strength : hint_range(0.0, 0.5, 0.01) = 0.10;
uniform float pixel_size : hint_range(1.0, 8.0, 1.0) = 1.0;
uniform vec4 highlight_color : source_color = vec4(0.76, 0.88, 0.92, 1.0);

void fragment() {
	vec2 source_pixel = TEXTURE_PIXEL_SIZE * pixel_size;
	vec2 snapped_uv = (floor(UV / source_pixel) + vec2(0.5)) * source_pixel;
	float current_mask = texture(TEXTURE, snapped_uv).r;
	float next_mask = texture(ripple_mask_next, snapped_uv).r;
	float mask = mix(current_mask, next_mask, frame_blend);

	// Two discrete luminance levels preserve the limited palette and keep the
	// existing long, horizontal marks instead of creating circular wave rings.
	float quiet_line = step(0.68, mask);
	float bright_line = step(0.88, mask);
	float highlight = (quiet_line * 0.65 + bright_line * 0.35) * highlight_strength;
	COLOR = vec4(highlight_color.rgb * highlight, highlight);
}
