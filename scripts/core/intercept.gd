class_name Intercept
extends RefCounted
## Visée prédictive : point d'interception d'un projectile de vitesse constante
## sur une cible à vitesse constante. Borné si l'interception est impossible.

const MAX_LEAD_TIME: float = 1.5


static func aim_point(
	shooter: Vector2, target: Vector2, target_vel: Vector2, speed: float
) -> Vector2:
	var d: Vector2 = target - shooter
	var a: float = target_vel.dot(target_vel) - speed * speed
	var b: float = 2.0 * d.dot(target_vel)
	var c: float = d.dot(d)
	var t: float = -1.0
	if absf(a) < 0.000001:
		if absf(b) > 0.000001:
			t = -c / b
	else:
		var disc: float = b * b - 4.0 * a * c
		if disc >= 0.0:
			var root: float = sqrt(disc)
			var t1: float = (-b - root) / (2.0 * a)
			var t2: float = (-b + root) / (2.0 * a)
			t = INF
			if t1 > 0.0:
				t = minf(t, t1)
			if t2 > 0.0:
				t = minf(t, t2)
			if is_inf(t):
				t = -1.0
	if t <= 0.0:
		return target
	return target + target_vel * minf(t, MAX_LEAD_TIME)
