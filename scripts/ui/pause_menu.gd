class_name PauseMenu
extends Control
## Menu pause : REPRENDRE, RECOMMENCER, MENU, plus deux réglages rapides : vibrations et
## comportement du jeu pendant les améliorations. Reste actif en pause.

signal resume_pressed
signal restart_pressed
signal menu_pressed
signal upgrade_mode_pressed

const UPGRADE_MODE_NAMES: Array[String] = ["Arrêt total", "Ralenti", "Aucune pause"]

var _haptics_button: Button
var _haptics_test_button: Button
var _mode_button: Button
var _quality_button: Button
var _sound_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.position = Vector2(190.0, 280.0)
	box.custom_minimum_size = Vector2(700.0, 0.0)
	add_child(box)
	box.add_child(UiKit.label("PAUSE", 96, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	var resume: Button = UiKit.button("REPRENDRE", Vector2(700.0, 130.0), 56)
	resume.pressed.connect(func() -> void: resume_pressed.emit())
	box.add_child(resume)
	var restart: Button = UiKit.button("RECOMMENCER", Vector2(700.0, 130.0), 56)
	restart.pressed.connect(func() -> void: restart_pressed.emit())
	box.add_child(restart)
	var menu: Button = UiKit.button("MENU", Vector2(700.0, 130.0), 56)
	menu.pressed.connect(func() -> void: menu_pressed.emit())
	box.add_child(menu)
	_haptics_button = UiKit.button("", Vector2(700.0, 100.0), 38)
	_haptics_button.pressed.connect(_on_haptics_pressed)
	box.add_child(_haptics_button)
	_haptics_test_button = UiKit.button("TESTER LA VIBRATION", Vector2(700.0, 100.0), 38)
	_haptics_test_button.pressed.connect(_on_haptics_test_pressed)
	box.add_child(_haptics_test_button)
	_mode_button = UiKit.button("", Vector2(700.0, 100.0), 38)
	_mode_button.pressed.connect(func() -> void: upgrade_mode_pressed.emit())
	box.add_child(_mode_button)
	_quality_button = UiKit.button("", Vector2(700.0, 100.0), 38)
	_quality_button.pressed.connect(_on_quality_pressed)
	box.add_child(_quality_button)
	_sound_button = UiKit.button("", Vector2(700.0, 100.0), 38)
	_sound_button.pressed.connect(_on_sound_pressed)
	box.add_child(_sound_button)
	visibility_changed.connect(refresh_labels)


func refresh_labels() -> void:
	_haptics_button.text = "VIBRATIONS : %s" % UserSettings.HAPTICS_NAMES[Haptics.level()]
	var mode: int = UserSettings.upgrade_pause(0)
	_mode_button.text = "AMÉLIORATIONS : %s" % UPGRADE_MODE_NAMES[mode]
	_quality_button.text = "QUALITÉ : %s" % QualityManager.mode_label()
	_sound_button.text = "SON : %s" % AudioManager.sound_label()


func _on_haptics_pressed() -> void:
	Haptics.cycle_level()
	# Petit échantillon : le joueur sent tout de suite le niveau choisi.
	Haptics.play(&"hurt_light", 0.7)
	refresh_labels()


## Vibration forte de 300 ms, indépendante des réglages : si le téléphone ne vibre pas ici,
## le problème est hors du jeu (réglages du téléphone) ou dans l'APK (permission).
func _on_haptics_test_pressed() -> void:
	UIManager.toast(Haptics.test_vibration())


## AUTO -> BAS -> MOYEN -> ÉLEVÉ : sauvegardé ; le profil s'applique tout de suite.
func _on_quality_pressed() -> void:
	QualityManager.cycle_mode()
	refresh_labels()


## Musique + effets -> effets seuls -> silence.
func _on_sound_pressed() -> void:
	AudioManager.cycle_sound_mode()
	refresh_labels()
