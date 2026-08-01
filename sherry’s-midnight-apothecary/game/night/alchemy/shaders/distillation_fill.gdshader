shader_type canvas_item;

// This is deliberately a data texture: do not mark it as source_color.
uniform sampler2D flow_order_texture : filter_linear, repeat_disable;
uniform float fill_progress : hint_range(0.0, 1.0, 0.001) = 0.0;
uniform vec4 liquid_color : source_color = vec4(0.20, 0.65, 0.95, 0.58);
uniform vec4 front_color : source_color = vec4(0.62, 0.88, 1.0, 0.70);
uniform float edge_softness : hint_range(0.001, 0.08, 0.001) = 0.018;

void fragment() {
	vec4 cover = texture(TEXTURE, UV);
	float mask_alpha = cover.a;

	// A zero progress must hide even pixels whose flow order is pure black.
	if (fill_progress <= 0.0 || mask_alpha <= 0.0) {
		COLOR = vec4(0.0);
	} else {
		float flow_order = texture(flow_order_texture, UV).r;
		float filled = 1.0 - smoothstep(
			fill_progress - edge_softness,
			fill_progress + edge_softness,
			flow_order
		);
		// Include the pure-white end of the data map at full progress.
		filled = mix(filled, 1.0, step(0.9999, fill_progress));

		float leading_edge = smoothstep(
			fill_progress - edge_softness * 3.0,
			fill_progress - edge_softness * 0.35,
			flow_order
		) * (1.0 - smoothstep(
			fill_progress - edge_softness * 0.35,
			fill_progress + edge_softness,
			flow_order
		));
		float inner_shimmer = 0.025 * sin(UV.y * 90.0 + TIME * 1.25);
		vec4 liquid = mix(liquid_color, front_color, leading_edge * 0.45);
		liquid.rgb += vec3(inner_shimmer * filled);
		liquid.a *= filled * mask_alpha;
		COLOR = liquid;
	}
}
