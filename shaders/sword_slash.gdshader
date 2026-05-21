shader_type spatial;
render_mode blend_add, cull_disabled, unshaded, shadows_disabled, depth_draw_never;

uniform vec4 slash_color : source_color = vec4(0.45, 0.82, 1.0, 0.95);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float band_width : hint_range(0.02, 0.5) = 0.14;
uniform float wave_freq : hint_range(1.0, 30.0) = 14.0;
uniform float wave_amp : hint_range(0.0, 0.3) = 0.08;
uniform float edge_soft : hint_range(0.01, 0.3) = 0.12;
uniform float reach = 2.2;
uniform float arc_half_rad = 1.0;

varying vec2 v_uv;

void vertex() {
	v_uv = UV;
	float t = (UV.x - 0.5) * 2.0;
	float ang = t * arc_half_rad;
	float r0 = reach * 0.14;
	float r1 = reach * 0.95;
	float r = mix(r0, r1, UV.y);
	// Горизонтальная дуга впереди: X — влево/вправо, Z — вперёд от игрока.
	VERTEX.x = sin(ang) * r;
	VERTEX.z = cos(ang) * r;
	float wave = sin(UV.x * wave_freq + progress * 18.0) * wave_amp;
	VERTEX.y = wave;
}

void fragment() {
	vec2 uv = v_uv;
	float u = uv.x;
	float v = uv.y;

	float envelope = smoothstep(0.0, edge_soft, v) * smoothstep(1.0, 1.0 - edge_soft, v);
	float side = smoothstep(0.0, edge_soft, u) * smoothstep(1.0, 1.0 - edge_soft, u);

	float leading = progress;
	float band = smoothstep(leading - band_width, leading, u);
	band *= 1.0 - smoothstep(leading, leading + band_width * 0.55, u);

	float ripple = sin(u * wave_freq - progress * 22.0) * 0.5 + 0.5;
	band *= mix(0.45, 1.0, ripple);

	float trail = smoothstep(leading - band_width * 2.2, leading - band_width * 0.3, u) * 0.35;
	trail *= 1.0 - smoothstep(leading - band_width * 0.5, leading, u);

	float energy = (band + trail) * envelope * side;
	vec3 col = slash_color.rgb * (0.7 + energy * 1.4);
	ALBEDO = col;
	ALPHA = energy * slash_color.a;
	EMISSION = col * energy * 2.2;
}
