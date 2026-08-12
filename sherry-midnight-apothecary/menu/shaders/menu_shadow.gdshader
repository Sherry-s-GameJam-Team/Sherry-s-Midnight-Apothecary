shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float softness : hint_range(0.01, 0.5) = 0.18;
uniform float noise_strength : hint_range(0.0, 0.2) = 0.035;
uniform vec4 shadow_color : source_color = vec4(0.055, 0.035, 0.12, 0.94);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.13, 289.71))) * 43758.5453);
}

void fragment() {
	float edge_noise = (hash(floor(UV * vec2(90.0, 56.0)) + TIME * 0.08) - 0.5) * noise_strength;
	float vertical = smoothstep(1.0 - progress - softness, 1.0 - progress + softness, UV.y + edge_noise);
	float vignette = smoothstep(0.72, 1.0, length((UV - vec2(0.5)) * vec2(1.1, 0.85))) * progress * 0.55;
	float alpha = clamp(max(vertical, vignette), 0.0, 1.0) * progress * shadow_color.a;
	COLOR = vec4(shadow_color.rgb, alpha);
}
