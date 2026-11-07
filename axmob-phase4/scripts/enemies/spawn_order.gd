class_name SpawnOrder
extends RefCounted
## Un ennemi à faire apparaître : son type et son niveau de puissance.

var data: EnemyData
var level: int = 1


func _init(p_data: EnemyData, p_level: int) -> void:
	data = p_data
	level = p_level
