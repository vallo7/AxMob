extends SceneTree
## godot --headless --script res://scripts/tools/bench_grid.gd


func _initialize() -> void:
	for n: int in [100, 200, 400, 800]:
		var r: Dictionary = RingBench.run(n, 120)
		print("[bench] n=%d  %.0f us/tick" % [r["count"], r["us_per_tick"]])
	quit(0)
