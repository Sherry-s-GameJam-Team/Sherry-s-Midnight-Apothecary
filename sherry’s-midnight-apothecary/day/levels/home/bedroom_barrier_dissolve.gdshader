shader_type canvas_item;

uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform vec4 magic_color : source_color = vec4(0.42, 0.22, 1.0, 1.0);
uniform vec4 edge_color : source_color = vec4(0.18, 0.9, 1.0, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.93, 289.17))) * 43758.5453);
}

void fragment() {
	vec4 sprite = texture(TEXTURE, UV);
	float noise = hash(floor(UV * vec2(80.0, 180.0)));
	float visible = smoothstep(dissolve - 0.035, dissolve + 0.035, noise);
	float edge = 1.0 - smoothstep(0.0, 0.07, abs(noise - dissolve));
	float transition = smoothstep(0.01, 0.08, dissolve) * (1.0 - smoothstep(0.92, 0.99, dissolve));
	edge *= transition;
	vec3 color = mix(sprite.rgb, mix(magic_color.rgb, edge_color.rgb, noise), edge * 0.9);
	float alpha = max(sprite.a * visible, edge * sprite.a * 0.9);
	COLOR = vec4(color, alpha);
}
