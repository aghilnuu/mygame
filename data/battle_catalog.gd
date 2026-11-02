extends RefCounted
## Static prototype content. A hand UID identifies a copy, while its kind selects these rules.
const CARDS = {
	"dash": {"name":"疾行", "effect":"move", "special":false, "attack":false, "move":3, "draw":1, "flow":1},
	"slash": {"name":"横砍", "effect":"strike", "special":false, "attack":true, "damage":6, "reach":1, "flow":1},
	"sleep": {"name":"深睡", "effect":"draw", "special":false, "attack":false, "draw":3, "flow":1},
	"rage": {"name":"狂怒", "effect":"burst", "special":true, "attack":true, "damage":8, "reach":1, "combo_hits":1, "armor":true, "flow":1}
}
const BASIC_HAND = ["dash", "slash", "sleep"]
const STARTING_PACK = {"rage":10}
const WATCHER = {"name":"守望者", "hp":24, "damage":3, "reach":1, "steps":1, "mode":"lock"}
const HUNTER = {"name":"追猎者", "hp":24, "damage":3, "reach":1, "steps":1, "mode":"track"}
const TRAINING = [
	{"stats":WATCHER, "pos":Vector2i(4,4)},
	{"stats":HUNTER, "pos":Vector2i(7,2)}
]

static func aimed(card: Dictionary) -> bool:
	return card.effect in ["move", "strike"]

static func offsets(card: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var reach: int = card.get("reach",0)
	for y in range(-reach,reach+1):
		for x in range(-reach,reach+1):
			if (x == 0 and y == 0) or (card.effect == "burst" and x != 0 and y != 0):
				continue
			cells.append(Vector2i(x,y))
	return cells

static func caption(card: Dictionary, compact: bool) -> String:
	var parts := PackedStringArray()
	if card.has("move"):
		parts.append("移动%d" % card.move)
	if card.has("damage"):
		parts.append("伤害%d" % card.damage)
	if card.has("draw") and (parts.is_empty() or not compact):
		parts.append("抽%d" % card.draw)
	if not compact:
		parts.append("流逝%d" % card.flow)
	return "%s · %s" % [card.name, " / ".join(parts)]

static func description(card: Dictionary) -> String:
	var lines := PackedStringArray()
	var category := "特殊卡牌" if card.special else "基础卡牌 · 可无限使用"
	lines.append(category + (" · 攻击牌" if card.attack else ""))
	match card.effect:
		"move":
			lines.append("移动%d：选择同行或同列格子组成路线，可原地。双击终点或点击完成路线。" % card.move)
			lines.append("受阻时停在前一格并终止后续指令。")
		"strike":
			lines.append("选择预计位置周围%d格中的一格，造成%d点伤害。目标格为空时仍执行。" % [offsets(card).size(),card.damage])
		"burst":
			lines.append("对四个方向上距离%d格以内的敌人各造成%d点伤害。" % [card.reach,card.damage])
	if card.get("armor",false):
		lines.append("获得霸体：仍受伤害，免疫受击中断，敌方回合结束后解除。")
	if card.get("combo_hits",0) > 0:
		var extra := "多造成一次伤害" if card.combo_hits == 1 else "追加%d次伤害" % card.combo_hits
		lines.append("连招：紧接攻击牌时，%s。全部伤害结算后再流逝。" % extra)
	if card.has("draw"):
		lines.append("立即抽取%d张特殊牌，牌堆不足时洗回弃牌补抽。" % card.draw)
	lines.append("流逝%d。" % card.flow)
	if card.special:
		lines.append("执行后进入弃牌堆。")
	return "\n".join(lines)
