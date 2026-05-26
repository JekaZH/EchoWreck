shader_type spatial;
render_mode blend_add, cull_disabled, unshaded, shadows_disabled, depth_draw_never;

uniform vec4 streak_color : source_color = vec4(1.0, 0.4, 0.05, 0.9);
uniform vec4 streak_tip : source_color = vec4(1.0, 0.85, 0.35, 0.0);
uniform float emission_strength : hint_range(0.5, 12.0) = 3.0;

varying vec2 v_uv;

void vertex() {
	v_uv = UV;
}

void fragment() {
	vec2 uv = v_uv;
	float along = smoothstep(0.0, 0.08, uv.y) * smoothstep(1.0, 0.72, uv.y);
	float across = smoothstep(0.5, 0.08, abs(uv.x - 0.5));
	float alpha = along * across;
	vec3 col = mix(streak_color.rgb, streak_tip.rgb, uv.y);
	ALBEDO = col;
	EMISSION = col * emission_strength * along;
	ALPHA = alpha * streak_color.a;
}
