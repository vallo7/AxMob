class_name Axe
extends RefCounted
## État d'une hache (un emplacement du pool).

var active: bool = false
## Indice de l'emplacement dans le pool (stable : sert aussi d'indice d'instance de flux).
var slot: int = 0
var pos: Vector2 = Vector2.ZERO
var dir: Vector2 = Vector2.ZERO
var speed: float = 0.0
var acceleration: float = 0.0
var max_speed: float = 0.0
var radius: float = 0.3
var damage: float = 0.0
var category: int = 0
var life_left: float = 0.0
var pierce_left: int = 0
var spin: float = 0.0
var spin_speed: float = 0.0
var born: float = 0.0
var hit_ids: PackedInt32Array = PackedInt32Array()
## Support du modèle (position, rotation, échelle) ; ses enfants sont les modèles par catégorie,
## créés à la demande : un seul est visible à la fois.
var visual: Node3D
var models: Dictionary = {}  # nom de modèle -> Node3D
var shown: Node3D
## Impact de zone (m) : rayon, décroissance, multiplicateur de dégâts, repoussement.
var splash_radius: float = 0.0
var splash_falloff: float = 0.45
var splash_mult: float = 0.8
var splash_knockback: float = 6.0
## Style de vol (animation, traînée) : la ProjectileData de la catégorie.
var style: ProjectileData
## Phase aléatoire de l'oscillation ; impulsion d'échelle après chaque impact (0..1).
var wobble_phase: float = 0.0
var hit_kick: float = 0.0
