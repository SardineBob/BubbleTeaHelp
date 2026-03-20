## ConveyorZone.gd
## MAP-06：手搖飲料店輸送帶推力
## 主角進入後，沿輸送帶方向獲得額外推力 80 px/s

extends Area2D

## 推力方向（正規化向量）
@export var push_direction: Vector2 = Vector2.RIGHT
## 推力大小（px/s）
@export var push_force: float = 80.0

var _player_inside: bool = false
var _player_ref: Node = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _physics_process(delta: float) -> void:
	if _player_inside and _player_ref != null and is_instance_valid(_player_ref):
		## 在 Player 的 velocity 上疊加推力（需在 Player 移動後處理）
		## 這裡透過直接修改 global_position 疊加
		var push_vec: Vector2 = push_direction.normalized() * push_force * delta
		_player_ref.global_position += push_vec


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = true
		_player_ref = body
		print("[MAP-06] 主角進入輸送帶！")


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		_player_ref = null
		print("[MAP-06] 主角離開輸送帶！")
