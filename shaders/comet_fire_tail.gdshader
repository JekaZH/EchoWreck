shader_type spatial;
render_mode blend_add, cull_disabled, unshaded, shadows_disabled, depth_draw_never;

uniform vec4 color_head : source_color = vec4(1.0, 0.95, 0.55, 1.0);
uniform vec4 color_mid : source_color = vec4(1.0, 0.42, 0.05, 0.85);
uniform vec4 color_tail : source_color = vec4(0.85, 0.12, 0.02, 0.0);
uniform float scroll_speed : hint_range(0.0, 20.0) = 6.0;
uniform float noise_scale : hint_range(1.0, 24.0) = 8.0;
uniform float emission_strength : hint_range(1.0, 16.0) = 5.0;

varying vec2 v_uv;

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
	v_uv = UV;
}

void fragment() {
	// CylinderMesh: V вдоль оси (длина хвоста), U по окружности.
	float along = 1.0 - v_uv.y;
	float across = abs(v_uv.x - 0.5) * 2.0;
	float n = noise(vec2(along * noise_scale - TIME * scroll_speed, across * 4.0 + TIME * 0.35));
	float edge = 1.0 - smoothstep(0.22, 1.0, across);
	float body = (1.0 - along) * edge;
	body *= 0.55 + 0.45 * n;
	body *= smoothstep(0.0, 0.06, along) * smoothstep(1.0, 0.78, along);
	vec3 col = mix(color_tail.rgb, color_mid.rgb, smoothstep(0.0, 0.45, along));
	col = mix(col, color_head.rgb, pow(1.0 - along, 0.65));
	float alpha = body * mix(color_tail.a, color_head.a, 1.0 - along);
	ALBEDO = col;
	EMISSION = col * emission_strength * body;
	ALPHA = alpha;
}
