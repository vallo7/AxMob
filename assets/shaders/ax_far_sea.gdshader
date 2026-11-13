shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
// Mer LOINTAINE (phase 7) : prolonge la mer animée de l'île jusqu'à l'horizon. Même teinte profonde
// que ax_ocean au raccord, puis brume dorée qui monte avec la distance à la caméra, bandes de houle
// très larges et scintillement du soleil. Aucune lecture de texture.

uniform vec4 deep_color : source_color = vec4(0.07, 0.46, 0.86, 1.0);
uniform vec4 far_color : source_color = vec4(0.30, 0.62, 0.95, 1.0);
uniform vec4 haze_color : source_color = vec4(1.0, 0.93, 0.74, 1.0);
uniform vec4 sun_glint : source_color = vec4(1.0, 0.96, 0.78, 1.0);
uniform float haze_start = 70.0;
uniform float haze_end = 520.0;
uniform vec2 sun_plan = vec2(0.45, -0.85);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 cam = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float dist = length(wpos.xz - cam.xz);
	float t = smoothstep(haze_start * 0.4, haze_start * 3.0, dist);
	vec3 col = mix(deep_color.rgb, far_color.rgb, t);
	// Bandes de houle larges, de plus en plus fines vers l'horizon (perspective).
	float band = sin(wpos.z * 0.09 + TIME * 0.35) * sin(wpos.x * 0.07 - TIME * 0.22);
	col += band * 0.03;
	// Reflet du soleil : traînée de paillettes dans la direction du soleil.
	vec2 sd = normalize(sun_plan);
	vec2 rel = wpos.xz - cam.xz;
	float along = dot(rel, sd);
	float across = abs(dot(rel, vec2(-sd.y, sd.x)));
	float glint_zone = smoothstep(60.0, 300.0, along) * (1.0 - smoothstep(10.0, 90.0, across));
	float sparkle = step(0.82, sin(wpos.x * 1.7 + TIME * 1.6) * sin(wpos.z * 1.3 - TIME * 1.1) * 0.5 + 0.5);
	col = mix(col, sun_glint.rgb, glint_zone * (0.12 + 0.28 * sparkle));
	float haze = smoothstep(haze_start, haze_end, dist);
	col = mix(col, haze_color.rgb, haze * haze * 0.95 + haze * 0.05);
	ALBEDO = col;
}
