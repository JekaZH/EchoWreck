shader_type spatial;
render_mode blend_add, cull_back, unshaded, depth_draw_always, fog_disabled;

uniform vec4 glow_color : source_color = vec4(0.9, 0.95, 1.0, 0.75);
uniform float pulse_speed : hint_range(0.0, 10.0) = 3.0;
uniform float ring_sharpness : hint_range(0.5, 8.0) = 3.2;

void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	float dist = length(centered);
	float ring = exp(-pow(dist * ring_sharpness, 2.0));
	float pulse = 0.7 + 0.3 * sin(TIME * pulse_speed);
	float alpha = ring * glow_color.a * pulse;
	ALBEDO = glow_color.rgb * pulse;
	ALPHA = alpha;
}
