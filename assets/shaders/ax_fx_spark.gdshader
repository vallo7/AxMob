shader_type spatial;
render_mode unshaded, blend_mix, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled;
// Étincelles, éclats, confettis : fusion normale (saturée) pour rester lisibles sur le sable clair,
// dessinés par-dessus la scène (pas de test de profondeur : jamais rognés par le sol).
#include "res://assets/shaders/ax_fx_particle.gdshaderinc"
