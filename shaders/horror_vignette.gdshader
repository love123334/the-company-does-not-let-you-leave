shader_type canvas_item;
uniform vec4 vignette_color : source_color = vec4(0.02, 0.01, 0.015, 1.0);
uniform float inner_radius : hint_range(0.0, 1.0) = 0.45;
uniform float outer_radius : hint_range(0.0, 2.0) = 1.05;
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.0;
uniform float pulse_intensity : hint_range(0.0, 0.5) = 0.06;

void fragment() {
    vec2 center = vec2(0.5, 0.5);
    float dist = distance(UV, center);
    float pulse = sin(TIME * pulse_speed) * pulse_intensity;
    float alpha = smoothstep(inner_radius + pulse, outer_radius, dist);
    COLOR = vec4(vignette_color.rgb, alpha * vignette_color.a);
}
