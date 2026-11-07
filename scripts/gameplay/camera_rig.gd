class_name CameraRig
extends Node3D
## Caméra 3D en vue plongée, perspective légère, LARGEUR visible fixe (keep_aspect sur la
## largeur) pour que le portrait fonctionne quel que soit le ratio. La largeur est DÉDUITE de
## la taille de l'arène (GameConfig.camera_visible_width) : toute l'arène et ses tourelles
## restent à l'écran. Suivi lissé très partiel + anticipation ; cadrage décalé vers le haut
## pour que le pouce ne masque pas l'action.

@export var fov_degrees: float = 55.0
@export var pitch_degrees: float = 70.0
## Part du déplacement du joueur suivie par la caméra (0 = cadrage fixe). Doit rester petit :
## la marge de cadrage (GameConfig.camera_margin) absorbe ce décalage.
@export var follow_factor: float = 0.08
@export var lead_seconds: float = 0.25
@export var follow_smoothing: float = 5.0
## Décale le point visé vers le bas de l'écran (fraction de la largeur visible).
@export var frame_shift_ratio: float = 0.105

var visible_width: float = 21.0

var _focus: Vector2 = Vector2.ZERO

@onready var _camera: Camera3D = $Camera3D


func setup(cfg: GameConfig) -> void:
	visible_width = cfg.camera_visible_width()
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.fov = fov_degrees
	_camera.current = true
	_place()


func camera() -> Camera3D:
	return _camera


func step(ctx: RunContext, dt: float) -> void:
	var target: Vector2 = (ctx.player_pos + ctx.player_vel * lead_seconds) * follow_factor
	_focus = _focus.lerp(target, 1.0 - exp(-follow_smoothing * dt))
	_place()


func _place() -> void:
	var distance: float = (visible_width * 0.5) / tan(deg_to_rad(fov_degrees * 0.5))
	var pitch: float = deg_to_rad(pitch_degrees)
	var shift: float = visible_width * frame_shift_ratio
	var look_at_point: Vector3 = Vector3(_focus.x, 0.0, _focus.y + shift)
	_camera.position = look_at_point + Vector3(0.0, sin(pitch), cos(pitch)) * distance
	_camera.look_at(look_at_point, Vector3.UP)
