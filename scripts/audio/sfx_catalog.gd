class_name SfxCatalog
extends RefCounted
## Catalogue des effets sonores (assets/audio/sfx/<nom>_<variante>.wav, générés par
## audio_src/build_audio.py). Chaque entrée règle le MIXAGE, pas le son lui-même :
##   n     : nombre de variantes (rotation sans répétition immédiate)
##   vol   : gain en dB ajouté au niveau du fichier (les fichiers portent déjà la hiérarchie)
##   pitch : variation aléatoire de hauteur (± fraction) : jamais deux sons identiques
##   cd    : délai minimal entre deux déclenchements du même son (s) : évite la bouillie
##   max   : nombre maximal d'instances simultanées de ce son
##   prio  : 0 (ambiance) .. 3 (vital : dégâts subis, boss) : qui est coupé en cas de saturation
##   bus   : SFX (positionné, passe par le compresseur) ou UI (jamais abaissé par les combats)
## `pos` : le son se place dans le champ stéréo selon sa position dans l'arène.

const ROOT: String = "res://assets/audio/sfx/"

const DEFS: Dictionary = {
	&"throw_rapid":
	{"n": 3, "vol": 0.0, "pitch": 0.05, "cd": 0.045, "max": 4, "prio": 1, "bus": &"SFX"},
	&"throw_heavy":
	{"n": 2, "vol": 1.5, "pitch": 0.03, "cd": 0.10, "max": 2, "prio": 2, "bus": &"SFX"},
	&"throw_multi":
	{"n": 2, "vol": 0.0, "pitch": 0.05, "cd": 0.08, "max": 3, "prio": 1, "bus": &"SFX"},
	&"throw_pierce":
	{"n": 2, "vol": 0.0, "pitch": 0.04, "cd": 0.08, "max": 3, "prio": 1, "bus": &"SFX"},
	&"hit_rapid":
	{"n": 3, "vol": -1.0, "pitch": 0.07, "cd": 0.035, "max": 5, "prio": 1, "bus": &"SFX"},
	&"hit_heavy":
	{"n": 2, "vol": 1.0, "pitch": 0.04, "cd": 0.06, "max": 3, "prio": 2, "bus": &"SFX"},
	&"hit_multi":
	{"n": 2, "vol": -2.0, "pitch": 0.07, "cd": 0.035, "max": 4, "prio": 1, "bus": &"SFX"},
	&"hit_pierce":
	{"n": 2, "vol": -1.0, "pitch": 0.05, "cd": 0.05, "max": 3, "prio": 1, "bus": &"SFX"},
	&"mat_shell":
	{"n": 2, "vol": -3.0, "pitch": 0.08, "cd": 0.05, "max": 3, "prio": 0, "bus": &"SFX"},
	&"mat_squish":
	{"n": 2, "vol": -3.0, "pitch": 0.08, "cd": 0.05, "max": 3, "prio": 0, "bus": &"SFX"},
	&"mat_hollow":
	{"n": 2, "vol": -3.0, "pitch": 0.06, "cd": 0.05, "max": 3, "prio": 0, "bus": &"SFX"},
	&"mat_bubble":
	{"n": 2, "vol": -3.0, "pitch": 0.08, "cd": 0.05, "max": 3, "prio": 0, "bus": &"SFX"},
	&"mat_kraken":
	{"n": 2, "vol": -2.0, "pitch": 0.05, "cd": 0.08, "max": 2, "prio": 1, "bus": &"SFX"},
	&"die_shell":
	{"n": 2, "vol": 0.0, "pitch": 0.07, "cd": 0.06, "max": 4, "prio": 2, "bus": &"SFX"},
	&"die_squish":
	{"n": 2, "vol": 0.0, "pitch": 0.07, "cd": 0.06, "max": 4, "prio": 2, "bus": &"SFX"},
	&"die_hollow":
	{"n": 2, "vol": 0.0, "pitch": 0.05, "cd": 0.06, "max": 3, "prio": 2, "bus": &"SFX"},
	&"die_bubble":
	{"n": 2, "vol": 0.0, "pitch": 0.07, "cd": 0.06, "max": 4, "prio": 2, "bus": &"SFX"},
	&"die_kraken":
	{"n": 1, "vol": 2.0, "pitch": 0.0, "cd": 1.0, "max": 1, "prio": 3, "bus": &"SFX"},
	&"splash_heavy":
	{"n": 2, "vol": 1.0, "pitch": 0.04, "cd": 0.12, "max": 2, "prio": 3, "bus": &"SFX"},
	&"boss_slam": {"n": 1, "vol": 1.0, "pitch": 0.0, "cd": 0.5, "max": 1, "prio": 3, "bus": &"SFX"},
	&"boss_roar": {"n": 1, "vol": 0.0, "pitch": 0.0, "cd": 0.5, "max": 1, "prio": 3, "bus": &"SFX"},
	&"boss_warning":
	{"n": 1, "vol": 0.0, "pitch": 0.0, "cd": 1.0, "max": 1, "prio": 3, "bus": &"UI"},
	&"boss_charge":
	{"n": 1, "vol": 0.0, "pitch": 0.0, "cd": 0.5, "max": 1, "prio": 3, "bus": &"SFX"},
	&"boss_phase":
	{"n": 1, "vol": 0.0, "pitch": 0.0, "cd": 0.5, "max": 1, "prio": 3, "bus": &"SFX"},
	&"boss_defeated":
	{"n": 1, "vol": 0.0, "pitch": 0.0, "cd": 1.0, "max": 1, "prio": 3, "bus": &"UI"},
	&"enemy_spawn":
	{"n": 3, "vol": -3.0, "pitch": 0.10, "cd": 0.12, "max": 3, "prio": 0, "bus": &"SFX"},
	&"enemy_windup":
	{"n": 2, "vol": -2.0, "pitch": 0.08, "cd": 0.25, "max": 2, "prio": 0, "bus": &"SFX"},
	&"combat_activate":
	{"n": 1, "vol": -2.0, "pitch": 0.03, "cd": 0.45, "max": 1, "prio": 1, "bus": &"SFX"},
	&"coin_spawn":
	{"n": 3, "vol": -4.0, "pitch": 0.04, "cd": 0.06, "max": 3, "prio": 0, "bus": &"SFX"},
	&"coin_get": {"n": 8, "vol": -1.0, "pitch": 0.0, "cd": 0.03, "max": 4, "prio": 1, "bus": &"UI"},
	&"multi_kill": {"n": 1, "vol": 0.0, "pitch": 0.0, "cd": 1.0, "max": 1, "prio": 3, "bus": &"UI"},
	&"wave_start": {"n": 1, "vol": 0.0, "pitch": 0.0, "cd": 1.0, "max": 1, "prio": 3, "bus": &"UI"},
	&"wave_clear": {"n": 1, "vol": 0.0, "pitch": 0.0, "cd": 1.0, "max": 1, "prio": 3, "bus": &"UI"},
	&"game_over": {"n": 1, "vol": 0.0, "pitch": 0.0, "cd": 1.0, "max": 1, "prio": 3, "bus": &"UI"},
	&"turret_upgrade":
	{"n": 1, "vol": 0.0, "pitch": 0.02, "cd": 0.2, "max": 2, "prio": 3, "bus": &"UI"},
	&"player_hurt":
	{"n": 3, "vol": 1.0, "pitch": 0.05, "cd": 0.15, "max": 1, "prio": 3, "bus": &"UI"},
	&"player_death":
	{"n": 1, "vol": 0.0, "pitch": 0.0, "cd": 1.0, "max": 1, "prio": 3, "bus": &"UI"},
	&"step_sand":
	{"n": 4, "vol": -5.0, "pitch": 0.08, "cd": 0.07, "max": 2, "prio": 0, "bus": &"SFX"},
	&"ui_tap": {"n": 1, "vol": 0.0, "pitch": 0.03, "cd": 0.03, "max": 3, "prio": 3, "bus": &"UI"},
	&"ui_confirm":
	{"n": 1, "vol": 0.0, "pitch": 0.0, "cd": 0.05, "max": 2, "prio": 3, "bus": &"UI"},
	&"ui_denied": {"n": 1, "vol": 0.0, "pitch": 0.0, "cd": 0.1, "max": 1, "prio": 3, "bus": &"UI"},
	&"ui_open": {"n": 1, "vol": 0.0, "pitch": 0.0, "cd": 0.1, "max": 1, "prio": 3, "bus": &"UI"},
	&"ui_close": {"n": 1, "vol": 0.0, "pitch": 0.0, "cd": 0.1, "max": 1, "prio": 3, "bus": &"UI"},
	&"ui_buy": {"n": 1, "vol": 0.0, "pitch": 0.0, "cd": 0.1, "max": 1, "prio": 3, "bus": &"UI"},
	&"ui_toggle":
	{"n": 1, "vol": 0.0, "pitch": 0.02, "cd": 0.05, "max": 2, "prio": 3, "bus": &"UI"},
}


static func has(sound: StringName) -> bool:
	return DEFS.has(sound)


static func def(sound: StringName) -> Dictionary:
	return DEFS.get(sound, {}) as Dictionary


static func path(sound: StringName, variant: int) -> String:
	return "%s%s_%d.wav" % [ROOT, String(sound), variant]
