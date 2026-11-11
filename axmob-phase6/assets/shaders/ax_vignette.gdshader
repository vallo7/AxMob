shader_type canvas_item;
// Vignette de dégâts (HUD) : bords teintés, intensité pilotée par le jeu (coup subi, PV bas).
uniform float intensity = 0.0;
uniform vec4 tint : source_color = vec4(0.92, 0.12, 0.14, 1.0);

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float v = smoothstep(0.30, 1.25, length(uv * vec2(0.85, 0.62)));
	COLOR = vec4(tint.rgb, v * intensity);
}
