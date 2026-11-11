class_name QualityProfile
extends RefCounted
## Profils graphiques Bas / Moyen / Élevé (plan §2.3). Données pures : un profil décrit TOUT ce
## que le gouverneur de qualité (QualityGovernor) change à chaud. Aucun profil ne modifie le
## gameplay (nombre d'ennemis, dégâts, portées) : seul le coût de rendu et d'effets varie.

enum Tier { LOW, MEDIUM, HIGH }

const NAMES: Array[String] = ["Bas", "Moyen", "Élevé"]

var tier: Tier = Tier.MEDIUM
## Budget de pixels du rendu 3D (millions). Le facteur d'échelle 3D en est déduit selon la
## résolution réelle de l'écran : un écran QHD+ n'a pas besoin d'être rendu à pleine résolution
## (l'interface reste nette, elle est dessinée à la résolution native par-dessus).
var render_megapixels: float = 1.6
## Anticrénelage matériel du rendu 3D (Viewport.MSAA_*). Données de profil : QualityManager ne
## l'applique QUE sur ordinateur (voir `effective_msaa`). Sur Android il reste DÉSACTIVÉ : le MSAA
## du moteur Compatibility y est la piste n°1 du plantage en graphisme élevé (phase 6).
var msaa: Viewport.MSAA = Viewport.MSAA_DISABLED
## Contours « cartoon » (seconde passe de rendu des personnages) et épaisseur en pixels d'écran.
var outlines: bool = false
var outline_px: float = 0.0
## Budget de mémoire vidéo (Mo) au-delà duquel le gestionnaire abaisse le profil.
var video_budget_mb: float = 300.0
## Détails de décor animés (écume, scintillements de l'eau).
var water_sparkles: bool = false
## Multiplicateur du nombre de particules émises (en plus de FeelConfig.fx_scale).
var fx_density: float = 1.0
## Capacité utile des lots de particules (<= capacité allouée).
var spark_capacity: int = 256
var puff_capacity: int = 96
var ring_capacity: int = 32
var coin_capacity: int = 48
## Fausses ombres (taches) sous les personnages.
var blob_shadows: bool = true
## Au-delà de cette distance au joueur (m), l'animation squelettique avance 1 tick sur `divisor`.
var far_anim_dist: float = 14.0
var far_anim_divisor: int = 2
## Détail de la mer (0 = aplat simple, 1 = vagues et écume complètes).
var ocean_detail: float = 1.0
## Nombre maximal de sons simultanés (polyphonie).
var max_voices: int = 20
## Image par seconde visée par le moteur.
var max_fps: int = 60


static func for_tier(t: Tier) -> QualityProfile:
	var p: QualityProfile = QualityProfile.new()
	p.tier = t
	match t:
		Tier.LOW:
			p.render_megapixels = 0.95
			p.msaa = Viewport.MSAA_DISABLED
			p.fx_density = 0.45
			p.spark_capacity = 128
			p.puff_capacity = 40
			p.ring_capacity = 16
			p.coin_capacity = 24
			p.blob_shadows = false
			p.far_anim_dist = 9.0
			p.far_anim_divisor = 3
			p.ocean_detail = 0.0
			p.max_voices = 12
			p.outlines = false
			p.video_budget_mb = 220.0
		Tier.MEDIUM:
			p.render_megapixels = 1.45
			p.msaa = Viewport.MSAA_DISABLED
			p.fx_density = 0.75
			p.spark_capacity = 192
			p.puff_capacity = 72
			p.ring_capacity = 24
			p.coin_capacity = 36
			p.blob_shadows = true
			p.far_anim_dist = 12.0
			p.far_anim_divisor = 2
			p.ocean_detail = 0.6
			p.max_voices = 16
			p.outlines = true
			p.outline_px = 2.2
			p.video_budget_mb = 320.0
		Tier.HIGH:
			p.render_megapixels = 2.1
			p.msaa = Viewport.MSAA_2X
			p.outlines = true
			p.outline_px = 2.8
			p.water_sparkles = true
			p.video_budget_mb = 440.0
	return p


static func clamp_tier(value: int) -> Tier:
	return clampi(value, Tier.LOW, Tier.HIGH) as Tier


## Facteur d'échelle du rendu 3D pour un écran de `width` x `height` pixels (1.0 = natif).
## Anticrénelage réellement appliqué : jamais sur mobile (cf. `msaa`).
func effective_msaa(is_mobile: bool) -> Viewport.MSAA:
	return Viewport.MSAA_DISABLED if is_mobile else msaa


func render_scale_for(width: float, height: float) -> float:
	var pixels: float = maxf(width * height, 1.0)
	return clampf(sqrt(render_megapixels * 1.0e6 / pixels), 0.5, 1.0)
