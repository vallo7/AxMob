class_name HapticPatterns
extends RefCounted
## Table des motifs de vibration du jeu : un seul endroit pour les régler.
## Impulsion = Vector3(durée ms, amplitude 0..1, pause ms après). L'amplitude finale est
## multipliée par l'échelle de l'événement, l'intensité générale et le niveau du joueur.
##
## Principe : les événements fréquents (contact, élimination, tir lourd) sont très brefs et
## limités ; les événements rares et importants (dégâts, mort, boss) sont nets et prioritaires.


static func defaults() -> Dictionary:
	var out: Dictionary = {}
	for p: HapticPattern in _all():
		out[p.id] = p
	return out


static func _all() -> Array[HapticPattern]:
	var low: HapticPattern.Priority = HapticPattern.Priority.LOW
	var normal: HapticPattern.Priority = HapticPattern.Priority.NORMAL
	var high: HapticPattern.Priority = HapticPattern.Priority.HIGH
	var critical: HapticPattern.Priority = HapticPattern.Priority.CRITICAL
	return [
		# Interface (phase 4 : impulsions >= 28 ms et amplitude >= 0,55, sinon beaucoup de moteurs
		# ne les rendent pas : c'est la cause probable du « rien ne vibre » de la phase 3)
		_p(&"ui_tap", low, 60, [Vector3(30, 0.6, 0)]),
		_p(&"ui_confirm", normal, 120, [Vector3(30, 0.7, 45), Vector3(45, 0.95, 0)]),
		_p(&"ui_denied", normal, 150, [Vector3(40, 0.7, 70), Vector3(40, 0.7, 0)]),
		_p(&"back_hint", low, 300, [Vector3(35, 0.6, 0)]),
		# Combat (fréquents : brefs, limités par le plafond cumulé)
		_p(&"contact", low, 140, [Vector3(28, 0.55, 0)]),
		_p(&"kill", low, 100, [Vector3(25, 0.5, 0)]),
		_p(&"multi_kill", normal, 300, [Vector3(45, 0.85, 40), Vector3(35, 0.65, 0)]),
		_p(&"heavy_shot", low, 200, [Vector3(30, 0.5, 0)]),
		# Le joueur est touché ou meurt
		_p(&"hurt_light", high, 120, [Vector3(60, 0.85, 0)]),
		_p(&"hurt_heavy", high, 120, [Vector3(90, 1.0, 50), Vector3(60, 0.8, 0)]),
		_p(
			&"death",
			critical,
			800,
			[
				Vector3(180, 1.0, 70),
				Vector3(140, 0.9, 70),
				Vector3(110, 0.7, 0),
			]
		),
		# Vagues
		_p(&"wave_start", normal, 400, [Vector3(40, 0.6, 0)]),
		_p(&"wave_clear", normal, 400, [Vector3(35, 0.6, 60), Vector3(35, 0.6, 0)]),
		# Boss
		_p(
			&"boss_warning",
			critical,
			1500,
			[Vector3(80, 0.8, 80), Vector3(80, 0.8, 80), Vector3(140, 1.0, 0)]
		),
		_p(&"boss_phase", high, 600, [Vector3(140, 1.0, 70), Vector3(90, 0.85, 0)]),
		_p(&"boss_slam", high, 250, [Vector3(100, 1.0, 0)]),
		_p(
			&"boss_defeated",
			critical,
			2000,
			[
				Vector3(60, 0.9, 50),
				Vector3(60, 0.9, 50),
				Vector3(90, 1.0, 60),
				Vector3(220, 0.8, 0),
			]
		),
	]


static func _p(
	id: StringName, priority: HapticPattern.Priority, cooldown_ms: int, pulses: Array[Vector3]
) -> HapticPattern:
	return HapticPattern.new(id, priority, cooldown_ms, pulses)
