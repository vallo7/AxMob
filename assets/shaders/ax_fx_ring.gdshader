shader_type spatial;
render_mode unshaded, blend_mix, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled;
#include "res://assets/shaders/ax_fx_common.gdshaderinc"
// Anneau d'onde de choc posé au sol, calculé dans le shader à partir de l'instant de naissance.
// Données : origine ; colonne 0 = (rayon initial, rayon final, épaisseur relative) ;
// données perso. = (naissance, durée, remplissage 0..1, -) ; couleur = teinte et opacité.

uniform float fx_time = 0.0;

varying vec4 v_color;
varying vec2 v_uv;
varying float v_k;
varying float v_th;
varying float v_fill;

void vertex() {
	float age = fx_time - INSTANCE_CUSTOM.x;
	float life = max(INSTANCE_CUSTOM.y, 0.001);
	float k = age / life;
	v_color = COLOR;
	v_k = k;
	v_uv = VERTEX.xz;
	v_fill = INSTANCE_CUSTOM.z;
	v_th = MODEL_MATRIX[0].z;
	POSITION = vec4(2.0, 2.0, 2.0, 1.0);
	if (age >= 0.0 && k < 1.0) {
		vec3 p0 = MODEL_MATRIX[3].xyz;
		float r = mix(MODEL_MATRIX[0].x, MODEL_MATRIX[0].y, fx_ease_out(k));
		vec3 world = p0 + vec3(VERTEX.x * r, 0.0, VERTEX.z * r);
		POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
	}
}

void fragment() {
	float d = length(v_uv);
	float th = v_th * (1.0 - 0.55 * v_k);
	float outer = smoothstep(1.0, 0.94, d);
	float inner = smoothstep(1.0 - th - 0.08, 1.0 - th, d);
	float ring = outer * inner;
	// Position à travers l'épaisseur de l'anneau : 0 = bord intérieur, 1 = bord extérieur.
	float x = clamp((d - (1.0 - th)) / max(th, 0.001), 0.0, 1.0);
	float edge = smoothstep(0.0, 0.2, x) * smoothstep(1.0, 0.8, x);
	vec3 ink = v_color.rgb * 0.40 + vec3(0.04, 0.02, 0.12);
	vec3 core = mix(v_color.rgb, vec3(1.0), 0.55 * smoothstep(0.35, 0.5, x) * (1.0 - smoothstep(0.5, 0.7, x)));
	float fill = (1.0 - smoothstep(0.0, 1.0, d)) * v_fill * outer;
	float fade = 1.0 - smoothstep(0.25, 1.0, v_k);
	ALBEDO = mix(v_color.rgb, mix(ink, core, edge), clamp(ring * 2.0, 0.0, 1.0));
	ALPHA = clamp((ring + fill * 0.8) * v_color.a * fade, 0.0, 1.0);
}
