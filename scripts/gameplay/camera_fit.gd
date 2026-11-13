class_name CameraFit
extends RefCounted
## Cadrage de la caméra (phase 7). Toute l'île est l'arène et la caméra SUIT le joueur : la distance
## n'est plus calculée pour faire tenir l'arène entière, mais pour obtenir une largeur de monde
## visible choisie (GameConfig.view_width, en mètres au niveau du point visé). Plus elle est petite,
## plus les personnages paraissent grands : c'est ce qui fait « sentir » la taille des éléments.
## Contrainte vérifiée par les tests : joueur au centre, les quatre tourelles restent à l'écran.
## Fonctions pures (testables sans moteur de rendu).

const TURRET_HEIGHT: float = 2.4
const TURRET_FOOT: float = 1.3


## Largeur visible (m) au niveau du point visé pour une distance donnée.
static func width_at(distance: float, fov_deg: float) -> float:
	return 2.0 * distance * tan(deg_to_rad(fov_deg * 0.5))


## Distance de la caméra pour obtenir `view_width` mètres de monde visibles au point visé.
static func distance_for(cfg: GameConfig, feel: FeelConfig) -> float:
	return cfg.view_width / (2.0 * tan(deg_to_rad(feel.fov_degrees * 0.5)))


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


## Pieds et sommets des quatre tourelles (le cadrage doit toujours les contenir).
static func _points(cfg: GameConfig) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var ring: float = cfg.ring_radius()
	for k: int in 4:
		var a: float = deg_to_rad(-45.0 + 90.0 * float(k))
		var c: Vector2 = Vector2(cos(a), sin(a)) * ring
		for j: int in 8:
			var foot: Vector2 = c + Vector2.from_angle(TAU * float(j) / 8.0) * TURRET_FOOT
			out.append(Vector3(foot.x, 0.0, foot.y))
			out.append(Vector3(foot.x, TURRET_HEIGHT, foot.y))
	return out


## Décalage du point visé vers le bas de l'écran (mètres) : le pouce ne masque pas l'action.
## Proportionnel à la largeur nominale de l'arène, donc indépendant de la distance calculée.
static func frame_shift(cfg: GameConfig, feel: FeelConfig) -> float:
	return cfg.camera_visible_width() * feel.frame_shift_ratio


## Points visés testés : joueur au centre de l'île (cas de référence de la lisibilité des
## tourelles).
static func _foci(cfg: GameConfig, feel: FeelConfig) -> Array[Vector3]:
	return [Vector3(0.0, 0.0, frame_shift(cfg, feel))]
