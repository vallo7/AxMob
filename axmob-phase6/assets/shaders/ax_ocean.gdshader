shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;
// Mer de la plage — style CARTOON (phase 6) : eau turquoise en BANDES de profondeur, caustiques
// qui dansent sur le fond peu profond, écume festonnée qui avance et recule, deuxième ligne
// d'écume détachée, traits de vagues, scintillements en étoile, eau LÉGÈREMENT TRANSPARENTE près
// du sable (on devine le fond). Le contour de l'île est EXACTEMENT celui de blender/source/
// arena_beach.py (edge(theta)) : toute modification doit être faite aux deux endroits.
// Coût : 3 lectures de texture (réseau de caustiques x2, scintillement) ; `detail` (profil de
// qualité) coupe les couches : 0 = aplats + écume, 0.5 = + caustiques + transparence, 1 = tout.

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec4 shallow_color : source_color = vec4(0.42, 0.95, 0.88, 1.0);
uniform vec4 mid_color : source_color = vec4(0.12, 0.76, 0.92, 1.0);
uniform vec4 deep_color : source_color = vec4(0.07, 0.46, 0.86, 1.0);
uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 0.97, 1.0);
// Mise à l'échelle du modèle : arena_radius / 13.
uniform float model_scale = 1.0;
// Distance entre le bord de l'île et la ligne d'eau (la pente passe sous l'eau).
uniform float shore_offset = 1.13;
uniform float edge_base = 22.5;
uniform float detail : hint_range(0.0, 1.0) = 1.0;
// 1 = scintillements en étoile (profil ÉLEVÉ).
uniform float sparkle : hint_range(0.0, 1.0) = 0.0;

varying vec2 plan;

float island_edge(float th) {
	return edge_base + 1.0 * sin(3.0 * th + 0.6) + 0.6 * sin(5.0 * th + 2.0);
}

void vertex() {
	plan = VERTEX.xz;
	VERTEX.y += 0.07 * sin(VERTEX.x * 0.35 + TIME * 0.9) * sin(VERTEX.z * 0.31 + TIME * 0.7);
}

void fragment() {
	vec2 p = plan / model_scale;
	float th = atan(p.x, -p.y);
	float d = length(p) - (island_edge(th) - shore_offset); // > 0 : au large de la ligne d'eau
	float depth = clamp(d / 15.0, 0.0, 1.0);
	// Couleur : dégradé + bandes franches (façon dessin animé).
	vec3 col = mix(shallow_color.rgb, mid_color.rgb, smoothstep(0.02, 0.30, depth));
	col = mix(col, deep_color.rgb, smoothstep(0.26, 0.85, depth));
	float steps_t = floor(depth * 5.0) / 5.0;
	col = mix(col, mix(shallow_color.rgb, deep_color.rgb, steps_t), 0.30);
	// Houle : grandes nappes claires/sombres qui dérivent.
	float swell = sin(p.x * 0.28 + TIME * 0.5) * sin(p.y * 0.25 - TIME * 0.4);
	col += swell * 0.035;
	// Caustiques sur le fond peu profond.
	if (detail > 0.3) {
		float c = texture(noise_tex, p * 0.055 + vec2(TIME * 0.018, TIME * 0.011)).r
			* texture(noise_tex, p * 0.037 - vec2(TIME * 0.013, -TIME * 0.017)).r;
		float caustic = smoothstep(0.10, 0.45, c) * (1.0 - smoothstep(0.0, 0.55, depth));
		col += vec3(0.85, 1.0, 0.95) * caustic * 0.30;
	}
	// Traits de vagues qui s'éloignent du rivage (fins, nets).
	float lines = 0.0;
	if (detail > 0.7) {
		float ripple = sin(d * 2.1 - TIME * 1.4 + sin(th * 9.0) * 1.7);
		lines = smoothstep(0.90, 0.97, ripple) * smoothstep(1.4, 2.2, d) * (1.0 - smoothstep(3.0, 9.0, d));
	}
	// Écume : front festonné qui avance/recule + seconde ligne détachée.
	float scallop = d + 0.30 * sin(th * 38.0 + TIME * 0.8) + 0.12 * sin(th * 91.0 - TIME * 1.3);
	float pulse = 0.62 + 0.28 * sin(TIME * 1.3 + th * 6.0);
	float shore_foam = 1.0 - smoothstep(pulse - 0.06, pulse, scallop);
	float line2 = 1.0 - smoothstep(0.0, 0.07, abs(scallop - (pulse + 0.95 + 0.25 * sin(TIME * 1.3 + 1.5))) - 0.11);
	line2 *= step(0.35, detail);
	float foam = clamp(shore_foam + line2 * 0.9 + lines * 0.7, 0.0, 1.0);
	// Scintillements (étoiles) : seuils très hauts sur un bruit qui change en cadence.
	float glint = 0.0;
	if (sparkle > 0.5) {
		float n = texture(noise_tex, p * 0.31 + vec2(floor(TIME * 1.5) * 0.173, 0.0)).g;
		glint = smoothstep(0.985, 0.998, n) * (1.0 - smoothstep(0.0, 0.7, depth));
	}
	vec3 outc = mix(col, foam_color.rgb, foam) + vec3(glint);
	// Transparence près du sable (on devine le fond) ; plus on s'éloigne, plus l'eau est opaque.
	float see = clamp(detail * 2.0, 0.0, 1.0);
	float alpha = mix(1.0, mix(0.66, 1.0, smoothstep(0.0, 0.30, depth)), see);
	ALBEDO = outc;
	ALPHA = clamp(max(alpha, foam), 0.0, 1.0);
}
