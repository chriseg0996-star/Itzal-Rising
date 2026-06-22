shader_type canvas_item;

// Subtle texture-splat ground. Anti-tiling: the sampling position is domain-warped
// and each material is blended from two very different scales, so the 512px tile
// never reads as a repeating grid / vertical stripes. Variation and grain are
// deliberately low — the terrain should sit behind units, buildings and
// resources, not compete with them.
//
// control splat: r = compacted earth (roads/bases), g = dark forest soil,
//                b = fertile soil (berries),        a = rocky ground (mines).

uniform sampler2D grass : repeat_enable, filter_linear_mipmap;
uniform sampler2D drygrass : repeat_enable, filter_linear_mipmap;
uniform sampler2D dirt : repeat_enable, filter_linear_mipmap;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform sampler2D control : filter_linear;
uniform float world_size = 4096.0;
uniform float tile_px = 512.0;

float n(vec2 p) { return texture(noise_tex, p).r; }

// Two-scale sample of a tiling texture — the large second scale gives broad,
// natural variation and hides the repeat.
vec3 detile(sampler2D tex, vec2 t) {
	return mix(texture(tex, t).rgb, texture(tex, t * 0.34 + vec2(0.5)).rgb, 0.5);
}

void fragment() {
	vec2 world = UV * world_size;

	// Domain warp breaks the regular tile grid (no stripes / lattice).
	vec2 warp = vec2(n(world / 820.0), n(world / 820.0 + vec2(37.0))) - vec2(0.5);
	vec2 t = (world + warp * 110.0) / tile_px;

	vec3 g  = detile(grass, t);
	vec3 dg = detile(drygrass, t * 1.1 + vec2(0.2));
	vec3 d  = detile(dirt, t * 0.9 + vec2(0.7));

	// Large, gentle grass clearings (low frequency, weak).
	float clearing = n(world / 2700.0);
	float dryw = smoothstep(0.55, 0.80, clearing) * 0.28;
	vec3 col = mix(g, dg, dryw);

	// Biome-scale rocky / fertile zones — broad and subtle, so whole regions of
	// the map read as stonier or richer ground without any clutter.
	float biome = n(world / 2800.0 + vec2(11.3));
	col = mix(col, d * vec3(0.86, 0.87, 0.91), smoothstep(0.70, 0.86, biome) * 0.22);
	col = mix(col, col * vec3(0.82, 1.02, 0.72), smoothstep(0.30, 0.16, biome) * 0.18);

	// Intentional ground from the control splat (resources embedded in terrain).
	vec4 c = texture(control, UV);
	col = mix(col, d, clamp(c.r, 0.0, 1.0));                          // compacted earth
	col = mix(col, d * vec3(0.82, 0.83, 0.87), clamp(c.a, 0.0, 1.0)); // rocky ground
	col = mix(col, col * vec3(0.50, 0.55, 0.42), c.g * 0.9);          // dark forest soil
	col = mix(col, col * vec3(0.72, 1.04, 0.60), c.b * 0.55);         // fertile soil

	// Very subtle grain (~30% less than before).
	col *= 0.99 + n(world / 72.0) * 0.024;

	COLOR = vec4(col, 1.0);
}
