class_name EnemyStore
extends RefCounted
## Pool d'ennemis de capacité fixe. L'indice d'un emplacement est son identifiant
## (aussi utilisé comme id dans la SpatialGrid).

var slots: Array[Enemy] = []


func _init(capacity: int) -> void:
	for i: int in capacity:
		slots.append(Enemy.new(i))


func capacity() -> int:
	return slots.size()


func find_free() -> int:
	for e: Enemy in slots:
		if e.state == Enemy.State.INACTIVE:
			return e.id
	return -1


## Ennemis vivants (hors DYING / INACTIVE) : ce qui compte pour la fin de vague.
func count_living() -> int:
	var n: int = 0
	for e: Enemy in slots:
		if e.state != Enemy.State.INACTIVE and e.state != Enemy.State.DYING:
			n += 1
	return n
