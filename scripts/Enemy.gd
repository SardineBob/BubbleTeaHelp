## Enemy.gd
## 敵人基礎腳本
## ENEMY-01：敵人朝主角移動（含各敵人速度）
## ENEMY-02：受到傷害視覺回饋（閃白 0.1 秒）
## ENEMY-03：老奶奶召喚小孫子（HP 降至 50% 時生成 2 隻路人甲）
## ENEMY-04：小女孩死亡分裂（死亡時生成 2 隻 HP 50% 的小女孩）
## ENEMY-05：敵人死亡流程（XP 掉落 + 擊殺計數 + 節點移除）
## ENEMY-06：珍奶控近距離加速（距離 200 px 以內加速至 150）
## ENEMY-07：健身大叔碰撞擊退主角（150 px）
## ENEMY-08：老闆娘遠程投擲杯子（300 px 內每 2 秒）
## COMBAT-04：受到減速效果
## COMBAT-05：擊殺時機率觸發珍珠爆裂爆炸

extends CharacterBody2D

# ── 敵人種類 ──────────────────────────────────────────────
## "passerby" | "grandma" | "little_girl" | "bbt_fan" | "gym_bro" | "boss_lady"
@export var enemy_type: String = "passerby"

# ── 基礎設定（export 允許外部覆寫；0 = 使用種類預設）──────
@export var max_hp: float = 0.0
@export var speed: float = 0.0
@export var contact_damage: float = 0.0

# ── ENEMY-04：是否為分裂出的小女孩（不再觸發分裂）──────
@export var is_split_girl: bool = false

# ── COMBAT-05 ─────────────────────────────────────────────
const COMBAT05_EXPLOSION_RADIUS: float = 80.0
const COMBAT05_CHANCE_PER_LEVEL: float = 0.1

# ── ENEMY-08：老闆娘 ─────────────────────────────────────
const BOSS_LADY_ATTACK_RANGE: float = 300.0
const BOSS_LADY_RETREAT_RANGE: float = 350.0
const BOSS_LADY_THROW_INTERVAL: float = 2.0
var _boss_lady_timer: float = 0.0
var _boss_lady_attacking: bool = false

# ── ENEMY-07：健身大叔 ───────────────────────────────────
const GYM_BRO_KNOCKBACK: float = 150.0
const GYM_BRO_KNOCKBACK_COOLDOWN: float = 1.0
var _knockback_timer: float = 0.0

# ── ENEMY-03：老奶奶 ─────────────────────────────────────
var _grandma_summoned: bool = false

# ── COMBAT-04：減速 ──────────────────────────────────────
var _slow_factor: float = 1.0
var _slow_timer: float = 0.0

# ── ENEMY-02：視覺 ───────────────────────────────────────
var _sprite: Label = null
var _is_flashing: bool = false

# ── PLAYER-04：接觸傷害冷卻 ──────────────────────────────
const CONTACT_DAMAGE_COOLDOWN: float = 0.5
const CONTACT_DAMAGE_DIST: float = 50.0
var _contact_dmg_timer: float = 0.0

# ── 內部狀態 ──────────────────────────────────────────────
var hp: float = 0.0
var _player: Node = null
var _is_dead: bool = false

# ── 信號 ─────────────────────────────────────────────────
## World 監聽此信號以處理 XP 掉落和擊殺計數
signal enemy_died(pos: Vector2, enemy_type: String)


func _ready() -> void:
	add_to_group("enemy")
	_apply_type_defaults()

	if has_node("Sprite"):
		_sprite = $Sprite
		# #72：依種類設定 emoji
		var emoji_map: Dictionary = {
			"passerby":   "🚶",
			"grandma":    "👵",
			"little_girl":"👧",
			"bbt_fan":    "🥤",
			"gym_bro":    "🏋️",
			"boss_lady":  "💁",
		}
		_sprite.text = emoji_map.get(enemy_type, "🚶")

	await get_tree().process_frame
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]


# ── ENEMY-01：依種類設定預設屬性 ────────────────────────
func _apply_type_defaults() -> void:
	var defaults: Dictionary = {
		"passerby":   {"hp": 4.0,  "spd": 80.0,  "dmg": 5.0},
		"grandma":    {"hp": 6.0,  "spd": 50.0,  "dmg": 8.0},
		"little_girl":{"hp": 1.0,  "spd": 130.0, "dmg": 3.0},
		"bbt_fan":    {"hp": 5.0,  "spd": 100.0, "dmg": 7.0},
		"gym_bro":    {"hp": 15.0, "spd": 60.0,  "dmg": 15.0},
		"boss_lady":  {"hp": 20.0, "spd": 90.0,  "dmg": 12.0},
	}
	var d: Dictionary = defaults.get(enemy_type, {"hp": 4.0, "spd": 80.0, "dmg": 5.0})
	if max_hp == 0.0:   max_hp = d["hp"]
	if speed == 0.0:    speed  = d["spd"]
	if contact_damage == 0.0: contact_damage = d["dmg"]
	hp = max_hp


func _physics_process(delta: float) -> void:
	if _is_dead or _player == null:
		return

	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			_slow_factor = 1.0

	if _knockback_timer > 0.0:
		_knockback_timer -= delta

	if _contact_dmg_timer > 0.0:
		_contact_dmg_timer -= delta

	var dist_to_player: float = global_position.distance_to(_player.global_position)

	# ENEMY-08：老闆娘
	if enemy_type == "boss_lady":
		_update_boss_lady(delta, dist_to_player)
		if _boss_lady_attacking:
			velocity = Vector2.ZERO
			move_and_slide()
			return

	# ENEMY-06：珍奶控速度
	var effective_speed: float = speed
	if enemy_type == "bbt_fan":
		effective_speed = BBT_FAN_BOOST_SPEED if dist_to_player < 200.0 else 100.0

	var dir: Vector2 = (_player.global_position - global_position).normalized()
	velocity = dir * effective_speed * _slow_factor
	move_and_slide()

	# PLAYER-04：接觸傷害（距離檢測，不依賴物理碰撞）
	if _contact_dmg_timer <= 0.0 and dist_to_player < CONTACT_DAMAGE_DIST:
		if _player.has_method("take_damage"):
			_player.take_damage(contact_damage)
		_contact_dmg_timer = CONTACT_DAMAGE_COOLDOWN

	# ENEMY-07：健身大叔擊退
	if enemy_type == "gym_bro" and _knockback_timer <= 0.0:
		if dist_to_player < 50.0:
			_knockback_player()

	# ENEMY-03：老奶奶 50% HP 召喚
	if enemy_type == "grandma" and not _grandma_summoned:
		if hp < max_hp * 0.5:
			_summon_grandchildren()


const BBT_FAN_BOOST_SPEED: float = 150.0


# ── ENEMY-08：老闆娘投擲邏輯 ────────────────────────────
func _update_boss_lady(delta: float, dist_to_player: float) -> void:
	if dist_to_player < BOSS_LADY_ATTACK_RANGE:
		_boss_lady_attacking = true
		_boss_lady_timer += delta
		if _boss_lady_timer >= BOSS_LADY_THROW_INTERVAL:
			_boss_lady_timer = 0.0
			_throw_cup()
	elif dist_to_player > BOSS_LADY_RETREAT_RANGE:
		_boss_lady_attacking = false
		_boss_lady_timer = 0.0


func _throw_cup() -> void:
	if _player == null:
		return
	# 通知 World 生成飛行杯子子彈
	var world: Node = get_tree().get_first_node_in_group("world")
	if world != null and world.has_method("spawn_boss_lady_cup"):
		world.spawn_boss_lady_cup(global_position, _player.global_position)
	else:
		print("[ENEMY-08] 老闆娘投擲杯子！目標：", _player.global_position)


# ── ENEMY-07：擊退主角 ──────────────────────────────────
func _knockback_player() -> void:
	if _player == null:
		return
	var knockback_dir: Vector2 = (_player.global_position - global_position).normalized()
	_player.global_position += knockback_dir * GYM_BRO_KNOCKBACK
	_knockback_timer = GYM_BRO_KNOCKBACK_COOLDOWN
	print("[ENEMY-07] 健身大叔擊退主角！")


# ── ENEMY-03：老奶奶召喚小孫子 ──────────────────────────
func _summon_grandchildren() -> void:
	_grandma_summoned = true
	var parent: Node = get_parent()
	if parent == null:
		return
	for i in range(2):
		var offset: Vector2 = Vector2(randf_range(-60.0, 60.0), randf_range(-60.0, 60.0))
		if parent.has_method("spawn_enemy"):
			parent.spawn_enemy("passerby", global_position + offset)
		else:
			print("[ENEMY-03] 老奶奶召喚路人甲（備用 log）！")


# ── 受傷 ──────────────────────────────────────────────────
func take_damage(amount: float) -> void:
	if _is_dead:
		return
	hp -= amount
	_flash_white()
	if hp <= 0.0:
		_die()


# ── ENEMY-02：閃白回饋 ──────────────────────────────────
func _flash_white() -> void:
	if _is_flashing or _sprite == null:
		return
	_is_flashing = true
	var original_modulate: Color = _sprite.modulate
	_sprite.modulate = Color(1.0, 0.3, 0.3, 1.0)  # 受傷紅色閃爍
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(self) and _sprite != null:
		_sprite.modulate = original_modulate
	_is_flashing = false


# ── COMBAT-04：減速效果 ──────────────────────────────────
func apply_slow(slow_pct: float, duration: float) -> void:
	_slow_factor = 1.0 - slow_pct
	_slow_timer = duration


# ── ENEMY-05：死亡流程 ────────────────────────────────────
func _die() -> void:
	_is_dead = true
	velocity = Vector2.ZERO

	# ENEMY-04：小女孩分裂
	if enemy_type == "little_girl" and not is_split_girl:
		_split_into_two()

	# COMBAT-05：珍珠爆裂
	_try_pearl_burst_explosion()

	# 發送死亡信號（World 處理 XP 掉落、擊殺計數）
	enemy_died.emit(global_position, enemy_type)

	queue_free()


# ── ENEMY-04：小女孩分裂 ────────────────────────────────
func _split_into_two() -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	for i in range(2):
		var offset: Vector2 = Vector2(randf_range(-30.0, 30.0), randf_range(-30.0, 30.0))
		var spawn_pos: Vector2 = global_position + offset
		if parent.has_method("spawn_enemy_split"):
			parent.spawn_enemy_split("little_girl", spawn_pos, max_hp * 0.5)
		else:
			print("[ENEMY-04] 小女孩分裂！位置：", spawn_pos)


# ── COMBAT-05：珍珠爆裂爆炸 ──────────────────────────────
func _try_pearl_burst_explosion() -> void:
	if _player == null:
		return
	if not _player.has_method("get_pearl_burst_level"):
		return
	var level: int = _player.get_pearl_burst_level()
	if level <= 0:
		return
	var chance: float = level * COMBAT05_CHANCE_PER_LEVEL
	if randf() >= chance:
		return
	var explosion_damage: float = 10.0
	if _player.has_method("get_weapon_damage"):
		explosion_damage = _player.get_weapon_damage()
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		if enemy == self:
			continue
		if global_position.distance_to(enemy.global_position) <= COMBAT05_EXPLOSION_RADIUS:
			if enemy.has_method("take_damage"):
				enemy.take_damage(explosion_damage)
	print("[COMBAT-05] 珍珠爆裂觸發！位置：", global_position)
