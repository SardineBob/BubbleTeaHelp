## Bullet.gd
## 子彈腳本
## COMBAT-01：子彈命中敵人判定
## COMBAT-02：穿透子彈命中多個敵人
## COMBAT-03：範圍爆炸傷害
## COMBAT-04：減速效果施加

extends Area2D

# ── 基礎設定 ──────────────────────────────────────────────
## 子彈傷害值
@export var damage: float = 10.0
## 飛行速度（px/s）
@export var speed: float = 300.0
## 飛行方向（正規化向量）
@export var direction: Vector2 = Vector2.RIGHT
## 最大射程（px）
@export var max_range: float = 500.0

# ── COMBAT-02：穿透設定 ───────────────────────────────────
## 是否為穿透型子彈（燕麥珍珠）
@export var piercing: bool = false

# ── COMBAT-03：爆炸設定 ───────────────────────────────────
## 是否為爆炸型子彈（黑糖爆爆珠）
@export var explosive: bool = false
## 爆炸半徑（px）
@export var explosion_radius: float = 80.0

# ── COMBAT-04：減速設定 ───────────────────────────────────
## 減速幅度（0.0 = 無減速，0.3 = 減速 30%）
@export var slow_percent: float = 0.0
## 減速持續時間（秒）
@export var slow_duration: float = 0.0

# ── 內部狀態 ──────────────────────────────────────────────
## 已行進距離
var _travel: float = 0.0
## 已命中的敵人列表（COMBAT-02：防止對同一敵人重複傷害）
var _hit_enemies: Array[Node] = []


func _physics_process(delta: float) -> void:
	# 移動子彈
	var move: Vector2 = direction.normalized() * speed * delta
	global_position += move
	_travel += move.length()

	# 超出最大射程 → 爆炸或消失
	if _travel >= max_range:
		if explosive:
			_explode()
		else:
			queue_free()


# ── COMBAT-01/02：碰撞區域偵測 ───────────────────────────
func _on_area_entered(area: Node) -> void:
	# 僅處理敵人碰撞箱
	if not area.is_in_group("enemy"):
		return

	# COMBAT-02：穿透子彈防止對同一敵人重複傷害
	if area in _hit_enemies:
		return

	_hit_enemies.append(area)

	# COMBAT-01：對敵人造成傷害
	if area.has_method("take_damage"):
		area.take_damage(damage)

	# COMBAT-04：施加減速效果
	if slow_percent > 0.0 and area.has_method("apply_slow"):
		area.apply_slow(slow_percent, slow_duration)

	# COMBAT-01：非穿透子彈命中後消失
	if not piercing:
		if explosive:
			_explode()
		else:
			queue_free()
	# COMBAT-02：穿透子彈繼續飛行（不消失）


# ── COMBAT-03：範圍爆炸 ───────────────────────────────────
func _explode() -> void:
	# 對爆炸半徑內所有敵人造成傷害
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		# 防止對已命中的敵人重複傷害（穿透爆炸情況）
		if enemy in _hit_enemies:
			continue
		var dist: float = global_position.distance_to(enemy.global_position)
		if dist <= explosion_radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage)
			# COMBAT-04：爆炸子彈同樣可施加減速
			if slow_percent > 0.0 and enemy.has_method("apply_slow"):
				enemy.apply_slow(slow_percent, slow_duration)

	queue_free()


func _ready() -> void:
	# 連接 area_entered 信號
	area_entered.connect(_on_area_entered)
