class_name EnemyJuice
extends RefCounted
## Animation procédurale des ennemis (phase 5), appliquée au noeud racine du modèle par-dessus
## les clips Blender : rebonds avec écrasement/étirement, balancement, inclinaison, respiration,
## apparition élastique, anticipation + élan avant le coup, réaction aux impacts, mort stylée.
## Fonctions pures sur des valeurs : testables sans rendu. Résultat dans un `Out` réutilisé
## (aucune allocation par ennemi et par tick).


class Out:
	extends RefCounted
	## Décalage du modèle (x latéral, y hauteur, z avant = -Z), échelle, rotation (pitch, yaw, roll).
	var offset: Vector3 = Vector3.ZERO
	var scale: Vector3 = Vector3.ONE
	var rot: Vector3 = Vector3.ZERO
	## Échelle uniforme additionnelle (mort : gonfle puis disparaît).
	var uniform: float = 1.0

	func reset() -> void:
		offset = Vector3.ZERO
		scale = Vector3.ONE
		rot = Vector3.ZERO
		uniform = 1.0


static var _default: JuiceProfile = JuiceProfile.new()


## Fait avancer les phases (course, repos) d'un ennemi. À appeler une fois par tick.
static func advance(e: Enemy, j: JuiceProfile, nominal_speed: float, dt: float) -> void:
	var ratio: float = clampf(e.vel.length() / maxf(nominal_speed, 0.1), 0.0, 1.6)
	# Un rebond par demi-période de sin : la fréquence suit la vitesse réelle.
	e.juice_phase = fposmod(
		e.juice_phase + TAU * j.hop_hz * (0.35 + 0.65 * ratio) * 0.5 * dt, TAU * 8.0
	)
	e.idle_phase = fposmod(e.idle_phase + TAU * j.breath_hz * dt, TAU * 8.0)
	e.hit_kick = maxf(e.hit_kick - dt * 3.2, 0.0)


static func profile_of(e: Enemy) -> JuiceProfile:
	return e.data.juice if e.data != null and e.data.juice != null else _default


## Calcule la pose. `death_time` : durée totale de l'animation de mort ; `spawn_time` : durée
## d'apparition ; `windup_time` : durée de l'armement ; `nominal_speed` : vitesse de poursuite.
static func compute(
	e: Enemy, j: JuiceProfile, spawn_time: float, death_time: float, nominal_speed: float, out: Out
) -> void:
	out.reset()
	var ratio: float = clampf(e.vel.length() / maxf(nominal_speed, 0.1), 0.0, 1.4)
	var sy: float = 1.0
	var off: Vector3 = Vector3(0.0, j.float_height, 0.0)
	var rot: Vector3 = Vector3.ZERO
	match e.state:
		Enemy.State.SPAWNING:
			# Phase 7 : l'ennemi MONTE hors de l'eau ou du sable (le sol et la mer le masquent d'abord),
			# avec un léger dépassement puis un petit écrasement à l'arrivée. Dans le sable il
			# tremble d'abord (la butte se soulève), dans l'eau il ondule.
			var u: float = clampf(e.state_time / maxf(spawn_time, 0.01), 0.0, 1.0)
			var rise: float = ProjectileManager.ease_out_back(smoothstep(0.0, 0.85, u), 1.4)
			var depth: float = maxf(e.data.height, 0.6) * 1.15
			out.uniform = lerpf(0.82, 1.0, rise)
			off.y += -depth * (1.0 - rise) + j.spawn_hop * 0.5 * sin(u * PI) * u
			if not e.from_water:
				rot.z = sin(e.state_time * 46.0) * 0.12 * (1.0 - u)
				rot.x = cos(e.state_time * 39.0) * 0.08 * (1.0 - u)
			else:
				rot.z = sin(e.state_time * 14.0) * 0.1 * (1.0 - u)
			rot.y = (1.0 - u) * (1.0 - u) * TAU * j.spawn_spin_turns * 0.5
			sy = 1.0 - 0.16 * smoothstep(0.72, 0.92, u) * (1.0 - smoothstep(0.92, 1.0, u))
		Enemy.State.CHASE, Enemy.State.CHARGING:
			var hop: float = absf(sin(e.juice_phase))
			var k: float = clampf(ratio, 0.0, 1.0)
			off.y += hop * j.hop_height * k
			sy = 1.0 + j.squash * (hop - 0.4) * k
			rot.z = sin(e.juice_phase) * deg_to_rad(j.sway_deg) * k
			rot.x = -deg_to_rad(j.lean_deg) * k
			if ratio < 0.2:
				sy = 1.0 + j.breath * sin(e.idle_phase)
		Enemy.State.WINDUP, Enemy.State.CHARGE_WINDUP:
			var p: float = clampf(e.state_time / 0.35, 0.0, 1.0)
			if e.state == Enemy.State.WINDUP and e.data != null:
				p = clampf(e.state_time / maxf(e.data.windup_time, 0.05), 0.0, 1.0)
			if p < 0.6:
				var q: float = p / 0.6
				sy = 1.0 - j.windup_crouch * q * q
			else:
				var q2: float = (p - 0.6) / 0.4
				sy = (1.0 - j.windup_crouch) + (j.windup_crouch + j.lunge_stretch) * q2 * q2
				off.z = -j.lunge_distance * q2 * q2
			rot.z = sin(e.state_time * 55.0) * 0.05 * p
		Enemy.State.RECOVER, Enemy.State.ATTACK:
			# Retour élastique après le coup : l'élan se relâche en oscillant.
			var t: float = e.state_time
			var decay: float = exp(-7.0 * t)
			sy = 1.0 + j.lunge_stretch * decay * cos(20.0 * t)
			off.z = -j.lunge_distance * decay * 0.5
			sy += j.breath * sin(e.idle_phase) * (1.0 - decay)
		Enemy.State.STAGGER:
			rot.z += sin(e.state_time * 38.0) * deg_to_rad(9.0) * (1.0 - e.state_time * 3.0)
		Enemy.State.DYING:
			_death(e, j, death_time, out, off, rot)
			return
		_:
			sy = 1.0 + j.breath * sin(e.idle_phase)
	_apply_hit(e, j, out)
	out.offset = off
	out.rot = Vector3(out.rot.x + rot.x, rot.y, out.rot.z + rot.z)
	# Conservation du volume : si la hauteur s'écrase, la largeur s'étale.
	var wide: float = 1.0 / sqrt(maxf(sy, 0.2))
	out.scale = Vector3(wide * out.scale.x, sy * out.scale.y, wide * out.scale.z)


## Réaction à un impact : écrasement dans le sens du coup, inclinaison à l'opposé de l'origine.
static func _apply_hit(e: Enemy, j: JuiceProfile, out: Out) -> void:
	var k: float = e.hit_kick
	if k <= 0.001:
		return
	var kk: float = k * k * (3.0 - 2.0 * k)
	out.scale = Vector3(
		1.0 + 0.5 * j.hit_squash * kk, 1.0 - j.hit_squash * kk, 1.0 + 0.5 * j.hit_squash * kk
	)
	var f: float = e.hit_dir.dot(e.facing)
	var lateral: float = e.facing.cross(e.hit_dir)
	out.rot.x = -deg_to_rad(j.hit_tilt_deg) * kk * f
	out.rot.z = deg_to_rad(j.hit_tilt_deg) * kk * lateral


static func _death(
	e: Enemy, j: JuiceProfile, death_time: float, out: Out, off: Vector3, rot: Vector3
) -> void:
	var k: float = clampf(e.state_time / maxf(death_time, 0.01), 0.0, 1.0)
	var sy: float = 1.0
	match j.death_style:
		JuiceProfile.DeathStyle.POP:
			# Gonfle, saute en tournant, puis disparaît (éclatement : particules au même moment).
			out.uniform = (
				1.0 + 0.28 * sin(minf(k * 4.0, 1.0) * PI * 0.5) - 0.28 * smoothstep(0.6, 1.0, k)
			)
			off.y += j.death_hop * sin(k * PI)
			rot.y = k * TAU * j.death_spin_turns
			rot.z = sin(k * TAU * 2.0) * 0.25 * (1.0 - k)
		JuiceProfile.DeathStyle.FLATTEN:
			var f: float = 1.0 - pow(1.0 - minf(k * 2.5, 1.0), 3.0)
			sy = 1.0 - 0.8 * f
			out.scale = Vector3(1.0 + 0.5 * f, 1.0, 1.0 + 0.5 * f)
			off.y += 0.2 * sin(minf(k * 3.0, 1.0) * PI) * (1.0 - f)
		JuiceProfile.DeathStyle.SPIN:
			rot.y = k * k * TAU * j.death_spin_turns
			off.y += j.death_hop * (1.0 - pow(1.0 - k, 2.0))
			out.uniform = 1.0 - 0.6 * smoothstep(0.5, 1.0, k)
		JuiceProfile.DeathStyle.BOSS:
			rot.z = sin(e.state_time * 45.0) * 0.06 * (1.0 - k)
			rot.x = sin(e.state_time * 37.0) * 0.04 * (1.0 - k)
			off.y -= 0.8 * smoothstep(0.3, 1.0, k)
			sy = 1.0 - 0.25 * smoothstep(0.3, 1.0, k)
	out.offset = off
	out.rot = Vector3(rot.x, rot.y, rot.z)
	var wide: float = 1.0 / sqrt(maxf(sy, 0.2))
	out.scale = Vector3(wide * out.scale.x, sy * out.scale.y, wide * out.scale.z)
