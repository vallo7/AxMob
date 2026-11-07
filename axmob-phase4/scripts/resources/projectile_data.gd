class_name ProjectileData
extends Resource
## Hache : comportement de vol et apparence. Les dégâts viennent de la tourelle.

enum Category { RAPID, HEAVY, MULTI, PIERCE }

@export var id: StringName = &"axe_light"
@export var category: Category = Category.RAPID
@export var speed: float = 22.0
## Accélération le long de la trajectoire (inertie de la hache lourde).
@export var acceleration: float = 0.0
@export var max_speed: float = 40.0
@export var radius: float = 0.3
@export var lifetime: float = 1.6
@export var spin_speed: float = 18.0
@export var visual_scale: float = 1.0
## Modèle glTF (assets/models/<nom>.glb). Vide = identifiant de la hache.
@export var model_name: String = ""


func model() -> String:
	return model_name if model_name != "" else str(id)
