shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// Fausse ombre (tache douce) sous les personnages : un MultiMesh pour tous, un seul appel de dessin.
// La transformation de l'instance (échelle = rayon) et sa couleur (alpha = opacité) font tout.

varying vec2 v_uv;

void vertex() {
	v_uv = VERTEX.xz;
}

void fragment() {
	float d = length(v_uv);
	float a = smoothstep(1.0, 0.15, d);
	ALBEDO = vec3(0.08, 0.14, 0.26);
	ALPHA = a * a * COLOR.a;
}
