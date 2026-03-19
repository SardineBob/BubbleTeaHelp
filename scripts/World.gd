## World.gd
## 世界場景的主要控制腳本（PLAYER-01）
## 負責在遊戲開始時將玩家生成於地圖中央

extends Node2D

# ── 匯出變數 ──────────────────────────────────────────────
## 玩家場景資源（在編輯器中指定，或由程式碼載入）
@export var player_scene: PackedScene = preload("res://scenes/Player.tscn")

# ── 節點參考 ──────────────────────────────────────────────
## 生成後的玩家實例參考
var _player: CharacterBody2D = null


func _ready() -> void:
	## 場景載入完成時呼叫
	## 在此生成玩家並設定其位置於視窗中央

	# 取得視窗（視口）的尺寸，計算中央位置
	var viewport_size: Vector2 = get_viewport_rect().size
	var center_position: Vector2 = viewport_size / 2.0

	# 實例化玩家場景
	_player = player_scene.instantiate() as CharacterBody2D

	# 將玩家加入場景樹（必須先加入才能設定全域位置）
	add_child(_player)

	# 設定玩家位置為地圖（視窗）中央
	_player.global_position = center_position

	print("世界場景已初始化，視窗大小：", viewport_size)
	print("玩家已生成於中央位置：", center_position)
