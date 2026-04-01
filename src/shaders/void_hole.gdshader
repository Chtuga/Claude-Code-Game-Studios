// Void Hole shader — Sprint 1 spike (S1-11)
// Renders the hole as a dark void with a glowing rim edge.
// Fallback: assign a dark StandardMaterial3D if this fails to compile on WebGL.
//
// TODO: implement void shader spike in Sprint 1

shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;

void fragment() {
	ALBEDO = vec3(0.19, 0.37, 0.14);
}
