class_name GameOverScreen
extends Control
## Écran de défaite minimal (prototype) : résultats + REJOUER / MENU.
## (REVIVE sur publicité récompensée : phase 8.)

signal play_again_pressed
signal menu_pressed

var _stats: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 26)
	box.position = Vector2(190.0, 480.0)
	box.custom_minimum_size = Vector2(700.0, 0.0)
	add_child(box)
	box.add_child(UiKit.label("DÉFAITE", 110, Color(0.9, 0.3, 0.3), HORIZONTAL_ALIGNMENT_CENTER))
	_stats = UiKit.label("", 52, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_stats)
	var again: Button = UiKit.button("REJOUER", Vector2(700.0, 140.0), 60)
	again.pressed.connect(func() -> void: play_again_pressed.emit())
	box.add_child(again)
	var menu: Button = UiKit.button("MENU", Vector2(700.0, 120.0), 52)
	menu.pressed.connect(func() -> void: menu_pressed.emit())
	box.add_child(menu)


func show_results(ctx: RunContext) -> void:
	var total: int = int(ctx.time)
	_stats.text = (
		"Vague atteinte : %d\nTemps : %d:%02d\nEnnemis éliminés : %d\nPièces gagnées : %d"
		% [ctx.wave, total / 60, total % 60, ctx.kills, ctx.coins]
	)
	visible = true
