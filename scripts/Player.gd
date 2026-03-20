## Player.gd
## 玩家角色控制腳本
## PLAYER-02：依輸入方向移動（速度 120 px/s，支援 8 方向）
## PLAYER-03：放開輸入時立即停止
## PLAYER-04：受到敵人接觸傷害（每 0.5 秒最多一次）
## PLAYER-05：回血（不超過 max_hp）
## PLAYER-06：HP 歸零觸發死亡流程
## PLAYER-07：XP 吸收
## UPGRADE-02：XP 累積，達標觸發 UPGRADE-03
## UPGRADE-04（介面）：珍珠爆裂等級，供 COMBAT-05 查詢
## WEAPON-01：自動鎖定最近敵人
## WEAPON-02：冷卻結束後自動射擊
## WEAPON-03：霰彈（芋頭珍珠 / 珍珠加量）
## WEAPON-05/06：武器解鎖與多武器管理
## MAP-01：地圖邊界限制
## MAP-02（camera lerp 在 World.gd 實作）

extends CharacterBody2D

# ── 移動設定（PLAYER-02）─────────────────────────────────
@export var speed: float = 120.0
@export var map_bounds: Rect2 = Rect2(0.0, 0.0, 3200.0, 3200.0)

# ── 生命值（PLAYER-04/05/06）────────────────────────────
@export var max_hp: float = 100.0
var hp: float = 100.0

# ── 傷害冷卻（PLAYER-04）────────────────────────────────
const DAMAGE_COOLDOWN: float = 0.5
var _dmg_timer: float = 0.0

# ── 死亡狀態（PLAYER-06）────────────────────────────────
var _is_dead: bool = false

# ── UPGRADE 狀態（UPGRADE-04 珍珠爆裂）──────────────────
var _pearl_burst_level: int = 0

# ── 升級屬性（UPGRADE-04 全升級清單）────────────────────
var _pearl_add_level: int = 0        ## 珍珠加量：子彈數量 +1/層，最高 5
var _max_hp_bonus: float = 0.0       ## 特濃奶茶：max_hp +20/層，最高 5
var _speed_bonus_pct: float = 0.0    ## 輕盈杯身：速度 +15%/層，最高 3
var _damage_reduce_pct: float = 0.0  ## 奶蓋防禦：受傷 -10%/層，最高 5
var _bullet_speed_pct: float = 0.0   ## QQ彈力：子彈速度 +20%/層，最高 3
var _fire_cooldown_bonus: float = 0.0 ## 糖分暴衝：冷卻 -0.05s/層，最高 5
var _pickup_range_bonus: float = 0.0 ## 磁石珍珠：拾取範圍 +50px/層，最高 3
var _range_bonus_pct: float = 0.0    ## 吸管延伸：射程 +25%/層，最高 3
var _lifesteal_level: int = 0        ## 回收紙吸管：擊殺回血 1HP/層，最高 3

# ── XP / 等級（UPGRADE-02/03）────────────────────────────
var xp: float = 0.0
var level: int = 1
var _xp_to_next: float = 10.0
## 每次升級所需 XP 序列（index 0 = Lv1->Lv2）
const XP_TABLE: Array[float] = [10.0, 18.0, 28.0, 42.0, 60.0, 85.0, 120.0,
                                  160.0, 210.0, 270.0, 340.0, 420.0, 510.0,
                                  610.0, 720.0, 840.0, 970.0, 1110.0, 1260.0,
                                  1420.0, 1590.0, 1770.0, 1960.0, 2160.0,
                                  2370.0, 2590.0, 2820.0, 3060.0, 3310.0]
const MAX_LEVEL: int = 30

# ── WEAPON-01/02：武器系統 ────────────────────────────────
## 當前已裝備武器列表（字串 ID），初始只有黑糖珍珠
var equipped_weapons: Array[String] = ["black_sugar"]
## 各武器冷卻計時（秒）
var _weapon_cooldowns: Dictionary = {}
## 武器設定表
var _weapon_stats: Dictionary = {
	"black_sugar":  {"damage": 1.0,  "cooldown": 0.35, "bullet_speed": 350.0, "range": 500.0, "piercing": false, "explosive": false, "homing": false, "spread": 0},
	"matcha":       {"damage": 2.0,  "cooldown": 0.55, "bullet_speed": 300.0, "range": 500.0, "piercing": false, "explosive": false, "homing": false, "spread": 0},
	"taro":         {"damage": 1.0,  "cooldown": 0.50, "bullet_speed": 280.0, "range": 500.0, "piercing": false, "explosive": false, "homing": false, "spread": 3},
	"popping_boba": {"damage": 3.0,  "cooldown": 0.80, "bullet_speed": 250.0, "range": 500.0, "piercing": false, "explosive": true,  "homing": false, "spread": 0},
	"oat":          {"damage": 1.0,  "cooldown": 0.15, "bullet_speed": 500.0, "range": 500.0, "piercing": true,  "explosive": false, "homing": false, "spread": 0},
	"strawberry":   {"damage": 5.0,  "cooldown": 1.20, "bullet_speed": 200.0, "range": 600.0, "piercing": false, "explosive": false, "homing": true,  "spread": 0},
}
## 武器解鎖狀態（WEAPON-05）
var _weapon_unlocked: Dictionary = {
	"black_sugar": true,
	"matcha":      false,
	"taro":        false,
	"popping_boba":false,
	"oat":         false,
	"strawberry":  false,
}
## 武器加入升級池的狀態
var _weapon_in_pool: Dictionary = {
	"black_sugar": false,
	"matcha":      false,
	"taro":        false,
	"popping_boba":false,
	"oat":         false,
	"strawberry":  false,
}

## 子彈場景（由 World 或 Inspector 指定）
var bullet_scene: PackedScene = null

# ── WEAPON-01：目標敵人 ──────────────────────────────────
var _target_enemy: Node = null

# ── 碰撞尺寸 ──────────────────────────────────────────────
const _HALF_W: float = 16.0
const _HALF_H: float = 22.0

# ── 信號 ─────────────────────────────────────────────────
signal hp_changed(current: float, maximum: float)
signal player_died
signal xp_changed(current: float, needed: float, lv: int)
signal level_up_triggered(level: int)
signal kill_count_changed(count: int)

# ── 擊殺計數 ──────────────────────────────────────────────
var kill_count: int = 0

# ── 節點參考 ─────────────────────────────────────────────
@onready var _sprite: ColorRect = $Sprite


func _ready() -> void:
	add_to_group("player")
	hp = max_hp
	# 初始化武器冷卻
	for w in equipped_weapons:
		_weapon_cooldowns[w] = 0.0
	if bullet_scene == null:
		bullet_scene = load("res://scenes/Bullet.tscn")
	hp_changed.emit(hp, max_hp)
	print("玩家已生成，位置：", global_position)


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	if _dmg_timer > 0.0:
		_dmg_timer -= delta

	# PLAYER-02/03：移動
	var dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var effective_speed: float = speed * (1.0 + _speed_bonus_pct)
	velocity = dir.normalized() * effective_speed if dir != Vector2.ZERO else Vector2.ZERO
	move_and_slide()

	# MAP-01：地圖邊界限制
	global_position.x = clamp(global_position.x, map_bounds.position.x + _HALF_W, map_bounds.position.x + map_bounds.size.x - _HALF_W)
	global_position.y = clamp(global_position.y, map_bounds.position.y + _HALF_H, map_bounds.position.y + map_bounds.size.y - _HALF_H)

	# WEAPON-01：鎖定最近敵人
	_find_target()

	# WEAPON-02：更新武器冷卻並射擊
	_update_weapons(delta)


# ── WEAPON-01：自動鎖定最近敵人 ─────────────────────────
func _find_target() -> void:
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemy")
	if enemies.is_empty():
		_target_enemy = null
		return
	var nearest: Node = null
	var min_dist: float = INF
	for e in enemies:
		var d: float = global_position.distance_to(e.global_position)
		if d < min_dist:
			min_dist = d
			nearest = e
	_target_enemy = nearest


# ── WEAPON-02：冷卻射擊 ──────────────────────────────────
func _update_weapons(delta: float) -> void:
	if _target_enemy == null or not is_instance_valid(_target_enemy):
		# 計時仍正常更新
		for w in equipped_weapons:
			if _weapon_cooldowns.has(w):
				_weapon_cooldowns[w] = max(_weapon_cooldowns[w] - delta, 0.0)
		return

	for w in equipped_weapons:
		if not _weapon_cooldowns.has(w):
			_weapon_cooldowns[w] = 0.0

		_weapon_cooldowns[w] -= delta
		if _weapon_cooldowns[w] <= 0.0:
			var stats: Dictionary = _weapon_stats.get(w, {})
			var cd: float = max(stats.get("cooldown", 0.35) - _fire_cooldown_bonus, 0.05)
			_weapon_cooldowns[w] = cd
			_fire_weapon(w, stats)


func _fire_weapon(weapon_id: String, stats: Dictionary) -> void:
	if bullet_scene == null:
		return
	var base_dir: Vector2 = (_target_enemy.global_position - global_position).normalized()
	var bullet_speed: float = stats.get("bullet_speed", 350.0) * (1.0 + _bullet_speed_pct)
	var b_damage: float = stats.get("damage", 1.0)
	var b_range: float = stats.get("range", 500.0) * (1.0 + _range_bonus_pct)
	var piercing: bool = stats.get("piercing", false)
	var explosive: bool = stats.get("explosive", false)
	var homing: bool = stats.get("homing", false)

	# WEAPON-03：霰彈（芋頭珍珠 spread > 0，或珍珠加量升級）
	var spread_count: int = stats.get("spread", 0)
	if _pearl_add_level > 0 and weapon_id == "black_sugar":
		spread_count = _pearl_add_level

	if spread_count > 1:
		# 均勻分散角度
		var spread_angle: float = 0.4 if weapon_id == "taro" else 0.3
		var start_angle: float = base_dir.angle() - spread_angle
		var step: float = (spread_angle * 2.0) / float(spread_count - 1)
		for i in range(spread_count):
			var shot_dir: Vector2 = Vector2.from_angle(start_angle + step * float(i))
			_spawn_bullet(shot_dir, bullet_speed, b_damage, b_range, piercing, explosive, homing)
	else:
		_spawn_bullet(base_dir, bullet_speed, b_damage, b_range, piercing, explosive, homing)


func _spawn_bullet(dir: Vector2, spd: float, dmg: float, rng: float, pierce: bool, expl: bool, hm: bool) -> void:
	var bullet: Node = bullet_scene.instantiate()
	get_parent().add_child(bullet)
	bullet.global_position = global_position
	if bullet.has_method("set") or true:
		bullet.set("direction", dir)
		bullet.set("speed", spd)
		bullet.set("damage", dmg)
		bullet.set("max_range", rng)
		bullet.set("piercing", pierce)
		bullet.set("explosive", expl)
		bullet.set("homing", hm)
		bullet.set("map_bounds", map_bounds)


# ── PLAYER-04：受到敵人接觸傷害 ──────────────────────────
func take_damage(amount: float) -> void:
	if _is_dead:
		return
	if _dmg_timer > 0.0:
		return
	_dmg_timer = DAMAGE_COOLDOWN
	var reduced: float = amount * (1.0 - _damage_reduce_pct)
	hp = max(hp - reduced, 0.0)
	hp_changed.emit(hp, max_hp)
	_flash_red()
	if hp <= 0.0:
		_die()


# ── PLAYER-05：回血 ───────────────────────────────────────
func heal_hp(amount: float) -> void:
	if _is_dead:
		return
	hp = min(hp + amount, max_hp)
	hp_changed.emit(hp, max_hp)


# ── PLAYER-06：死亡流程 ───────────────────────────────────
func _die() -> void:
	_is_dead = true
	velocity = Vector2.ZERO
	_sprite.color = Color(0.55, 0.55, 0.55, 1.0)
	player_died.emit()
	await get_tree().create_timer(2.0).timeout
	print("[PLAYER-06] 死亡動畫完成，等待 FLOW-04 切換")


# ── PLAYER-07：吸收 XP（UPGRADE-02）─────────────────────
func add_xp(amount: float) -> void:
	if level >= MAX_LEVEL:
		return
	xp += amount
	xp_changed.emit(xp, _xp_to_next, level)

	# UPGRADE-02：達到門檻 -> 升級
	while xp >= _xp_to_next and level < MAX_LEVEL:
		xp -= _xp_to_next
		level += 1
		var idx: int = level - 2  # Lv2 對應 index 0
		if idx + 1 < XP_TABLE.size():
			_xp_to_next = XP_TABLE[idx + 1]
		else:
			_xp_to_next = 9999.0
		level_up_triggered.emit(level)
		print("[UPGRADE-02] 升至等級 ", level)

		# WEAPON-05：等級達 5 解鎖芋頭珍珠
		if level >= 5 and not _weapon_unlocked["taro"]:
			_unlock_weapon("taro")

	xp_changed.emit(xp, _xp_to_next, level)

	# WEAPON-05：擊殺數解鎖抹茶珍珠（在 on_kill 中處理）


# ── 擊殺通知（由 World 呼叫）────────────────────────────
func on_kill() -> void:
	kill_count += 1
	kill_count_changed.emit(kill_count)

	# 回收紙吸管：擊殺回血
	if _lifesteal_level > 0:
		heal_hp(float(_lifesteal_level))

	# WEAPON-05：擊殺 50 解鎖抹茶珍珠
	if kill_count >= 50 and not _weapon_unlocked["matcha"]:
		_unlock_weapon("matcha")


# ── WEAPON-05：武器解鎖 ──────────────────────────────────
func _unlock_weapon(weapon_id: String) -> void:
	_weapon_unlocked[weapon_id] = true
	_weapon_in_pool[weapon_id] = true
	print("[WEAPON-05] 解鎖武器：", weapon_id)


func unlock_weapon_by_boss() -> void:
	## WEAPON-05：首次擊殺 Boss 解鎖黑糖爆爆珠
	if not _weapon_unlocked["popping_boba"]:
		_unlock_weapon("popping_boba")


func unlock_weapon_by_time(minutes_survived: float) -> void:
	## WEAPON-05：生存 15 分鐘解鎖燕麥珍珠
	if minutes_survived >= 15.0 and not _weapon_unlocked["oat"]:
		_unlock_weapon("oat")


# ── WEAPON-06：加入武器（透過升級卡選擇）────────────────
func add_weapon(weapon_id: String) -> void:
	if weapon_id in equipped_weapons:
		return
	if equipped_weapons.size() >= 6:
		return
	equipped_weapons.append(weapon_id)
	_weapon_cooldowns[weapon_id] = 0.0
	print("[WEAPON-06] 裝備武器：", weapon_id)


# ── 查詢當前武器傷害（COMBAT-05 用）─────────────────────
func get_weapon_damage() -> float:
	if equipped_weapons.is_empty():
		return 1.0
	return _weapon_stats.get(equipped_weapons[0], {}).get("damage", 1.0)


# ── UPGRADE-04：升級介面 ─────────────────────────────────
func get_pearl_burst_level() -> int:
	return _pearl_burst_level


func upgrade_pearl_burst() -> void:
	_pearl_burst_level = min(_pearl_burst_level + 1, 3)
	print("[UPGRADE-04] 珍珠爆裂升至 Lv.", _pearl_burst_level)


## 套用升級卡牌效果（由 UpgradeUI 呼叫）
func apply_upgrade(upgrade_id: String) -> void:
	match upgrade_id:
		"pearl_add":
			_pearl_add_level = min(_pearl_add_level + 1, 5)
		"max_hp":
			_max_hp_bonus += 20.0
			max_hp += 20.0
			hp = min(hp + 20.0, max_hp)
			hp_changed.emit(hp, max_hp)
		"speed":
			_speed_bonus_pct = min(_speed_bonus_pct + 0.15, 0.45)
		"defense":
			_damage_reduce_pct = min(_damage_reduce_pct + 0.10, 0.50)
		"bullet_speed":
			_bullet_speed_pct = min(_bullet_speed_pct + 0.20, 0.60)
		"fire_rate":
			_fire_cooldown_bonus = min(_fire_cooldown_bonus + 0.05, 0.25)
		"pickup_range":
			_pickup_range_bonus = min(_pickup_range_bonus + 50.0, 150.0)
			# 通知所有場景中的 PickupItem 更新拾取範圍
		"pearl_burst":
			upgrade_pearl_burst()
		"range":
			_range_bonus_pct = min(_range_bonus_pct + 0.25, 0.75)
		"lifesteal":
			_lifesteal_level = min(_lifesteal_level + 1, 3)
		_:
			# 可能是武器 ID
			add_weapon(upgrade_id)
	print("[UPGRADE-04] 套用升級：", upgrade_id)


## 取得拾取範圍加成（供 PickupItem 查詢）
func get_pickup_range_bonus() -> float:
	return _pickup_range_bonus


# ── 受傷閃爍 ─────────────────────────────────────────────
func _flash_red() -> void:
	_sprite.color = Color(1.0, 0.2, 0.2, 1.0)
	await get_tree().create_timer(0.1).timeout
	if not _is_dead:
		_sprite.color = Color(0.502, 0.333, 0.169, 1.0)
