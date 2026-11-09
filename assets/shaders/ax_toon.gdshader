shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_back;
// Matériau partagé de tous les modèles AxMob (une seule texture « palette » + ce shader =
// un seul matériau pour tout le jeu : batching préservé, plan §2.3).
// Les variations par instance (teinte de niveau, flash d'impact, armement, lueur de palier)
// passent par des « instance uniform » : aucun nouveau matériau.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 rim_color : source_color = vec4(1.0, 0.96, 0.86, 1.0);
uniform float rim_power : hint_range(0.5, 6.0) = 2.6;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.28;
uniform float wrap : hint_range(0.0, 1.0) = 0.55;

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
	base = mix(base, base * tint.rgb * 1.2, tint.a);
	ALBEDO = base;
	ROUGHNESS = 0.95;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	vec3 em = rim_color.rgb * fres * rim_strength * base;
	em += vec3(flash);
	em += alert.rgb * alert.a;
	em += mix(base, tint.rgb, 0.5) * glow * (0.35 + 0.65 * fres);
	EMISSION = em;
}

// Demi-Lambert « enveloppé » : les faces à l'ombre restent lisibles, rendu doux de jeu mobile.
void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = clamp((ndl + wrap) / (1.0 + wrap), 0.0, 1.0);
	// Phase 5 : courbe plus douce (moins de contraste) = surfaces plus lisses, rendu « jouet ».
	float soft = mix(lit, lit * lit, 0.45);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * soft * 0.86;
}
