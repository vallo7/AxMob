extends Node3D
## Scène témoin de la Phase 0 : prouve que le build Android affiche de la 3D.
## Affiche version Godot, renderer, FPS. Boutons : jouer (prototype) ou spike perf.

## Fenêtre de la double pression « retour » pour quitter (s).
const QUIT_WINDOW: float = 2.0

## Action de sortie (remplaçable en test pour ne pas fermer le moteur).
var quit_action: Callable = Callable(self, "_quit")

var _t: float = 0.0
var _double_press: DoublePress = DoublePress.new(QUIT_WINDOW)

@onready var _label: Label = $Hud/Info
@onready var _cube: MeshInstance3D = $Cube


func _ready() -> void:
	var renderer: String = str(ProjectSettings.get_setting("rendering/renderer/rendering_method"))
	var v: Dictionary = Engine.get_version_info()
	_label.text = (
		"AxMob - prototype (phase 3)\nGodot %s\nrenderer: %s" % [v.get("string", "?"), renderer]
	)
	_build_buttons()
	# Musique du menu (la partie lance la sienne) : fondu enchaîné, ambiance coupée.
	AudioManager.stop_ambience()
	AudioManager.play_music(&"menu", 1.0)
	UIManager.push_back(self, _on_back)
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


## Bouton retour sur l'écran d'accueil : une 1re pression prévient, la 2e quitte.
func _on_back() -> bool:
	if _double_press.press(float(Time.get_ticks_msec()) / 1000.0):
		quit_action.call()
	else:
		UIManager.toast("Appuyez encore pour quitter")
		Haptics.play(&"back_hint")
	return true


func _quit() -> void:
	get_tree().quit()


func _go(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)
