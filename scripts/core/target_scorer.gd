class_name TargetScorer
extends RefCounted
## Score d'une cible pour une tourelle (plan §5.3). Plus haut = meilleur.
## Termes : proximité, achever (PV bas), menace (proche du joueur), priorité
## (élite/boss), moins une pénalité par tourelle déjà assignée.

const W_PROXIMITY: float = 1.0
const W_FINISH: float = 0.5
const W_THREAT: float = 0.8
const ASSIGNED_PENALTY: float = 0.6
const THREAT_RADIUS: float = 6.0


static func score(
	dist: float,
	turret_range: float,
	hp_fraction: float,
	player_dist: float,
	assigned: int,
	priority: float
) -> float:
	var proximity: float = 1.0 - clampf(dist / maxf(turret_range, 0.001), 0.0, 1.0)
	var finish: float = 1.0 - clampf(hp_fraction, 0.0, 1.0)
	var threat: float = 1.0 - clampf(player_dist / THREAT_RADIUS, 0.0, 1.0)
	return (
		W_PROXIMITY * proximity
		+ W_FINISH * finish
		+ W_THREAT * threat
		+ priority
		- ASSIGNED_PENALTY * float(assigned)
	)
