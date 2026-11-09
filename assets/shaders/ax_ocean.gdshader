shader_type spatial;
render_mode unshaded, cull_disabled;
// Mer de la plage : eau turquoise peu profonde près du sable, plus profonde au large, écume
// animée le long du rivage. Le contour de l'île est EXACTEMENT celui de blender/source/
// arena_beach.py (edge(theta)) : toute modification doit être faite aux deux endroits.

uniform vec4 shallow_color : source_color = vec4(0.49, 0.91, 0.93, 1.0);
uniform vec4 mid_color : source_color = vec4(0.2, 0.78, 0.88, 1.0);
uniform vec4 deep_color : source_color = vec4(0.12, 0.55, 0.82, 1.0);
uniform vec4 foam_color : source_color = vec4(1.0, 0.99, 0.94, 1.0);
// Mise à l'échelle du modèle : arena_radius / 13.
uniform float model_scale = 1.0;
// Distance entre le bord de l'île et la ligne d'eau (la pente passe sous l'eau).
uniform float shore_offset = 1.13;
uniform float edge_base = 22.5;
// Détail (profil de qualité) : 0 = aplat + écume de rivage, 0.5 = + reflets, 1 = + lignes de vagues.
uniform float detail : hint_range(0.0, 1.0) = 1.0;

varying vec2 plan;

float island_edge(float th) {
	return edge_base + 1.0 * sin(3.0 * th + 0.6) + 0.6 * sin(5.0 * th + 2.0);
}

void vertex() {
	plan = VERTEX.xz;
	VERTEX.y += 0.05 * sin(VERTEX.x * 0.35 + TIME * 0.9) * sin(VERTEX.z * 0.31 + TIME * 0.7);
}

void fragment() {
	vec2 p = plan / model_scale;
	float th = atan(p.x, -p.y);
	float d = length(p) - (island_edge(th) - shore_offset); // > 0 : au large de la ligne d'eau
	float depth = clamp(d / 14.0, 0.0, 1.0);
	vec3 col = mix(shallow_color.rgb, mid_color.rgb, smoothstep(0.0, 0.35, depth));
	col = mix(col, deep_color.rgb, smoothstep(0.3, 1.0, depth));
	// reflets : bandes douces qui dérivent
	if (detail > 0.3) {
		float caustic = sin(p.x * 0.9 + TIME * 0.6) * sin(p.y * 0.8 - TIME * 0.5);
		col += 0.04 * smoothstep(0.35, 0.9, caustic);
	}
	// écume : liseré qui pulse au rivage + lignes de vagues qui s'éloignent
	float pulse = 0.55 + 0.25 * sin(TIME * 1.3 + th * 12.0) + 0.1 * sin(TIME * 2.1 + th * 31.0);
	float shore_foam = 1.0 - smoothstep(0.0, pulse, d);
	float lines = 0.0;
	if (detail > 0.7) {
		float ripple = sin(d * 2.4 - TIME * 1.5 + sin(th * 9.0) * 1.6);
		lines = smoothstep(0.80, 0.98, ripple) * smoothstep(0.7, 1.3, d) * (1.0 - smoothstep(2.5, 8.0, d));
	}
	float foam = clamp(shore_foam + lines * 0.75, 0.0, 1.0);
	ALBEDO = mix(col, foam_color.rgb, foam);
}
