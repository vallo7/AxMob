class_name BossPhases
extends RefCounted
## Règles pures du boss (testables sans moteur) : phase selon les PV, capacités débloquées.


## Phase 1..N : 1 + nombre de seuils de PV franchis.
static func phase_for(hp_fraction: float, thresholds: PackedFloat32Array) -> int:
	var phase: int = 1
	for threshold: float in thresholds:
		if hp_fraction <= threshold:
			phase += 1
	return phase


static func can_charge(phase: int) -> bool:
	return phase >= 2


static func can_summon(phase: int) -> bool:
	return phase >= 3


## Les attaques s'accélèrent avec les phases (réduction du temps de récupération).
static func recover_scale(phase: int) -> float:
	return 1.0 - 0.18 * float(clampi(phase - 1, 0, 2))
