## MainMenu.gd
## FLOW-01：開始畫面進入遊戲

extends Control


func _ready() -> void:
	# 確保遊戲未暫停
	get_tree().paused = false


## 「開始遊戲」按鈕被按下
func _on_start_button_pressed() -> void:
	print("[FLOW-01] 進入遊戲！")
	get_tree().change_scene_to_file("res://scenes/World.tscn")
