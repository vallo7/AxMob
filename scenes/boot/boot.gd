extends Node3D
## Scène témoin de la Phase 0 : prouve que le build Android affiche de la 3D.
## Affiche version Godot, renderer, FPS. Touche/tap : bascule vers le spike perf.

var _t: float = 0.0

@onready var _label: Label = $Hud/Info
@onready var _cube: MeshInstance3D = $Cube


func _ready() -> void:
	var renderer: String = str(ProjectSettings.get_setting("rendering/renderer/rendering_method"))
	var v: Dictionary = Engine.get_version_info()
	_label.text = "AxMob phase 0\nGodot %s\nrenderer: %s" % [v.get("string", "?"), renderer]
	print("[AxMob] boot ok - Godot ", v.get("string", "?"), " - ", renderer)


func _process(delta: float) -> void:
	_t += delta
	_cube.rotation.y = _t * 1.2
	_cube.rotation.x = sin(_t) * 0.3
	$Hud/Fps.text = "%d FPS" % Engine.get_frames_per_second()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		get_tree().change_scene_to_file("res://scenes/spikes/perf_spike.tscn")
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		get_tree().change_scene_to_file("res://scenes/spikes/perf_spike.tscn")
