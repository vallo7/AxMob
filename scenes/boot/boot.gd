extends Node3D
## Scène témoin de la Phase 0 : prouve que le build Android affiche de la 3D.
## Affiche version Godot, renderer, FPS. Boutons : jouer (prototype) ou spike perf.

var _t: float = 0.0

@onready var _label: Label = $Hud/Info
@onready var _cube: MeshInstance3D = $Cube


func _ready() -> void:
	var renderer: String = str(ProjectSettings.get_setting("rendering/renderer/rendering_method"))
	var v: Dictionary = Engine.get_version_info()
	_label.text = (
		"AxMob - prototype (phase 2)\nGodot %s\nrenderer: %s" % [v.get("string", "?"), renderer]
	)
	_build_buttons()
	print("[AxMob] boot ok - Godot ", v.get("string", "?"), " - ", renderer)


func _process(delta: float) -> void:
	_t += delta
	_cube.rotation.y = _t * 1.2
	_cube.rotation.x = sin(_t) * 0.3
	$Hud/Fps.text = "%d FPS" % Engine.get_frames_per_second()


func _build_buttons() -> void:
	var play: Button = UiKit.button("JOUER (prototype)", Vector2(760.0, 150.0), 60)
	play.position = Vector2(160.0, 1150.0)
	play.pressed.connect(_go.bind("res://scenes/gameplay/gameplay.tscn"))
	$Hud.add_child(play)
	var spike: Button = UiKit.button("Spike perf (phase 0)", Vector2(760.0, 110.0), 44)
	spike.position = Vector2(160.0, 1340.0)
	spike.pressed.connect(_go.bind("res://scenes/spikes/perf_spike.tscn"))
	$Hud.add_child(spike)


func _go(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)
