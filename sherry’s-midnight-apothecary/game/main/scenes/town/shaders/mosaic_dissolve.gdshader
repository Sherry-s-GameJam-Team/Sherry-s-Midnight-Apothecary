shader_type canvas_item;
render_mode blend_mix;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D from_texture : source_color;
uniform sampler2D to_texture : source_color;
uniform sampler2D mask_texture : hint_default_white;
uniform float from_alpha_multiplier : hint_range(0.0, 1.0) = 1.0;
uniform float to_alpha_multiplier : hint_range(0.0, 1.0) = 1.0;

uniform float wave_amplitude : hint_range(0.0, 0.1) = 0.02;
uniform float wave_frequency : hint_range(0.0, 10.0) = 3.0;
uniform float wave_speed : hint_range(0.0, 5.0) = 1.5;

uniform float particle_speed : hint_range(0.01, 0.5) = 0.05;
uniform float particle_lifetime : hint_range(1.0, 10.0) = 3.0;
uniform float particle_softness : hint_range(0.001, 1.0) = 0.01;
uniform float particle_spacing : hint_range(0.01, 1.0) = 0.1;
uniform vec2 particle_offset = vec2(0.0, 0.0);
uniform vec2 particle_start_scale = vec2(0.018, 0.018);
uniform vec2 particle_end_scale = vec2(0.006, 0.006);
uniform float particle_scale_randomness : hint_range(0.0, 1.0) = 0.5;
uniform int particle_amount : hint_range(0, 50) = 20;

float rand(vec2 co) {
	return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

float particle(vec2 uv, float particle_id, float time, float mask_value, float dissolve_edge) {
	float spawn_time = particle_id * particle_spacing;
	float life = mod(time - spawn_time, particle_lifetime) / particle_lifetime;
	float vertical_pos = rand(vec2(particle_id, 1.0));
	float horizontal_pos = dissolve_edge - life * particle_speed;
	vec2 particle_pos = vec2(horizontal_pos, vertical_pos) + particle_offset;

	float scale_random = rand(vec2(particle_id, 2.0)) * particle_scale_randomness;
	vec2 start_scale = particle_start_scale * (1.0 - scale_random);
	vec2 end_scale = particle_end_scale * (1.0 - scale_random);
	vec2 current_scale = mix(start_scale, end_scale, life);

	vec2 scaled_uv = (uv - particle_pos) / current_scale;
	float dist = length(scaled_uv);
	float alpha = 1.0 - smoothstep(0.65, 1.0, life);

	return smoothstep(1.0 + particle_softness, 1.0, dist) * alpha * mask_value;
}

void fragment() {
	vec2 uv = UV;
	vec4 from_color = texture(from_texture, uv);
	vec4 to_color = texture(to_texture, uv);
	from_color.a *= from_alpha_multiplier;
	to_color.a *= to_alpha_multiplier;
	float mask = texture(mask_texture, uv).r;

	float wave_offset = wave_amplitude * sin(wave_frequency * uv.y + TIME * wave_speed);
	float dissolve_edge = 1.0 - progress + wave_offset;
	float edge_band = 0.035;

	float transition_mask = step(dissolve_edge, uv.x) * mask;
	float edge = smoothstep(dissolve_edge - edge_band, dissolve_edge, uv.x) - smoothstep(dissolve_edge, dissolve_edge + edge_band, uv.x);

	float particles = 0.0;
	for (float i = 0.0; i < float(particle_amount); i++) {
		particles += particle(uv, i, TIME, mask, dissolve_edge);
	}
	particles = clamp(particles, 0.0, 1.0);

	float final_mask = clamp(transition_mask + edge * 0.65 + particles * 0.85, 0.0, 1.0);
	COLOR = mix(from_color, to_color, final_mask);
}
