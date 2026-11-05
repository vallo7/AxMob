extends RefCounted
## Planar, JoystickMath, Intercept, SweptCircle, DamageCalculator, HealthComponent.

var t: Object


func test_planar_roundtrip() -> void:
	for deg: int in [0, 45, 90, 135, 180, -90, -170]:
		var yaw: float = deg_to_rad(float(deg))
		var back: float = Planar.yaw_from_dir(Planar.dir_from_yaw(yaw))
		t.call("check", absf(angle_difference(yaw, back)) < 0.0001, "yaw %d" % deg)
	t.call("check", Planar.dir_from_yaw(0.0).is_equal_approx(Vector2(0.0, -1.0)), "yaw 0 = -Z")


func test_joystick_deadzone() -> void:
	t.call("check", JoystickMath.from_offset(Vector2(10, 0), 100.0, 0.15) == Vector2.ZERO)
	var full: Vector2 = JoystickMath.from_offset(Vector2(500, 0), 100.0, 0.15)
	t.call("check", is_equal_approx(full.length(), 1.0), "saturé à 1")
	var just_out: Vector2 = JoystickMath.from_offset(Vector2(16, 0), 100.0, 0.15)
	t.call("check", just_out.length() < 0.02, "pas de saut à la sortie de la zone morte")


func test_intercept_static_target() -> void:
	var p: Vector2 = Intercept.aim_point(Vector2.ZERO, Vector2(5, 0), Vector2.ZERO, 20.0)
	t.call("check", p.is_equal_approx(Vector2(5, 0)))


func test_intercept_moving_target_meets() -> void:
	var shooter: Vector2 = Vector2(0, 0)
	var target: Vector2 = Vector2(8, 0)
	var vel: Vector2 = Vector2(0, 3)
	var speed: float = 20.0
	var aim: Vector2 = Intercept.aim_point(shooter, target, vel, speed)
	var flight: float = aim.distance_to(shooter) / speed
	var target_then: Vector2 = target + vel * flight
	t.call("check", aim.distance_to(target_then) < 0.05, "la hache et la cible se rejoignent")


func test_intercept_impossible_is_bounded() -> void:
	# Cible plus rapide que la hache et qui s'éloigne : pas d'interception, on vise la cible.
	var p: Vector2 = Intercept.aim_point(Vector2.ZERO, Vector2(5, 0), Vector2(30, 0), 10.0)
	t.call("check", p.is_equal_approx(Vector2(5, 0)))


func test_swept_circle_no_tunneling() -> void:
	# Segment de 30 unités en un tick : un ennemi au milieu doit être touché.
	t.call("check", SweptCircle.hits(Vector2(0, 0), Vector2(30, 0), 0.3, Vector2(15, 0.2), 0.4))
	t.call("check", not SweptCircle.hits(Vector2(0, 0), Vector2(30, 0), 0.3, Vector2(15, 2.0), 0.4))
	t.call("check", not SweptCircle.hits(Vector2(0, 0), Vector2(10, 0), 0.3, Vector2(15, 0), 0.4))
	t.call("check", SweptCircle.hits(Vector2(0, 0), Vector2(10, 0), 0.3, Vector2(10.6, 0), 0.4))
	t.call("check", SweptCircle.hits(Vector2(0, 0), Vector2(0, 0), 0.3, Vector2(0.5, 0), 0.4))


func test_damage_calculator() -> void:
	t.call("check", is_equal_approx(DamageCalculator.compute(40.0, 0.6, 1.0), 24.0))
	t.call("check", DamageCalculator.compute(10.0, -1.0) == 0.0, "jamais négatif")


func test_health_invulnerability() -> void:
	var h: HealthComponent = HealthComponent.new(100.0, 0.6)
	t.call("check", is_equal_approx(h.apply_damage(30.0), 30.0))
	t.call("check", h.apply_damage(30.0) == 0.0, "invulnérable juste après un coup")
	h.tick(0.7)
	t.call("check", is_equal_approx(h.apply_damage(30.0), 30.0), "touché à nouveau après invuln")
	h.tick(0.7)
	t.call("check", is_equal_approx(h.apply_damage(500.0), 40.0), "dégâts bornés aux PV restants")
	t.call("check", h.is_dead())
	t.call("check", h.apply_damage(5.0) == 0.0, "un mort ne reçoit plus de dégâts")
