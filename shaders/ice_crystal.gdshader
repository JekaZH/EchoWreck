shader_type spatial;
render_mode blend_add, unshaded, shadows_disabled, cull_disabled;

uniform vec4 crystal_color : source_color = vec4(0.35, 0.75, 1.0, 0.85);
uniform vec4 rim_color : source_color = vec4(0.85, 0.98, 1.0, 1.0);
uniform float emission_strength : hint_range(0.5, 14.0) = 5.0;
uniform float rim_power : hint_range(1.0, 8.0) = 3.2;
uniform float facet_contrast : hint_range(0.0, 1.0) = 0.55;

varying vec3 v_local_pos;
varying vec3 v_world_normal;

void vertex() {
	v_local_pos = VERTEX;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(v_world_normal);
	vec3 view_dir = normalize(CAMERA_DIRECTION_WORLD);
	float fresnel = pow(1.0 - max(dot(n, view_dir), 0.0), rim_power);
	float facet = 0.5 + 0.5 * sin(v_local_pos.x * 18.0 + v_local_pos.y * 11.0 + v_local_pos.z * 9.0);
	facet = mix(1.0, facet, facet_contrast);
	vec3 col = mix(crystal_color.rgb, rim_color.rgb, fresnel);
	float alpha = crystal_color.a * facet * (0.55 + 0.45 * fresnel);
	EMISSION = col * emission_strength * facet;
	ALBEDO = col;
	ALPHA = alpha;
}
