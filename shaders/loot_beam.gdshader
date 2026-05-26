shader_type spatial;
render_mode blend_add, cull_disabled, unshaded, depth_draw_always, fog_disabled;

uniform vec4 beam_color : source_color = vec4(0.85, 0.92, 1.0, 0.65);
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.4;
uniform float scroll_speed : hint_range(0.0, 4.0) = 1.1;
uniform float shimmer_speed : hint_range(0.0, 12.0) = 5.5;
uniform float noise_strength : hint_range(0.0, 1.0) = 0.42;
uniform float core_tightness : hint_range(0.05, 0.8) = 0.22;
uniform float beam_falloff : hint_range(0.5, 3.0) = 1.35;

void fragment() {
	float height_fade = pow(clamp(1.0 - UV.y, 0.0, 1.0), beam_falloff);
	float radial = 1.0 - abs(UV.x - 0.5) * 2.0;
	float core = smoothstep(core_tightness, 0.0, abs(UV.x - 0.5) * 2.0);

	vec2 noise_uv = vec2(UV.x * 4.0 + TIME * scroll_speed * 0.15, UV.y * 7.0 - TIME * scroll_speed);
	float noise_sample = texture(noise_tex, noise_uv).r;
	float shimmer = 0.68 + 0.32 * sin(TIME * shimmer_speed + UV.y * 14.0 + noise_sample * 6.28318);
	float pulse = 0.72 + 0.28 * sin(TIME * pulse_speed);
	float energy = height_fade * smoothstep(0.0, 0.55, radial);
	energy *= mix(0.45, 1.0, core);
	energy *= mix(1.0 - noise_strength * 0.5, 1.0 + noise_strength * 0.5, noise_sample);
	energy *= shimmer * pulse;

	ALBEDO = beam_color.rgb * (0.85 + core * 0.55);
	ALPHA = energy * beam_color.a;
}
