## UpgradeSystem.gd
## 升級系統
## UPGRADE-03：XP 達標時暫停遊戲並顯示升級介面
## UPGRADE-04：玩家選擇升級卡牌後套用效果
## UPGRADE-05：免費重抽升級卡牌
## UPGRADE-06：升級池排除已達上限的項目

extends Node

# ── 升級定義（UPGRADE-04）────────────────────────────────
const UPGRADES: Array[Dictionary] = [
	{"id": "pearl_add",    "name": "珍珠加量",   "desc": "子彈數量 +1",       "max_level": 5, "rarity": "common"},
	{"id": "max_hp",       "name": "特濃奶茶",   "desc": "最大HP +20",         "max_level": 5, "rarity": "common"},
	{"id": "speed",        "name": "輕盈杯身",   "desc": "移速 +15%",          "max_level": 3, "rarity": "common"},
	{"id": "defense",      "name": "奶蓋防禦",   "desc": "受傷 -10%",          "max_level": 5, "rarity": "rare"},
	{"id": "bullet_speed", "name": "QQ彈力",     "desc": "子彈速度 +20%",      "max_level": 3, "rarity": "rare"},
	{"id": "fire_rate",    "name": "糖分暴衝",   "desc": "射擊冷卻 -0.05s",   "max_level": 5, "rarity": "rare"},
	{"id": "pickup_range", "name": "磁石珍珠",   "desc": "拾取範圍 +50px",     "max_level": 3, "rarity": "common"},
	{"id": "pearl_burst",  "name": "珍珠爆裂",   "desc": "擊殺爆炸 +10%",     "max_level": 3, "rarity": "epic"},
	{"id": "range",        "name": "吸管延伸",   "desc": "攻擊射程 +25%",     "max_level": 3, "rarity": "rare"},
	{"id": "lifesteal",    "name": "回收紙吸管", "desc": "擊殺回血 1HP",       "max_level": 3, "rarity": "epic"},
	# 武器卡
	{"id": "matcha",       "name": "抹茶珍珠",   "desc": "新武器：傷害 2, 冷卻 0.55s",  "max_level": 1, "rarity": "rare"},
	{"id": "taro",         "name": "芋頭珍珠",   "desc": "新武器：霰彈×3",              "max_level": 1, "rarity": "rare"},
	{"id": "popping_boba", "name": "黑糖爆爆珠", "desc": "新武器：爆炸傷害 3",          "max_level": 1, "rarity": "epic"},
	{"id": "oat",          "name": "燕麥珍珠",   "desc": "新武器：穿透快速連射",        "max_level": 1, "rarity": "rare"},
	{"id": "strawberry",   "name": "草莓珍珠",   "desc": "新武器：追蹤敵人（生存20分解鎖）", "max_level": 1, "rarity": "epic"},
]

# ── 當前升級等級追蹤 ──────────────────────────────────────
var _current_levels: Dictionary = {}

# ── UPGRADE-05：免費重抽 ─────────────────────────────────
var _reroll_count: int = 1  ## 每局 1 次

# ── 信號 ─────────────────────────────────────────────────
signal upgrade_chosen(upgrade_id: String)
signal upgrade_cards_drawn(cards: Array)


func _ready() -> void:
	# 初始化所有升級等級為 0
	for upg in UPGRADES:
		_current_levels[upg["id"]] = 0


# ── UPGRADE-03：抽取 3 張卡牌 ────────────────────────────
func draw_upgrade_cards(player: Node = null) -> Array[Dictionary]:
	var available: Array[Dictionary] = _get_available_upgrades(player)
	available.shuffle()
	var count: int = min(3, available.size())
	var cards: Array[Dictionary] = available.slice(0, count)
	upgrade_cards_drawn.emit(cards)
	return cards


# ── UPGRADE-06：排除已滿的升級 ──────────────────────────
func _get_available_upgrades(player: Node = null) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for upg in UPGRADES:
		var uid: String = upg["id"]
		var current_lv: int = _current_levels.get(uid, 0)
		var max_lv: int = upg["max_level"]
		if current_lv >= max_lv:
			continue
		# 武器需要已解鎖才能出現
		if uid in ["matcha", "taro", "popping_boba", "oat", "strawberry"]:
			if player == null or not _is_weapon_in_pool(player, uid):
				continue
		# 顯示當前層數
		var card: Dictionary = upg.duplicate()
		card["current_level"] = current_lv
		result.append(card)
	return result


func _is_weapon_in_pool(player: Node, weapon_id: String) -> bool:
	if player.has_method("get") :
		var pool: Dictionary = player.get("_weapon_in_pool")
		if pool != null:
			return pool.get(weapon_id, false)
	return false


# ── UPGRADE-04：玩家選擇卡牌 ─────────────────────────────
func choose_upgrade(upgrade_id: String, player: Node) -> void:
	if player == null:
		return
	if player.has_method("apply_upgrade"):
		player.apply_upgrade(upgrade_id)

	# 更新本地等級記錄
	_current_levels[upgrade_id] = _current_levels.get(upgrade_id, 0) + 1
	upgrade_chosen.emit(upgrade_id)
	print("[UPGRADE-04] 選擇升級：", upgrade_id, "，目前層數：", _current_levels[upgrade_id])


# ── UPGRADE-05：免費重抽 ─────────────────────────────────
func try_reroll(player: Node = null) -> Array[Dictionary]:
	if _reroll_count <= 0:
		print("[UPGRADE-05] 無可用重抽次數")
		return []
	_reroll_count -= 1
	print("[UPGRADE-05] 重抽！剩餘次數：", _reroll_count)
	return draw_upgrade_cards(player)


func get_reroll_count() -> int:
	return _reroll_count


# ── 重置（FLOW-06 再玩一次）─────────────────────────────
func reset() -> void:
	for key in _current_levels:
		_current_levels[key] = 0
	_reroll_count = 1
