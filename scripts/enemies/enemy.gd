class_name Enemy
extends RefCounted
## État d'un ennemi (un emplacement du pool). Aucune physique moteur : tout est calculé.

enum State { INACTIVE, SPAWNING, CHASE, WINDUP, ATTACK, RECOVER, STAGGER, DYING }

var id: int
var state: State = State.INACTIVE
var state_time: float = 0.0
var data: EnemyData
var pos: Vector2 = Vector2.ZERO
var vel: Vector2 = Vector2.ZERO
var facing: Vector2 = Vector2(0.0, 1.0)
var health: HealthComponent = HealthComponent.new()
var damage_mult: float = 1.0
var flash_left: float = 0.0
var contact_rearm_at: float = 0.0
var reward_granted: bool = false
var visual: MeshInstance3D


func _init(p_id: int) -> void:
	id = p_id


func is_active() -> bool:
	return state != State.INACTIVE


## Touchable par les haches et ciblable par les tourelles.
func is_hittable() -> bool:
	return state != State.INACTIVE and state != State.SPAWNING and state != State.DYING


func radius() -> float:
	return data.radius if data != null else 0.0
