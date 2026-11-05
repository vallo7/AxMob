class_name PauseMenu
extends Control
## Menu pause minimal (prototype) : REPRENDRE, RECOMMENCER, MENU. Reste actif en pause.

signal resume_pressed
signal restart_pressed
signal menu_pressed


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 28)
	box.position = Vector2(190.0, 620.0)
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
