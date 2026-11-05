class_name TurretData
extends Resource
## Tourelle niveau 1. (TurretLevelData et les 10 niveaux arrivent en Phase 3.)

@export var id: StringName = &"rapid"
@export var display_name: String = "Rapid"
@export var projectile: ProjectileData
@export var damage: float = 8.0
## Salves par seconde.
@export var fire_rate: float = 3.0
@export var attack_range: float = 13.0
## Rad/s.
@export var rotation_speed: float = 6.0
## Nombre de haches par salve (éventail si > 1).
@export var axe_count: int = 1
@export var fan_angle_deg: float = 0.0
## Nombre d'ennemis traversés EN PLUS du premier impact.
@export var pierce: int = 0
@export var color: Color = Color(0.93, 0.47, 0.12)
