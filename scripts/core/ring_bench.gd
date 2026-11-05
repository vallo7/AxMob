class_name RingBench
extends RefCounted
## Micro-benchmark headless : reconstruction de grille + requêtes, pour le spike perf.


static func run(count: int, ticks: int) -> Dictionary:
	var grid: SpatialGrid = SpatialGrid.new(2.0)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1234
	var pos: PackedVector2Array = PackedVector2Array()
	pos.resize(count)
	for i: int in count:
		pos[i] = Vector2(rng.randf_range(-12.0, 12.0), rng.randf_range(-12.0, 12.0))
	var t0: int = Time.get_ticks_usec()
	var hits: int = 0
	for _t: int in ticks:
		grid.clear()
		for i: int in count:
			grid.insert(i, pos[i])
		for i: int in count:
			hits += grid.query_circle(pos[i], 1.2).size()
	var us: float = float(Time.get_ticks_usec() - t0) / float(ticks)
	return {"count": count, "us_per_tick": us, "hits": hits}
