class_name AxRoundButton
extends BaseButton
## Bouton rond à icône (pause, fermer, retour, réglages...). Même retour tactile que AxButton.

@export var style: String = "blue":
	set(v):
		style = v
		_refresh()
@export var icon_name: String = "":
	set(v):
		icon_name = v
		_refresh()

var _bg: TextureRect
var _icon: TextureRect
var _tween: Tween


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE


func _ready() -> void:
	_bg = TextureRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_SCALE
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	_icon = TextureRect.new()
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.offset_left = 22
	_icon.offset_right = -22
	_icon.offset_top = 14
	_icon.offset_bottom = -28
	add_child(_icon)
	resized.connect(func() -> void: pivot_offset = size * 0.5)
	button_down.connect(_squash.bind(true))
	button_up.connect(_squash.bind(false))
	pressed.connect(func() -> void: AudioManager.play_ui(&"ui_tap"))
	_refresh()


func _refresh() -> void:
	if _bg == null:
		return
	_bg.texture = UiArt.tex(
		"buttons/btn_round_%s" % (style if style in AxButton.STYLES else "blue")
	)
	_icon.texture = UiArt.tex("icons/" + icon_name) if icon_name != "" else null


func _squash(down: bool) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	if down:
		_tween.tween_property(self, "scale", Vector2(0.92, 0.92), 0.06)
	else:
		(
			_tween
			. tween_property(self, "scale", Vector2.ONE, 0.22)
			. set_trans(Tween.TRANS_BACK)
			. set_ease(Tween.EASE_OUT)
		)


static func make(p_style: String, p_icon: String, px: float = 120.0) -> AxRoundButton:
	var b: AxRoundButton = AxRoundButton.new()
	b.custom_minimum_size = Vector2(px, px * 1.09)
	b.style = p_style
	b.icon_name = p_icon
	return b
