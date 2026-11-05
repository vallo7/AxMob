class_name Arena
extends Node3D
## Arène circulaire : sol, bordure lisible, décor minimal (direction artistique D4, « pierre »).
## Primitives temporaires jusqu'en phase 4.


func setup(cfg: GameConfig) -> void:
	var floor_mesh: CylinderMesh = CylinderMesh.new()
	floor_mesh.top_radius = cfg.arena_radius
	floor_mesh.bottom_radius = cfg.arena_radius
	floor_mesh.height = 0.3
	floor_mesh.radial_segments = 48
	var floor_instance: MeshInstance3D = MeshInstance3D.new()
	floor_instance.mesh = floor_mesh
	floor_instance.position.y = -0.15
	var floor_mat: StandardMaterial3D = StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.26, 0.28, 0.33)
	floor_instance.material_override = floor_mat
	add_child(floor_instance)

	var border_mesh: TorusMesh = TorusMesh.new()
	border_mesh.inner_radius = cfg.arena_radius - 0.12
	border_mesh.outer_radius = cfg.arena_radius + 0.25
	border_mesh.rings = 64
	border_mesh.ring_segments = 8
	var border: MeshInstance3D = MeshInstance3D.new()
	border.mesh = border_mesh
	border.position.y = 0.05
	var border_mat: StandardMaterial3D = StandardMaterial3D.new()
	border_mat.albedo_color = Color(0.1, 0.1, 0.13)
	border_mat.emission_enabled = true
	border_mat.emission = Color(0.93, 0.47, 0.12)
	border_mat.emission_energy_multiplier = 0.35
	border.material_override = border_mat
	add_child(border)

	var outer_mesh: CylinderMesh = CylinderMesh.new()
	outer_mesh.top_radius = cfg.arena_radius + 60.0
	outer_mesh.bottom_radius = cfg.arena_radius + 60.0
	outer_mesh.height = 0.1
	outer_mesh.radial_segments = 32
	var outer: MeshInstance3D = MeshInstance3D.new()
	outer.mesh = outer_mesh
	outer.position.y = -0.4
	var outer_mat: StandardMaterial3D = StandardMaterial3D.new()
	outer_mat.albedo_color = Color(0.1, 0.11, 0.14)
	outer.material_override = outer_mat
	add_child(outer)
