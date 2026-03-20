## Bullet.gd
## 子彈腳本
## COMBAT-01：子彈命中敵人判定
## COMBAT-02：穿透子彈命中多個敵人
## COMBAT-03：範圍爆炸傷害
## COMBAT-04：減速效果施加
## COMBAT-06：子彈超出地圖範圍自動消失
## WEAPON-04：追蹤型子彈持續修正飛行方向

extends Area2D

# ── 基礎設定 ──────────────────────────────────────────────
@export var damage: float = 10.0
@export var speed: float = 300.0
@export var direction: Vector2 = Vector2.RIGHT
@export var max_range: float = 500.0

# ── COMBAT-02：穿透設定 ───────────────────────────────────
@export var piercing: bool = false

# ── COMBAT-03：爆炸設定 ───────────────────────────────────
@export var explosive: bool = false
@export var explosion_radius: float = 80.0

# ── COMBAT-04：減速設定 ───────────────────────────────────
@export var slow_percent: float = 0.0
@export var slow_duration: float = 0.0

# ── WEAPON-04：追蹤設定 ───────────────────────────────────
## 是否為追蹤型子彈（限定草莓珍珠）
@export var homing: bool = false
## 最大轉向角速度（弧度/秒）
@export var homing_turn_speed: float = 2.5

# ── COMBAT-06：地圖邊界（由 World 設定）────────────────────
## 地圖邊界：3200 x 3200，超出邊界 100 px 消失
var map_bounds: Rect2 = Rect2(0, 0, 3200, 3200)
const BOUNDS_MARGIN: float = 100.0

# ── 內部狀態 ──────────────────────────────────────────────
var _travel: float = 0.0
var _hit_enemies: Array[Node] = []


func _physics_process(delta: float) -> void:
	# WEAPON-04：追蹤型子彈逐幀修正方向
	if homing:
		_update_homing(delta)

	var move: Vector2 = direction.normalized() * speed * delta
	global_position += move
	_travel += move.length()

	# COMBAT-06：超出地圖邊界 100 px 自動消失
	var check_bounds: Rect2 = Rect2(
		map_bounds.position.x - BOUNDS_MARGIN,
		map_bounds.position.y - BOUNDS_MARGIN,
		map_bounds.size.x + BOUNDS_MARGIN * 2.0,
		map_bounds.size.y + BOUNDS_MARGIN * 2.0
	)
	if not check_bounds.has_point(global_position):
		queue_free()
		return

	# 超出最大射程 -> 爆炸或消失
	if _travel >= max_range:
		if explosive:
			_explode()
		else:
			queue_free()


# ── WEAPON-04：追蹤方向修正 ───────────────────────────────
func _update_homing(delta: float) -> void:
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemy")
	if enemies.is_empty():
		return

	var nearest: Node = null
	var min_dist: float = INF
	for e in enemies:
		var d: float = global_position.distance_to(e.global_position)
		if d < min_dist:
			min_dist = d
			nearest = e

	if nearest == null:
		return

	var target_dir: Vector2 = (nearest.global_position - global_position).normalized()
	var current_angle: float = direction.angle()
	var target_angle: float = target_dir.angle()

	var angle_diff: float = wrapf(target_angle - current_angle, -PI, PI)
	var max_turn: float = homing_turn_speed * delta
	var turn: float = clamp(angle_diff, -max_turn, max_turn)
	direction = Vector2.from_angle(current_angle + turn)


# ── COMBAT-01/02：碰撞體偵測（Enemy 是 CharacterBody2D，需用 body_entered）
func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("enemy"):
		return

	if body in _hit_enemies:
		return

	_hit_enemies.append(body)

	if body.has_method("take_damage"):
		body.take_damage(damage)

	if slow_percent > 0.0 and body.has_method("apply_slow"):
		body.apply_slow(slow_percent, slow_duration)

	if not piercing:
		if explosive:
			_explode()
		else:
			queue_free()


# ── COMBAT-03：範圍爆炸 ───────────────────────────────────
func _explode() -> void:
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		if enemy in _hit_enemies:
			continue
		var dist: float = global_position.distance_to(enemy.global_position)
		if dist <= explosion_radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage)
			if slow_percent > 0.0 and enemy.has_method("apply_slow"):
				enemy.apply_slow(slow_percent, slow_duration)

	queue_free()


func _ready() -> void:
	body_entered.connect(_on_body_entered)
