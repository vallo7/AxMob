class_name Obstacles
extends RefCounted
## Obstacles solides du décor (palmiers, rochers, château de sable, tourelles) : de simples
## cercles sur le plan XZ. Le joueur et les ennemis glissent autour ; les haches passent au-dessus
## (elles volent à hauteur de ceinture, le décor solide est mince ou bas). Fonctions pures.

var centers: PackedVector2Array = PackedVector2Array()
var radii: PackedFloat32Array = PackedFloat32Array()


func add(center: Vector2, radius: float) -> void:
	centers.append(center)
	radii.append(radius)


func count() -> int:
	return centers.size()


func clear() -> void:
	centers.clear()
	radii.clear()


## Repousse un corps de rayon `body_radius` hors de tous les obstacles (le long de la normale).
func push_out(pos: Vector2, body_radius: float) -> Vector2:
	var p: Vector2 = pos
	for i: int in centers.size():
		var delta: Vector2 = p - centers[i]
		var min_d: float = radii[i] + body_radius
		var d_sq: float = delta.length_squared()
		if d_sq >= min_d * min_d:
			continue
		var d: float = sqrt(d_sq)
		if d < 0.0001:
			delta = Vector2(1.0, 0.0)
			d = 1.0
		p = centers[i] + delta / d * min_d
	return p


## Vrai si un corps de rayon `body_radius` (+ marge) chevauche un obstacle.
func overlaps(pos: Vector2, body_radius: float, margin: float = 0.0) -> bool:
	for i: int in centers.size():
		var min_d: float = radii[i] + body_radius + margin
		if pos.distance_squared_to(centers[i]) < min_d * min_d:
			return true
	return false
