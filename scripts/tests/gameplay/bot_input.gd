class_name BotInput
extends RefCounted
## Bot minimal pour les tests, le simulateur et les captures : il FRÔLE les ennemis (c'est le
## geste central du jeu). Il s'approche de l'ennemi le plus proche jusqu'à l'anneau de
## déclenchement, tourne autour à cette distance, recule s'il entre dans l'anneau de dégâts,
## et revient vers le centre quand il n'y a personne. Ce n'est PAS un bon joueur.

## Écart de surface (m) sous lequel il recule / au-dessus duquel il s'approche.
const GRAZE_MIN: float = 0.28
const GRAZE_MAX: float = 0.5


static func compute(ctx: RunContext) -> Vector2:
	var nearest: Enemy = null
	var best_gap: float = INF
	for e: Enemy in ctx.enemies.slots:
		if not e.is_hittable():
			continue
		var gap: float = (
			e.pos.distance_to(ctx.player_pos) - ctx.config.player_radius - e.data.radius
		)
		if gap < best_gap:
			best_gap = gap
			nearest = e
	var to_center: Vector2 = (-ctx.player_pos).limit_length(1.0)
	if nearest == null:
		return to_center
	var to_enemy: Vector2 = (nearest.pos - ctx.player_pos).normalized()
	var tangent: Vector2 = Vector2(-to_enemy.y, to_enemy.x)
	if best_gap < GRAZE_MIN:
		return (-to_enemy * 0.9 + tangent * 0.5 + to_center * 0.3).limit_length(1.0)
	if best_gap > GRAZE_MAX:
		return to_enemy
	return (tangent * 0.9 + to_enemy * 0.15 + to_center * 0.1).limit_length(1.0)
