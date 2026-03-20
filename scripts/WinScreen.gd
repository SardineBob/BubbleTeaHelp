## WinScreen.gd
## FLOW-05：勝利結算畫面
## FLOW-06：再玩一次

extends Control

var survival_time: float = 0.0
var kill_count: int = 0
var final_level: int = 1
var skills_used: Array[String] = []


func _ready() -> void:
	get_tree().paused = false
	_display_stats()
	_play_victory_animation()


func _display_stats() -> void:
	var mins: int = int(survival_time / 60.0)
	var secs: int = int(survival_time) % 60

	if has_node("TimeLabel"):
		$TimeLabel.text = "生存時間：%02d:%02d" % [mins, secs]
	if has_node("KillLabel"):
		$KillLabel.text = "擊殺數：" + str(kill_count)
	if has_node("LevelLabel"):
		$LevelLabel.text = "最終等級：" + str(final_level)

	print("[FLOW-05] 勝利結算！存活 %02d:%02d，擊殺 %d，等級 %d" % [mins, secs, kill_count, final_level])


func _play_victory_animation() -> void:
	## 勝利演出動畫（簡化版：modulate 閃爍）
	for i in range(5):
		modulate = Color(1.5, 1.5, 0.5)
		await get_tree().create_timer(0.15).timeout
		modulate = Color.WHITE
		await get_tree().create_timer(0.15).timeout


func _on_retry_button_pressed() -> void:
	print("[FLOW-06] 再玩一次！")
	get_tree().change_scene_to_file("res://scenes/World.tscn")


func _on_main_menu_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
