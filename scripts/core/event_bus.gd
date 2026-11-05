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
