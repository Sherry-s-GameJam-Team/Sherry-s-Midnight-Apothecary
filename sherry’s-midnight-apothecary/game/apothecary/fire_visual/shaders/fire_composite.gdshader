shader_type canvas_item;
uniform float heat = 0.0;
uniform float emission_strength = 1.0;
uniform float saturation_boost = 0.0;
uniform float alpha_multiplier = 1.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float core = smoothstep(0.45, 1.0, max(c.r, c.g));
	c.rgb = mix(vec3(dot(c.rgb, vec3(0.299, 0.587, 0.114))), c.rgb, 1.0 + saturation_boost);
	c.rgb += c.rgb * core * heat * emission_strength;
	c.a *= alpha_multiplier;
	COLOR = c;
}
