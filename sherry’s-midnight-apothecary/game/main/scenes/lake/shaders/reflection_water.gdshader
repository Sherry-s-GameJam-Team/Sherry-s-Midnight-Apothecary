shader_type canvas_item;
render_mode unshaded;

// All samplers are nearest-neighbour: interpolation between texture pixels is
// never used. Frame blending is temporal only and does not spatially blur art.
uniform sampler2D ripple_mask_current : filter_nearest, repeat_disable;
uniform sampler2D ripple_mask_next : filter_nearest, repeat_disable;
uniform sampler2D water_region_mask : filter_nearest, repeat_disable;

// Horizontal displacement in logical pixels, not normalized UV units.
uniform float ripple_strength : hint_range(0.0, 4.0, 0.05) = 0.75;
uniform float reflection_strength : hint_range(0.0, 1.0, 0.01) = 0.36;
// Depth fraction at which the reflection has fully faded.
uniform float reflection_fade : hint_range(0.05, 1.0, 0.01) = 0.82;
// One logical pixel may cover several source texels for a chunkier look.
uniform float pixel_size : hint_range(1.0, 8.0, 1.0) = 1.0;
uniform float frame_blend : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// Snap processing to logical rows. This produces horizontal pixel segments
	// instead of smooth fluid waves.
	vec2 logical_grid = max(TEXTURE_PIXEL_SIZE * pixel_size, TEXTURE_PIXEL_SIZE);
	vec2 snapped_uv = (floor(UV / logical_grid) + vec2(0.5)) * logical_grid;

	float mask_a = texture(ripple_mask_current, snapped_uv).r;
	float mask_b = texture(ripple_mask_next, snapped_uv).r;
	float ripple = mix(mask_a, mask_b, frame_blend);

	// The supplied grayscale masks have a neutral mid-gray water level near 0.42.
	// Alternating row direction breaks the image into quiet horizontal fragments.
	float row = floor(snapped_uv.y / logical_grid.y);
	float row_direction = mix(-1.0, 1.0, mod(row, 2.0));
	float displacement_pixels = (ripple - 0.42) * 2.0
		* row_direction * ripple_strength * pixel_size;
	float displacement_u = displacement_pixels * TEXTURE_PIXEL_SIZE.x;

	// Flip the upright source vertically at the shoreline and sample on the same
	// nearest-neighbour logical grid.
	vec2 reflection_uv = vec2(
		clamp(snapped_uv.x + displacement_u, 0.0, 1.0),
		1.0 - snapped_uv.y
	);
	vec4 reflection = texture(TEXTURE, reflection_uv);

	// Hide the capture outside the painted lake alpha. A small shore gate avoids
	// a hard one-pixel seam; the main fade then decreases with water depth.
	float lake_alpha = texture(water_region_mask, UV).a;
	float shore_gate = smoothstep(0.0, 0.025, UV.y);
	float depth_fade = 1.0 - smoothstep(0.0, max(reflection_fade, 0.001), UV.y);
	reflection.a *= reflection_strength * lake_alpha * shore_gate * depth_fade;
	COLOR = reflection;
}
