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
signal boss_spawned
signal game_over(wave: int, coins: int)
signal rewarded_ad_completed

# Ajouts de la phase 2 (communication entre systèmes de partie sans dépendance directe)
signal contact_detected(contacts: int, position: Vector3)
signal turret_fired(turret_id: int, data: TurretData, origin: Vector2, direction: Vector2)
signal axe_hit(enemy_id: int, raw_damage: float, category: int, direction: Vector2)
signal enemy_attack_landed(damage: float, source: Vector2)
signal enemy_spawn_requested(data: EnemyData, position: Vector2, hp_mult: float, damage_mult: float)
