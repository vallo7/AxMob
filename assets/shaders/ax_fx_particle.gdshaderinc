// Particules « tire et oublie » de la phase 5 (étincelles, confettis, fumée). Tout le mouvement
// est calculé dans le shader à partir de l'instant de naissance : le CPU n'écrit qu'UNE fois par
// particule (à l'émission) et ne fait plus rien ensuite.
//
// Données de l'instance (MultiMesh) :
//   transformation : origine = position de départ ; colonne 0 = vitesse initiale (m/s) ;
//                    colonne 1 = (gravité, frottement, croissance) ;
//                    colonne 2 = (étirement, rotation rad/s, -)
//   couleur        : teinte et opacité
//   données perso. : (instant de naissance, durée, taille, forme)
#include "res://assets/shaders/ax_fx_common.gdshaderinc"

uniform float fx_time = 0.0;

varying vec4 v_color;
varying vec2 v_uv;
varying float v_shape;
varying float v_k;

void vertex() {
	float age = fx_time - INSTANCE_CUSTOM.x;
	float life = max(INSTANCE_CUSTOM.y, 0.001);
	float k = age / life;
	v_color = COLOR;
	v_uv = VERTEX.xy;
	v_shape = INSTANCE_CUSTOM.w;
	v_k = k;
	POSITION = vec4(2.0, 2.0, 2.0, 1.0);
	if (age >= 0.0 && k < 1.0) {
		vec3 p0 = MODEL_MATRIX[3].xyz;
		vec3 vel = MODEL_MATRIX[0].xyz;
		float gravity = MODEL_MATRIX[1].x;
		float drag = MODEL_MATRIX[1].y;
		float grow = MODEL_MATRIX[1].z;
		float stretch = MODEL_MATRIX[2].x;
		float spin = MODEL_MATRIX[2].y;
		float travel = drag > 0.001 ? (1.0 - exp(-drag * age)) / drag : age;
		vec3 pos = p0 + vel * travel + vec3(0.0, -0.5 * gravity * age * age, 0.0);
		pos.y = max(pos.y, 0.05);
		vec3 vnow = vel * exp(-drag * age) - vec3(0.0, gravity * age, 0.0);
		float size = INSTANCE_CUSTOM.z * (1.0 + grow * k) * fx_pop(k, 0.12);
		vec3 right = INV_VIEW_MATRIX[0].xyz;
		vec3 up = INV_VIEW_MATRIX[1].xyz;
		vec2 q = VERTEX.xy;
		if (stretch > 0.001) {
			// Étincelle allongée dans le sens de sa vitesse apparente à l'écran.
			vec2 d = (VIEW_MATRIX * vec4(vnow, 0.0)).xy;
			float sp = length(d);
			d = sp > 0.001 ? d / sp : vec2(1.0, 0.0);
			float st = 1.0 + stretch * min(sp * 0.16, 3.0);
			q = vec2(q.x * st, q.y);
			q = vec2(q.x * d.x - q.y * d.y, q.x * d.y + q.y * d.x);
		} else if (abs(spin) > 0.001) {
			float a = spin * age;
			q = vec2(q.x * cos(a) - q.y * sin(a), q.x * sin(a) + q.y * cos(a));
		}
		vec3 world = pos + (right * q.x + up * q.y) * size;
		POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
	}
}

void fragment() {
	vec2 uv = v_uv;
	float d = length(uv);
	float a = 0.0;
	int shape = int(v_shape + 0.5);
	if (shape == 0) {
		// Point lumineux doux.
		a = pow(clamp(1.0 - d, 0.0, 1.0), 1.6);
	} else if (shape == 1) {
		// Éclat en étoile à quatre branches.
		float arms = max(0.0, 1.0 - abs(uv.x) * 7.0) * max(0.0, 1.0 - abs(uv.y))
				+ max(0.0, 1.0 - abs(uv.y) * 7.0) * max(0.0, 1.0 - abs(uv.x));
		float core = pow(clamp(1.0 - d * 1.5, 0.0, 1.0), 2.0);
		a = clamp(arms * 0.85 + core, 0.0, 1.0);
	} else if (shape == 2) {
		// Disque net (confetti rond).
		a = smoothstep(1.0, 0.8, d);
	} else if (shape == 3) {
		// Carré arrondi (confetti).
		vec2 q = abs(uv);
		a = smoothstep(1.0, 0.82, max(q.x, q.y)) * smoothstep(1.35, 1.0, q.x + q.y);
	} else {
		// Nuage doux (fumée, poussière) : bord très progressif.
		float s = clamp(1.0 - d, 0.0, 1.0);
		a = s * s * (3.0 - 2.0 * s);
	}
	float fade = 1.0 - smoothstep(0.55, 1.0, v_k);
	// Cœur éclairci pour les points et étoiles (effet « lumineux » en fusion normale).
	float core = (shape <= 1) ? pow(clamp(1.0 - d * 1.6, 0.0, 1.0), 2.0) : 0.0;
	ALBEDO = mix(v_color.rgb, vec3(1.0), core * 0.8);
	ALPHA = clamp(a * v_color.a * fade, 0.0, 1.0);
}
