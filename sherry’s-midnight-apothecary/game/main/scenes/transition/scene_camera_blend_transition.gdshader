shader_type canvas_item;

uniform sampler2D tex_from : filter_nearest, repeat_disable;
uniform sampler2D tex_to : filter_nearest, repeat_disable;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float softness : hint_range(0.001, 0.3) = 0.075;
uniform float pixel_cell : hint_range(1.0, 32.0) = 2.0;
uniform float noise_strength : hint_range(0.0, 0.5) = 0.18;
uniform float particle_amount : hint_range(0.0, 1.0) = 0.20;
uniform float particle_band : hint_range(0.001, 0.3) = 0.075;
uniform float seed = 1.0;
uniform float time_value = 0.0;
uniform vec2 target_size = vec2(1280.0, 720.0);
uniform float dissolve_motion : hint_range(0.0, 1.0) = 0.22;
uniform float particle_flicker : hint_range(0.0, 1.0) = 0.72;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 safe_size = max(target_size, vec2(1.0));
	vec2 pixel_step = max(vec2(pixel_cell) / safe_size, vec2(0.00001));
	vec2 puv = floor(UV / pixel_step) * pixel_step + pixel_step * 0.5;

	vec4 from_col = texture(tex_from, puv);
	vec4 to_col = texture(tex_to, puv);

	float amount = clamp(progress, 0.0, 1.0);
	vec2 grid = floor(UV / pixel_step);
	float n = hash12(grid + seed);
	float animated_time = TIME + time_value;
	float time_slice = floor(animated_time * 12.0);
	float slow_time_slice = floor(animated_time * 5.0);
	float animated_noise = hash12(grid * 0.73 + time_slice + seed * 3.17);
	float crawl_noise = hash12(grid * 0.41 + vec2(slow_time_slice * 0.37, -slow_time_slice * 0.21) + seed * 7.11);
	float sparkle_a = hash12(grid * 1.91 + vec2(time_slice * 1.17, -time_slice * 0.63) + seed * 11.3);
	float sparkle_b = hash12((grid + vec2(1.0, -1.0)) * 2.37 + vec2(-time_slice * 0.41, time_slice * 1.29) + seed * 19.7);
	float ripple = sin(UV.y * 18.0 + animated_time * 3.2 + seed) * 0.5 + 0.5;
	float dynamic_noise = ((animated_noise - 0.5) * 0.65 + (crawl_noise - 0.5) * 0.45 + (ripple - 0.5) * 0.18) * dissolve_motion;

	float field = UV.x + (n - 0.5) * noise_strength + dynamic_noise * noise_strength;
	float boundary = mix(-softness - noise_strength, 1.0 + softness + noise_strength, amount);
	float mask = 1.0 - smoothstep(boundary - softness, boundary + softness, field);
	if (amount <= 0.001) {
		mask = 0.0;
	} else if (amount >= 0.999) {
		mask = 1.0;
	}

	vec4 base_col = mix(from_col, to_col, mask);

	float edge = 1.0 - smoothstep(0.0, particle_band, abs(field - boundary));
	float flicker_gate = mix(animated_noise, max(sparkle_a, sparkle_b), particle_flicker);
	float flicker_strength = mix(0.35, 1.0, sparkle_a) * mix(0.55, 1.15, sparkle_b);
	float particle = edge * step(1.0 - particle_amount, flicker_gate) * flicker_strength * smoothstep(0.02, 0.12, amount) * (1.0 - smoothstep(0.88, 0.995, amount));
	vec3 particle_col = mix(from_col.rgb, to_col.rgb, n);
	base_col.rgb = mix(base_col.rgb, particle_col, clamp(particle * 0.92, 0.0, 1.0));

	COLOR = vec4(base_col.rgb, 1.0);
}
