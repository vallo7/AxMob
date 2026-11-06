class_name GameConfig
extends Resource
## Paramètres globaux de la partie. TOUTES ces valeurs sont des hypothèses de départ,
## à régler au toucher (plan §5.8). Modifiables dans l'inspecteur sans toucher au code.

## Comportement du jeu pendant que le panneau d'amélioration est ouvert.
enum UpgradePause { FULL_STOP, SLOW, NONE }

@export_group("Arène")
## Rayon de l'arène : LE réglage de taille. L'anneau de tourelles et le cadrage de la caméra en
## sont déduits (voir ring_radius() et camera_visible_width()). Plus il est grand, plus les
## personnages paraissent petits à l'écran (la caméra garde toute l'arène dans la largeur).
@export var arena_radius: float = 13.0
## Distance des tourelles au-delà du bord de l'arène.
@export var turret_ring_offset: float = 1.4
## Marge de sécurité (en unités) au-delà de l'anneau de tourelles. Le test de cadrage mesure
## le pire cas (joueur au bord, caméra décalée) : à 0.4, il reste ~4 % de la demi-largeur.
@export var camera_margin: float = 0.4

@export_group("Joueur")
@export var player_hp: float = 100.0
@export var player_speed: float = 6.5
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
@export var spawn_min_player_dist: float = 7.0
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

@export_group("Améliorations en partie")
## Comportement du jeu pendant que le panneau d'amélioration est ouvert.
@export var upgrade_pause: UpgradePause = UpgradePause.FULL_STOP
## Échelle de temps en mode SLOW.
@export var upgrade_slow_scale: float = 0.25


## Rayon de l'anneau où sont posées les tourelles.
func ring_radius() -> float:
	return arena_radius + turret_ring_offset


## Largeur visible (en unités, au niveau du sol) pour que toute l'arène et ses tourelles tiennent.
func camera_visible_width() -> float:
	return 2.0 * (ring_radius() + camera_margin)


## Facteur de temps de simulation selon le mode de pause des améliorations.
func upgrade_time_scale() -> float:
	match upgrade_pause:
		UpgradePause.FULL_STOP:
			return 0.0
		UpgradePause.SLOW:
			return upgrade_slow_scale
	return 1.0
