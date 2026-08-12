shader_type canvas_item;
render_mode blend_add;

uniform float effect_strength : hint_range(0.0, 1.0) = 0.0;
uniform float depth_factor : hint_range(0.0, 1.0) = 0.0;
uniform vec3 caustic_color : source_color = vec3(0.34, 0.95, 0.84);
uniform float scale = 18.0;

void fragment() {
	vec2 p = UV * scale;
	float a = sin(p.x + sin(p.y * 0.73 + TIME * 0.55) * 2.2 + TIME * 0.8);
	float b = sin(p.y * 1.13 + sin(p.x * 0.61 - TIME * 0.42) * 2.5 - TIME * 0.63);
	float lines = smoothstep(1.35, 1.8, a + b);
	float shallow_fade = smoothstep(1.0, 0.1, depth_factor);
	float alpha = lines * 0.08 * effect_strength * shallow_fade;
	COLOR = vec4(caustic_color, alpha);
}
