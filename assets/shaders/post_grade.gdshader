shader_type canvas_item;
// Full-screen cinematic grade for the game world (HUD draws above it):
// soft bloom from the screen mip chain, filmic contrast, split-tone colour grade and vignette.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float bloom_strength = 0.45;
uniform float bloom_threshold = 0.62;
uniform float saturation = 1.12;
uniform float contrast = 1.1;
uniform vec3 shadow_tint = vec3(0.02, 0.03, 0.07);
uniform vec3 highlight_tint = vec3(1.05, 1.0, 0.94);
uniform float vignette = 0.42;
uniform float exposure = 1.0;
uniform float letterbox = 0.0;   // 0..1 cinematic bars for specials

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb * exposure;
	vec3 b = textureLod(screen_tex, SCREEN_UV, 2.5).rgb * 0.5 + textureLod(screen_tex, SCREEN_UV, 4.0).rgb * 0.5;
	b = max(b - vec3(bloom_threshold), vec3(0.0)) / (1.0 - bloom_threshold);
	c += b * bloom_strength;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	c = (c - 0.5) * contrast + 0.5;
	// split toning: cool shadows, warm highlights
	c = mix(c + shadow_tint, c * highlight_tint, smoothstep(0.15, 0.85, l));
	vec2 d = SCREEN_UV - vec2(0.5);
	d.x *= 1.3;
	c *= 1.0 - smoothstep(0.25, 0.95, length(d)) * vignette;
	float bar = letterbox * 0.11;
	if (SCREEN_UV.y < bar || SCREEN_UV.y > 1.0 - bar) {
		c = vec3(0.0);
	}
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
