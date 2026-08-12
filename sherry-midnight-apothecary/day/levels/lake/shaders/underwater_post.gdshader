shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float effect_strength : hint_range(0.0, 1.0) = 0.0;
uniform float depth_factor : hint_range(0.0, 1.0) = 0.0;
uniform vec3 shallow_tint : source_color = vec3(0.72, 0.98, 0.94);
uniform vec3 deep_tint : source_color = vec3(0.27, 0.66, 0.70);

void fragment() {
	vec3 source = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	vec3 tint = mix(shallow_tint, deep_tint, depth_factor);
	float luminance = dot(source, vec3(0.299, 0.587, 0.114));
	vec3 graded = mix(source, vec3(luminance), depth_factor * 0.16) * tint;
	graded.r *= mix(1.0, 0.78, depth_factor);
	graded *= mix(1.0, 0.72, depth_factor);
	vec2 centered = UV * 2.0 - 1.0;
	float vignette = smoothstep(1.25, 0.25, dot(centered, centered));
	graded *= mix(0.88, 1.0, vignette);
	COLOR = vec4(mix(source, graded, effect_strength), effect_strength);
}
