shader_type spatial;
render_mode cull_back, diffuse_lambert;

uniform sampler2D grass_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D splat_map : hint_default_white, filter_linear, repeat_disable;

uniform float uv_scale = 0.35;
uniform float height_blend_start = 2.5;
uniform float height_blend_end = 7.0;
uniform float slope_rock_start = 0.55;
uniform float slope_rock_end = 0.82;

varying float v_height;
varying float v_slope;


void vertex() {
	v_height = VERTEX.y;
	vec3 n = normalize((MODEL_NORMAL_MATRIX * NORMAL).xyz);
	v_slope = 1.0 - abs(n.y);
}


void fragment() {
	vec2 uv = UV * uv_scale;
	vec4 splat = texture(splat_map, UV);

	float height_w = smoothstep(height_blend_start, height_blend_end, v_height);
	float slope_w = smoothstep(slope_rock_start, slope_rock_end, v_slope);

	float grass_w = splat.r * (1.0 - height_w * 0.65) * (1.0 - slope_w);
	float dirt_w = splat.g * (1.0 - slope_w * 0.35);
	float rock_w = max(splat.b, height_w * 0.85 + slope_w * 0.9);

	float sum_w = grass_w + dirt_w + rock_w + 0.0001;
	grass_w /= sum_w;
	dirt_w /= sum_w;
	rock_w /= sum_w;

	vec3 col = texture(grass_tex, uv).rgb * grass_w
		+ texture(dirt_tex, uv * 1.15).rgb * dirt_w
		+ texture(rock_tex, uv * 0.9).rgb * rock_w;

	ALBEDO = col;
	ROUGHNESS = 0.92;
	METALLIC = 0.0;
}
