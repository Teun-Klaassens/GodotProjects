shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_disabled;

// Screen and Depth buffers
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

// Underwater palette & absorption parameters
uniform vec3 water_fog_color : source_color = vec3(0.063, 0.231, 0.251);     // #103B40
uniform vec3 deep_water_color : source_color = vec3(0.027, 0.122, 0.161);    // #071F29
uniform vec3 absorption = vec3(0.32, 0.085, 0.055);                           // Red absorbs 6x faster than blue
uniform float scattering_strength : hint_range(0.0, 1.0) = 0.85;
uniform float fog_density : hint_range(0.01, 0.5) = 0.12;                     // 6-10m visibility cutoff
uniform float underwater_blend : hint_range(0.0, 1.0) = 0.0;                  // Camera submerged blend factor

// Refraction / Wavery distortion
uniform float wave_distortion_strength : hint_range(0.0, 0.05) = 0.006;
uniform float wave_speed : hint_range(0.1, 5.0) = 1.6;

// Animated Caustics projection
uniform float caustic_intensity : hint_range(0.0, 1.0) = 0.25;

float caustic_pattern(vec2 uv, float t) {
	vec2 p = uv * 3.5;
	float c1 = sin(p.x * 2.5 + t * 1.8 + sin(p.y * 3.0 + t * 1.2));
	float c2 = cos(p.y * 2.8 - t * 1.4 + cos(p.x * 3.2 - t * 1.5));
	return pow(clamp((c1 + c2) * 0.5 + 0.5, 0.0, 1.0), 3.0);
}

void vertex() {
	// Fullscreen quad in front of camera
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	if (underwater_blend <= 0.001) {
		discard;
	}

	// 1. Subtle wavery optical refraction
	float t = TIME * wave_speed;
	vec2 uv_offset = vec2(
		sin(SCREEN_UV.y * 28.0 + t) * cos(SCREEN_UV.x * 18.0 + t * 0.7),
		cos(SCREEN_UV.x * 24.0 + t * 1.1) * sin(SCREEN_UV.y * 20.0 - t * 0.8)
	) * wave_distortion_strength * underwater_blend;

	vec2 distorted_uv = clamp(SCREEN_UV + uv_offset, vec2(0.001), vec2(0.999));

	// 2. Linear Depth reconstruction
	float depth_raw = texture(depth_texture, distorted_uv).r;
	vec4 ndc = vec4(distorted_uv * 2.0 - 1.0, depth_raw, 1.0);
	vec4 world_pos = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * ndc;
	world_pos.xyz /= world_pos.w;

	vec3 camera_pos = INV_VIEW_MATRIX[3].xyz;
	float dist_to_object = length(world_pos.xyz - camera_pos);

	// Handle background sky / infinite distance
	if (depth_raw >= 1.0 || dist_to_object > 180.0) {
		dist_to_object = 25.0; // Saturate into pure deep teal fog
	}

	// 3. Beer-Lambert wavelength light absorption (red rapidly decays, teal/blue persists)
	vec3 original_color = texture(screen_texture, distorted_uv).rgb;
	vec3 transmission = exp(-absorption * dist_to_object);
	vec3 absorbed_color = original_color * transmission;

	// 4. Exponential scattering & depth fog
	float fog_factor = 1.0 - exp(-fog_density * dist_to_object);
	vec3 fog_color = mix(water_fog_color, deep_water_color, clamp(dist_to_object / 18.0, 0.0, 1.0));

	// 5. Subtle underwater caustics on nearby surfaces
	if (dist_to_object < 16.0) {
		float caust = caustic_pattern(world_pos.xz * 0.15, t * 0.8) * caustic_intensity;
		float caustic_falloff = exp(-dist_to_object * 0.25);
		absorbed_color += vec3(caust * 0.6, caust * 0.9, caust * 1.0) * caustic_falloff;
	}

	// Combine absorption and scattering
	vec3 final_underwater = mix(absorbed_color, fog_color, fog_factor * scattering_strength);

	// Contrast and desaturation in water
	float gray = dot(final_underwater, vec3(0.299, 0.587, 0.114));
	final_underwater = mix(vec3(gray), final_underwater, 0.82);

	// Output blended smoothly with air vision
	ALBEDO = mix(original_color, final_underwater, underwater_blend);
}
