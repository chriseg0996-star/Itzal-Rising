shader_type canvas_item;

// Texture-splatting ground: blends several seamless terrain tiles by noise with
// crisp transitions (no blurry overlays), then applies a per-map control splat
// for resource-driven terrain (excavated dirt, leaf litter, fertile soil).

uniform sampler2D grass : repeat_enable, filter_linear_mipmap;
uniform sampler2D drygrass : repeat_enable, filter_linear_mipmap;
uniform sampler2D dirt : repeat_enable, filter_linear_mipmap;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform sampler2D control : filter_linear;     // RGBA splat over the whole map
uniform float world_size = 4096.0;
uniform float tile_px = 512.0;

float n(vec2 p) { return texture(noise_tex, p).r; }

void fragment() {
	vec2 world = UV * world_size;
	vec2 t = world / tile_px;

	vec3 g  = texture(grass,    t).rgb;
	vec3 dg = texture(drygrass, t * 1.17 + vec2(0.31, 0.62)).rgb;
	vec3 d  = texture(dirt,     t * 1.09 + vec2(0.73, 0.19)).rgb;

	// Broad grass clearings: one large-scale octave only, so variation reads as
	// gentle intentional clearings rather than busy random patches.
	float clearing = n(world / 1700.0);
	float dryw = smoothstep(0.54, 0.74, clearing) * 0.8;
	vec3 col = mix(g, dg, dryw);

	// Dirt is INTENTIONAL only — from the control splat (buildings, resources,
	// worn routes, rocky patches). No random brown stains on open grass.
	vec4 c = texture(control, UV);
	col = mix(col, d, clamp(c.r, 0.0, 1.0));
	col = mix(col, col * vec3(0.64, 0.68, 0.52), c.g * 0.75);   // leaf litter
	col = mix(col, col * vec3(0.74, 1.02, 0.66), c.b * 0.55);   // fertile soil

	// Subtle fine grain only (no excessive noise).
	col *= 0.96 + n(world / 70.0) * 0.07;

	COLOR = vec4(col, 1.0);
}
