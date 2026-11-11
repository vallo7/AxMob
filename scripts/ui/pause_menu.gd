class_name PauseMenu
extends Control
## Menu pause (cahier §10.6) : REPRENDRE, RECOMMENCER, RÉGLAGES, MENU PRINCIPAL. Les réglages
## (vibrations, qualité, son, comportement pendant les améliorations...) sont dans l'écran
## RÉGLAGES, identique à celui du menu principal. Reste actif en pause.

signal resume_pressed
signal restart_pressed
signal menu_pressed
signal upgrade_mode_pressed

var _built: bool = false
var _title: Label
var _buttons: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.04, 0.07, 0.2, 0.66)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel: Control = Control.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(800, 880)
	panel.size = Vector2(800, 880)
	panel.offset_left = -400.0
	panel.offset_right = 400.0
	panel.offset_top = -400.0
	panel.offset_bottom = 480.0
	add_child(panel)
	panel.add_child(UiArt.nine("panels/panel_light", 78, 78, 78, 84))
	var rib: TextureRect = UiArt.image("brand/banner_blue")
	rib.position = Vector2(80.0, -118.0)
	rib.size = Vector2(640.0, 218.0)
	rib.stretch_mode = TextureRect.STRETCH_SCALE
	panel.add_child(rib)
	_title = UiArt.label(Loc.t("pause_title"), 64, UiArt.WHITE, Color("#0F3C8A"))
	_title.position = Vector2(140.0, -58.0)
	_title.size = Vector2(520.0, 120.0)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(_title)
	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 80.0
	box.offset_right = -80.0
	box.offset_top = 130.0
	box.offset_bottom = -90.0
	box.add_theme_constant_override(&"separation", 24)
	panel.add_child(box)
	_add(box, "resume", "green", "play", func() -> void: resume_pressed.emit(), 150.0)
	_add(box, "restart", "blue", "replay", func() -> void: restart_pressed.emit())
	_add(box, "settings", "blue", "gear", _open_settings)
	_add(box, "main_menu", "red", "home", func() -> void: menu_pressed.emit())
	_built = true
	visibility_changed.connect(refresh_labels)


func _add(
	box: VBoxContainer, key: String, style: String, icon: String, action: Callable, h: float = 128.0
) -> void:
	var b: AxButton = AxButton.make(Loc.t(key), style, Vector2(0, h), 50 if h > 140.0 else 44, icon)
	b.pressed.connect(action)
	box.add_child(b)
	_buttons[key] = b


func _open_settings() -> void:
	var s: SettingsScreen = SettingsScreen.new()
	s.upgrade_pause_changed.connect(func(_m: int) -> void: upgrade_mode_pressed.emit())
	add_child(s)


## Retraduit les textes (langue changée dans les réglages).
func refresh_labels() -> void:
	if not _built:
		return
	_title.text = Loc.t("pause_title")
	for key: String in _buttons.keys():
		(_buttons[key] as AxButton).text = Loc.t(key)
