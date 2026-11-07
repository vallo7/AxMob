class_name SpatialGrid
extends RefCounted
## Grille spatiale sur le plan XZ, reconstruite à chaque tick en O(n).
## Toutes les requêtes de proximité passent par elle (plan §2.3).
## Implémentation : listes chaînées par cellule (_head/_next), sans allocation
## par cellule. Attention : les PackedArray sont copiés à la lecture en GDScript,
## d'où l'absence de tableau par cellule.

var _inv: float
var _head: Dictionary = {}  # clé de cellule -> premier id (int)
var _next: PackedInt32Array = PackedInt32Array()
var _positions: PackedVector2Array = PackedVector2Array()


func _init(cell_size: float = 2.0) -> void:
	_inv = 1.0 / cell_size


static func _key(cx: int, cy: int) -> int:
	return (cx + 32768) * 65536 + (cy + 32768)


func clear() -> void:
	_head.clear()
	_next.resize(0)
	_positions.resize(0)


func insert(id: int, pos: Vector2) -> void:
	if id >= _positions.size():
		_positions.resize(id + 1)
		_next.resize(id + 1)
	_positions[id] = pos
	var k: int = _key(floori(pos.x * _inv), floori(pos.y * _inv))
	_next[id] = _head.get(k, -1)
	_head[k] = id


## Retourne les ids dont la position est à au plus `radius` de `center`.
func query_circle(center: Vector2, radius: float) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	var x0: int = floori((center.x - radius) * _inv)
	var x1: int = floori((center.x + radius) * _inv)
	var y0: int = floori((center.y - radius) * _inv)
	var y1: int = floori((center.y + radius) * _inv)
	var r2: float = radius * radius
	for cx: int in range(x0, x1 + 1):
		for cy: int in range(y0, y1 + 1):
			var id: int = _head.get(_key(cx, cy), -1)
			while id != -1:
				if _positions[id].distance_squared_to(center) <= r2:
					out.append(id)
				id = _next[id]
	return out
