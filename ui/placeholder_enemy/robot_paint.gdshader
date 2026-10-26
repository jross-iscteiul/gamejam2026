shader_type canvas_item;
// Palette swap for the robot art: the body's three warm tones (yellow plate, orange and red
// shading) are replaced by a paint job; the screen, jaw, outline and highlights stay as drawn.
// Modulate still multiplies on top, so hit flashes and fades keep working.

uniform vec3 main_color : source_color = vec3(1.0, 0.882, 0.098);
uniform vec3 shade_color : source_color = vec3(1.0, 0.427, 0.02);
uniform vec3 dark_color : source_color = vec3(1.0, 0.0, 0.0);

const vec3 SRC_MAIN = vec3(1.0, 0.882, 0.098);
const vec3 SRC_SHADE = vec3(1.0, 0.427, 0.02);
const vec3 SRC_DARK = vec3(1.0, 0.0, 0.0);
const float MATCH = 0.08;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 c = tex.rgb;
	if (distance(c, SRC_MAIN) < MATCH) {
		c = main_color;
	} else if (distance(c, SRC_SHADE) < MATCH) {
		c = shade_color;
	} else if (distance(c, SRC_DARK) < MATCH) {
		c = dark_color;
	}
	COLOR = vec4(c, tex.a) * COLOR;
}
