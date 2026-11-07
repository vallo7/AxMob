class_name EnemyData
extends Resource
## Type d'ennemi. Le niveau (puissance) est un axe distinct, appliqué par des multiplicateurs
## (voir EnemyLevels et BalanceConfig).

@export var id: StringName = &"basic"
@export var display_name: String = "Basic"
@export var max_hp: float = 30.0
@export var speed: float = 2.6
@export var max_accel: float = 12.0
@export var damage: float = 8.0
@export var radius: float = 0.4
@export var height: float = 1.0
## Distance, au-delà des rayons, à laquelle l'ennemi commence son attaque (anneau de dégâts).
@export var attack_range: float = 0.25
@export var windup_time: float = 0.35
@export var recover_time: float = 0.7
## 1 = interrompu par un impact ; < 0.5 = ne se laisse pas interrompre (lourds).
@export var stagger_scale: float = 1.0
@export var reward: int = 1
@export var wave_cost: float = 1.0
@export var unlock_wave: int = 1
@export var spawn_weight: float = 1.0
## Bonus de ciblage (élites, boss).
@export var target_priority: float = 0.0
## Barre de vie toujours visible (élites, boss) ; sinon elle n'apparaît qu'après un impact.
@export var bar_always: bool = false
## Durée de l'animation de mort ; 0 = valeur de GameConfig.
@export var death_time: float = 0.0
## Multiplicateur de dégâts par catégorie de hache (index = ProjectileData.Category).
@export var resistances: PackedFloat32Array = PackedFloat32Array([1.0, 1.0, 1.0, 1.0])
@export var color: Color = Color(0.62, 0.25, 0.55)
## Modèle glTF (assets/models/<nom>.glb). Vide = « enemy_<id> ».
@export var model_name: String = ""
## Agrandissement du modèle à l'écran (lisibilité en vue de dessus) ;
## les rayons de collision ne changent pas.
@export var visual_scale: float = 1.0


func resistance(category: int) -> float:
	if category < 0 or category >= resistances.size():
		return 1.0
	return resistances[category]


func model() -> String:
	return model_name if model_name != "" else "enemy_%s" % id
