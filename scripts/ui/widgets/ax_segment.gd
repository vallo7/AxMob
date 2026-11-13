class_name AxSegment
extends HBoxContainer
## Sélecteur à choix unique (AUTO | BAS | MOYEN | ÉLEVÉ...). Le choix actif est jaune.
## Un choix peut être verrouillé (grisé) : il reste visible mais non sélectionnable.

signal selected_changed(index: int)
signal locked_pressed(index: int)

var selected: int = 0
var _buttons: Array[AxButton] = []
var _locked: Array[bool] = []


func _init() -> void:
	add_theme_constant_override(&"separation", 10)
	alignment = BoxContainer.ALIGNMENT_CENTER


func setup(labels: Array[String], p_selected: int, font_size: int = 34) -> void:
	for b: AxButton in _buttons:
		b.queue_free()
	_buttons.clear()
	_locked.clear()
	selected = p_selected
	for i: int in labels.size():
		var b: AxButton = AxButton.make(labels[i], "blue", Vector2(120, 88), font_size)
		b.small = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_pressed.bind(i))
		add_child(b)
		_buttons.append(b)
		_locked.append(false)
	_restyle()


func set_locked(index: int, locked: bool) -> void:
	_locked[index] = locked
	_restyle()


func select(index: int) -> void:
	selected = index
	_restyle()


func _on_pressed(i: int) -> void:
	if _locked[i]:
		locked_pressed.emit(i)
		return
	if i != selected:
		selected = i
		_restyle()
		selected_changed.emit(i)


func _restyle() -> void:
	for i: int in _buttons.size():
		var b: AxButton = _buttons[i]
		b.style = "gold" if i == selected else ("grey" if _locked[i] else "stone")
		b.icon_name = "lock" if _locked[i] else ""
