shader_type canvas_item;
render_mode unshaded;

// This shader touches the whole water texture. It only changes luminance by a
// few percent; stronger isolated strokes remain the highlight overlay's job.
uniform sampler2D ripple_mask_current : filter_nearest, repeat_disable;
uniform sampler2D ripple_mask_next : filter_nearest, repeat_disable;
uniform float frame_blend : hint_range(0.0, 1.0) = 0.0;
uniform float surface_ripple_strength : hint_range(0.0, 0.15, 0.005) = 0.035;
uniform float pixel_size : hint_range(1.0, 8.0, 1.0) = 1.0;
uniform vec4 ripple_tint : source_color = vec4(0.66, 0.78, 0.82, 1.0);

void fragment() {
	vec2 logical_pixel = max(TEXTURE_PIXEL_SIZE * pixel_size, TEXTURE_PIXEL_SIZE);
	vec2 snapped_uv = (floor(UV / logical_pixel) + vec2(0.5)) * logical_pixel;
	vec4 water = texture(TEXTURE, snapped_uv);

	float mask_a = texture(ripple_mask_current, snapped_uv).r;
	float mask_b = texture(ripple_mask_next, snapped_uv).r;
	float ripple = mix(mask_a, mask_b, frame_blend);

	// Quantized bands keep a limited palette. The masks' neutral gray is near
	// 0.42, so calm areas receive tiny changes instead of becoming a bright wash.
	float wave = clamp((ripple - 0.42) * 2.0, -1.0, 1.0);
	wave = floor(wave * 4.0 + 0.5) / 4.0;
	float light_wave = max(wave, 0.0);
	float dark_wave = max(-wave, 0.0);
	water.rgb += ripple_tint.rgb * light_wave * surface_ripple_strength;
	water.rgb *= 1.0 - dark_wave * surface_ripple_strength * 0.45;
	COLOR = water;
}
