## PickupItem.gd
## 掉落物自動吸收腳本
## PLAYER-07：掉落物進入主角拾取範圍後自動吸引，碰觸後套用效果
## UPGRADE-01：XP 掉落物
## UPGRADE-02：主角吸收後累積 XP

extends Area2D

# ── 效果設定 ──────────────────────────────────────────────
@export var effect_type: String = "xp"
@export var effect_value: float = 5.0

# ── 拾取設定（PLAYER-07）────────────────────────────────
## 基礎拾取感應範圍（px）
var pickup_range: float = 80.0
const ATTRACT_SPEED: float = 200.0
const BASE_PICKUP_RANGE: float = 80.0

var _attracted: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return

	var player: Node = players[0]

	# 動態取得拾取範圍加成（磁石珍珠升級）
	var effective_range: float = BASE_PICKUP_RANGE
	if player.has_method("get_pickup_range_bonus"):
		effective_range += player.get_pickup_range_bonus()
	pickup_range = effective_range

	var dist: float = global_position.distance_to(player.global_position)

	if dist < pickup_range:
		_attracted = true

	if _attracted:
		var dir: Vector2 = (player.global_position - global_position).normalized()
		global_position += dir * ATTRACT_SPEED * delta

		if dist < 8.0:
			_apply_effect(player)
			queue_free()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_apply_effect(body)
		queue_free()


func _apply_effect(player: Node) -> void:
	match effect_type:
		"xp":
			if player.has_method("add_xp"):
				player.add_xp(effect_value)
		"hp":
			if player.has_method("heal_hp"):
				player.heal_hp(effect_value)
