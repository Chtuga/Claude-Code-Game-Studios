shader_type spatial;

uniform vec3 hole_world_position;
uniform float hole_radius : hint_range(0.0, 10.0) = 0.5;
uniform vec4 albedo : source_color = vec4(0.19, 0.37, 0.14, 1.0);

varying vec3 v_world_pos;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float dist = length(vec2(v_world_pos.x - hole_world_position.x, v_world_pos.z - hole_world_position.z));
	if (dist < hole_radius) {
		discard;
	}
	ALBEDO = albedo.rgb;
}
