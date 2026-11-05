class_name GameConfig
extends Resource
## Paramètres globaux de la partie. TOUTES ces valeurs sont des hypothèses de départ,
## à régler au toucher (plan §5.8). Modifiables dans l'inspecteur sans toucher au code.

@export_group("Arène")
@export var arena_radius: float = 9.0
@export var turret_ring_radius: float = 10.4

@export_group("Joueur")
@export var player_hp: float = 100.0
@export var player_speed: float = 5.0
@export var player_radius: float = 0.45
@export var accel_time: float = 0.12
@export var decel_time: float = 0.10
@export var turn_speed: float = 14.0
@export var invuln_time: float = 0.6

@export_group("Contact et fenêtre de combat")
@export var window_duration: float = 2.0
@export var activation_cooldown: float = 0.5
## Anneau de déclenchement = rayon joueur + rayon ennemi + tolérance.
@export var contact_tolerance: float = 0.45
@export var contact_rearm: float = 0.4

@export_group("Commandes")
@export var joystick_deadzone: float = 0.15
@export var joystick_radius_px: float = 150.0
## Fraction de la hauteur d'écran au-dessus de laquelle le joystick ne démarre pas.
@export var joystick_zone_top: float = 0.45

@export_group("Ennemis")
@export var enemy_cap: int = 60
@export var spawn_invuln: float = 0.5
## Marge au-delà de la portée d'attaque dans laquelle un coup en cours d'armement porte encore.
@export var attack_leeway: float = 0.25
@export var spawn_min_player_dist: float = 5.0
@export var stagger_time: float = 0.2
@export var knockback_speed: float = 3.0
@export var death_time: float = 0.25

@export_group("Haches")
@export var axe_pool_size: int = 128
@export var axe_height: float = 1.1

@export_group("Tourelles")
@export var retarget_interval: float = 0.1
@export var target_hold_time: float = 0.8
@export var switch_margin: float = 0.25
@export var fire_tolerance_deg: float = 5.0
