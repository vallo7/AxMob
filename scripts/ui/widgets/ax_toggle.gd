class_name AxToggle
extends BaseButton
## Interrupteur OUI/NON : glissière verte/grise et pastille blanche qui se déplace.

const KNOB_PAD: float = 8.0

var _bg: TextureRect
var _knob: TextureRect
var _tween: Tween


func _init() -> void:
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(150, 80)
	action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE


func _ready() -> void:
	_bg = TextureRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_SCALE
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	_knob = TextureRect.new()
	_knob.texture = UiArt.tex("bars/knob_white")
	_knob.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_knob.stretch_mode = TextureRect.STRETCH_SCALE
	_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_knob)
	toggled.connect(
		func(_on: bool) -> void:
			_sync(true)
			AudioManager.play_ui(&"ui_tap")
	)
	resized.connect(func() -> void: _sync(false))
	_sync(false)


func set_on(on: bool) -> void:
	set_pressed_no_signal(on)
	_sync(false)


func _sync(animate: bool) -> void:
	if _bg == null:
		return
	_bg.texture = UiArt.tex("bars/toggle_on" if button_pressed else "bars/toggle_off")
	var k: float = size.y - KNOB_PAD * 2.0 + 6.0
	_knob.size = Vector2(k * 0.92, k)
	var x: float = size.x - _knob.size.x - KNOB_PAD - 2.0 if button_pressed else KNOB_PAD + 2.0
	var y: float = KNOB_PAD - 4.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if animate:
		_tween = create_tween()
		(
			_tween
			. tween_property(_knob, "position", Vector2(x, y), 0.14)
			. set_trans(Tween.TRANS_BACK)
			. set_ease(Tween.EASE_OUT)
		)
	else:
		_knob.position = Vector2(x, y)
