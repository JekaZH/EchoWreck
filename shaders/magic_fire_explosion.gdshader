shader_type spatial;
render_mode blend_add, cull_disabled, unshaded, shadows_disabled, depth_draw_never;

uniform vec4 color_hot : source_color = vec4(1.0, 0.9, 0.35, 1.0);
uniform vec4 color_mid : source_color = vec4(1.0, 0.45, 0.08, 1.0);
uniform vec4 color_dark : source_color = vec4(0.55, 0.08, 0.02, 1.0);
uniform float progress : hint_range(0.0, 1.5) = 0.0;
uniform float ring_sharpness : hint_range(1.0, 24.0) = 8.0;
uniform float emission_strength : hint_range(0.5, 12.0) = 4.0;
uniform float noise_scale : hint_range(1.0, 20.0) = 6.0;

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
	vec2 uv = v_uv - vec2(0.5);
	float dist = length(uv) * 2.0;
	float ring = 1.0 - abs(dist - progress);
	ring = pow(max(ring, 0.0), ring_sharpness);
	float n = noise(uv * noise_scale + vec2(progress * 3.0, TIME * 0.5));
	float core = smoothstep(0.55, 0.0, dist) * (0.6 + 0.4 * n);
	float sparks = step(0.82, n) * ring;
	vec3 col = mix(color_dark.rgb, color_mid.rgb, clamp(dist * 1.2, 0.0, 1.0));
	col = mix(col, color_hot.rgb, core + sparks);
	float alpha = (ring * 0.85 + core * 0.65 + sparks) * color_mid.a;
	alpha *= smoothstep(1.05, 0.15, dist);
	ALBEDO = col;
	EMISSION = col * emission_strength;
	ALPHA = alpha;
}
