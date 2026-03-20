## SlowZone.gd
## MAP-05：便利商店冰箱減速區
## 進入者移動速度降低 25%；離開後立即恢復

extends Area2D

## 減速幅度（0.25 = 25%）
@export var slow_amount: float = 0.25

## 目前在區域內的節點
var _bodies_inside: Array[Node] = []


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if not (body.is_in_group("player") or body.is_in_group("enemy")):
		return
	if body in _bodies_inside:
		return
	_bodies_inside.append(body)
	_apply_slow(body)


func _on_body_exited(body: Node) -> void:
	if body in _bodies_inside:
		_bodies_inside.erase(body)
		_remove_slow(body)


func _apply_slow(body: Node) -> void:
	if body.has_method("apply_slow"):
		body.apply_slow(slow_amount, 9999.0)  ## 持續直到離開
	elif body.has_method("get") and body.has_method("set"):
		## 備用：直接設定速度倍率（對 Player 適用）
		if body.has_method("set"):
			var current_speed = body.get("speed")
			if current_speed != null:
				body.set("_slow_zone_speed", current_speed)
				body.set("speed", current_speed * (1.0 - slow_amount))


func _remove_slow(body: Node) -> void:
	if body.has_method("apply_slow"):
		body.apply_slow(0.0, 0.0)
	elif body.has_method("get") and body.has_method("set"):
		var saved = body.get("_slow_zone_speed")
		if saved != null:
			body.set("speed", saved)
