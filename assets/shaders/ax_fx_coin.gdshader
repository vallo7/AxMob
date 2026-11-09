shader_type spatial;
render_mode unshaded, blend_mix, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled;
#include "res://assets/shaders/ax_fx_common.gdshaderinc"
// Pièce cosmétique : jaillit de l'ennemi, retombe, puis file vers le joueur (position courante,
// `target`) en tournant sur elle-même. La pièce est DÉJÀ créditée : tout ceci est visuel.
// Données : origine ; colonne 0 = vitesse initiale ; colonne 1 = (durée du jaillissement,
// gravité, -) ; données perso. = (naissance, durée totale, taille, vitesse de rotation).

uniform float fx_time = 0.0;
uniform vec3 target = vec3(0.0, 1.0, 0.0);

varying vec2 v_uv;
varying float v_k;

vec3 pop_pos(vec3 p0, vec3 vel, float g, float t) {
	return p0 + vel * t + vec3(0.0, -0.5 * g * t * t, 0.0);
}

void vertex() {
	float age = fx_time - INSTANCE_CUSTOM.x;
	float life = max(INSTANCE_CUSTOM.y, 0.001);
	float k = age / life;
	v_uv = VERTEX.xy;
	v_k = k;
	POSITION = vec4(2.0, 2.0, 2.0, 1.0);
	if (age >= 0.0 && k < 1.0) {
		vec3 p0 = MODEL_MATRIX[3].xyz;
		vec3 vel = MODEL_MATRIX[0].xyz;
		float t_pop = MODEL_MATRIX[1].x;
		float g = MODEL_MATRIX[1].y;
		vec3 pos;
		if (age < t_pop) {
			pos = pop_pos(p0, vel, g, age);
			pos.y = max(pos.y, 0.15);
		} else {
			vec3 from = pop_pos(p0, vel, g, t_pop);
			from.y = max(from.y, 0.15);
			float u = clamp((age - t_pop) / max(life - t_pop, 0.001), 0.0, 1.0);
			u = u * u * (3.0 - 2.0 * u);
			pos = mix(from, target, u);
		}
		float size = INSTANCE_CUSTOM.z * (0.35 + 0.65 * smoothstep(0.0, 0.1, k)) * (1.0 - 0.45 * smoothstep(0.8, 1.0, k));
		float flip = cos(INSTANCE_CUSTOM.w * age);
		vec2 q = vec2(VERTEX.x * max(abs(flip), 0.12), VERTEX.y);
		vec3 right = INV_VIEW_MATRIX[0].xyz;
		vec3 up = INV_VIEW_MATRIX[1].xyz;
		vec3 world = pos + (right * q.x + up * q.y) * size;
		POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
	}
}

void fragment() {
	float d = length(v_uv);
	float disc = smoothstep(1.0, 0.86, d);
	// Liseré sombre, anneau doré plus foncé, cœur clair avec un reflet.
	vec3 gold = vec3(1.0, 0.80, 0.22);
	vec3 deep = vec3(0.92, 0.56, 0.08);
	vec3 col = gold;
	col = mix(col, deep, smoothstep(0.52, 0.62, d) * (1.0 - smoothstep(0.74, 0.82, d)));
	col = mix(col, vec3(0.62, 0.34, 0.05), smoothstep(0.80, 0.92, d));
	float glint = smoothstep(0.35, 0.0, length(v_uv - vec2(-0.28, 0.3)));
	col += vec3(1.0, 0.95, 0.7) * glint * 0.7;
	ALBEDO = col;
	ALPHA = disc * (1.0 - smoothstep(0.9, 1.0, v_k));
}
