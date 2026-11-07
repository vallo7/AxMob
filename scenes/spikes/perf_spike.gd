extends Node3D
## Spike perf (Phase 0) : N ennemis en MultiMesh qui poursuivent un joueur,
## séparation via SpatialGrid. Touchez l'écran : +50 ennemis (max 400).
## Objectif : mesurer le FPS réel sur le téléphone avant de figer l'architecture.

const ARENA_R: float = 12.0
const ENEMY_R: float = 0.45
const SPEED: float = 2.2

var _count: int = 100
var _pos: PackedVector2Array = PackedVector2Array()
var _mm: MultiMesh
var _grid: SpatialGrid = SpatialGrid.new(2.0)
var _player: Vector2 = Vector2.ZERO
var _t: float = 0.0
var _log_timer: float = 0.0
var _label: Label


func _ready() -> void:
	UIManager.push_back(self, _on_back)
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = ENEMY_R
	cyl.bottom_radius = ENEMY_R
	cyl.height = 1.0
	cyl.radial_segments = 10
	cyl.rings = 1
	_mm.mesh = cyl
	_mm.instance_count = 400
	_mm.visible_instance_count = _count
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.multimesh = _mm
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.25, 0.55)
	mmi.material_override = mat
	add_child(mmi)
	_spawn(400)

	var cam: Camera3D = Camera3D.new()
	cam.position = Vector3(0, 22, 14)
	add_child(cam)
	cam.look_at(Vector3.ZERO)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	add_child(sun)

	var layer: CanvasLayer = CanvasLayer.new()
	_label = Label.new()
	_label.position = Vector2(40, 120)
	_label.add_theme_font_size_override("font_size", 48)
	layer.add_child(_label)
	add_child(layer)


## Bouton retour du téléphone : retour à l'écran d'accueil.
func _on_back() -> bool:
	get_tree().change_scene_to_file("res://scenes/boot/boot.tscn")
	return true


func _spawn(n: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	_pos.resize(n)
	for i: int in n:
		var a: float = rng.randf() * TAU
		_pos[i] = Vector2(cos(a), sin(a)) * rng.randf_range(ARENA_R * 0.6, ARENA_R)


func _physics_process(delta: float) -> void:
	_t += delta
	_player = Vector2(cos(_t * 0.6), sin(_t * 0.6)) * 5.0
	_grid.clear()
	for i: int in _count:
		_grid.insert(i, _pos[i])
	for i: int in _count:
		var p: Vector2 = _pos[i]
		var steer: Vector2 = (_player - p).normalized() * SPEED
		for j: int in _grid.query_circle(p, ENEMY_R * 2.0):
			if j != i:
				var d: Vector2 = p - _pos[j]
				var l: float = maxf(d.length(), 0.001)
				steer += d / l * (ENEMY_R * 2.0 - l) * 6.0
		p += steer * delta
		if p.length() > ARENA_R:
			p = p.normalized() * ARENA_R
		_pos[i] = p
	for i: int in _count:
		_mm.set_instance_transform(
			i, Transform3D(Basis.IDENTITY, Vector3(_pos[i].x, 0.5, _pos[i].y))
		)


func _process(delta: float) -> void:
	_log_timer += delta
	var fps: int = Engine.get_frames_per_second()
	_label.text = "SPIKE PERF\n%d ennemis\n%d FPS\ntap = +50" % [_count, fps]
	if _log_timer >= 2.0:
		_log_timer = 0.0
		var calls: int = int(
			RenderingServer.get_rendering_info(
				RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
			)
		)
		print("[perf] enemies=%d fps=%d draw_calls=%d" % [_count, fps, calls])


func _unhandled_input(event: InputEvent) -> void:
	var pressed: bool = false
	if event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	elif event is InputEventMouseButton:
		pressed = (event as InputEventMouseButton).pressed
	if pressed:
		_count = mini(_count + 50, 400)
		_mm.visible_instance_count = _count
