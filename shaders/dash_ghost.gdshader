shader_type spatial;
render_mode blend_add, cull_disabled, unshaded, shadows_disabled, depth_draw_never;

uniform vec4 ghost_color : source_color = vec4(0.5, 0.85, 1.0, 0.7);
uniform float emission_strength : hint_range(0.5, 6.0) = 2.2;
uniform float edge_soft : hint_range(0.01, 0.5) = 0.18;

varying vec2 v_uv;

void vertex() {
	v_uv = UV;
}

void fragment() {
	vec2 uv = v_uv - vec2(0.5);
	float dist = length(uv);
	float ring = smoothstep(0.5, 0.5 - edge_soft, dist) * smoothstep(0.08, 0.2, dist);
	float streak = smoothstep(0.55, 0.0, abs(uv.x)) * smoothstep(0.35, 0.0, abs(uv.y));
	float alpha = ring * streak * ghost_color.a;
	ALBEDO = ghost_color.rgb;
	EMISSION = ghost_color.rgb * emission_strength * alpha;
	ALPHA = alpha;
}
