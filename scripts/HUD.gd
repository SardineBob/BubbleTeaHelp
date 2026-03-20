## HUD.gd
## 遊戲 HUD 介面控制腳本
## HUD-01：HP 血條即時更新並變色
## HUD-02：XP 條即時更新（升級時閃光動畫）
## HUD-03：擊殺計數更新
## HUD-04：遊戲計時器每秒更新（MM:SS 格式）
## HUD-05：Boss 血條顯示與隱藏
## HUD-06：升級介面遮罩

extends CanvasLayer

# ── 節點參考（需在 Inspector 或 @onready 中指定）──────────
@onready var hp_bar: ProgressBar = $HPBar if has_node("HPBar") else null
@onready var xp_bar: ProgressBar = $XPBar if has_node("XPBar") else null
@onready var level_label: Label = $LevelLabel if has_node("LevelLabel") else null
@onready var kill_label: Label = $KillLabel if has_node("KillLabel") else null
@onready var timer_label: Label = $TimerLabel if has_node("TimerLabel") else null
@onready var boss_bar_container: Control = $BossBarContainer if has_node("BossBarContainer") else null
@onready var boss_hp_bar: ProgressBar = $BossBarContainer/BossHPBar if has_node("BossBarContainer/BossHPBar") else null
@onready var boss_name_label: Label = $BossBarContainer/BossNameLabel if has_node("BossBarContainer/BossNameLabel") else null
@onready var overlay: ColorRect = $Overlay if has_node("Overlay") else null
@onready var upgrade_panel: Control = $UpgradePanel if has_node("UpgradePanel") else null

# ── 狀態 ──────────────────────────────────────────────────
var _xp_flash_playing: bool = false


func _ready() -> void:
	# 隱藏 Boss 血條
	if boss_bar_container != null:
		boss_bar_container.visible = false

	# 隱藏升級介面
	if upgrade_panel != null:
		upgrade_panel.visible = false

	# 隱藏遮罩
	if overlay != null:
		overlay.visible = false


# ── HUD-01：HP 血條更新 ──────────────────────────────────
func update_hp(current: float, maximum: float) -> void:
	if hp_bar == null:
		return
	var ratio: float = current / maximum if maximum > 0.0 else 0.0
	hp_bar.value = ratio * 100.0

	# 顏色規則
	var style: StyleBoxFlat = hp_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if style == null:
		style = StyleBoxFlat.new()
		hp_bar.add_theme_stylebox_override("fill", style)

	if ratio > 0.5:
		style.bg_color = Color(0.2, 0.8, 0.2)  # 綠
	elif ratio > 0.3:
		style.bg_color = Color(0.9, 0.8, 0.1)  # 黃
	else:
		style.bg_color = Color(0.9, 0.2, 0.2)  # 紅
		# HP < 30% 輕微閃爍（以 modulate 實現）
		if not _is_blinking:
			_start_hp_blink()


var _is_blinking: bool = false


func _start_hp_blink() -> void:
	if _is_blinking:
		return
	_is_blinking = true
	while hp_bar != null and hp_bar.value / 100.0 < 0.3:
		hp_bar.modulate = Color(1.0, 0.4, 0.4)
		await get_tree().create_timer(0.3).timeout
		if hp_bar == null:
			break
		hp_bar.modulate = Color.WHITE
		await get_tree().create_timer(0.3).timeout
	if hp_bar != null:
		hp_bar.modulate = Color.WHITE
	_is_blinking = false


# ── HUD-02：XP 條更新 ────────────────────────────────────
func update_xp(current: float, needed: float, lv: int) -> void:
	if xp_bar != null:
		xp_bar.value = (current / needed * 100.0) if needed > 0.0 else 100.0
	if level_label != null:
		level_label.text = "Lv." + str(lv)


func play_xp_level_up_flash() -> void:
	if xp_bar == null or _xp_flash_playing:
		return
	_xp_flash_playing = true
	xp_bar.value = 100.0
	for i in range(3):
		xp_bar.modulate = Color(1.5, 1.5, 0.5)
		await get_tree().create_timer(0.1).timeout
		xp_bar.modulate = Color.WHITE
		await get_tree().create_timer(0.1).timeout
	xp_bar.value = 0.0
	_xp_flash_playing = false


# ── HUD-03：擊殺計數 ─────────────────────────────────────
func update_kill_count(count: int) -> void:
	if kill_label != null:
		kill_label.text = "擊殺：" + str(count)


# ── HUD-04：遊戲計時器 ───────────────────────────────────
func update_timer(seconds: float) -> void:
	if timer_label == null:
		return
	var mins: int = int(seconds / 60.0)
	var secs: int = int(seconds) % 60
	timer_label.text = "%02d:%02d" % [mins, secs]


# ── HUD-05：Boss 血條顯示/隱藏 ──────────────────────────
func show_boss_bar(boss_name: String, current_hp: float, max_hp: float) -> void:
	if boss_bar_container == null:
		return
	boss_bar_container.visible = true
	if boss_name_label != null:
		boss_name_label.text = boss_name
	_update_boss_hp(current_hp, max_hp)


func _update_boss_hp(current: float, maximum: float) -> void:
	if boss_hp_bar != null:
		boss_hp_bar.value = (current / maximum * 100.0) if maximum > 0.0 else 0.0


func hide_boss_bar() -> void:
	if boss_bar_container != null:
		boss_bar_container.visible = false


# ── HUD-06：升級介面遮罩 ─────────────────────────────────
func show_upgrade_panel() -> void:
	if overlay != null:
		overlay.visible = true
		overlay.color = Color(0.0, 0.0, 0.0, 0.5)
	if upgrade_panel != null:
		upgrade_panel.visible = true


func hide_upgrade_panel() -> void:
	if overlay != null:
		overlay.visible = false
	if upgrade_panel != null:
		upgrade_panel.visible = false
