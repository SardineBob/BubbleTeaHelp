## Player.gd
## 玩家角色的控制腳本（PLAYER-01）
## 負責處理玩家的輸入與移動邏輯

extends CharacterBody2D

# ── 移動設定 ──────────────────────────────────────────────
## 玩家每秒的移動速度（像素/秒）
@export var speed: float = 200.0

# ── 內部變數 ──────────────────────────────────────────────
## 當前幀的移動方向向量
var _direction: Vector2 = Vector2.ZERO


func _ready() -> void:
	## 玩家節點初始化時呼叫
	## 在此可進行初始設定，例如動畫、狀態機等
	print("玩家已生成，位置：", global_position)


func _physics_process(delta: float) -> void:
	## 每個物理幀呼叫，處理輸入與移動
	## delta：距離上一幀的時間（秒）

	# 讀取輸入方向（WASD 或方向鍵，由 project.godot 的 Input Map 定義）
	_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	# 根據方向與速度設定速度向量
	# normalize() 確保斜向移動速度與直向一致
	if _direction != Vector2.ZERO:
		velocity = _direction.normalized() * speed
	else:
		# 無輸入時停止移動
		velocity = Vector2.ZERO

	# 套用物理移動（自動處理碰撞）
	move_and_slide()
