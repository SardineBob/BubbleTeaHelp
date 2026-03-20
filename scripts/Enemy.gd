## Enemy.gd
## 敵人基礎腳本
## ENEMY-01：敵人朝主角移動（待 ENEMY-01 issue 完成時擴充速度表）
## ENEMY-02：受到傷害視覺回饋（待 ENEMY-02 issue 完成）
## COMBAT-05：擊殺時機率觸發爆炸

extends CharacterBody2D

# ── 基礎設定 ──────────────────────────────────────────────
## 敵人最大 HP
@export var max_hp: float = 30.0
## 移動速度（px/s），預設路人甲
@export var speed: float = 80.0
## 接觸玩家造成的傷害
@export var contact_damage: float = 10.0

# ── COMBAT-05：爆炸設定 ───────────────────────────────────
## 爆炸半徑（同 COMBAT-03 預設值）
const COMBAT05_EXPLOSION_RADIUS: float = 80.0
## 每升級層數增加的爆炸觸發機率
const COMBAT05_CHANCE_PER_LEVEL: float = 0.1

# ── 內部狀態 ──────────────────────────────────────────────
var hp: float = 0.0
var _player: Node = null
var _is_dead: bool = false


func _ready() -> void:
	add_to_group("enemy")
	hp = max_hp

	# 取得玩家參考（等一幀確保 World 場景完成初始化）
	await get_tree().process_frame
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]


func _physics_process(_delta: float) -> void:
	# ENEMY-01：朝主角移動（待 ENEMY-01 實作時可在此擴充速度表）
	if _is_dead or _player == null:
		return
	var dir: Vector2 = (_player.global_position - global_position).normalized()
	velocity = dir * speed
	move_and_slide()


# ── 受傷 ──────────────────────────────────────────────────
## 由子彈或範圍傷害呼叫
func take_damage(amount: float) -> void:
	if _is_dead:
		return
	hp -= amount
	# ENEMY-02：受傷視覺回饋（待 ENEMY-02 實作）
	if hp <= 0.0:
		_die()


# ── 死亡流程 ──────────────────────────────────────────────
func _die() -> void:
	_is_dead = true
	velocity = Vector2.ZERO

	# COMBAT-05：擊殺時機率觸發珍珠爆裂爆炸
	_try_pearl_burst_explosion()

	queue_free()


# ── COMBAT-05：珍珠爆裂爆炸 ──────────────────────────────
func _try_pearl_burst_explosion() -> void:
	# 需要玩家有珍珠爆裂升級（UPGRADE-04）
	if _player == null:
		return
	if not _player.has_method("get_pearl_burst_level"):
		return

	var level: int = _player.get_pearl_burst_level()
	if level <= 0:
		return

	# 每層 10% 觸發機率
	var chance: float = level * COMBAT05_CHANCE_PER_LEVEL
	if randf() >= chance:
		return

	# 觸發爆炸：對死亡位置半徑內所有其他敵人造成傷害（同 COMBAT-03）
	var explosion_pos: Vector2 = global_position
	var explosion_damage: float = 10.0

	# 若玩家提供武器傷害介面則使用之
	if _player.has_method("get_weapon_damage"):
		explosion_damage = _player.get_weapon_damage()

	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		if enemy == self:
			continue
		var dist: float = explosion_pos.distance_to(enemy.global_position)
		if dist <= COMBAT05_EXPLOSION_RADIUS:
			if enemy.has_method("take_damage"):
				enemy.take_damage(explosion_damage)

	print("[COMBAT-05] 珍珠爆裂觸發！位置：", explosion_pos, "，層數：", level, "，機率：", chance * 100, "%")
