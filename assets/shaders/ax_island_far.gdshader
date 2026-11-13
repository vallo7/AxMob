shader_type spatial;
render_mode unshaded, cull_back, fog_disabled, shadows_disabled;
// Îles LOINTAINES (phase 7) : silhouettes douces façon décor de dessin animé. Couleur par hauteur
// (sable, herbe, roche) + face éclairée par le soleil, puis brume bleutée selon la distance
// (perspective atmosphérique) : plus c'est loin, plus c'est pâle.

uniform vec4 base_color : source_color = vec4(0.95, 0.80, 0.50, 1.0);
uniform vec4 grass_color : source_color = vec4(0.35, 0.72, 0.42, 1.0);
uniform vec4 rock_color : source_color = vec4(0.52, 0.50, 0.70, 1.0);
uniform vec4 haze_color : source_color = vec4(0.78, 0.84, 0.98, 1.0);
uniform float haze_amount = 0.55;
uniform vec3 sun_dir = vec3(0.45, 0.6, -0.65);

varying float hgt;
varying vec3 nrm;

void vertex() {
	hgt = VERTEX.y;
	nrm = NORMAL;
}

void fragment() {
	float h = clamp(hgt / 30.0, 0.0, 1.0);
	vec3 col = mix(base_color.rgb, grass_color.rgb, smoothstep(0.02, 0.18, h));
	col = mix(col, rock_color.rgb, smoothstep(0.55, 0.9, h));
	float lit = clamp(dot(normalize(nrm), normalize(sun_dir)) * 0.5 + 0.55, 0.0, 1.0);
	col *= mix(0.72, 1.12, lit);
	// Bande d'écume à la base.
	col = mix(col, vec3(1.0), (1.0 - smoothstep(0.0, 0.8, hgt)) * 0.8);
	col = mix(col, haze_color.rgb, haze_amount);
	ALBEDO = col;
}
