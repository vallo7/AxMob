class_name BotInput
extends RefCounted
## Bot minimal pour les tests et les captures : s'approche des ennemis pour les frôler,
## s'écarte quand ils sont trop près, revient vers le centre sinon.


static func compute(ctx: RunContext) -> Vector2:
	var nearest: Enemy = null
	var best: float = INF
	for e: Enemy in ctx.enemies.slots:
		if not e.is_hittable():
			continue
		var d: float = e.pos.distance_to(ctx.player_pos)
		if d < best:
			best = d
			nearest = e
	var to_center: Vector2 = (-ctx.player_pos).limit_length(1.0)
	if nearest == null:
		return to_center
	var to_enemy: Vector2 = (nearest.pos - ctx.player_pos).normalized()
	if best < 2.2:
		var tangent: Vector2 = Vector2(-to_enemy.y, to_enemy.x)
		return (-to_enemy * 0.8 + tangent * 0.6 + to_center * 0.4).limit_length(1.0)
	return to_enemy
