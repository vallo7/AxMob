class_name EventRecorder
extends RefCounted
## Enregistre les événements EventBus d'un scénario (compteurs, récompenses, identifiants).

var counts: Dictionary = {}
var reward_sum: int = 0
var died_ids: Array[int] = []
var coins_history: Array[int] = []


func start() -> void:
	for key: String in ["fired", "hit", "combat", "died", "damaged", "game_over"]:
		counts[key] = 0
	EventBus.turret_fired.connect(_on_fired)
	EventBus.enemy_hit.connect(_on_hit)
	EventBus.combat_activated.connect(_on_combat)
	EventBus.player_damaged.connect(_on_damaged)
	EventBus.game_over.connect(_on_game_over)
	EventBus.enemy_died.connect(_on_died)
	EventBus.coins_changed.connect(_on_coins)


func stop() -> void:
	EventBus.turret_fired.disconnect(_on_fired)
	EventBus.enemy_hit.disconnect(_on_hit)
	EventBus.combat_activated.disconnect(_on_combat)
	EventBus.player_damaged.disconnect(_on_damaged)
	EventBus.game_over.disconnect(_on_game_over)
	EventBus.enemy_died.disconnect(_on_died)
	EventBus.coins_changed.disconnect(_on_coins)


func n(key: String) -> int:
	return counts[key] as int


func _bump(key: String) -> void:
	counts[key] = (counts[key] as int) + 1


func _on_fired(_i: int, _d: TurretData, _o: Vector2, _dir: Vector2) -> void:
	_bump("fired")


func _on_hit(_i: int, _d: float) -> void:
	_bump("hit")


func _on_combat(_c: int, _p: Vector3) -> void:
	_bump("combat")


func _on_damaged(_a: float, _h: float) -> void:
	_bump("damaged")


func _on_game_over(_w: int, _c: int) -> void:
	_bump("game_over")


func _on_died(enemy_id: int, reward: int, _pos: Vector3) -> void:
	_bump("died")
	reward_sum += reward
	died_ids.append(enemy_id)


func _on_coins(total: int) -> void:
	coins_history.append(total)
