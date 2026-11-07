class_name Planar
extends RefCounted
## Conversions entre le plan de simulation XZ (Vector2) et l'espace 3D.
## Convention : yaw 0 = avant du noeud = -Z. direction(yaw) = (-sin, -cos) sur (x, z).


static func to3(v: Vector2, y: float = 0.0) -> Vector3:
	return Vector3(v.x, y, v.y)


static func to2(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


static func yaw_from_dir(d: Vector2) -> float:
	return atan2(-d.x, -d.y)


static func dir_from_yaw(yaw: float) -> Vector2:
	return Vector2(-sin(yaw), -cos(yaw))
