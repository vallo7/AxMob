class_name SettingsScreen
extends AxScreen
## Réglages (cahier des charges §10.9) : musique et effets (interrupteurs + volumes séparés),
## sensibilité du joystick, vibrations, qualité graphique, comportement du jeu pendant les
## améliorations, langue, compteur d'images et rapport technique copiable.
## Tout s'applique et se sauvegarde immédiatement.

signal upgrade_pause_changed(mode: int)

var _quality_note: Label
var _sens_note: Label
var _test_button: AxButton


func _init() -> void:
	banner = "blue"


func _ready() -> void:
	title = Loc.t("settings")
	super._ready()


func build() -> void:
	for c: Node in content.get_children():
		c.queue_free()
	set_title(Loc.t("settings"))
	_build_audio()
	_build_controls()
	_build_graphics()
	_build_misc()
	if QualityManager.crash_notice_pending:
		QualityManager.crash_notice_pending = false
		UIManager.toast(Loc.t("crash_notice"))


func _build_audio() -> void:
	var music: AxToggle = AxToggle.new()
	music.set_on(UserSettings.music_enabled())
	music.toggled.connect(AudioManager.set_music_enabled)
	content.add_child(AxScreen.row(Loc.t("set_music"), music))
	var mv: AxSlider = _slider(
		10, UserSettings.music_volume_step(), AudioManager.set_music_volume_step
	)
	content.add_child(AxScreen.row(Loc.t("set_music_vol"), mv))
	var sfx: AxToggle = AxToggle.new()
	sfx.set_on(UserSettings.sfx_enabled())
	sfx.toggled.connect(AudioManager.set_sfx_enabled)
	content.add_child(AxScreen.row(Loc.t("set_sfx"), sfx))
	var sv: AxSlider = _slider(10, UserSettings.sfx_volume_step(), _on_sfx_volume)
	content.add_child(AxScreen.row(Loc.t("set_sfx_vol"), sv))


func _build_controls() -> void:
	var js: AxSlider = _slider(4, UserSettings.joystick_step(), _on_joystick)
	var step_text: String = Loc.t("sens_%d" % UserSettings.joystick_step())
	var row_node: Control = AxScreen.row(Loc.t("set_joystick"), js, step_text)
	content.add_child(row_node)
	_sens_note = _sub_of(row_node)
	var hap: AxSegment = AxSegment.new()
	var hap_labels: Array[String] = []
	for i: int in 4:
		hap_labels.append(Loc.t("haptics_%d" % i))
	hap.setup(hap_labels, Haptics.level(), 27)
	hap.selected_changed.connect(_on_haptics)
	content.add_child(AxScreen.stacked_row(Loc.t("set_haptics"), hap))
	_test_button = AxButton.make(Loc.t("set_test_vibration"), "blue", Vector2(0, 96), 34, "vibrate")
	_test_button.small = true
	_test_button.pressed.connect(_on_test_vibration)
	_test_button.visible = Haptics.level() > 0
	content.add_child(_test_button)


func _build_graphics() -> void:
	var gfx: AxSegment = AxSegment.new()
	var gfx_labels: Array[String] = []
	for key: String in ["AUTO", "LOW", "MEDIUM", "HIGH"]:
		gfx_labels.append(Loc.t("quality_" + key))
	gfx.setup(gfx_labels, QualityManager.mode, 29)
	for i: int in 4:
		if not QualityManager.mode_available(i):
			gfx.set_locked(i, true)
	gfx.selected_changed.connect(_on_quality)
	gfx.locked_pressed.connect(_on_quality_locked)
	var note: String = Loc.t("quality_note", [QualityManager.mode_label()])
	var row_node: Control = AxScreen.stacked_row(Loc.t("set_graphics"), gfx, note)
	content.add_child(row_node)
	_quality_note = _sub_of(row_node)
	var up: AxSegment = AxSegment.new()
	var up_labels: Array[String] = []
	for i: int in 3:
		up_labels.append(Loc.t("pause_mode_%d" % i))
	up.setup(up_labels, UserSettings.upgrade_pause(0), 27)
	up.selected_changed.connect(_on_upgrade_pause)
	content.add_child(AxScreen.stacked_row(Loc.t("set_upgrade_pause"), up))


func _build_misc() -> void:
	var lang: AxSegment = AxSegment.new()
	var lang_labels: Array[String] = []
	for n: String in Loc.MODE_NAMES:
		lang_labels.append(n)
	lang.setup(lang_labels, UserSettings.language_mode(), 29)
	lang.selected_changed.connect(_on_language)
	content.add_child(AxScreen.stacked_row(Loc.t("set_language"), lang))
	var fps: AxToggle = AxToggle.new()
	fps.set_on(UserSettings.show_fps())
	fps.toggled.connect(UserSettings.set_show_fps)
	content.add_child(AxScreen.row("FPS", fps))
	var report: AxButton = AxButton.make(
		Loc.t("set_report"), "purple", Vector2(0, 104), 34, "chart"
	)
	report.small = true
	report.pressed.connect(_on_report)
	content.add_child(report)


func _slider(steps: int, value: int, on_change: Callable) -> AxSlider:
	var s: AxSlider = AxSlider.new()
	s.steps = steps
	s.value = value
	s.custom_minimum_size = Vector2(430, 76)
	s.value_changed.connect(on_change)
	return s


func _on_sfx_volume(step: int) -> void:
	AudioManager.set_sfx_volume_step(step)
	AudioManager.play_ui(&"ui_tap")


func _on_joystick(step: int) -> void:
	UserSettings.set_joystick_step(step)
	if _sens_note != null:
		_sens_note.text = Loc.t("sens_%d" % step)


func _on_haptics(level: int) -> void:
	Haptics.set_level(level)
	UserSettings.set_haptics_level(level)
	Haptics.play(&"hurt_light", 0.7)
	_test_button.visible = level > 0


func _on_test_vibration() -> void:
	UIManager.toast(Haptics.test_vibration())


func _on_quality(mode: int) -> void:
	if QualityManager.set_mode(mode):
		_quality_note.text = Loc.t("quality_note", [QualityManager.mode_label()])


func _on_quality_locked(_index: int) -> void:
	AudioManager.play_ui(&"ui_denied")
	UIManager.toast(Loc.t("quality_locked"))


func _on_upgrade_pause(mode: int) -> void:
	UserSettings.set_upgrade_pause(mode)
	upgrade_pause_changed.emit(mode)


func _on_language(mode: int) -> void:
	UserSettings.set_language_mode(mode)
	build()


func _on_report() -> void:
	DisplayServer.clipboard_set(Diagnostics.report())
	UIManager.toast(Loc.t("set_report_done"))


static func _sub_of(row_node: Node) -> Label:
	return row_node.find_child("Sub", true, false) as Label
