class_name HapticsConfig
extends Resource
## Réglages globaux du retour haptique. Les motifs eux-mêmes sont dans HapticPatterns.
## Toutes les valeurs sont des hypothèses : seul un vrai téléphone dit si c'est agréable.

## Intensité générale (multipliée par le niveau choisi par le joueur : léger/normal/fort).
@export var master_intensity: float = 1.0
## Durée minimale d'une impulsion (ms) : en dessous, beaucoup de moteurs ne se sentent pas.
@export var min_pulse_ms: int = 15
## Amplitude minimale : une impulsion plus faible que ça est ignorée (inaudible, inutile).
@export var min_amplitude: float = 0.08
## Dégâts reçus qui donnent la vibration de dégâts maximale.
@export var damage_full_scale: float = 30.0
## En dessous de cette part de la vibration maximale, un coup reçu donne le motif « léger ».
@export var heavy_hit_fraction: float = 0.6
## Plafond de vibration cumulée (ms) sur 5 s : protège la batterie et le confort. Les motifs
## de priorité HIGH et CRITICAL (dégâts, mort, boss) ne sont jamais bloqués par ce plafond.
@export var budget_ms_per_5s: int = 1600
## Éliminations simultanées qui déclenchent le motif « multi-élimination », et fenêtre (ms).
@export var multi_kill_count: int = 3
@export var multi_kill_window_ms: int = 250
