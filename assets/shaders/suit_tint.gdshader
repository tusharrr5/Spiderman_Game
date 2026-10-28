shader_type canvas_item;
// Alternate suit colourways from the classic sheet: strongly red pixels take primary_to and strongly
// blue pixels take secondary_to, keeping the pre-rendered lighting (luminance) intact.

uniform vec3 primary_to = vec3(1.0, 0.2, 0.2);
uniform vec3 secondary_to = vec3(0.2, 0.3, 1.0);
uniform float strength = 1.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float l = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	float red = clamp((c.r - max(c.g, c.b)) * 3.0, 0.0, 1.0);
	float blue = clamp((c.b - max(c.r, c.g)) * 3.0, 0.0, 1.0);
	vec3 rc = primary_to * clamp(l * 2.4, 0.0, 1.4);
	vec3 bc = secondary_to * clamp(l * 2.4, 0.0, 1.4);
	c.rgb = mix(c.rgb, rc, red * strength);
	c.rgb = mix(c.rgb, bc, blue * strength);
	COLOR = c * COLOR;
}
