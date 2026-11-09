class_name TurretLevelData
extends Resource
## Statistiques d'une tourelle à un niveau donné. Générées depuis les courbes de TurretData
## (TurretLeveling.build) ou posées à la main dans TurretData.levels pour un contrôle total.

@export var level: int = 1
@export var damage: float = 8.0
@export var fire_rate: float = 3.0
@export var attack_range: float = 13.0
@export var rotation_speed: float = 6.0
## Multiplicateur appliqué à la vitesse de la hache de la catégorie.
@export var projectile_speed_mult: float = 1.0
@export var axe_count: int = 1
@export var fan_angle_deg: float = 0.0
@export var pierce: int = 0
## Palier visuel (0 = niveaux 1-3, 1 = 4-6, 2 = 7-9, 3 = niveau 10 par défaut).
@export var visual_tier: int = 0
## Rayon de l'impact de zone de la hache (m, 0 = aucune zone) ; croît avec le niveau.
@export var splash_radius: float = 0.0
