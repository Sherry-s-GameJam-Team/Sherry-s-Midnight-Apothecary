shader_type canvas_item;
render_mode unshaded;

uniform vec2 window_center = vec2(0.0, 0.0);
uniform float window_radius = 229.5;
uniform float edge_softness = 2.0;

varying vec2 local_vertex;


void vertex() {
	local_vertex = VERTEX;
}


void fragment() {
	float dist_to_window = distance(local_vertex, window_center);
	float window_alpha = 1.0 - smoothstep(window_radius, window_radius + edge_softness, dist_to_window);
	COLOR = texture(TEXTURE, UV);
	COLOR.a *= window_alpha;
}
