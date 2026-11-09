extends Node
## Signaux globaux typés. Aucun état : les systèmes de partie ne se connaissent pas,
## ils communiquent ici (voir plan §2.2).

signal run_started
signal run_paused(paused: bool)
signal combat_activated(contacts: int, position: Vector3)
signal enemy_hit(enemy_id: int, damage: float)
signal enemy_died(enemy_id: int, reward: int, position: Vector3)
signal player_damaged(amount: float, hp_left: float)
signal player_died
signal coins_changed(total: int)
signal turret_upgraded(turret_id: int, level: int)
signal wave_started(wave: int)
signal wave_completed(wave: int)
signal boss_spawned(enemy_id: int)
signal game_over(wave: int, coins: int)
signal rewarded_ad_completed

# Ajouts de la phase 2 (communication entre systèmes de partie sans dépendance directe)
signal contact_detected(contacts: int, position: Vector3)
signal turret_fired(turret_id: int, data: TurretData, origin: Vector2, direction: Vector2)
signal axe_hit(enemy_id: int, raw_damage: float, category: int, direction: Vector2)
signal enemy_attack_landed(damage: float, source: Vector2)
signal enemy_spawn_requested(data: EnemyData, position: Vector2, level: int)

# Ajouts de la phase 3 (boss, améliorations, retour haptique)
signal boss_warning(wave: int, seconds: float, position: Vector2)
signal boss_phase_changed(enemy_id: int, phase: int)
signal boss_defeated(enemy_id: int, reward: int)
signal shockwave(position: Vector2, radius: float)
signal upgrade_denied(turret_id: int)

# Ajouts de la phase 5 (game feel : effets, son, caméra, performance)
## Impact de zone (hache lourde) : centre, rayon, dégâts bruts AU CENTRE de la zone, catégorie,
## ennemi touché en direct (déjà frappé : exclu de la zone), part des dégâts restante au bord,
## vitesse de repoussement au centre. `axe_splash_resolved` donne ensuite le nombre de touchés.
signal axe_splash(
	position: Vector2,
	radius: float,
	raw_damage: float,
	category: int,
	source_id: int,
	falloff: float,
	knockback: float
)
signal axe_splash_resolved(position: Vector2, radius: float, hits: int)
signal enemy_spawned(enemy_id: int, position: Vector2)
## Une pièce (cosmétique) arrive au joueur : `streak` = nombre de pièces récentes (hauteur du son).
signal coin_collected(streak: int)
## Série d'éliminations rapprochées (anneau + son montant).
signal multi_kill(count: int, position: Vector3)
## Arrêt sur image / ralenti demandé : durée en secondes RÉELLES, échelle de temps pendant.
signal time_punch(duration: float, scale: float)
signal quality_changed(tier: int)
## Un pas du héros (son de pas dans le sable) ; `speed_ratio` 0..1 règle le volume.
signal player_step(speed_ratio: float)
## Un ennemi arme son attaque (`charging` : charge télégraphiée du boss) : son d'avertissement.
signal enemy_windup(enemy_id: int, charging: bool)
