shader_type particles;

uniform vec2 target_position = vec2(0.0);
uniform vec2 wind_velocity = vec2(0.0);
uniform float disperse : hint_range(0.0, 3.0) = 0.0;
uniform float chase_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float swarm_radius = 75.0;
uniform float attract_force = 560.0;
uniform float orbit_speed = 3.8;
uniform float base_scale = 1.15;
uniform float wobble_speed = 4.5;
uniform float drag_factor = 2.0;
uniform vec4 tint_from : source_color = vec4(0.88, 0.16, 0.14, 1.0);
uniform vec4 tint_to : source_color = vec4(0.98, 0.48, 0.20, 1.0);
uniform float alpha_mult : hint_range(0.0, 1.0) = 1.0;

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

vec2 hash21(float p) {
	vec3 p3 = fract(vec3(p) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

void start() {
	float id = float(INDEX);
	float r1 = hash11(id * 17.13 + 1.0);
	float r2 = hash11(id * 43.71 + 7.0);
	float r3 = hash11(id * 91.29 + 13.0);
	float r4 = hash11(id * 137.83 + 29.0);

	// Spawn distributed across a ring around target_position
	float angle = r1 * 6.2831853;
	float radius = mix(swarm_radius * 0.4, swarm_radius * 1.5, r2);
	vec2 offset = vec2(cos(angle), sin(angle)) * radius;

	TRANSFORM[3].xy = target_position + offset;

	// Initial velocity tangent to circle for wild dance
	vec2 tangent = vec2(-sin(angle), cos(angle));
	float initial_speed = mix(70.0, 200.0, r3);
	vec2 rand_dir = (hash21(id * 3.7 + 1.9) - vec2(0.5)) * 2.0;
	VELOCITY.xy = tangent * initial_speed + rand_dir * 30.0;
	VELOCITY.z = 0.0;

	// CUSTOM mapping:
	// CUSTOM.x = random starting phase
	// CUSTOM.y = wobble frequency multiplier
	// CUSTOM.z = rotation speed and spin direction
	// CUSTOM.w = random leaf scale factor (0.85 ~ 1.25)
	CUSTOM.x = r1 * 6.2831853;
	CUSTOM.y = mix(0.8, 1.3, r2) * wobble_speed;
	CUSTOM.z = mix(-3.0, 3.0, r3);
	CUSTOM.w = mix(0.85, 1.25, r4);

	COLOR = mix(tint_from, tint_to, r2);
}

void process() {
	vec2 pos = TRANSFORM[3].xy;
	vec2 to_target = target_position - pos;
	float dist = length(to_target);
	vec2 dir = dist > 0.001 ? to_target / dist : vec2(0.0);
	vec2 tangent = vec2(-dir.y, dir.x);

	// Multipliers based on chase intensity
	float current_attract = mix(attract_force * 0.5, attract_force * 1.3, chase_intensity);
	float current_swirl = mix(orbit_speed * 0.7, orbit_speed * 1.4, chase_intensity);

	// 1. Inward attraction toward target center
	float attract_mag = current_attract * smoothstep(8.0, 160.0, dist);
	vec2 f_attract = dir * attract_mag;

	// 2. Swirling / cyclone force around target
	float swirl_mag = current_attract * 0.7 * current_swirl * smoothstep(0.0, 120.0, dist);
	vec2 f_swirl = tangent * swirl_mag * sign(CUSTOM.z);

	// 3. Chaos and curling air turbulence
	float phase = CUSTOM.x + TIME * CUSTOM.y;
	float chaos_strength = mix(50.0, 110.0, chase_intensity);
	vec2 f_chaos = vec2(sin(phase * 1.3 + pos.y * 0.02), cos(phase * 1.1 + pos.x * 0.02)) * chaos_strength;

	// 4. Explosion / purification scatter
	vec2 f_disperse = vec2(0.0);
	if (disperse > 0.01) {
		vec2 away = dist > 0.01 ? -dir : vec2(cos(CUSTOM.x), sin(CUSTOM.x));
		f_disperse = (away * 750.0 + (hash21(float(INDEX) + TIME) - vec2(0.5)) * 450.0) * disperse;
	}

	// 5. Wind potion force
	vec2 f_wind = wind_velocity * 4.0;

	// Update velocity with drag damping
	vec2 accel = f_attract + f_swirl + f_chaos + f_disperse + f_wind;
	VELOCITY.xy += (accel - VELOCITY.xy * drag_factor) * DELTA;

	// 2D Rotation & 3D Tumbling Flip
	// Ensure the leaf texture NEVER collapses into a zero-width sliver:
	// We clamp minimum horizontal scale to 0.45 so the maple texture and edges stay always clearly visible
	float rot_angle = CUSTOM.x + TIME * CUSTOM.z * mix(0.7, 1.4, chase_intensity);
	float raw_flip = sin(CUSTOM.x + TIME * CUSTOM.y * mix(0.8, 1.35, chase_intensity));
	float flip_sign = raw_flip >= 0.0 ? 1.0 : -1.0;
	float flip_thickness = 0.45 + 0.55 * abs(raw_flip);
	float flip = flip_sign * flip_thickness;

	float leaf_scale = base_scale * CUSTOM.w * mix(1.0, 1.15, chase_intensity);
	float sx = leaf_scale * flip;
	float sy = leaf_scale * (0.90 + 0.10 * cos(phase * 0.7));

	float cos_a = cos(rot_angle);
	float sin_a = sin(rot_angle);

	TRANSFORM[0].xy = vec2(cos_a, sin_a) * sx;
	TRANSFORM[1].xy = vec2(-sin_a, cos_a) * sy;

	// Dynamic color intensity: deeper crimson during chase, rich warm gold/red in idle
	vec4 base_color = mix(tint_from, tint_to, hash11(float(INDEX) * 43.71 + 7.0));
	vec4 chase_tint = mix(base_color, vec4(1.0, 0.22, 0.14, 1.0), chase_intensity * 0.35);
	COLOR.rgb = chase_tint.rgb;
	COLOR.a = alpha_mult;
}
