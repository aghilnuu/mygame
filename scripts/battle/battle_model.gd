extends RefCounted
## Rules only: no scene nodes, rendering or animation dependencies.
const Catalog = preload("res://data/battle_catalog.gd")
var cards: Dictionary
var copy_kinds: Array[String] = []
var player := Vector2i(2, 4)
var hp := 30
var floor_bounds := Rect2i(0,0,9,7)
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

func _init(seed_value: int = 42, pack: Dictionary = Catalog.STARTING_PACK, definitions: Dictionary = Catalog.CARDS) -> void:
	rng.seed = seed_value
	cards = definitions
	for kind in pack:
		assert(cards.has(kind) and cards[kind].special and pack[kind] >= 0)
		for copy in range(pack[kind]):
			deck.append(copy_kinds.size())
			copy_kinds.append(kind)
	shuffle_deck()
	draw_cards(5)
	configure_enemies(Catalog.TRAINING)

func configure_enemies(lineup: Array) -> void:
	enemies.clear()
	for spawn in lineup:
		var enemy: Dictionary = spawn.stats.duplicate()
		enemy.pos = spawn.pos
		enemies.append(enemy)
	refresh_intents()

func inside(p: Vector2i) -> bool:
	return floor_bounds.has_point(p)

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
		if cards[card.kind].effect == "move" and card.valid and not card.path.is_empty():
			pos = card.path.back()
	return pos

func add_card(kind: String, uid: int = -1) -> bool:
	if queue.size() >= 5 or not cards.has(kind) or not result.is_empty():
		return false
	if cards[kind].special:
		if uid not in hand or copy_kinds[uid] != kind:
			return false
		hand.erase(uid)
	queue.append({"kind": kind, "uid": uid, "path": [], "target": Vector2i(-1, -1), "valid": not Catalog.aimed(cards[kind])})
	return true

func invalidate_after(index: int) -> void:
	for i in range(index + 1, queue.size()):
		if Catalog.aimed(cards[queue[i].kind]):
			queue[i].valid = false
			queue[i].path = []
			queue[i].target = Vector2i(-1, -1)

func remove_card(index: int) -> void:
	var card: Dictionary = queue[index]
	if cards[card.kind].special:
		hand.append(card.uid)
	queue.remove_at(index)
	invalidate_after(index - 1)

func set_target(index: int, target: Vector2i, path: Array = []) -> bool:
	var card: Dictionary = queue[index]
	var origin := projected_position(index)
	if not inside(target):
		return false
	if cards[card.kind].effect == "strike":
		var delta := target - origin
		if delta not in Catalog.offsets(cards[card.kind]):
			return false
	elif cards[card.kind].effect == "move":
		if path.size() > cards[card.kind].move:
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
		enemy.intent = "attack" if maxi(absi(delta.x), absi(delta.y)) <= enemy.get("reach", Catalog.WATCHER.reach) else "move"
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
			var moved := 0
			for step in range(enemy.get("steps", Catalog.WATCHER.steps)):
				var next := step_toward(enemy.pos)
				if next == enemy.pos:
					break
				enemy.pos = next
				moved += 1
			var action := "原地待命" if moved == 0 else "移动%d格" % moved
			record(enemy.name + action)
		else:
			var target: Vector2i = enemy.target if enemy.mode == "lock" else player
			var delta: Vector2i = target - enemy.pos
			if target == player and maxi(absi(delta.x), absi(delta.y)) <= enemy.get("reach", Catalog.WATCHER.reach):
				var damage: int = enemy.get("damage", Catalog.WATCHER.damage)
				hp -= damage
				var protected := super_armor
				if not protected:
					interrupted = true
				check_result()
				record("%s命中，受到%d点伤害，%s" % [enemy.name, damage, "霸体抵抗中断" if protected else "指令中断"])
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
			if cards[card.kind].special:
				hand.append(card.uid)
			continue
		if cards[card.kind].special:
			used.append(card.uid)
		if cards[card.kind].get("armor", false):
			grant_super_armor()
		var definition: Dictionary = cards[card.kind]
		match definition.effect:
			"move":
				for cell in card.path:
					if blocked(cell):
						interrupted = true
						record("移动受阻，停在前一格，结束后续指令")
						break
					player = cell
					record("疾行：移动")
			"strike":
				var hit := damage_at(card.target, definition.damage)
				record("%s：%s" % [definition.name, "%d点伤害" % definition.damage if hit else "打空"])
			"burst":
				var repeats: int = 1 + (definition.get("combo_hits",0) if previous_attack else 0)
				for repeat_index in range(repeats):
					if not result.is_empty():
						break
					for dir in Catalog.offsets(definition):
						damage_at(player + dir, definition.damage)
					record("%s%s：范围内各%d点伤害" % [definition.name, "连招追加" if repeat_index > 0 else "", definition.damage])
					check_result()
		var requested: int = cards[card.kind].get("draw", 0)
		if not interrupted and requested > 0:
			var shuffles_before := shuffle_count
			var drawn := draw_cards(requested)
			var detail := "（洗回弃牌后补抽）" if shuffle_count > shuffles_before else ""
			record("%s：抽取%d，实际入手%d张%s" % [cards[card.kind].name, requested, drawn, detail])
		check_result()
		if not interrupted:
			completed += 1
			previous_attack = cards[card.kind].attack
			# All damage instructions, including combo damage, precede card flow.
			for tick in range(cards[card.kind].flow):
				if result.is_empty():
					enemy_round()
	for uid in used:
		discard.append(uid)
	queue.clear()
	record("弃牌阶段：已使用特殊牌进入弃牌堆。%s" % ("指令已中断" if interrupted else "完成%d张指令" % completed))
	return events.duplicate(true)
