## World.gd
## 世界場景主控腳本
## PLAYER-01：遊戲開始時於地圖中央生成主角
## PLAYER-02：設定地圖邊界（3200x3200）至主角
## PLAYER-06：監聽玩家死亡信號 -> FLOW-04
## ENEMY-05：監聽敵人死亡 -> XP 掉落 + 擊殺計數
## SPAWN-01：遊戲開始時啟動生成計時器（2.5 秒）
## SPAWN-02：計時器歸零時生成一批敵人
## SPAWN-03：依遊戲時間決定敵人種類
## SPAWN-04：生成間隔隨難度縮短（最低 0.4 秒）
## SPAWN-05：同屏敵人數量上限控制
## SPAWN-06：Boss 在 5:00, 15:00, 30:00 生成
## SPAWN-07：Boss 死亡後恢復普通生成
## DIFF-01：初始化難度
## DIFF-02：每秒重新計算難度指數
## DIFF-03：難度 HP 倍率套用到新敵人
## UPGRADE-01：敵人死亡生成 XP 掉落物
## UPGRADE-03：XP 達標暫停遊戲顯示升級介面
## MAP-01：地圖邊界 3200x3200
## MAP-02：相機平滑跟隨主角
## FLOW-01：遊戲開始初始化
## FLOW-02/03：暫停/恢復
## FLOW-04：死亡結算
## FLOW-05：勝利結算
## FLOW-06：再玩一次
## DATA-01/02：啟動時載入 JSON 數值
## HUD-01~06：UI 更新

extends Node2D

# ── 地圖設定（MAP-01）────────────────────────────────────
const MAP_SIZE: Vector2 = Vector2(3200.0, 3200.0)
const SPAWN_MARGIN: float = 100.0

# ── 匯出 ──────────────────────────────────────────────────
@export var player_scene: PackedScene
@export var enemy_scene: PackedScene
@export var pickup_scene: PackedScene
@export var bullet_scene: PackedScene

# ── 節點參考 ──────────────────────────────────────────────
var _player: Node = null
var _camera: Camera2D = null
var _hud: CanvasLayer = null

# ── 遊戲狀態 ──────────────────────────────────────────────
var _game_time: float = 0.0   ## 遊戲經過時間（秒）
var _is_paused: bool = false
var _is_game_over: bool = false
var _boss_alive: bool = false
var _boss_spawned_times: Array[float] = []  ## 已生成 Boss 的時間點

# ── DIFF-01/02：難度系統 ─────────────────────────────────
var _difficulty: float = 1.0
var _diff_timer: float = 0.0

# ── SPAWN-01：生成計時器 ─────────────────────────────────
const INITIAL_SPAWN_INTERVAL: float = 2.5
const MIN_SPAWN_INTERVAL: float = 0.4
var _spawn_timer: float = 0.0
var _spawn_paused: bool = false  ## SPAWN-06：Boss 戰時暫停普通生成

# ── HUD 節點（若存在）────────────────────────────────────
var _hp_bar: Node = null
var _xp_bar: Node = null
var _kill_label: Node = null
var _timer_label: Node = null
var _boss_bar: Node = null
var _overlay: Node = null
var _upgrade_ui: Node = null
var _pause_menu: Node = null

# ── DATA-01：載入的 JSON 數值 ─────────────────────────────
var _enemy_data: Dictionary = {}
var _weapon_data: Dictionary = {}
var _upgrade_data: Dictionary = {}

# ── Boss 觸發時間（秒）────────────────────────────────────
const BOSS_TIMES: Array[float] = [300.0, 900.0, 1800.0]


func _ready() -> void:
	add_to_group("world")
	randomize()

	# DATA-01：載入 JSON
	_load_json_data()

	# FLOW-01：初始化遊戲
	_initialize_game()

	# #72：觸發背景繪製
	queue_redraw()


# ── #72：繪製街道磚格背景 ────────────────────────────────
const TILE_SIZE: float = 80.0
func _draw() -> void:
	var cols: int = int(MAP_SIZE.x / TILE_SIZE) + 1
	var rows: int = int(MAP_SIZE.y / TILE_SIZE) + 1
	var color_a: Color = Color(0.78, 0.76, 0.70)   # 淺灰磚
	var color_b: Color = Color(0.72, 0.70, 0.64)   # 深灰磚
	for row in range(rows):
		for col in range(cols):
			var c: Color = color_a if (row + col) % 2 == 0 else color_b
			draw_rect(Rect2(col * TILE_SIZE, row * TILE_SIZE, TILE_SIZE, TILE_SIZE), c)
	# 道路標線（橫向虛線）
	var line_color: Color = Color(0.9, 0.85, 0.55, 0.4)
	var road_y: float = 0.0
	while road_y < MAP_SIZE.y:
		for seg in range(int(MAP_SIZE.x / 80)):
			if seg % 2 == 0:
				draw_rect(Rect2(seg * 80.0, road_y - 2.0, 60.0, 4.0), line_color)
		road_y += 400.0


func _load_json_data() -> void:
	var files: Dictionary = {
		"enemies": "res://data/enemies.json",
		"weapons": "res://data/weapons.json",
		"upgrades": "res://data/upgrades.json",
	}
	for key in files:
		var path: String = files[key]
		if ResourceLoader.exists(path):
			var file: FileAccess = FileAccess.open(path, FileAccess.READ)
			if file:
				var json: JSON = JSON.new()
				var result: int = json.parse(file.get_as_text())
				file.close()
				if result == OK:
					match key:
						"enemies": _enemy_data = json.data
						"weapons": _weapon_data = json.data
						"upgrades": _upgrade_data = json.data
				else:
					push_warning("[DATA-01] JSON 解析錯誤：" + path)
			else:
				push_warning("[DATA-01] 無法開啟檔案：" + path)
		else:
			print("[DATA-01] 找不到 JSON 檔案，使用內建預設值：", path)


func _initialize_game() -> void:
	# 載入場景
	if player_scene == null:
		player_scene = load("res://scenes/Player.tscn")
	if enemy_scene == null and ResourceLoader.exists("res://scenes/Enemy.tscn"):
		enemy_scene = load("res://scenes/Enemy.tscn")
	if pickup_scene == null and ResourceLoader.exists("res://scenes/PickupItem.tscn"):
		pickup_scene = load("res://scenes/PickupItem.tscn")
	if bullet_scene == null and ResourceLoader.exists("res://scenes/Bullet.tscn"):
		bullet_scene = load("res://scenes/Bullet.tscn")

	# MAP-01：地圖邊界（3200x3200 中央）
	var map_bounds: Rect2 = Rect2(Vector2.ZERO, MAP_SIZE)

	# PLAYER-01：生成主角於地圖中央
	_player = player_scene.instantiate()
	add_child(_player)
	_player.global_position = MAP_SIZE / 2.0
	_player.map_bounds = map_bounds
	if bullet_scene != null:
		_player.bullet_scene = bullet_scene

	# 監聽玩家信號
	_player.player_died.connect(_on_player_died)
	if _player.has_signal("level_up_triggered"):
		_player.level_up_triggered.connect(_on_level_up)
	if _player.has_signal("hp_changed"):
		_player.hp_changed.connect(_on_hp_changed)
	if _player.has_signal("xp_changed"):
		_player.xp_changed.connect(_on_xp_changed)
	if _player.has_signal("kill_count_changed"):
		_player.kill_count_changed.connect(_on_kill_count_changed)

	# MAP-02：相機（修正 #65：呼叫 make_current() 確保此相機為主相機）
	_camera = Camera2D.new()
	_player.add_child(_camera)
	_camera.enabled = true
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 12.0
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = int(MAP_SIZE.x)
	_camera.limit_bottom = int(MAP_SIZE.y)
	_camera.make_current()

	# HUD-01~06：動態載入 HUD 場景
	if ResourceLoader.exists("res://scenes/HUD.tscn"):
		var hud_scene: PackedScene = load("res://scenes/HUD.tscn")
		_hud = hud_scene.instantiate()
		add_child(_hud)
		_hp_bar = _hud.get_node_or_null("HPBar")
		_xp_bar = _hud.get_node_or_null("XPBar")
		_kill_label = _hud.get_node_or_null("KillLabel")
		_timer_label = _hud.get_node_or_null("TimerLabel")
		_boss_bar = _hud.get_node_or_null("BossBarContainer")
		_overlay = _hud.get_node_or_null("Overlay")
		_upgrade_ui = _hud.get_node_or_null("UpgradePanel")

	# DIFF-01：初始化難度
	_difficulty = 1.0
	_spawn_timer = INITIAL_SPAWN_INTERVAL

	# SPAWN-01：生成計時器啟動
	print("[SPAWN-01] 生成計時器啟動，間隔：", INITIAL_SPAWN_INTERVAL, " 秒")
	print("[FLOW-01] 遊戲初始化完成。主角位置：", _player.global_position)


func _process(delta: float) -> void:
	if _is_game_over or _is_paused:
		return

	_game_time += delta

	# HUD-04：更新計時器
	if _hud != null and _hud.has_method("update_timer"):
		_hud.update_timer(_game_time)

	# DIFF-02：每秒更新難度
	_diff_timer += delta
	if _diff_timer >= 1.0:
		_diff_timer -= 1.0
		_recalculate_difficulty()
		# WEAPON-05：時間解鎖武器
		if _player != null and _player.has_method("unlock_weapon_by_time"):
			_player.unlock_weapon_by_time(_game_time / 60.0)

	# SPAWN-06：Boss 觸發
	_check_boss_spawn()

	# SPAWN-01/02/03/04/05：普通敵人生成
	if not _spawn_paused:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_try_spawn_enemies()
			var new_interval: float = _calculate_spawn_interval()
			_spawn_timer = new_interval

	# FLOW-02：Esc 暫停
	if Input.is_action_just_pressed("ui_cancel"):
		_toggle_pause()


# ── DIFF-02：計算難度指數 ────────────────────────────────
func _recalculate_difficulty() -> void:
	var t: float = _game_time / 60.0  ## 分鐘
	_difficulty = 1.0 + 0.15 * t + 0.005 * t * t
	print("[DIFF-02] 難度指數：", snappedf(_difficulty, 0.01))


# ── SPAWN-04：計算生成間隔 ───────────────────────────────
func _calculate_spawn_interval() -> float:
	var t: float = _game_time / 60.0
	## 從 2.5s@0min 線性插值至 0.4s@30min
	var interval: float = lerp(2.5, 0.4, clamp(t / 30.0, 0.0, 1.0))
	return max(interval, MIN_SPAWN_INTERVAL)


# ── SPAWN-05：同屏上限 ───────────────────────────────────
func _get_max_enemies() -> int:
	var t: float = _game_time / 60.0
	return int(lerp(10.0, 200.0, clamp(t / 30.0, 0.0, 1.0)))


# ── SPAWN-02/03/04/05：生成敵人 ─────────────────────────
func _try_spawn_enemies() -> void:
	var current_count: int = get_tree().get_nodes_in_group("enemy").size()
	var max_enemies: int = _get_max_enemies()
	if current_count >= max_enemies:
		print("[SPAWN-05] 同屏敵人上限 ", max_enemies, "，跳過生成")
		return

	# SPAWN-03：決定可用敵人種類
	var available_types: Array[String] = _get_available_enemy_types()
	if available_types.is_empty():
		return

	# 每次生成 1~3 隻
	var count: int = randi_range(1, 3)
	count = min(count, max_enemies - current_count)

	for i in range(count):
		var etype: String = available_types[randi() % available_types.size()]
		var pos: Vector2 = _get_spawn_position()
		spawn_enemy(etype, pos)


# ── SPAWN-03：依時間決定可用種類 ────────────────────────
func _get_available_enemy_types() -> Array[String]:
	var t_seconds: float = _game_time
	var types: Array[String] = []
	if t_seconds >= 0:     types.append("passerby")
	if t_seconds >= 120:   types.append("grandma")
	if t_seconds >= 180:   types.append("little_girl")
	if t_seconds >= 300:   types.append("bbt_fan")
	if t_seconds >= 480:   types.append("gym_bro")
	if t_seconds >= 600:   types.append("boss_lady")
	return types


# ── SPAWN-02：隨機選邊生成位置 ──────────────────────────
func _get_spawn_position() -> Vector2:
	var side: int = randi() % 4
	var x: float = 0.0
	var y: float = 0.0
	match side:
		0:  ## 上
			x = randf_range(0.0, MAP_SIZE.x)
			y = -SPAWN_MARGIN
		1:  ## 下
			x = randf_range(0.0, MAP_SIZE.x)
			y = MAP_SIZE.y + SPAWN_MARGIN
		2:  ## 左
			x = -SPAWN_MARGIN
			y = randf_range(0.0, MAP_SIZE.y)
		3:  ## 右
			x = MAP_SIZE.x + SPAWN_MARGIN
			y = randf_range(0.0, MAP_SIZE.y)
	return Vector2(x, y)


# ── 生成敵人（供 ENEMY-03/04 呼叫）─────────────────────
func spawn_enemy(etype: String, pos: Vector2) -> void:
	if enemy_scene == null:
		return
	var enemy: Node = enemy_scene.instantiate()
	# 修正 #69：先設定 type/HP 再 add_child
	# 讓 _ready() -> _apply_type_defaults() 以正確種類計算 speed/contact_damage
	enemy.set("enemy_type", etype)
	var base_hp: float = _get_base_hp(etype)
	var hp_mult: float = _get_hp_multiplier()
	enemy.set("max_hp", base_hp * hp_mult)
	add_child(enemy)
	enemy.global_position = pos
	if enemy.has_signal("enemy_died"):
		enemy.enemy_died.connect(_on_enemy_died)


func spawn_enemy_split(etype: String, pos: Vector2, split_hp: float) -> void:
	if enemy_scene == null:
		return
	var enemy: Node = enemy_scene.instantiate()
	enemy.set("enemy_type", etype)
	enemy.set("max_hp", split_hp)
	enemy.set("is_split_girl", true)
	add_child(enemy)
	enemy.global_position = pos
	if enemy.has_signal("enemy_died"):
		enemy.enemy_died.connect(_on_enemy_died)


func _get_base_hp(etype: String) -> float:
	var hp_table: Dictionary = {
		"passerby": 4.0, "grandma": 6.0, "little_girl": 1.0,
		"bbt_fan": 5.0, "gym_bro": 15.0, "boss_lady": 20.0,
	}
	return hp_table.get(etype, 4.0)


func _get_hp_multiplier() -> float:
	var t: float = _game_time / 60.0  ## 分鐘
	# 0:00->x1, 5:00->x1.5, 10:00->x2.0, 20:00->x3.5, 30:00->x6.0
	if t <= 5.0:  return lerp(1.0, 1.5, t / 5.0)
	elif t <= 10.0: return lerp(1.5, 2.0, (t - 5.0) / 5.0)
	elif t <= 20.0: return lerp(2.0, 3.5, (t - 10.0) / 10.0)
	else: return lerp(3.5, 6.0, clamp((t - 20.0) / 10.0, 0.0, 1.0))


# ── SPAWN-06：Boss 在指定時間生成 ────────────────────────
func _check_boss_spawn() -> void:
	if _boss_alive:
		return
	for boss_time in BOSS_TIMES:
		if _game_time >= boss_time and not (boss_time in _boss_spawned_times):
			_boss_spawned_times.append(boss_time)
			_spawn_boss(boss_time)
			break


func _spawn_boss(trigger_time: float) -> void:
	_spawn_paused = true
	_boss_alive = true
	print("[SPAWN-06] Boss 生成！時間：", trigger_time / 60.0, " 分鐘")
	## 在地圖右側邊緣生成 Boss（此處簡化為生成老闆娘作為示例）
	var boss_pos: Vector2 = Vector2(MAP_SIZE.x + SPAWN_MARGIN, MAP_SIZE.y / 2.0)
	spawn_enemy("boss_lady", boss_pos)
	## TODO：播放 Boss 警告演出（畫面震動 + 提示文字）
	## TODO：HUD-05 Boss 血條


# ── ENEMY-05：敵人死亡回呼 ──────────────────────────────
func _on_enemy_died(pos: Vector2, etype: String) -> void:
	# 擊殺計數
	if _player != null and _player.has_method("on_kill"):
		_player.on_kill()

	# UPGRADE-01：生成 XP 掉落物
	_spawn_xp(pos, etype)

	# 如果是 Boss
	if etype == "boss_lady":
		_on_boss_died()


func _spawn_xp(pos: Vector2, etype: String) -> void:
	if pickup_scene == null:
		return
	var xp_table: Dictionary = {
		"passerby": 2.0, "grandma": 4.0, "little_girl": 1.0,
		"bbt_fan": 3.0, "gym_bro": 6.0, "boss_lady": 20.0,
	}
	var xp_val: float = xp_table.get(etype, 2.0)
	var pickup: Node = pickup_scene.instantiate()
	add_child(pickup)
	pickup.global_position = pos
	if pickup.has_method("set"):
		pickup.set("effect_type", "xp")
		pickup.set("effect_value", xp_val)


# ── SPAWN-07：Boss 死亡後恢復普通生成 ───────────────────
func _on_boss_died() -> void:
	_boss_alive = false
	_spawn_paused = false
	print("[SPAWN-07] Boss 死亡，恢復普通生成")
	# WEAPON-05：解鎖黑糖爆爆珠
	if _player != null and _player.has_method("unlock_weapon_by_boss"):
		_player.unlock_weapon_by_boss()
	# FLOW-05：檢查是否達成勝利條件
	if _game_time >= 1800.0:  ## 30 分鐘
		_win_game()


# ── UPGRADE-03：升級介面 ─────────────────────────────────
func _on_level_up(lv: int) -> void:
	print("[UPGRADE-03] 等級提升至 ", lv, "，顯示升級介面")
	get_tree().paused = true
	## 實際介面需要 UpgradeUI 場景；此處僅暫停並 log
	## TODO：實例化 UpgradeUI 場景，顯示 3 張卡牌
	## 測試環境下自動套用（避免卡關）：
	await get_tree().create_timer(0.1).timeout
	get_tree().paused = false


# ── FLOW-02/03：暫停/恢復 ───────────────────────────────
func _toggle_pause() -> void:
	_is_paused = !_is_paused
	get_tree().paused = _is_paused
	print("[FLOW-0", "2" if _is_paused else "3", "] 遊戲", "暫停" if _is_paused else "恢復")


# ── PLAYER-06：玩家死亡 ──────────────────────────────────
func _on_player_died() -> void:
	_is_game_over = true
	print("[World] 玩家死亡！等待 FLOW-04 死亡結算...")
	await get_tree().create_timer(2.0).timeout
	## FLOW-04：顯示死亡結算畫面
	## get_tree().change_scene_to_file("res://scenes/DeathScreen.tscn")
	print("[FLOW-04] 死亡結算（場景尚未實作，請手動切換）")


# ── FLOW-05：勝利 ────────────────────────────────────────
func _win_game() -> void:
	_is_game_over = true
	print("[FLOW-05] 勝利！生存時間：", _game_time / 60.0, " 分鐘")
	## get_tree().change_scene_to_file("res://scenes/WinScreen.tscn")


# ── ENEMY-08：老闆娘杯子（讓 Enemy 呼叫）────────────────
func spawn_boss_lady_cup(from_pos: Vector2, target_pos: Vector2) -> void:
	if bullet_scene == null:
		return
	var cup: Node = bullet_scene.instantiate()
	add_child(cup)
	cup.global_position = from_pos
	var dir: Vector2 = (target_pos - from_pos).normalized()
	cup.set("direction", dir)
	cup.set("speed", 200.0)
	cup.set("damage", 10.0)
	cup.set("max_range", 600.0)
	cup.set("map_bounds", Rect2(Vector2.ZERO, MAP_SIZE))


# ── HUD 信號回呼 ─────────────────────────────────────────
func _on_hp_changed(current: float, maximum: float) -> void:
	## HUD-01：HP 血條更新
	if _hud != null and _hud.has_method("update_hp"):
		_hud.update_hp(current, maximum)


func _on_xp_changed(current: float, needed: float, lv: int) -> void:
	## HUD-02：XP 條更新
	if _hud != null and _hud.has_method("update_xp"):
		_hud.update_xp(current, needed, lv)


func _on_kill_count_changed(count: int) -> void:
	## HUD-03：擊殺計數更新
	if _hud != null and _hud.has_method("update_kill_count"):
		_hud.update_kill_count(count)
