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
	float along = clamp(1.0 - v_u, 0.0, 1.0);
	// Largeur qui s'effile vers la queue ; bord net (aplat), cœur clair.
	float w = mix(0.12, 1.0, pow(along, 0.75));
	float edge = 1.0 - smoothstep(w - 0.14, w, abs(v_v));
	float core = 1.0 - smoothstep(w * 0.28, w * 0.46, abs(v_v));
	ALBEDO = mix(COLOR.rgb, vec3(1.0), core * 0.9);
	ALPHA = clamp(edge * smoothstep(0.0, 0.22, along) * COLOR.a * 1.2, 0.0, 1.0);
}
