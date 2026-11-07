extends RefCounted
## Fenêtre de combat : durée, cooldown (limite les activations, pas la cadence de tir).

var t: Object


func test_activation_and_expiry() -> void:
	var w: CombatWindow = CombatWindow.new(2.0, 0.5)
	t.call("check", not w.is_active(0.0), "inactive au départ")
	t.call("check", w.try_activate(1.0), "première activation acceptée")
	t.call("check", w.is_active(2.9), "active à +1.9 s")
	t.call("check", not w.is_active(3.0), "expirée à +2.0 s")


func test_cooldown_blocks_rapid_reactivation() -> void:
	var w: CombatWindow = CombatWindow.new(2.0, 0.5)
	t.call("check", w.try_activate(0.0))
	t.call("check", not w.try_activate(0.3), "refusée pendant le cooldown")
	t.call("check", w.try_activate(0.5), "acceptée après le cooldown")


func test_activation_extends_without_stacking() -> void:
	var w: CombatWindow = CombatWindow.new(2.0, 0.5)
	w.try_activate(0.0)
	w.try_activate(1.5)
	t.call("check", is_equal_approx(w.window_end, 3.5), "fin = maintenant + 2 s, sans empiler")
	t.call("check", is_equal_approx(w.remaining(2.5), 1.0))
