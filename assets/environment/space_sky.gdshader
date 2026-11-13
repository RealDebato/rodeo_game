// Procedural starfield sky: deep-space colour plus hashed point stars. No textures.
shader_type sky;

uniform vec3 space_color : source_color = vec3(0.004, 0.006, 0.012);
// Fraction of sky cells that contain a star.
uniform float star_density : hint_range(0.0, 0.05) = 0.004;
// Cells per unit direction; larger = smaller, more numerous stars.
uniform float star_scale = 350.0;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

void sky() {
	vec3 cell = floor(EYEDIR * star_scale);
	float star = step(1.0 - star_density, hash13(cell));
	float brightness = 0.3 + 0.7 * hash13(cell + 17.0);
	COLOR = space_color + vec3(star * brightness);
}
