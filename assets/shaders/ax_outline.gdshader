shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled, depth_draw_opaque;
// Contour cartoon par « coque inversée » (seconde passe du matériau toon, via next_pass) :
// les faces ARRIÈRE sont repoussées le long de leur normale d'une largeur CONSTANTE EN PIXELS
// d'écran, quelle que soit la distance. Couleur = couleur de la palette assombrie (contour
// teinté, plus doux qu'un noir pur). Désactivé (next_pass = null) sur le profil BAS.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float outline_px : hint_range(0.0, 8.0) = 2.4;
uniform vec4 ink : source_color = vec4(0.10, 0.07, 0.20, 1.0);
uniform float ink_mix : hint_range(0.0, 1.0) = 0.62;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec4 cn = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(NORMAL, 0.0);
	vec2 dir = cn.xy;
	float len = length(dir);
	dir = len > 0.0001 ? dir / len : vec2(0.0);
	clip.xy += dir * outline_px * 2.0 / VIEWPORT_SIZE * clip.w;
	POSITION = clip;
}

void fragment() {
	vec3 base = texture(albedo_tex, UV).rgb;
	ALBEDO = mix(base * 0.30, ink.rgb, ink_mix);
}
