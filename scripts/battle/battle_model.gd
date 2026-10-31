extends RefCounted
## Rules only: no scene nodes, rendering or animation dependencies.
const CARDS = {
	"dash": {"name": "疾行", "flow": 1, "attack": false},
	"slash": {"name": "横砍", "flow": 1, "attack": true},
	"sleep": {"name": "深睡", "flow": 1, "attack": false},
	"rage": {"name": "狂怒", "flow": 1, "attack": true, "armor": true}
}
var player := Vector2i(2, 4)
var hp := 30
var obstacles: Array = [Vector2i(4, 2), Vector2i(4, 3), Vector2i(6, 5)]
var enemies: Array = []
var hand: Array = []
var deck: Array = []
var discard: Array = []
var queue: Array = []
var events: Array = []
var interrupted := false
var super_armor := false
var result := ""
var shuffle_count := 0
var rng := RandomNumberGenerator.new()

func _init(seed_value: int = 42) -> void:
	rng.seed = seed_value
	for i in range(10):
		deck.append(i)
	shuffle_deck()
	draw_cards(5)
	enemies = [
		{"name": "守望者", "pos": Vector2i(4, 4), "hp": 24, "mode": "lock", "intent": "", "target": player},
		{"name": "追猎者", "pos": Vector2i(7, 2), "hp": 24, "mode": "track", "intent": "", "target": player}
	]
	refresh_intents()
	events.clear()

func inside(p: Vector2i) -> bool:
	return p.x >= 0 and p.x < 9 and p.y >= 0 and p.y < 7

func blocked(p: Vector2i) -> bool:
	if not inside(p) or p in obstacles:
		return true
	for enemy in enemies:
		if enemy.hp > 0 and enemy.pos == p:
			return true
	return false

func shuffle_deck() -> void:
	for i in range(deck.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var value = deck[i]
		deck[i] = deck[j]
		deck[j] = value

func draw_cards(count: int) -> int:
	var drawn := 0
	for i in range(count):
		if deck.is_empty() and not discard.is_empty():
			deck = discard.duplicate()
			discard.clear()
			shuffle_deck()
			shuffle_count += 1
		if deck.is_empty():
			break
		hand.append(deck.pop_back())
		drawn += 1
	return drawn

func projected_position(before: int = -1) -> Vector2i:
	var pos := player
	var limit := queue.size() if before < 0 else before
	for i in range(limit):
		var card: Dictionary = queue[i]
		if card.kind == "dash" and card.valid and not card.path.is_empty():
			pos = card.path.back()
	return pos

func add_card(kind: String, uid: int = -1) -> bool:
	if queue.size() >= 5 or not CARDS.has(kind) or not result.is_empty():
		return false
	if kind == "rage":
		if uid not in hand:
			return false
		hand.erase(uid)
	queue.append({"kind": kind, "uid": uid, "path": [], "target": Vector2i(-1, -1), "valid": kind in ["sleep", "rage"]})
	return true

func invalidate_after(index: int) -> void:
	for i in range(index + 1, queue.size()):
		if queue[i].kind in ["dash", "slash"]:
			queue[i].valid = false
			queue[i].path = []
			queue[i].target = Vector2i(-1, -1)

func remove_card(index: int) -> void:
	var card: Dictionary = queue[index]
	if card.kind == "rage":
		hand.append(card.uid)
	queue.remove_at(index)
	invalidate_after(index - 1)

func set_target(index: int, target: Vector2i, path: Array = []) -> bool:
	var card: Dictionary = queue[index]
	var origin := projected_position(index)
	if not inside(target):
		return false
	if card.kind == "slash":
		var delta := target - origin
		if delta == Vector2i.ZERO or maxi(absi(delta.x), absi(delta.y)) > 1:
			return false
	elif card.kind == "dash":
		if path.size() > 3:
			return false
		var last := origin
		for cell in path:
			if not inside(cell) or absi(cell.x-last.x)+absi(cell.y-last.y) != 1:
				return false
			last = cell
		if last != target:
			return false
	else:
		return false
	var changed: bool = not card.valid or card.target != target or card.path != path
	card.target = target
	card.path = path.duplicate()
	card.valid = true
	if changed:
		invalidate_after(index)
	return true

func snapshot(message: String = "") -> Dictionary:
	return {"player": player, "hp": hp, "enemies": enemies.duplicate(true), "hand": hand.duplicate(), "deck": deck.size(), "discard": discard.size(), "result": result, "message": message, "shuffle": shuffle_count, "super_armor": super_armor}

func record(message: String) -> void:
	events.append(snapshot(message))

func grant_super_armor() -> void:
	# A state lasts until the next complete enemy round, even across planning.
	super_armor = true
	record("进入霸体：仍受伤害，免疫受击中断，持续至敌方回合结束")

func check_result() -> void:
	if hp <= 0:
		hp = 0
		result = "梦境破碎"
	elif enemies.all(func(e): return e.hp <= 0):
		result = "战斗胜利"
	if not result.is_empty():
		super_armor = false

func refresh_intents() -> void:
	for enemy in enemies:
		if enemy.hp <= 0:
			continue
		var delta: Vector2i = enemy.pos - player
		enemy.intent = "attack" if maxi(absi(delta.x), absi(delta.y)) <= 1 else "move"
		enemy.target = player

func step_toward(start: Vector2i) -> Vector2i:
	var frontier: Array = [start]
	var previous := {start: start}
	var found := false
	while not frontier.is_empty():
		var pos: Vector2i = frontier.pop_front()
		if pos == player:
			found = true
			break
		for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = pos + dir
			if not previous.has(next) and inside(next) and (next == player or not blocked(next)):
				previous[next] = pos
				frontier.append(next)
	if not found:
		return start
	var cursor := player
	while previous[cursor] != start:
		cursor = previous[cursor]
	return start if cursor == player else cursor

func enemy_round() -> void:
	for enemy in enemies:
		if enemy.hp <= 0 or not result.is_empty():
			continue
		if enemy.intent == "move":
			enemy.pos = step_toward(enemy.pos)
			record(enemy.name + "移动一格")
		else:
			var target: Vector2i = enemy.target if enemy.mode == "lock" else player
			var delta: Vector2i = target - enemy.pos
			if target == player and maxi(absi(delta.x), absi(delta.y)) <= 1:
				hp -= 3
				var protected := super_armor
				if not protected:
					interrupted = true
				check_result()
				record(enemy.name + ("命中，受到3点伤害，霸体抵抗中断" if protected else "命中，受到3点伤害，指令中断"))
			else:
				record(enemy.name + "攻击落空")
	if super_armor:
		super_armor = false
		record("本次所有敌人行动完毕，霸体结束")
	refresh_intents()
	record("敌方回合结束，更新下一回合意图")

func damage_at(target: Vector2i, amount: int) -> bool:
	for enemy in enemies:
		if enemy.hp > 0 and enemy.pos == target:
			enemy.hp = maxi(0, enemy.hp - amount)
			return true
	return false

func execute() -> Array:
	events.clear()
	if queue.is_empty() or queue.any(func(c): return not c.valid) or not result.is_empty():
		return []
	interrupted = false
	var previous_attack := false
	var used: Array = []
	var completed := 0
	for card in queue:
		if interrupted or not result.is_empty():
			if card.kind == "rage":
				hand.append(card.uid)
			continue
		if card.kind == "rage":
			used.append(card.uid)
		if CARDS[card.kind].get("armor", false):
			grant_super_armor()
		match card.kind:
			"dash":
				for cell in card.path:
					if blocked(cell):
						interrupted = true
						record("移动受阻，停在前一格，结束后续指令")
						break
					player = cell
					record("疾行：移动")
				if not interrupted:
					record("疾行：抽取%d张牌" % draw_cards(1))
			"slash":
				var hit := damage_at(card.target, 6)
				record("横砍：6点伤害" if hit else "横砍：打空")
			"sleep":
				record("深睡：抽取%d张牌" % draw_cards(3))
			"rage":
				var repeats := 2 if previous_attack else 1
				for repeat_index in range(repeats):
					if not result.is_empty():
						break
					if repeat_index > 0:
						grant_super_armor()
					for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
						damage_at(player + dir, 8)
					record("狂怒%s：四邻格各8点伤害" % ("连招追加" if repeat_index == 1 else ""))
					check_result()
					# The combo copy keeps attack/armor but explicitly has flow 0.
					var flow_count: int = CARDS.rage.flow if repeat_index == 0 else 0
					for tick in range(flow_count):
						if result.is_empty():
							enemy_round()
		check_result()
		if not interrupted:
			completed += 1
			previous_attack = CARDS[card.kind].attack
			if card.kind != "rage":
				for tick in range(CARDS[card.kind].flow):
					if result.is_empty():
						enemy_round()
	for uid in used:
		discard.append(uid)
	queue.clear()
	record("弃牌阶段：已使用特殊牌进入弃牌堆。%s" % ("指令已中断" if interrupted else "完成%d张指令" % completed))
	return events.duplicate(true)
