class_name Axe
extends RefCounted
## État d'une hache (un emplacement du pool).

var active: bool = false
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
var visual: Node3D
