shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_back;
// Matériau partagé de tous les modèles AxMob — style CARTOON (phase 6).
// Une texture « palette » + ce shader = un seul matériau pour tout le jeu (batching préservé).
// Rendu : 3 paliers d'éclairage à bords doux, OMBRES COLORÉES (violet-bleu, jamais de gris sale),
// couleurs saturées, reflet « point blanc » façon dessin animé, liseré clair sur les silhouettes.
// Le contour noir est une SECONDE PASSE (ax_outline.gdshader) branchée par ToonStyle selon le profil.
// Variations par instance (teinte de niveau, flash d'impact, armement, lueur) : « instance uniform ».

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 rim_color : source_color = vec4(0.86, 0.96, 1.0, 1.0);
uniform float rim_width : hint_range(0.05, 0.8) = 0.34;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.40;
uniform vec4 shadow_tint : source_color = vec4(0.50, 0.44, 0.86, 1.0);
uniform float saturation : hint_range(0.5, 2.0) = 1.22;
uniform float band_soft : hint_range(0.01, 0.3) = 0.07;
uniform float spec_strength : hint_range(0.0, 1.0) = 0.55;
uniform float wrap : hint_range(0.0, 1.0) = 0.55;
uniform float brightness : hint_range(0.3, 1.5) = 1.0;

// rgb = teinte, a = intensité du mélange (0 = couleur de la palette telle quelle).
instance uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 0.0);
// Flash blanc d'impact (0..1).
instance uniform float flash = 0.0;
// Lueur d'armement / d'alerte : rgb = couleur, a = force (0..1).
instance uniform vec4 alert : source_color = vec4(1.0, 0.35, 0.1, 0.0);
// Lueur de palier (élites, niveaux élevés) : 0..1, teintée par `tint`.
instance uniform float glow = 0.0;

void fragment() {
	vec3 base = texture(albedo_tex, UV).rgb;
	float g = dot(base, vec3(0.299, 0.587, 0.114));
	base = clamp(mix(vec3(g), base, saturation) * brightness, 0.0, 1.0);
	base = mix(base, base * tint.rgb * 1.2, tint.a);
	ALBEDO = base;
	ROUGHNESS = 1.0;
	vec3 n = normalize(NORMAL);
	float fres = 1.0 - clamp(dot(n, VIEW), 0.0, 1.0);
	// Liseré net (palier unique) sur le contour de la forme.
	float rim = smoothstep(1.0 - rim_width, 1.0 - rim_width + 0.14, fres) * rim_strength;
	vec3 em = rim_color.rgb * rim * mix(base, vec3(1.0), 0.45);
	// Reflet « point » façon dessin animé : direction fixe dans l'espace caméra (en haut à gauche).
	float h = dot(n, normalize(vec3(-0.45, 0.62, 0.64)));
	em += vec3(smoothstep(0.915, 0.94, h)) * spec_strength;
	em += vec3(flash);
	em += alert.rgb * alert.a;
	em += mix(base, tint.rgb, 0.5) * glow * (0.35 + 0.65 * fres);
	EMISSION = em;
}

// Éclairage à paliers : ombre teintée, lumière, plein soleil. Les bords des paliers sont doux
// (band_soft) pour rester propres quand la 3D est rendue à une échelle réduite.
void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = clamp((ndl + wrap) / (1.0 + wrap), 0.0, 1.0);
	float s1 = smoothstep(0.34 - band_soft, 0.34 + band_soft, lit);
	float s2 = smoothstep(0.74 - band_soft, 0.74 + band_soft, lit);
	vec3 shade = mix(shadow_tint.rgb * 0.60, vec3(0.88), s1);
	shade = mix(shade, vec3(1.04), s2 * 0.7);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * shade;
}
