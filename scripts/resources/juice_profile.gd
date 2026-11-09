class_name JuiceProfile
extends Resource
## « Jus » d'un type d'ennemi (phase 5) : animation PROCÉDURALE ajoutée par-dessus les clips
## Blender (écrasement/étirement, rebonds, balancement, anticipation, réaction aux impacts,
## apparition et mort). Données pures : on règle la personnalité d'un ennemi sans toucher au code.

enum DeathStyle { POP, FLATTEN, SPIN, BOSS }

@export_group("Déplacement")
## Hauteur des rebonds en courant (m) et fréquence (rebonds par seconde à vitesse nominale).
@export var hop_height: float = 0.10
@export var hop_hz: float = 3.6
## Hauteur de flottement permanente (m) : poisson-globe, kraken.
@export var float_height: float = 0.0
## Écrasement/étirement lié aux rebonds (0 = rigide).
@export_range(0.0, 0.6, 0.01) var squash: float = 0.14
## Balancement latéral (roulis, degrés) et inclinaison vers l'avant (degrés) en courant.
@export var sway_deg: float = 7.0
@export var lean_deg: float = 6.0

@export_group("Repos")
@export_range(0.0, 0.2, 0.005) var breath: float = 0.03
@export var breath_hz: float = 0.9

@export_group("Apparition")
@export_range(0.0, 1.0, 0.01) var spawn_overshoot: float = 0.45
@export var spawn_hop: float = 0.55
@export var spawn_spin_turns: float = 0.5

@export_group("Attaque (anticipation)")
## Accroupissement avant le coup (0 = aucun) et élan vers l'avant (m).
@export_range(0.0, 0.6, 0.01) var windup_crouch: float = 0.22
@export var lunge_distance: float = 0.28
@export_range(0.0, 0.5, 0.01) var lunge_stretch: float = 0.16

@export_group("Impacts reçus")
## Écrasement à l'impact et inclinaison (degrés) dans le sens du coup.
@export_range(0.0, 0.8, 0.01) var hit_squash: float = 0.30
@export var hit_tilt_deg: float = 22.0

@export_group("Mort")
@export var death_style: DeathStyle = DeathStyle.POP
@export var death_spin_turns: float = 1.5
@export var death_hop: float = 0.7
