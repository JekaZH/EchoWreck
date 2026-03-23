shader_type spatial;
render_mode cull_front, unshaded;

uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 0.0, 1.0); // жёлтый по умолчанию
uniform float outline_width : hint_range(0.001, 0.1) = 0.015;

void vertex() {
    // Расширяем вершины по нормали для создания обводки
    VERTEX += NORMAL * outline_width;
}

void fragment() {
    ALBEDO = outline_color.rgb;
    ALPHA = outline_color.a;
}