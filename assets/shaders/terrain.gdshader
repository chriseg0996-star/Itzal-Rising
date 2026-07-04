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

// Anti-tiling WITHOUT blur: blend a second sample that is rotated AND at a
// different (irrational) scale, so the axis-aligned 512px repeat is broken while
// every sample stays at full texel detail (no zoomed-in, blurry octave).
vec3 detile(sampler2D tex, vec2 t) {
	vec2 r = mat2(vec2(0.80, 0.60), vec2(-0.60, 0.80)) * (t * 1.37) + vec2(0.37, 0.71);
	return mix(texture(tex, t).rgb, texture(tex, r).rgb, 0.45);
}

void fragment() {
	vec2 world = UV * world_size;

	// Gentle domain warp breaks the regular tile grid (no stripes / lattice).
	vec2 warp = vec2(n(world / 820.0), n(world / 820.0 + vec2(37.0))) - vec2(0.5);
	vec2 t = (world + warp * 70.0) / tile_px;

	vec3 g  = detile(grass, t);
	vec3 dg = detile(drygrass, t * 1.1 + vec2(0.2));
	vec3 d  = detile(dirt, t * 0.9 + vec2(0.7));

	// Large, gentle grass clearings (low frequency).
	float clearing = n(world / 2700.0);
	float dryw = smoothstep(0.50, 0.78, clearing) * 0.42;
	vec3 col = mix(g, dg, dryw);

	// Biome-scale rocky / fertile zones — broad, so whole regions of the map read
	// as stonier or richer ground without any clutter.
	float biome = n(world / 2800.0 + vec2(11.3));
	col = mix(col, d * vec3(0.86, 0.87, 0.91), smoothstep(0.66, 0.84, biome) * 0.34);
	col = mix(col, col * vec3(0.82, 1.04, 0.68), smoothstep(0.32, 0.15, biome) * 0.30);

	// MACRO variation: a big, non-tiling field modulates brightness and tint, so
	// the 512px repeat is overpowered by a larger organic pattern and no two zones
	// of the map read the same. This is what kills the visible tiling lattice.
	float macro = n(world / 2350.0 + vec2(4.0));
	float macro2 = n(world / 1250.0 + vec2(19.0));
	col *= mix(0.84, 1.14, macro);
	col = mix(col, col * vec3(0.93, 1.03, 0.80), macro2 * 0.30);

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
