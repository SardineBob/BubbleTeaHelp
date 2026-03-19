## PickupItem.gd
## 掉落物自動吸收腳本
## PLAYER-07：掉落物進入主角拾取範圍後自動吸引，碰觸後套用效果

extends Area2D

# ── 效果設定 ──────────────────────────────────────────────
## 效果類型："xp" 或 "hp"
@export var effect_type: String = "xp"
## 效果數值
@export var effect_value: float = 5.0

# ── 吸引設定（PLAYER-07）────────────────────────────────
## 拾取感應範圍（px），可透過磁石珍珠升級擴大
var pickup_range: float = 80.0
## 吸引移動速度（px/s）
const ATTRACT_SPEED: float = 200.0

# ── 內部狀態 ──────────────────────────────────────────────
var _attracted: bool = false


func _ready() -> void:
	# 連接 body_entered 信號作為備用拾取（玩家碰撞體直接接觸）
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	# 尋找玩家節點
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return

	var player: Node = players[0]
	var dist: float = global_position.distance_to(player.global_position)

	# 進入拾取範圍 → 開始吸引
	if dist < pickup_range:
		_attracted = true

	if _attracted:
		# 移動朝玩家
		var dir: Vector2 = (player.global_position - global_position).normalized()
		global_position += dir * ATTRACT_SPEED * delta

		# 距離夠近 → 套用效果並消失
		if dist < 8.0:
			_apply_effect(player)
			queue_free()


# ── 備用拾取：玩家碰撞體直接進入 ────────────────────────
func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_apply_effect(body)
		queue_free()


# ── 套用效果 ─────────────────────────────────────────────
func _apply_effect(player: Node) -> void:
	match effect_type:
		"xp":
			if player.has_method("add_xp"):
				player.add_xp(effect_value)
		"hp":
			if player.has_method("heal_hp"):
				player.heal_hp(effect_value)
