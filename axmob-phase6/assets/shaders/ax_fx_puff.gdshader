shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// Poussière, fumée, éclaboussures de sable : fusion normale (opacité), test de profondeur actif.
#include "res://assets/shaders/ax_fx_particle.gdshaderinc"
