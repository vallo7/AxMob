class_name ContactDetector
extends Node
## Détecte les contacts joueur/ennemi par calcul (pas de collision moteur).
## Anneau de déclenchement = rayon joueur + rayon ennemi + tolérance : plus large que
## l'anneau de dégâts, donc frôler un ennemi active les tourelles sans forcément blesser.
## Filtre anti-répétition : un ennemi ne redéclenche qu'après `contact_rearm` secondes.

const MAX_ENEMY_RADIUS: float = 1.0

var _ctx: RunContext


func setup(ctx: RunContext) -> void:
	_ctx = ctx


func step() -> void:
	if not _ctx.player_alive:
		return
	var cfg: GameConfig = _ctx.config
	var reach: float = cfg.player_radius + MAX_ENEMY_RADIUS + cfg.contact_tolerance
	var contacts: int = 0
	for id: int in _ctx.grid.query_circle(_ctx.player_pos, reach):
		var e: Enemy = _ctx.enemies.slots[id]
		if not e.is_hittable() or _ctx.time < e.contact_rearm_at:
			continue
		var trigger: float = cfg.player_radius + e.data.radius + cfg.contact_tolerance
		if e.pos.distance_to(_ctx.player_pos) <= trigger:
			e.contact_rearm_at = _ctx.time + cfg.contact_rearm
			contacts += 1
	if contacts > 0:
		EventBus.contact_detected.emit(contacts, Planar.to3(_ctx.player_pos))
