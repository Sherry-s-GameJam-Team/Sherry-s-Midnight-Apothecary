shader_type canvas_item;

uniform float charge : hint_range(0.0, 1.0) = 0.0;
uniform float burst : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float vertical_flow = 0.5 + 0.5 * sin(UV.y * 34.0 - TIME * (5.0 + charge * 8.0));
	float pulse = 0.5 + 0.5 * sin(TIME * (8.0 + charge * 20.0));
	float edge = smoothstep(0.7, 0.15, abs(UV.x - 0.5));
	vec3 glow = vec3(0.34, 0.82, 1.0) * vertical_flow * edge * charge;
	vec3 color = source.rgb * (1.0 + charge * (0.32 + pulse * 0.42));
	color += glow * 0.55 + vec3(0.8, 0.96, 1.0) * burst * 1.8;
	COLOR = vec4(color, source.a);
}
