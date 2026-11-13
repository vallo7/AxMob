class_name GameConfig
extends Resource
## Paramètres globaux de la partie. TOUTES ces valeurs sont des hypothèses de départ,
## à régler au toucher (plan §5.8). Modifiables dans l'inspecteur sans toucher au code.

## Comportement du jeu pendant que le panneau d'amélioration est ouvert.
enum UpgradePause { FULL_STOP, SLOW, NONE }

@export_group("Île et caméra")
## Rayon MOYEN de la zone jouable (joueur), en mètres. Toute l'île est l'arène : le contour réel de
## la
## plage (IslandShape) fixe la limite, il n'y a plus de bordure artificielle. L'île, la mer et le
## décor sont mis à l'échelle de ce rayon (voir Arena).
@export var arena_radius: float = 16.2
## Rayon (m) de l'anneau où sont posées les quatre tourelles (à l'intérieur de l'île).
@export var turret_ring_radius: float = 9.8
## Largeur du monde visible (m, au niveau du point visé). Plus elle est petite, plus les personnages
## paraissent grands ; la caméra suit le joueur (FeelConfig.follow_factor).
@export var view_width: float = 22.0
## Rayon de collision des tourelles (m) : le joueur et les ennemis les contournent.
@export var turret_collision_radius: float = 1.15

@export_group("Joueur")
@export var player_hp: float = 100.0
@export var player_speed: float = 6.5
@export var player_radius: float = 0.5
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
## Part des apparitions qui sortent du SABLE (le reste sort de l'EAU, sur le rivage).
@export_range(0.0, 1.0, 0.05) var sand_spawn_chance: float = 0.4
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
	return turret_ring_radius


## Largeur visible (en mètres, au niveau du point visé).
func camera_visible_width() -> float:
	return view_width


## Échelle monde / modèle de l'île, déduite du rayon jouable.
func island_scale() -> float:
	return IslandShape.scale_for_play_radius(arena_radius)


## Facteur de temps de simulation selon le mode de pause des améliorations.
func upgrade_time_scale() -> float:
	match upgrade_pause:
		UpgradePause.FULL_STOP:
			return 0.0
		UpgradePause.SLOW:
			return upgrade_slow_scale
	return 1.0
