class_name CombatDirector
extends Node
## Transforme les contacts en activations de combat : applique le cooldown global
## et prolonge la fenêtre. Les tourelles lisent la fenêtre via le RunContext.

var last_intensity: int = 0

var _ctx: RunContext


func setup(ctx: RunContext) -> void:
	_ctx = ctx
	EventBus.contact_detected.connect(_on_contact_detected)


func _on_contact_detected(contacts: int, position: Vector3) -> void:
	if _ctx.combat.try_activate(_ctx.time):
		last_intensity = contacts
		EventBus.combat_activated.emit(contacts, position)
