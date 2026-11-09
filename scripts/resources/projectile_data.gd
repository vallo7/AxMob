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

@export_group("Zone (impact de zone)")
## Rayon de l'explosion à l'impact (m, avant bonus de niveau). 0 = pas de zone.
@export var splash_radius: float = 0.0
## Part des dégâts de la hache infligée au CENTRE de la zone aux ennemis voisins (le touché en
## direct prend les dégâts pleins).
@export_range(0.0, 1.5, 0.05) var splash_damage_mult: float = 0.8
## Part de ces dégâts encore appliquée au bord de la zone (décroissance linéaire).
@export_range(0.0, 1.0, 0.05) var splash_falloff: float = 0.45
## Vitesse de repoussement au centre de la zone (m/s, avant résistance de l'ennemi).
@export var splash_knockback: float = 6.0

@export_group("Animation du vol (phase 5)")
## Oscillation (inclinaison) de la hache en vol, degrés et vitesse (rad/s).
@export var wobble_deg: float = 10.0
@export var wobble_speed: float = 14.0
## Petit saut après le lancer : hauteur (m) et durée (s). 0 = vol à plat.
@export var arc_height: float = 0.0
@export var arc_time: float = 0.45
## Apparition « pop » à la bouche : durée (s) et dépassement (rebond élastique).
@export var pop_time: float = 0.12
@export var pop_overshoot: float = 0.35
## Traînée lumineuse (flux) : couleur, longueur (m) et largeur (m).
@export var trail_color: Color = Color(1.0, 0.62, 0.2, 0.85)
@export var trail_length: float = 2.2
@export var trail_width: float = 0.34
## Couleur des étincelles à l'impact.
@export var impact_color: Color = Color(1.0, 0.8, 0.35)


func model() -> String:
	return model_name if model_name != "" else str(id)
