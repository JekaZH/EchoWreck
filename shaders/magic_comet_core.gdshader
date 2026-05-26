shader_type spatial;
render_mode blend_add, unshaded, shadows_disabled, depth_draw_opaque, cull_disabled;

uniform sampler2D main_tex : filter_linear, repeat_disable;
uniform sampler2D noise_tex : filter_linear, repeat_enable;
uniform vec4 core_color : source_color = vec4(1.0, 0.45, 0.08, 1.0);
uniform vec4 core_hot_color : source_color = vec4(1.0, 0.95, 0.55, 1.0);
uniform float emission_strength : hint_range(0.5, 12.0) = 4.0;
uniform float noise_scroll : hint_range(0.0, 20.0) = 4.0;
uniform float pulse_speed : hint_range(0.0, 20.0) = 10.0;

varying vec3 v_local_pos;

void vertex() {
	v_local_pos = VERTEX;
}

void fragment() {
	vec2 uv = vec2(length(v_local_pos.xy) * 1.35 + 0.5, 0.5);
	vec4 soft = texture(main_tex, uv);
	float n = texture(noise_tex, v_local_pos.xy * 3.0 + vec2(TIME * noise_scroll, 0.0)).r;
	float flicker = 0.7 + 0.3 * sin(TIME * pulse_speed);
	float body = soft.a * flicker * (0.75 + 0.25 * n);
	vec3 col = mix(core_color.rgb, core_hot_color.rgb, clamp(n + soft.r, 0.0, 1.0));
	ALBEDO = col;
	EMISSION = col * emission_strength * body;
	ALPHA = body * core_color.a;
}
