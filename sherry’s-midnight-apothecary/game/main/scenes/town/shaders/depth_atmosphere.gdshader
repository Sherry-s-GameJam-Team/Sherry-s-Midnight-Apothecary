shader_type canvas_item;

uniform vec4 haze_color : source_color = vec4(0.68, 0.80, 0.86, 1.0);
uniform float haze_strength : hint_range(0.0, 1.0) = 0.35;
uniform float desaturation : hint_range(0.0, 1.0) = 0.25;
uniform float contrast_loss : hint_range(0.0, 1.0) = 0.20;
uniform float brightness : hint_range(-0.5, 0.5) = 0.03;
uniform float vertical_haze : hint_range(0.0, 1.0) = 0.20;

void fragment() {
	vec4 tex = texture(TEXTURE, UV) * COLOR;
	float luminance = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 gray = vec3(luminance);
	vec3 color = mix(tex.rgb, gray, desaturation);

	color = mix(color, vec3(0.5), contrast_loss);

	float height_haze = smoothstep(1.0, 0.0, UV.y) * vertical_haze;
	float final_haze = clamp(haze_strength + height_haze, 0.0, 1.0);
	color = mix(color, haze_color.rgb, final_haze);
	color += brightness;

	COLOR = vec4(color, tex.a);
}
