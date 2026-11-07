class_name Steering
extends RefCounted
## Briques de pilotage sur le plan XZ (plan §2.1 : steering maison, sans physique moteur).


## Rejoint la vitesse désirée avec une accélération maximale (virage et freinage limités).
static func approach(vel: Vector2, desired: Vector2, max_accel: float, dt: float) -> Vector2:
	var dv: Vector2 = desired - vel
	var max_dv: float = max_accel * dt
	if dv.length() <= max_dv:
		return desired
	return vel + dv.normalized() * max_dv


## Comme approach, mais avec un taux de freinage distinct (accélération / décélération du joueur).
static func approach_asymmetric(
	vel: Vector2, desired: Vector2, accel: float, decel: float, dt: float
) -> Vector2:
	var rate: float = decel if desired.length() < vel.length() else accel
	return approach(vel, desired, rate, dt)


## Répulsion radiale qui grandit quand on s'approche du bord (de 0 à `strength`).
static func edge_push(pos: Vector2, arena_radius: float, margin: float, strength: float) -> Vector2:
	var d: float = pos.length()
	var start: float = arena_radius - margin
	if d <= start or d < 0.0001:
		return Vector2.ZERO
	return -pos / d * clampf((d - start) / margin, 0.0, 1.0) * strength


## Garde un corps de rayon `body_radius` dans l'arène circulaire.
static func clamp_to_arena(pos: Vector2, body_radius: float, arena_radius: float) -> Vector2:
	var limit: float = maxf(arena_radius - body_radius, 0.0)
	return pos.limit_length(limit)
