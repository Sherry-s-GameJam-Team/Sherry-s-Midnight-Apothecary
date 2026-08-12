shader_type canvas_item;

uniform float wind_speed : hint_range(0.0, 10.0) = 2.5;
uniform float wind_strength : hint_range(0.0, 50.0) = 15.0;
uniform float wind_detail : hint_range(0.0, 5.0) = 1.0;

uniform vec4 glow_color : source_color = vec4(0.85, 1.0, 0.9, 1.0);
uniform float glow_speed : hint_range(0.0, 10.0) = 2.0;
uniform float glow_intensity : hint_range(0.0, 1.0) = 0.35;

void vertex() {
    float height_factor = pow(1.0 - UV.y, 1.5);
    float wave1 = sin(TIME * wind_speed + VERTEX.y * 0.02) * wind_strength;
    float wave2 = cos(TIME * wind_speed * 1.5 + VERTEX.x * 0.01) * (wind_strength * 0.3);

    VERTEX.x += (wave1 + wave2) * height_factor;
}

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    float breath = (sin(TIME * glow_speed) * 0.5 + 0.5) * glow_intensity;
    float top_mask = pow(1.0 - UV.y, 2.0);
    vec3 glowing_rgb = tex_color.rgb + (glow_color.rgb * breath * top_mask);

    COLOR = vec4(glowing_rgb, tex_color.a);
}