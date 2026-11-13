// Full-screen border glow for direct gameplay feedback (green = slowing, red = speeding up).
// Put on a ColorRect covering the whole viewport; drive `intensity` and `glow_color` from script.
// Cost: one full-screen alpha-blended pass; the HUD hides the rect when intensity ~ 0.
shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(0.2, 1.0, 0.45, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
// Glow width as a fraction of the shorter screen side.
uniform float width_fraction : hint_range(0.01, 0.5) = 0.1;

void fragment() {
	vec2 size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 p = UV * size;
	float edge_distance = min(min(p.x, size.x - p.x), min(p.y, size.y - p.y));
	float width = width_fraction * min(size.x, size.y);
	float falloff = 1.0 - smoothstep(0.0, width, edge_distance);
	COLOR = vec4(glow_color.rgb, glow_color.a * intensity * falloff * falloff);
}
