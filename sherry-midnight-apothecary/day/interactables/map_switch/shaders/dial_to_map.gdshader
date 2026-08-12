shader_type canvas_item;
render_mode unshaded;

uniform sampler2D dial_texture : source_color, filter_linear_mipmap;
uniform float transition_progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 magic_color_a : source_color = vec4(0.25, 0.75, 1.0, 1.0);
uniform vec4 magic_color_b : source_color = vec4(0.72, 0.28, 1.0, 1.0);

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 345.45));
    p += dot(p, p + 34.345);
    return fract(p.x * p.y);
}

float value_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
    vec2 uv = UV;
    float circle_dist = length(uv - vec2(0.5));
    float circle_alpha = 1.0 - smoothstep(0.485, 0.5, circle_dist);
    if (circle_alpha <= 0.001) {
        COLOR = vec4(0.0);
    } else {
        vec4 dial_col = texture(dial_texture, uv);
        vec4 map_col = texture(TEXTURE, uv);

        float n1 = value_noise(uv * 9.0 + vec2(TIME * 0.14, -TIME * 0.09));
        float n2 = value_noise(uv * 24.0 - vec2(TIME * 0.22, TIME * 0.17));
        float noise_value = mix(n1, n2, 0.35);

        // Organic magical dissolve from the start dial into the live map.
        float reveal = smoothstep(noise_value - 0.13, noise_value + 0.13, transition_progress);
        float edge_distance = abs(noise_value - transition_progress);
        float magic_band = 1.0 - smoothstep(0.0, 0.075, edge_distance);
        magic_band *= step(0.015, transition_progress) * step(transition_progress, 0.985);

        vec4 result = mix(dial_col, map_col, reveal);
        vec3 magic = mix(magic_color_a.rgb, magic_color_b.rgb, n2);
        result.rgb += magic * magic_band * 0.72;

        // Soft rim keeps the circular display legible against the brass frame.
        float rim = smoothstep(0.40, 0.49, circle_dist) * circle_alpha;
        result.rgb += magic_color_a.rgb * rim * 0.12;
        result.a *= circle_alpha;
        COLOR = result;
    }
}
