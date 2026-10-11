shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_always, cull_disabled, shadows_disabled, specular_disabled, ambient_light_disabled;

// --- Appearance ---
uniform vec4 shallow_color : source_color = vec4(0.02, 0.08, 0.18, 1.0);
uniform vec4 deep_abyss_color : source_color = vec4(0.0, 0.01, 0.04, 1.0);
uniform vec4 foam_color : source_color = vec4(0.78, 0.86, 0.94, 1.0);
uniform vec4 ambient_color : source_color = vec4(0.01, 0.03, 0.08, 1.0);
uniform vec4 diffuse_color : source_color = vec4(0.04, 0.12, 0.28, 1.0);
uniform vec4 specular_color : source_color = vec4(0.72, 0.84, 0.98, 1.0);
uniform vec4 sun_color : source_color = vec4(0.42, 0.52, 0.72, 1.0);
uniform vec4 oil_sheen_color : source_color = vec4(0.04, 0.14, 0.32, 1.0);

uniform vec3 sun_direction = vec3(0.08, 0.99, 0.12);
// 0 = mirror-sharp highlights, 1 = very broad/rough highlights
uniform float roughness : hint_range(0.0, 1.0) = 0.287;
uniform float specular_strength = 1.15;
uniform float diffuse_strength = 0.35;
uniform float reflection_strength = 0.85;
uniform float sheen_strength = 0.55;
uniform float refraction_strength = 0.03;
uniform float surface_opacity = 0.94;
uniform float foam_amount = 1.0;
uniform float fresnel_f0 = 0.04;

uniform float visible_depth = 1.35;
uniform float depth_falloff_steepness = 0.9;
uniform float foam_distance = 1.15;
uniform float foam_scale = 0.18;
uniform float caustic_scale = 0.18;
uniform float caustic_speed = 0.55;
uniform float caustic_strength = 0.12;

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap, repeat_disable;

// Crashing swells
uniform float wave_height = 2.15;
uniform float wave_time_scale = 1.15;
uniform float base_wavelength = 38.0;
uniform float base_speed = 2.4;
uniform int octaves : hint_range(1, 16) = 12;
uniform float lacunarity = 1.28;
uniform float persistence = 0.78;
uniform float peak_sharpness = 2.35;
uniform float domain_warp = 0.85;
uniform float wave_lean = 0.55;
uniform float wave_direction = 0.0; // degrees, rotates the whole swell pattern

uniform vec3 creature_position = vec3(0.0);
uniform vec3 creature_velocity = vec3(0.0);
uniform float creature_disturbance_radius = 48.0;
uniform float creature_surge_intensity = 0.0;

varying vec3 v_world_pos;
varying vec2 v_plane_xz;
varying float v_wave_peak;
varying float v_wake;
varying float v_steepness;

const int MAX_OCTAVES = 16;

struct WaveSample {
	float height;
	vec2 deriv;
	float peak;
	float wake;
};

vec2 octave_dir(int i) {
	float n = float(i) + 1.0;
	float x = fract(sin(n * 127.1) * 43758.5453) * 2.0 - 1.0;
	float z = fract(sin(n * 269.5) * 43758.5453) * 2.0 - 1.0;
	vec2 d = normalize(vec2(x, z));
	float a = radians(wave_direction);
	float c = cos(a);
	float s = sin(a);
	return vec2(d.x * c - d.y * s, d.x * s + d.y * c);
}

float get_caustics(vec2 pos, float time) {
	vec2 p = pos * caustic_scale;
	float c1 = sin(p.x + sin(p.y + time) + time);
	float c2 = cos(p.y + cos(p.x - time) + time * 1.1);
	float c3 = sin((p.x + p.y) * 0.7 + time * 0.9);
	return clamp((c1 * c2 + c3) * 0.5 + 0.5, 0.0, 1.0);
}

void accumulate_creature(vec2 p, float t, float surge, inout WaveSample s) {
	vec2 to_p = p - creature_position.xz;
	float dist = length(to_p);
	float local_factor = clamp(1.0 - dist / creature_disturbance_radius, 0.0, 1.0);
	local_factor = pow(local_factor, 1.25);
	if (local_factor <= 0.001) {
		return;
	}

	float k_ring = 0.38;
	float k_chop = 1.1;
	float rings = sin(dist * k_ring - t * 6.2);
	float chop = sin(dist * k_chop - t * 9.0) * 0.28;
	float bulge = exp(-dist * dist * 0.0065) * (0.45 + surge * 1.35);

	vec2 vel_xz = creature_velocity.xz;
	float speed = length(vel_xz);
	float trailing = 0.0;
	if (speed > 0.15 && dist > 0.001) {
		vec2 ahead = vel_xz / speed;
		float behind = clamp(-dot(to_p / dist, ahead), 0.0, 1.0);
		float corridor = exp(-pow(abs(dot(to_p, vec2(-ahead.y, ahead.x))), 2.0) * 0.08);
		trailing = behind * corridor * sin(dist * 0.55 - t * 7.0) * min(speed * 0.12, 1.4);
	}

	float wake = (rings * (0.95 + surge * 1.7) + chop + bulge + trailing) * local_factor;
	s.wake += wake;
	s.height += wake;

	if (dist > 0.001) {
		vec2 ddist = to_p / dist;
		float drings = cos(dist * k_ring - t * 6.2) * k_ring * (0.95 + surge * 1.7);
		float dchop = cos(dist * k_chop - t * 9.0) * k_chop * 0.28;
		float dbulge = bulge * (-2.0 * dist * 0.0065);
		s.deriv += ddist * (drings + dchop + dbulge) * local_factor;
	}
}

void accumulate_wave(vec2 p, vec2 dir, float freq, float amp, float phase, inout WaveSample s) {
	float theta = dot(dir, p) * freq + phase;
	float sn = sin(theta);
	float cs = cos(theta);
	float shape = exp(peak_sharpness * (sn - 1.0));
	s.height += amp * shape;
	s.peak += amp * shape;

	float d_dtheta = amp * peak_sharpness * cs * shape;
	s.deriv += dir * freq * d_dtheta;
}

WaveSample sample_waves(vec2 p, float t, int count) {
	WaveSample s;
	s.height = 0.0;
	s.deriv = vec2(0.0);
	s.peak = 0.0;
	s.wake = 0.0;

	float freq = TAU / max(base_wavelength, 0.001);
	float amp = 1.0;
	vec2 warped = p;

	int n = clamp(count, 1, MAX_OCTAVES);
	for (int i = 0; i < MAX_OCTAVES; i++) {
		if (i >= n) {
			break;
		}
		vec2 dir = octave_dir(i);
		float speed_i = base_speed * mix(0.75, 1.4, fract(sin(float(i + 3) * 91.7) * 453.1));
		float phase = speed_i * freq * t;
		accumulate_wave(warped, dir, freq, amp, phase, s);

		warped = p + s.deriv * domain_warp;

		freq *= lacunarity;
		amp *= persistence;
	}

	s.height *= wave_height;
	s.deriv *= wave_height;
	s.peak *= wave_height;

	accumulate_creature(p, t, creature_surge_intensity, s);
	return s;
}

float schlick_fresnel(float n_dot_v) {
	float f = clamp(1.0 - n_dot_v, 0.0, 1.0);
	return fresnel_f0 + (1.0 - fresnel_f0) * pow(f, 5.0);
}

vec3 sample_environment(vec3 dir, float t) {
	vec3 d = normalize(dir);
	vec3 void_col = vec3(0.002, 0.008, 0.02);
	vec3 ceiling = vec3(0.03, 0.05, 0.09);
	vec3 sky = mix(void_col, ceiling, smoothstep(-0.05, 0.55, d.y));

	float lamps = 0.0;
	lamps += pow(max(dot(d, normalize(vec3(0.12, 0.98, 0.08))), 0.0), 280.0);
	lamps += pow(max(dot(d, normalize(vec3(-0.18, 0.97, -0.12))), 0.0), 320.0);
	lamps += pow(max(dot(d, normalize(vec3(0.04, 0.99, 0.22))), 0.0), 400.0);
	sky += sun_color.rgb * lamps * 0.55;

	float drift = sin(d.x * 9.0 + t * 0.015) * sin(d.z * 7.0 + t * 0.012);
	sky *= 1.0 + drift * 0.04;
	return sky;
}

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * wave_time_scale;
	WaveSample s = sample_waves(world_pos.xz, t, min(octaves, 8));

	vec2 lean = -s.deriv * wave_lean;
	VERTEX.xz += lean;
	VERTEX.y += s.height;
	NORMAL = normalize(vec3(-s.deriv.x, 1.0, -s.deriv.y));

	v_plane_xz = world_pos.xz;
	v_world_pos = world_pos + vec3(lean.x, s.height, lean.y);
	v_wake = s.wake;
	v_wave_peak = clamp(s.peak / max(wave_height * 2.2, 0.001), 0.0, 1.0);
	v_steepness = clamp(length(s.deriv) / max(wave_height * 1.8, 0.001), 0.0, 1.0);
}

void fragment() {
	float t = TIME * wave_time_scale;
	WaveSample s = sample_waves(v_plane_xz, t, octaves);

	vec3 N = normalize(vec3(-s.deriv.x, 1.0, -s.deriv.y));
	vec3 L = normalize(sun_direction);
	vec3 V = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	vec3 H = normalize(V + L);
	vec3 R = reflect(-V, N);

	float n_dot_l = max(dot(N, L), 0.0);
	float n_dot_v = max(dot(N, V), 0.0);
	float n_dot_h = max(dot(N, H), 0.0);
	float fresnel = schlick_fresnel(n_dot_v);

	vec3 lambert = diffuse_color.rgb * n_dot_l * diffuse_strength;
	float specular_exponent = exp2(mix(11.0, 1.0, clamp(roughness, 0.0, 1.0)));
	vec3 blinn = specular_color.rgb * pow(n_dot_h, specular_exponent) * fresnel * specular_strength;
	vec3 env = sample_environment(R, TIME);

	float depth_val = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth_val);
	vec4 view_coords = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view_coords.xyz /= view_coords.w;
	float water_depth = max(0.0, -view_coords.z - VERTEX.z);

	float depth_factor = 1.0 - exp(-water_depth * (2.4 / max(visible_depth, 0.05)));
	depth_factor = clamp(pow(depth_factor, depth_falloff_steepness), 0.0, 1.0);

	vec2 refract_uv = clamp(SCREEN_UV + N.xz * mix(refraction_strength, refraction_strength * 0.133, depth_factor), vec2(0.001), vec2(0.999));
	vec3 scene_underwater = textureLod(screen_texture, refract_uv, 0.0).rgb;
	scene_underwater *= shallow_color.rgb;
	float caustic_val = get_caustics(v_world_pos.xz, TIME * caustic_speed);
	float caustic_mask = (1.0 - depth_factor) * (1.0 - smoothstep(0.0, 0.9, water_depth));
	scene_underwater += vec3(0.25, 0.45, 0.95) * caustic_val * caustic_strength * caustic_mask;

	vec3 transmission = mix(scene_underwater, deep_abyss_color.rgb, depth_factor);
	float oil = pow(1.0 - n_dot_v, 3.0);
	vec3 sheen = oil_sheen_color.rgb * oil * sheen_strength;
	vec3 water_body = ambient_color.rgb + lambert + transmission * (1.0 - fresnel * 0.92) + sheen;
	vec3 water_color = mix(water_body, env, clamp(fresnel * reflection_strength, 0.0, 1.0)) + blinn;

	float foam_noise = sin(v_world_pos.x * foam_scale * 22.0 + TIME * 3.2)
			* cos(v_world_pos.z * foam_scale * 18.0 + TIME * 2.6);
	foam_noise = clamp(foam_noise * 0.5 + 0.55, 0.0, 1.0);
	float shore_crash = (1.0 - smoothstep(0.0, foam_distance, water_depth)) * foam_noise;
	float breaking = smoothstep(0.38, 0.82, v_steepness) * smoothstep(0.35, 0.8, v_wave_peak);
	float crest_foam = breaking * mix(0.55, 1.0, foam_noise);
	float spray = pow(breaking, 1.6) * foam_noise;
	float wake_foam = smoothstep(0.35, 1.1, abs(v_wake)) * 0.7;
	float foam_mask = clamp((shore_crash * 0.95 + crest_foam * 0.95 + spray * 0.65 + wake_foam) * foam_amount, 0.0, 1.0);
	water_color = mix(water_color, foam_color.rgb, foam_mask);

	ALBEDO = water_color;
	ALPHA = mix(surface_opacity, 1.0, depth_factor);
}
