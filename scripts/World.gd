## World.gd
## 世界場景主控腳本
## PLAYER-01：遊戲開始時於地圖中央生成主角
## PLAYER-02：設定地圖邊界至主角
## PLAYER-06：監聽玩家死亡信號

extends Node2D

# ── 匯出變數 ──────────────────────────────────────────────
@export var player_scene: PackedScene = preload("res://scenes/Player.tscn")

# ── 節點參考 ──────────────────────────────────────────────
var _player: CharacterBody2D = null


func _ready() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var center_pos: Vector2 = viewport_size / 2.0

	# 實例化玩家
	_player = player_scene.instantiate() as CharacterBody2D
	add_child(_player)
	_player.global_position = center_pos

	# PLAYER-02：設定地圖邊界（以視窗範圍為準）
	_player.map_bounds = Rect2(Vector2.ZERO, viewport_size)

	# PLAYER-06：監聽死亡信號
	_player.player_died.connect(_on_player_died)

	print("世界場景已初始化，視窗大小：", viewport_size)
	print("玩家已生成於中央位置：", center_pos)


# PLAYER-06：玩家死亡處理（FLOW-04 實作前的佔位）
func _on_player_died() -> void:
	print("[World] 玩家死亡，等待 2 秒後切換至 FLOW-04 死亡結算畫面...")
