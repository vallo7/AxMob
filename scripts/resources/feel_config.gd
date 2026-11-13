class_name FeelConfig
extends Resource
## Réglages de « game feel » de la phase 5 : caméra, secousses, impacts, effets. Tout est
## modifiable dans l'inspecteur (resources/balancing/feel_config.tres) sans toucher au code.
## Ces valeurs sont des hypothèses de départ, à régler au toucher sur téléphone.

@export_group("Caméra : angle et cadrage")
## Élévation de la caméra (90 = vue de dessus pure). Phase 4 : 70. Plus bas = plus en plongée.
@export_range(35.0, 85.0, 0.5) var pitch_degrees: float = 46.0
@export_range(25.0, 80.0, 0.5) var fov_degrees: float = 34.0
## Part du déplacement du joueur suivie par la caméra (0 = cadrage fixe).
@export_range(0.0, 1.0, 0.005) var follow_factor: float = 0.82
## Anticipation : la caméra regarde un peu devant le joueur (secondes de vitesse).
@export_range(0.0, 1.0, 0.01) var lead_seconds: float = 0.35
@export_range(1.0, 12.0, 0.1) var follow_smoothing: float = 4.0
## Décale le point visé vers le bas de l'écran (fraction de la largeur visible).
@export_range(0.0, 0.3, 0.005) var frame_shift_ratio: float = 0.07

@export_group("Caméra : mouvement dynamique")
## Inclinaison latérale max (degrés) quand le joueur court : sensation de vitesse.
@export_range(0.0, 5.0, 0.1) var bank_degrees: float = 1.6
@export_range(1.0, 15.0, 0.1) var bank_smoothing: float = 6.0
## Variation d'élévation à pleine vitesse (négatif = un peu plus en plongée en courant).
@export_range(-6.0, 6.0, 0.1) var pitch_run_delta_deg: float = -1.8
## Dé-zoom progressif quand la foule se resserre (fraction de la distance, à `crowd_full` ennemis).
@export_range(0.0, 0.08, 0.001) var crowd_zoom_out: float = 0.02
@export_range(1, 60) var crowd_full: int = 30
## Coup de zoom (fraction de la distance, négatif = on se rapproche) au déclenchement du combat,
## sur un impact de zone et sur un coup subi.
@export_range(0.0, 0.05, 0.001) var punch_combat: float = 0.010
@export_range(0.0, 0.08, 0.001) var punch_splash: float = 0.022
@export_range(0.0, 0.08, 0.001) var punch_hurt: float = 0.016
## Ressort du zoom : raideur et amortissement (sous-amorti = petit rebond).
@export_range(40.0, 400.0, 1.0) var spring_stiffness: float = 190.0
@export_range(4.0, 40.0, 0.5) var spring_damping: float = 15.0

@export_group("Caméra : secousses")
## 0 = aucune secousse (accessibilité) ; 1 = normal.
@export_range(0.0, 2.0, 0.05) var shake_scale: float = 1.0
@export_range(0.0, 1.0, 0.01) var shake_max_offset: float = 0.32
@export_range(0.0, 6.0, 0.1) var shake_max_roll_deg: float = 2.0
@export_range(0.2, 6.0, 0.05) var shake_decay: float = 2.0
@export var trauma_hurt: float = 0.30
@export var trauma_splash: float = 0.14
@export var trauma_slam: float = 0.65
@export var trauma_boss_death: float = 0.95
@export var trauma_boss_phase: float = 0.45

@export_group("Impacts")
## Arrêt sur image (secondes réelles) sur un impact de zone touchant au moins `hitstop_min_hits`
## ennemis, et sur la mort du boss. 0 = désactivé.
@export_range(0.0, 0.12, 0.005) var hitstop_splash: float = 0.04
@export var hitstop_min_hits: int = 2
@export_range(0.0, 0.3, 0.005) var hitstop_boss_death: float = 0.10
## Ralenti à la mort du boss : durée (s) et échelle de temps.
@export_range(0.0, 2.0, 0.05) var slowmo_boss_death_time: float = 0.9
@export_range(0.1, 1.0, 0.05) var slowmo_boss_death_scale: float = 0.35
## Série d'éliminations : au-delà de ce nombre en `multikill_window` s, anneau et son montant.
@export var multikill_count: int = 4
@export_range(0.1, 2.0, 0.05) var multikill_window: float = 0.6

@export_group("Effets visuels")
## Multiplie le nombre de particules (le profil de qualité s'y ajoute).
@export_range(0.0, 2.0, 0.05) var fx_scale: float = 1.0
@export_range(0.0, 1.0, 0.05) var coin_pop_chance: float = 1.0
## Durée de vol d'une pièce vers le joueur (s) ; la pièce est déjà créditée, c'est cosmétique.
@export_range(0.2, 2.0, 0.05) var coin_fly_time: float = 0.55

@export_group("Animation des haches")
@export_range(0.0, 3.0, 0.05) var axe_wobble_scale: float = 1.0
@export_range(0.0, 3.0, 0.05) var axe_pop_scale: float = 1.0


## Facteur global de secousse (réglage joueur d'accessibilité x profil).
func shake_amount() -> float:
	return shake_scale
