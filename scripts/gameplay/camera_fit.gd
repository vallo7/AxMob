class_name CameraFit
extends RefCounted
## Calcule la distance de la caméra pour que l'arène ET ses quatre tourelles tiennent dans la
## largeur de l'écran, QUEL QUE SOIT l'angle de vue. Avec la perspective, plus la caméra est en
## plongée oblique, plus le bas de l'arène (proche) paraît large : la largeur « fixe » de la phase 4
## n'était exacte que pour une vue presque verticale. Fonction pure (testable sans moteur).
##
## Pire cas : le joueur au bord de l'arène (la caméra le suit un peu), points = pieds et sommets
## des tourelles + bord de l'arène. Résultat : distance D telle que max |x_ndc| = `target`.

const SAMPLES_RING: int = 12
const SAMPLES_RIM: int = 48
const TURRET_HEIGHT: float = 1.6


## Largeur visible (m) au niveau du point visé pour une distance donnée.
static func width_at(distance: float, fov_deg: float) -> float:
	return 2.0 * distance * tan(deg_to_rad(fov_deg * 0.5))


static func distance_for(cfg: GameConfig, feel: FeelConfig) -> float:
	var points: Array[Vector3] = _points(cfg)
	var foci: Array[Vector3] = _foci(cfg, feel)
	var lo: float = 4.0
	var hi: float = 400.0
	for i: int in 40:
		var mid: float = 0.5 * (lo + hi)
		if worst_ndc_x(points, foci, mid, feel) > feel.fit_target:
			lo = mid
		else:
			hi = mid
	return hi


## Plus grand |x| à l'écran (1.0 = bord) sur tous les points et toutes les positions de caméra.
static func worst_ndc_x(
	points: Array[Vector3], foci: Array[Vector3], distance: float, feel: FeelConfig
) -> float:
	var pitch: float = deg_to_rad(feel.pitch_degrees)
	var sp: float = sin(pitch)
	var cp: float = cos(pitch)
	var tan_half: float = tan(deg_to_rad(feel.fov_degrees * 0.5))
	var worst: float = 0.0
	for look: Vector3 in foci:
		var cam: Vector3 = look + Vector3(0.0, sp, cp) * distance
		for p: Vector3 in points:
			# Axe avant de la caméra = -(0, sp, cp) : profondeur = (p - cam) . avant.
			var depth: float = -((p.y - cam.y) * sp + (p.z - cam.z) * cp)
			if depth <= 0.01:
				return INF
			worst = maxf(worst, absf(p.x - cam.x) / depth / tan_half)
	return worst


static func _points(cfg: GameConfig) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var ring: float = cfg.ring_radius()
	for k: int in 4:
		var a: float = deg_to_rad(-45.0 + 90.0 * float(k))
		var c: Vector2 = Vector2(cos(a), sin(a)) * ring
		for j: int in SAMPLES_RING:
			var foot: Vector2 = c + Vector2.from_angle(TAU * float(j) / float(SAMPLES_RING))
			out.append(Vector3(foot.x, 0.0, foot.y))
			out.append(Vector3(foot.x, TURRET_HEIGHT, foot.y))
	for j: int in SAMPLES_RIM:
		var rim: Vector2 = (
			Vector2.from_angle(TAU * float(j) / float(SAMPLES_RIM)) * cfg.arena_radius
		)
		out.append(Vector3(rim.x, 0.0, rim.y))
	return out


## Décalage du point visé vers le bas de l'écran (mètres) : le pouce ne masque pas l'action.
## Proportionnel à la largeur nominale de l'arène, donc indépendant de la distance calculée.
static func frame_shift(cfg: GameConfig, feel: FeelConfig) -> float:
	return cfg.camera_visible_width() * feel.frame_shift_ratio


## Positions du point visé : joueur au centre et aux quatre bords (le suivi est partiel).
static func _foci(cfg: GameConfig, feel: FeelConfig) -> Array[Vector3]:
	var shift: float = frame_shift(cfg, feel)
	var out: Array[Vector3] = []
	var r: float = cfg.arena_radius
	for c: Vector2 in [Vector2.ZERO, Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r)]:
		out.append(Vector3(c.x * feel.follow_factor, 0.0, c.y * feel.follow_factor + shift))
	return out
