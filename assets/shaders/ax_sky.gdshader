shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, fog_disabled, shadows_disabled;
// Ciel d'AxMob (phase 7) : dégradé « fin d'après-midi » aux couleurs du logo (or/crème à l'horizon,
// pervenche puis indigo au zénith), soleil dessin animé (disque net + halo doux + rayons très
// légers). Dôme centré sur la caméra : il paraît infiniment loin. Aucune texture.

uniform vec4 zenith : source_color = vec4(0.30, 0.33, 0.74, 1.0);
uniform vec4 upper : source_color = vec4(0.46, 0.60, 0.95, 1.0);
uniform vec4 middle : source_color = vec4(0.72, 0.84, 1.0, 1.0);
uniform vec4 glow : source_color = vec4(1.0, 0.86, 0.52, 1.0);
uniform vec4 horizon : source_color = vec4(1.0, 0.93, 0.74, 1.0);
uniform vec4 sun_color : source_color = vec4(1.0, 0.97, 0.80, 1.0);
uniform vec3 sun_dir = vec3(0.45, 0.28, -0.85);

varying vec3 dir;

void vertex() {
	dir = normalize(VERTEX);
}

void fragment() {
	vec3 d = normalize(dir);
	float h = d.y;
	vec3 col = mix(horizon.rgb, glow.rgb, smoothstep(0.0, 0.06, h));
	col = mix(col, middle.rgb, smoothstep(0.03, 0.22, h));
	col = mix(col, upper.rgb, smoothstep(0.18, 0.55, h));
	col = mix(col, zenith.rgb, smoothstep(0.5, 1.0, h));
	// Sous l'horizon : la mer lointaine prend le relais, on garde la couleur de brume.
	col = mix(col, horizon.rgb, smoothstep(0.0, -0.05, h));
	vec3 s = normalize(sun_dir);
	float c = dot(d, s);
	float halo = smoothstep(0.80, 1.0, c);
	col += glow.rgb * halo * halo * 0.55;
	float disc = smoothstep(0.9965, 0.9975, c);
	col = mix(col, sun_color.rgb, disc);
	ALBEDO = col;
}
