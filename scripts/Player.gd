## Player.gd
## 玩家角色控制腳本
## PLAYER-02：依輸入方向移動（速度 120 px/s，支援 8 方向）
## PLAYER-03：放開輸入時立即停止
## PLAYER-04：受到敵人接觸傷害（每 0.5 秒最多一次）
## PLAYER-05：回血（不超過 max_hp）
## PLAYER-06：HP 歸零觸發死亡流程

extends CharacterBody2D

# ── 移動設定（PLAYER-02）─────────────────────────────────
## 玩家每秒移動速度（px/s）
@export var speed: float = 120.0

## 地圖邊界（由 World 設定，預設 1280×720）
@export var map_bounds: Rect2 = Rect2(0.0, 0.0, 1280.0, 720.0)

# ── 生命值設定（PLAYER-04/05/06）────────────────────────
@export var max_hp: float = 100.0
var hp: float = 100.0

# ── 傷害冷卻（PLAYER-04）────────────────────────────────
const DAMAGE_COOLDOWN: float = 0.5
var _dmg_timer: float = 0.0

# ── 死亡狀態（PLAYER-06）────────────────────────────────
var _is_dead: bool = false

# ── 碰撞尺寸（for boundary clamp）───────────────────────
const _HALF_W: float = 16.0
const _HALF_H: float = 22.0   # 與碰撞圓半徑對齊

# ── 信號 ─────────────────────────────────────────────────
## HP 變動時發送（供 HUD 血條使用）
signal hp_changed(current: float, maximum: float)
## 玩家死亡時發送（供 World / FLOW-04 監聽）
signal player_died

# ── 節點參考 ─────────────────────────────────────────────
@onready var _sprite: ColorRect = $Sprite


func _ready() -> void:
	add_to_group("player")
	print("玩家已生成，位置：", global_position)
	hp_changed.emit(hp, max_hp)


# ── PLAYER-07：經驗值獲取（供 PickupItem 呼叫）────────────
## 獲得 XP，具體升級邏輯待 LEVEL-UP 系統實作
func add_xp(amount: float) -> void:
	print("[PLAYER-07] 獲得 XP：", amount)


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	# 更新傷害冷卻計時
	if _dmg_timer > 0.0:
		_dmg_timer -= delta

	# ── PLAYER-02/03：移動輸入 ───────────────────────────
	var dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	# PLAYER-02：有輸入 → 朝方向移動（normalize 保證斜向速度一致）
	# PLAYER-03：無輸入 → 速度立即歸零
	velocity = dir.normalized() * speed if dir != Vector2.ZERO else Vector2.ZERO

	move_and_slide()

	# ── PLAYER-02：地圖邊界限制 ──────────────────────────
	global_position.x = clamp(
		global_position.x,
		map_bounds.position.x + _HALF_W,
		map_bounds.position.x + map_bounds.size.x - _HALF_W
	)
	global_position.y = clamp(
		global_position.y,
		map_bounds.position.y + _HALF_H,
		map_bounds.position.y + map_bounds.size.y - _HALF_H
	)


# ── PLAYER-04：受到敵人接觸傷害 ──────────────────────────
## 由敵人碰撞回呼呼叫，amount 為該敵人的傷害值
func take_damage(amount: float) -> void:
	if _is_dead:
		return
	if _dmg_timer > 0.0:
		return  # 0.5 秒內已受傷，忽略此次傷害

	_dmg_timer = DAMAGE_COOLDOWN
	hp = max(hp - amount, 0.0)
	hp_changed.emit(hp, max_hp)

	_flash_red()   # 受傷閃爍回饋

	if hp <= 0.0:
		_die()


# ── PLAYER-05：回血 ───────────────────────────────────────
## 由升級技能（回收紙吸管）呼叫
func heal_hp(amount: float) -> void:
	if _is_dead:
		return
	hp = min(hp + amount, max_hp)
	hp_changed.emit(hp, max_hp)


# ── PLAYER-06：死亡流程 ───────────────────────────────────
func _die() -> void:
	_is_dead = true
	velocity = Vector2.ZERO

	# 死亡動畫：變灰
	_sprite.color = Color(0.55, 0.55, 0.55, 1.0)

	# 通知 World（FLOW-04 切換由 World 處理）
	player_died.emit()

	# 2 秒後觸發死亡結算（FLOW-04 場景，待實作時取消註解）
	await get_tree().create_timer(2.0).timeout
	# get_tree().change_scene_to_file("res://scenes/DeathScreen.tscn")
	print("[PLAYER-06] 死亡動畫完成，等待 FLOW-04 切換")


# ── 受傷閃爍（視覺回饋）─────────────────────────────────
func _flash_red() -> void:
	_sprite.color = Color(1.0, 0.2, 0.2, 1.0)
	await get_tree().create_timer(0.1).timeout
	if not _is_dead:
		_sprite.color = Color(0.502, 0.333, 0.169, 1.0)
