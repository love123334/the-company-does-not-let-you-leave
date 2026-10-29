shader_type canvas_item;
uniform float scanline_count : hint_range(0.0, 1080.0) = 360.0;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.08;
uniform float vignette_opacity : hint_range(0.0, 1.0) = 0.25;

void fragment() {
    vec2 uv = UV;
    float scan = sin(uv.y * scanline_count * 3.14159) * 0.5 + 0.5;
    vec2 vig_uv = uv * (1.0 - uv.yx);
    float vig = vig_uv.x * vig_uv.y * 15.0;
    vig = clamp(pow(vig, 0.25), 0.0, 1.0);
    COLOR = vec4(0.0, 0.0, 0.0, (1.0 - scan) * scanline_intensity + (1.0 - vig) * vignette_opacity);
}
