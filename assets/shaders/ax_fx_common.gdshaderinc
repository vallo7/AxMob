// Fonctions communes des shaders d'effets (phase 5).
float fx_ease_out(float x) {
	x = clamp(x, 0.0, 1.0);
	return 1.0 - (1.0 - x) * (1.0 - x) * (1.0 - x);
}

float fx_pop(float k, float t_in) {
	// Entrée rapide (pop) puis sortie douce : courbe d'échelle d'une particule.
	return smoothstep(0.0, t_in, k) * (1.0 - smoothstep(0.55, 1.0, k));
}

float fx_hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}
