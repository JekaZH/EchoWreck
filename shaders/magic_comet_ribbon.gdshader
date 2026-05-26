shader_type spatial;
render_mode blend_add, cull_disabled, unshaded, shadows_disabled, depth_draw_never, particle_trails;

uniform sampler2D main_tex : filter_linear, repeat_disable;
uniform sampler2D noise_tex : filter_linear, repeat_enable;
uniform vec4 color_hot : source_color = vec4(1.0, 0.95, 0.55, 1.0);
uniform vec4 color_mid : source_color = vec4(1.0, 0.42, 0.05, 1.0);
uniform vec4 color_tail : source_color = vec4(0.7, 0.08, 0.02, 0.0);
uniform float scroll_speed : hint_range(0.0, 20.0) = 5.0;
uniform float noise_strength : hint_range(0.0, 1.0) = 0.45;
uniform float emission_strength : hint_range(0.5, 16.0) = 4.5;

varying vec2 v_uv;

void vertex() {
	v_uv = UV;
}

void fragment() {
	float along = v_uv.x;
	float across = abs(v_uv.y - 0.5) * 2.0;
	vec4 soft = texture(main_tex, vec2(across * 0.5 + 0.25, 0.5));
	float n = texture(noise_tex, vec2(along * 2.5 - TIME * scroll_speed, across * 1.5)).r;
	float edge = 1.0 - smoothstep(0.35, 1.0, across);
	float body = soft.a * edge;
	body *= smoothstep(0.0, 0.05, along) * smoothstep(1.0, 0.7, along);
	body *= 0.65 + noise_strength * (n - 0.5);
	vec3 col = mix(color_tail.rgb, color_mid.rgb, smoothstep(0.0, 0.5, along));
	col = mix(col, color_hot.rgb, pow(1.0 - along, 0.7));
	float alpha = body * mix(color_tail.a, color_hot.a, 1.0 - along);
	ALBEDO = col;
	EMISSION = col * emission_strength * body;
	ALPHA = alpha;
}
