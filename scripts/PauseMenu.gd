## PauseMenu.gd
## FLOW-02：遊戲暫停選單
## FLOW-03：恢復遊戲

extends Control


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS


func show_menu() -> void:
	visible = true


func hide_menu() -> void:
	visible = false


## 「繼續」按鈕
func _on_resume_button_pressed() -> void:
	print("[FLOW-03] 恢復遊戲")
	hide_menu()
	get_tree().paused = false


## 「放棄本局」按鈕
func _on_quit_button_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
