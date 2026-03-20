## DeathScreen.gd
## FLOW-04：死亡結算畫面
## FLOW-06：再玩一次

extends Control

## 由 World 傳入的結算數據
var survival_time: float = 0.0
var kill_count: int = 0
var final_level: int = 1
var skills_used: Array[String] = []


func _ready() -> void:
	get_tree().paused = false
	_display_stats()


func _display_stats() -> void:
	var mins: int = int(survival_time) / 60
	var secs: int = int(survival_time) % 60

	if has_node("TimeLabel"):
		$TimeLabel.text = "生存時間：%02d:%02d" % [mins, secs]
	if has_node("KillLabel"):
		$KillLabel.text = "擊殺數：" + str(kill_count)
	if has_node("LevelLabel"):
		$LevelLabel.text = "最終等級：" + str(final_level)
	if has_node("SkillsLabel"):
		$SkillsLabel.text = "技能：" + ", ".join(skills_used)

	print("[FLOW-04] 死亡結算 - 時間：%02d:%02d，擊殺：%d，等級：%d" % [mins, secs, kill_count, final_level])


## 「再玩一次」按鈕（FLOW-06）
func _on_retry_button_pressed() -> void:
	print("[FLOW-06] 再玩一次！")
	get_tree().change_scene_to_file("res://scenes/World.tscn")


## 「返回主選單」按鈕
func _on_main_menu_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
