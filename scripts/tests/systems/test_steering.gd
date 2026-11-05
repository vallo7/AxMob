extends RefCounted
## Steering : accélération limitée, glissement au bord, enfermement dans l'arène.

var t: Object


func test_player_reaches_speed_in_accel_time() -> void:
	var speed: float = 5.0
	var vel: Vector2 = Vector2.ZERO
	var dt: float = 1.0 / 60.0
	var elapsed: float = 0.0
	while vel.length() < speed - 0.001 and elapsed < 1.0:
		vel = Steering.approach_asymmetric(vel, Vector2(speed, 0), speed / 0.12, speed / 0.10, dt)
		elapsed += dt
	t.call("check", absf(elapsed - 0.12) < 0.03, "0,12 s pour atteindre la vitesse max")


func test_player_stops_in_decel_time() -> void:
	var vel: Vector2 = Vector2(5, 0)
	var dt: float = 1.0 / 60.0
	var elapsed: float = 0.0
	while vel.length() > 0.001 and elapsed < 1.0:
		vel = Steering.approach_asymmetric(vel, Vector2.ZERO, 5.0 / 0.12, 5.0 / 0.10, dt)
		elapsed += dt
	t.call("check", absf(elapsed - 0.10) < 0.03, "0,10 s pour s'arrêter")


func test_approach_is_frame_rate_independent() -> void:
	var a: Vector2 = Vector2.ZERO
	for i: int in 60:
		a = Steering.approach(a, Vector2(5, 0), 10.0, 1.0 / 60.0)
	var b: Vector2 = Vector2.ZERO
	for i: int in 120:
		b = Steering.approach(b, Vector2(5, 0), 10.0, 1.0 / 120.0)
	t.call("check", a.distance_to(b) < 0.01, "même résultat à 60 et 120 Hz")


func test_clamp_to_arena() -> void:
	var p: Vector2 = Steering.clamp_to_arena(Vector2(20, 0), 0.5, 9.0)
	t.call("check", is_equal_approx(p.length(), 8.5))
	var inside: Vector2 = Steering.clamp_to_arena(Vector2(1, 1), 0.5, 9.0)
	t.call("check", inside == Vector2(1, 1))


func test_edge_push_only_near_border() -> void:
	t.call("check", Steering.edge_push(Vector2(2, 0), 9.0, 1.2, 4.0) == Vector2.ZERO)
	var push: Vector2 = Steering.edge_push(Vector2(8.9, 0), 9.0, 1.2, 4.0)
	t.call("check", push.x < 0.0, "pousse vers le centre")
