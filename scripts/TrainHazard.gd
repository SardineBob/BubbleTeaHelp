## TrainHazard.gd
## MAP-04：捷運站列車定時通過造成傷害
## 每 20 秒觸發：提前 3 秒警告，列車通過傷害所有角色 50 點

extends Node2D

## 觸發間隔（秒）
@export var trigger_interval: float = 20.0
## 警告時間（秒）
@export var warning_time: float = 3.0
## 列車傷害
@export var train_damage: float = 50.0
## 列車通過的 Y 座標
@export var train_y: float = 400.0
## 列車 X 起始 / 結束
@export var train_start_x: float = -200.0
@export var train_end_x: float = 3400.0
## 列車速度（px/s）
@export var train_speed: float = 1200.0

var _timer: float = 0.0
var _warning_label: Label = null
var _train_active: bool = false
var _train_x: float = 0.0


func _ready() -> void:
	_timer = trigger_interval
	# 警告文字（若場景中有 WarningLabel 節點）
	if has_node("WarningLabel"):
		_warning_label = $WarningLabel
		_warning_label.visible = false


func _process(delta: float) -> void:
	if _train_active:
		return

	_timer -= delta
	if _timer <= warning_time and _warning_label != null:
		_warning_label.visible = true
		_warning_label.text = "列車即將通過！%d 秒" % int(_timer)

	if _timer <= 0.0:
		_timer = trigger_interval
		_start_train()


func _start_train() -> void:
	if _warning_label != null:
		_warning_label.visible = false
	_train_active = true
	_train_x = train_start_x
	print("[MAP-04] 列車通過！")


func _physics_process(delta: float) -> void:
	if not _train_active:
		return

	_train_x += train_speed * delta

	# 列車碰撞：對 Y 座標接近的角色造成傷害
	var all_chars: Array[Node] = []
	all_chars.append_array(get_tree().get_nodes_in_group("player"))
	all_chars.append_array(get_tree().get_nodes_in_group("enemy"))

	for char_node in all_chars:
		if not is_instance_valid(char_node):
			continue
		var pos: Vector2 = char_node.global_position
		# 列車在 train_y 的寬度範圍（±50 px）
		if abs(pos.y - train_y) < 50.0 and pos.x > _train_x - 50.0 and pos.x < _train_x + 100.0:
			if char_node.has_method("take_damage"):
				char_node.take_damage(train_damage)

	if _train_x > train_end_x:
		_train_active = false
