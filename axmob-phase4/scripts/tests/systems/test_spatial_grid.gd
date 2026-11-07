extends RefCounted
## Tests de SpatialGrid : comparaison avec la force brute.

var t: Object


func test_query_matches_brute_force() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var grid: SpatialGrid = SpatialGrid.new(2.0)
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in 300:
		var p: Vector2 = Vector2(rng.randf_range(-15, 15), rng.randf_range(-15, 15))
		pts.append(p)
		grid.insert(i, p)
	for _k: int in 50:
		var c: Vector2 = Vector2(rng.randf_range(-15, 15), rng.randf_range(-15, 15))
		var r: float = rng.randf_range(0.3, 5.0)
		var expected: int = 0
		for p: Vector2 in pts:
			if p.distance_to(c) <= r:
				expected += 1
		t.call("check", grid.query_circle(c, r).size() == expected, "requete cercle != force brute")


func test_negative_coordinates_and_clear() -> void:
	var grid: SpatialGrid = SpatialGrid.new(2.0)
	grid.insert(0, Vector2(-0.5, -0.5))
	grid.insert(1, Vector2(0.5, 0.5))
	t.call("check", grid.query_circle(Vector2.ZERO, 1.0).size() == 2, "coords negatives")
	grid.clear()
	t.call("check", grid.query_circle(Vector2.ZERO, 5.0).size() == 0, "clear")
