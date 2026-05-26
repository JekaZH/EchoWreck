shader_type spatial;
render_mode blend_add, unshaded, shadows_disabled, depth_draw_opaque;

uniform vec4 core_color : source_color = vec4(1.0, 0.5, 0.1, 1.0);
uniform vec4 core_hot_color : source_color = vec4(1.0, 0.9, 0.4, 1.0);
uniform float emission_strength : hint_range(0.5, 10.0) = 3.5;
uniform float noise_scroll : hint_range(0.0, 20.0) = 4.0;
uniform float pulse_speed : hint_range(0.0, 20.0) = 8.0;

varying vec3 v_local_pos;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void vertex() {
	v_local_pos = VERTEX;
}

void fragment() {
	vec3 n = normalize(NORMAL);
	float fres = pow(1.0 - abs(dot(n, vec3(0.0, 0.0, 1.0))), 2.0);
	float r = length(v_local_pos.xy);
	float sphere = 1.0 - smoothstep(0.38, 0.48, r);
	float core_hot = 1.0 - smoothstep(0.0, 0.22, r);
	float t = TIME;
	float n1 = noise(v_local_pos.xy * 6.0 + vec2(t * noise_scroll, t * noise_scroll * 0.7));
	float n2 = noise(v_local_pos.xy * 11.0 - vec2(t * noise_scroll * 1.3, 0.0));
	float flicker = 0.65 + 0.35 * sin(t * pulse_speed + n1 * 6.28);
	float fire = sphere * (0.55 + 0.45 * n1) * flicker;
	fire += fres * 0.35;
	fire = max(fire, core_hot * 0.85);
	vec3 col = mix(core_color.rgb, core_hot_color.rgb, clamp(n2 + fres + core_hot, 0.0, 1.0));
	float alpha = fire * core_color.a;
	ALBEDO = col;
	EMISSION = col * emission_strength * fire;
	ALPHA = alpha;
}
