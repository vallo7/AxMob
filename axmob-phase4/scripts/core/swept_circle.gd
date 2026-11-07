class_name SweptCircle
extends RefCounted
## Collision par balayage : un cercle (rayon `radius`) qui se déplace de a vers b
## touche-t-il un cercle fixe ? Aucun effet tunnel, quelle que soit la vitesse.


static func hits(a: Vector2, b: Vector2, radius: float, center: Vector2, c_radius: float) -> bool:
	var ab: Vector2 = b - a
	var len2: float = ab.length_squared()
	var t: float = 0.0
	if len2 > 0.000000001:
		t = clampf((center - a).dot(ab) / len2, 0.0, 1.0)
	var closest: Vector2 = a + ab * t
	var reach: float = radius + c_radius
	return closest.distance_squared_to(center) <= reach * reach
