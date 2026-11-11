class_name ToonStyle
extends RefCounted
## Style cartoon partagé (phase 6) : branche / débranche la passe de CONTOUR du matériau toon
## selon le profil de qualité. Le matériau palette est unique : un seul réglage pour tout le jeu.
## Profil BAS : pas de contour (la seconde passe double le coût des personnages).

const OUTLINE_SHADER: Shader = preload("res://assets/shaders/ax_outline.gdshader")

static var _outline: ShaderMaterial = null


static func outline_material() -> ShaderMaterial:
	if _outline == null:
		_outline = ShaderMaterial.new()
		_outline.shader = OUTLINE_SHADER
		_outline.set_shader_parameter(
			&"albedo_tex", ModelRig.PALETTE.get_shader_parameter(&"albedo_tex")
		)
	return _outline


static func apply_profile(p: QualityProfile) -> void:
	var pal: ShaderMaterial = ModelRig.PALETTE
	if p.outlines:
		var mat: ShaderMaterial = outline_material()
		mat.set_shader_parameter(&"outline_px", p.outline_px)
		pal.next_pass = mat
	else:
		pal.next_pass = null
