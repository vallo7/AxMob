class_name CameraRig
extends Node3D
## Caméra 3D en vue plongée, perspective légère, LARGEUR d'arène fixe (keep_aspect sur la
## largeur) pour que le portrait fonctionne quel que soit le ratio. Suivi lissé partiel
## (l'arène reste en vue) avec anticipation dans le sens du déplacement. Cadrage décalé
## vers le haut pour que le pouce ne masque pas l'action.

@export var fov_degrees: float = 55.0
@export var pitch_degrees: float = 70.0
@export var visible_width: float = 21.0
@export var follow_factor: float = 0.2
@export var lead_seconds: float = 0.25
@export var follow_smoothing: float = 5.0
## Décale le point visé vers le bas de l'écran : l'arène remonte à l'écran.
@export var frame_shift_z: float = 2.2

var _focus: Vector2 = Vector2.ZERO

@onready var _camera: Camera3D = $Camera3D


func setup() -> void:
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.fov = fov_degrees
	_camera.current = true
	_place()


func step(ctx: RunContext, dt: float) -> void:
	var target: Vector2 = (ctx.player_pos + ctx.player_vel * lead_seconds) * follow_factor
	_focus = _focus.lerp(target, 1.0 - exp(-follow_smoothing * dt))
	_place()


func _place() -> void:
	var distance: float = (visible_width * 0.5) / tan(deg_to_rad(fov_degrees * 0.5))
	var pitch: float = deg_to_rad(pitch_degrees)
	var look_at_point: Vector3 = Vector3(_focus.x, 0.0, _focus.y + frame_shift_z)
	_camera.position = look_at_point + Vector3(0.0, sin(pitch), cos(pitch)) * distance
	_camera.look_at(look_at_point, Vector3.UP)
