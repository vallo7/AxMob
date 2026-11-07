class_name TurretData
extends Resource
## Catégorie de tourelle. Les champs de base sont le niveau 1 ; les niveaux 2..max_level sont
## déduits des courbes ci-dessous (TurretLeveling.build) sauf si `levels` est renseigné.
## Toutes les valeurs sont des hypothèses de départ, à régler au toucher.

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
## Modèle glTF (assets/models/<nom>.glb). Vide = « turret_<id> ».
@export var model_name: String = ""

@export_group("Niveaux")
@export var max_level: int = 10
## Multiplicateurs appliqués à chaque passage de niveau (compose : base × croissance^(niveau-1)).
@export var damage_growth: float = 1.17
@export var rate_growth: float = 1.06
@export var range_growth: float = 1.025
@export var rotation_growth: float = 1.04
@export var projectile_speed_growth: float = 1.01
## Nombre de haches / de perforations par niveau (index 0 = niveau 1). Vide = valeur de base.
@export var axe_count_steps: PackedInt32Array = PackedInt32Array()
@export var pierce_steps: PackedInt32Array = PackedInt32Array()
## Éventail supplémentaire par hache au-delà du nombre de base.
@export var fan_per_extra_deg: float = 6.0
## Niveaux où le visuel change de palier (niveaux 1, 4, 7, 10 par défaut).
@export var tier_levels: PackedInt32Array = PackedInt32Array([1, 4, 7, 10])
## Facteur de coût propre à la catégorie (× BalanceConfig.upgrade_cost_base).
@export var cost_scale: float = 1.0
## Table écrite à la main : si non vide, elle remplace entièrement les courbes.
@export var levels: Array[TurretLevelData] = []


func model() -> String:
	return model_name if model_name != "" else "turret_%s" % id
