shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// Flux lumineux derrière une hache (phase 5). Un quad par hache, dans un seul MultiMesh :
// x = 0 (tête) .. 1 (queue), z = -1..1 (largeur). La transformation de l'instance porte la
// direction, la longueur et la largeur ; la couleur d'instance porte teinte et intensité.

varying float v_u;
varying float v_v;

void vertex() {
	v_u = VERTEX.x;
	v_v = VERTEX.z;
}

void fragment() {
	float along = pow(clamp(1.0 - v_u, 0.0, 1.0), 1.7);
	float across = 1.0 - v_v * v_v;
	// Cœur plus lumineux au centre : un trait « chaud » dans un halo coloré.
	float core = pow(across, 5.0) * along;
	// Teinte saturée sur les bords, cœur éclairci : lisible sur le sable clair comme sur la mer.
	ALBEDO = mix(COLOR.rgb, vec3(1.0), core * 0.75);
	ALPHA = clamp(along * across * COLOR.a * 1.25, 0.0, 1.0);
}
