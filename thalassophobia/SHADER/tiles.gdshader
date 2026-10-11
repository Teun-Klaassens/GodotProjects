shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 tile_color : source_color = vec4(0.88, 0.94, 0.96, 1.0);
uniform vec4 grout_color : source_color = vec4(0.35, 0.40, 0.45, 1.0);

// Tile size in meters (0.5 means each tile is 2.0 meters wide; clean and readable)
uniform float tile_scale = 0.5;
// Grout line width relative to tile
uniform float grout_thickness = 0.035;

uniform float roughness = 0.12;
uniform float specular = 0.8;

uniform float water_height = 0.5;
uniform float splash_zone_height = 0.45;

void fragment() {
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 world_norm = abs(INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;

	// Pure orthogonal projection
	vec2 uv;
	if (world_norm.x > world_norm.y && world_norm.x > world_norm.z) {
		uv = vec2(world_pos.z, world_pos.y) * tile_scale;
	} else if (world_norm.z > world_norm.y) {
		uv = vec2(world_pos.x, world_pos.y) * tile_scale;
	} else {
		uv = vec2(world_pos.x, world_pos.z) * tile_scale;
	}

	// --- ANTI-ALIASED PROCEDURAL GRID (Eliminates Moiré & optical warping) ---
	vec2 grid = fract(uv);
	vec2 dist_to_edge = min(grid, 1.0 - grid);
	float edge = min(dist_to_edge.x, dist_to_edge.y);

	// Screen-space pixel derivative: automatically fades thin lines in distance to prevent aliasing
	vec2 fw = fwidth(uv);
	float pixel_filter = max(fw.x, fw.y);

	// Smoothly integrate grout across pixel boundaries
	float half_grout = grout_thickness * 0.5;
	float is_grout = 1.0 - smoothstep(half_grout - pixel_filter, half_grout + pixel_filter, edge);

	// Distance fade: far away, gently blend out high frequency grout lines to solid clean wall
	float dist_from_cam = length(VERTEX);
	float distance_blend = clamp(1.0 - (dist_from_cam - 30.0) / 120.0, 0.0, 1.0);
	is_grout *= distance_blend;

	vec3 col = mix(tile_color.rgb, grout_color.rgb, is_grout);

	// Capillary wetness along waterline
	float dist_from_water = world_pos.y - water_height;
	float is_wet_zone = 0.0;
	if (dist_from_water <= splash_zone_height) {
		is_wet_zone = clamp(1.0 - (dist_from_water / splash_zone_height), 0.0, 1.0);
	}

	col = mix(col, col * 0.75, is_wet_zone);
	float current_rough = mix(roughness, 0.02, is_wet_zone);
	float current_spec = mix(specular, 0.98, is_wet_zone);

	ALBEDO = col;
	ROUGHNESS = current_rough;
	SPECULAR = current_spec;
	METALLIC = 0.02;
	NORMAL = NORMAL;
}
