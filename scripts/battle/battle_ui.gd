extends Control
const Model = preload("res://scripts/battle/battle_model.gd")
const ORIGIN := Vector2(24, 100)
const CELL := 58.0
var model = Model.new()
var shown: Dictionary
var selected := -1
var inspected := -1
var intent_buttons: Array = []
var intent_popup := AcceptDialog.new()
var card_popup := AcceptDialog.new()
var return_card_button: Button
var detail_index := -1
var route: Array = []
var busy := false
var info: Label
var hint: Label
var log_view: RichTextLabel
var tray := HBoxContainer.new()
var hand_row := HBoxContainer.new()
var actions: Array = []
var confirm: Button

func _ready() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei"])
	var skin := Theme.new()
	skin.default_font = font
	skin.default_font_size = 18
	theme = skin
	RenderingServer.set_default_clear_color(Color("091321"))
	label_at("清醒梦 / 战斗试炼", Vector2(24, 12), Vector2(450, 38), 27)
	button_at("重新开始", Vector2(940, 16), Vector2(140, 38), restart)
	button_at("返回菜单", Vector2(1090, 16), Vector2(160, 38), back)
	hint = label_at("", Vector2(24, 58), Vector2(1220, 36), 18)
	info = label_at("", Vector2(580, 100), Vector2(660, 170), 19)
	log_view = RichTextLabel.new()
	log_view.position = Vector2(580, 275)
	log_view.size = Vector2(660, 165)
	log_view.scroll_following = true
	add_child(log_view)
	confirm = button_at("确认执行", Vector2(580, 454), Vector2(220, 48), run_plan)
	actions.append(button_at("完成路线", Vector2(812, 454), Vector2(200, 48), finish_route))
	actions.append(button_at("清空托盘", Vector2(1024, 454), Vector2(220, 48), clear_tray))
	tray.position = Vector2(24, 525)
	tray.add_theme_constant_override("separation", 8)
	add_child(tray)
	for i in range(3):
		var id: String = ["dash", "slash", "sleep"][i]
		var caption: String = ["疾行 · 移动3 / 抽1 / 流逝1", "横砍 · 伤害6 / 流逝1", "深睡 · 抽3 / 流逝1"][i]
		var card_button := button_at(caption, Vector2(24 + i * 410, 584), Vector2(398, 42), func(): choose(id))
		bind_card_details(card_button, id)
		actions.append(card_button)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(24, 640)
	scroll.size = Vector2(1220, 66)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	scroll.add_child(hand_row)
	hand_row.add_theme_constant_override("separation", 8)
	shown = model.snapshot()
	intent_popup.title = "敌人行动意图"
	add_child(intent_popup)
	card_popup.title = "卡牌详情"
	card_popup.get_ok_button().text = "关闭"
	add_child(card_popup)
	return_card_button = card_popup.add_button("取回此牌", true, "return_card")
	card_popup.custom_action.connect(func(action):
		if action == "return_card":
			return_detailed_card())
	for i in range(model.enemies.size()):
		var intent_button := button_at("", Vector2.ZERO, Vector2(42, 26), func(): show_intent(i))
		intent_button.tooltip_text = "点击查看详细意图"
		intent_button.add_theme_font_size_override("font_size", 16)
		intent_buttons.append(intent_button)
	refresh()
	say("开战抽取5张特殊牌。狂怒：霸体、四邻格8伤害、流逝1；连招追加流逝0的狂怒。")

func label_at(text: String, pos: Vector2, dimensions: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = dimensions
	label.add_theme_font_size_override("font_size", font_size)
	add_child(label)
	return label

func button_at(text: String, pos: Vector2, dimensions: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = dimensions
	button.pressed.connect(callback)
	add_child(button)
	return button

func say(message: String) -> void:
	log_view.append_text(message + "\n")

func bind_card_details(button: Button, kind: String, tray_index: int = -1) -> void:
	button.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			button.accept_event()
			show_card_details(kind, tray_index))

func show_card_details(kind: String, tray_index: int = -1) -> void:
	detail_index = tray_index
	var descriptions := {
		"dash": "基础卡牌 · 可无限使用\n移动3：分段选择同行或同列格子，累计最多3格，可原地。\n双击终点或点击完成路线；受阻停在前格并终止后续指令。\n随后抽1张特殊牌，流逝1。",
		"slash": "基础卡牌 · 攻击牌 · 可无限使用\n选择预计位置周围8格中的一格，造成6点伤害。\n目标格没有敌人时仍执行动作和流逝。\n流逝1。",
		"sleep": "基础卡牌 · 可无限使用\n抽3张特殊卡牌。\n抽牌堆耗尽时洗回弃牌堆；两个牌堆都为空时停止抽牌。\n流逝1。",
		"rage": "特殊卡牌 · 攻击牌\n对周围4个相邻格中的敌人各造成8点伤害，获得霸体，流逝1。\n连招：紧接攻击牌时，追加一次流逝0的狂怒，保留攻击和霸体。\n霸体：仍受伤害，但免疫受击中断；所有敌人完成一回合后解除。\n使用后进入弃牌堆，连招追加不消耗额外手牌。"
	}
	card_popup.title = Model.CARDS[kind].name + " · 卡牌详情"
	card_popup.dialog_text = descriptions[kind]
	return_card_button.visible = tray_index >= 0
	return_card_button.disabled = busy or tray_index < 0 or tray_index >= model.queue.size()
	card_popup.popup_centered(Vector2i(760,320))

func return_detailed_card() -> void:
	if busy or detail_index < 0 or detail_index >= model.queue.size():
		return
	model.remove_card(detail_index)
	detail_index = -1
	selected = -1
	inspected = -1
	route.clear()
	card_popup.hide()
	refresh()

func show_intent(index: int) -> void:
	var enemy: Dictionary = shown.enemies[index]
	if enemy.hp <= 0:
		return
	var detail := ""
	if enemy.intent == "move":
		detail = "下次行动：移动。沿可通行路线向玩家靠近最多1格，不能穿过障碍或其他敌人。"
	elif enemy.mode == "lock":
		detail = "下次行动：锁定格攻击。目标：第%d列、第%d行（左上为1,1）。\n造成3点伤害，目标格不会随玩家移动而改变；目标不在攻击距离内时打空。" % [enemy.target.x+1, enemy.target.y+1]
	else:
		detail = "下次行动：瞄准玩家攻击。执行时瞄准玩家当时所在格，造成3点伤害。\n攻击距离为敌人周围8格，玩家离开攻击距离时打空。"
	intent_popup.dialog_text = "%s · 行动顺序 %d\n%s\n流逝1触发一次行动；仅展示下次意图。" % [enemy.name,index+1,detail]
	intent_popup.popup_centered(Vector2i(660,220))

func refresh() -> void:
	if not busy:
		shown = model.snapshot()
	info.text = "生命 %d / 30     抽牌堆 %d  ·  弃牌堆 %d  ·  手牌 %d\n洗牌次数 %d  ·  状态：%s\n" % [shown.hp, shown.deck, shown.discard, shown.hand.size(), shown.shuffle, "霸体（敌方回合结束后解除）" if shown.super_armor else "正常"]
	for i in range(shown.enemies.size()):
		var e: Dictionary = shown.enemies[i]
		var intent_button: Button = intent_buttons[i]
		intent_button.visible = e.hp > 0
		intent_button.position = center(e.pos) + Vector2(-21,-48)
		intent_button.text = "移" if e.intent == "move" else ("锁" if e.mode == "lock" else "追")
		var intent := "已击败" if e.hp <= 0 else ("移动1格" if e.intent == "move" else ("锁定格攻击3" if e.mode == "lock" else "瞄准玩家攻击3"))
		info.text += "%d. %s  HP %d  |  下回合：%s\n" % [i+1, e.name, e.hp, intent]
	if not shown.result.is_empty():
		hint.text = shown.result + " · 可重新开始或返回菜单"
	elif busy:
		hint.text = shown.message
	elif selected >= 0:
		hint.text = ("第%d张疾行：单击添加直线路段，双击终点或点完成路线；右键撤销一步。" if model.queue[selected].kind == "dash" else "第%d张横砍：点击预计位置周围8格之一，可指定空格。") % (selected+1)
	else:
		hint.text = "左键选牌或调整目标，右键查看卡牌；托盘牌可在详情中取回。最多排列5张。"
	confirm.disabled = busy or selected >= 0 or model.queue.is_empty() or model.queue.any(func(c): return not c.valid) or not model.result.is_empty()
	for button in actions:
		button.disabled = busy or not model.result.is_empty()
	if not busy:
		for child in tray.get_children():
			tray.remove_child(child)
			child.queue_free()
		for i in range(5):
			var button := Button.new()
			button.custom_minimum_size = Vector2(236, 44)
			if i < model.queue.size():
				var c: Dictionary = model.queue[i]
				button.text = "%d. %s  %s" % [i+1, Model.CARDS[c.kind].name, "✓" if c.valid else "待指定"]
				button.pressed.connect(func(): edit_target(i))
				bind_card_details(button, c.kind, i)
			else:
				button.text = "%d. 空槽" % (i+1)
				button.disabled = true
			tray.add_child(button)
		for child in hand_row.get_children():
			hand_row.remove_child(child)
			child.queue_free()
		for uid in model.hand:
			var button := Button.new()
			button.text = "狂怒 #%d" % (uid+1)
			button.tooltip_text = "特殊牌：进入霸体，四邻格各8伤害，流逝1。接在攻击牌后追加一次流逝0的狂怒（仍有攻击与霸体）。\n霸体仍受伤害，但免疫受击中断；持续到敌方完整一回合结束。"
			button.custom_minimum_size = Vector2(140, 44)
			button.pressed.connect(func(): choose("rage", uid))
			bind_card_details(button, "rage")
			hand_row.add_child(button)
	queue_redraw()

func choose(kind: String, uid: int = -1) -> void:
	if busy:
		return
	if model.queue.any(func(c): return not c.valid):
		say("请先完成托盘中待指定的目标。")
		return
	if model.add_card(kind, uid):
		inspected = model.queue.size()-1
		selected = model.queue.size()-1 if kind in ["dash", "slash"] else -1
		route.clear()
	refresh()

func edit_target(index: int) -> void:
	if busy:
		return
	for i in range(index):
		if not model.queue[i].valid:
			say("请从前向后重新指定目标。")
			return
	inspected = index
	selected = index if model.queue[index].kind in ["dash", "slash"] else -1
	route.clear()
	refresh()

func finish_route() -> void:
	if busy or selected < 0 or model.queue[selected].kind != "dash":
		return
	var target: Vector2i = model.projected_position(selected) if route.is_empty() else route.back()
	if model.set_target(selected, target, route):
		selected = -1
		route = []
	refresh()

func _gui_input(event: InputEvent) -> void:
	if busy or selected < 0 or not (event is InputEventMouseButton) or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		if not route.is_empty():
			route.pop_back()
		queue_redraw()
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	var local: Vector2 = (event.position - ORIGIN) / CELL
	var target := Vector2i(floori(local.x), floori(local.y))
	if not model.inside(target):
		return
	if model.queue[selected].kind == "slash":
		if model.set_target(selected, target):
			selected = -1
		else:
			say("横砍只能指定预计位置周围8格中的一格。")
	else:
		var last: Vector2i = model.projected_position(selected) if route.is_empty() else route.back()
		var delta := target - last
		if delta.x != 0 and delta.y != 0:
			say("请选择同行或同列的格子。")
			return
		var distance := absi(delta.x)+absi(delta.y)
		if route.size()+distance > 3:
			say("疾行路线最多3格。")
			return
		var direction := Vector2i(signi(delta.x), signi(delta.y))
		for step in range(distance):
			last += direction
			route.append(last)
		if event.double_click:
			finish_route()
	refresh()

func clear_tray() -> void:
	if busy:
		return
	while not model.queue.is_empty():
		model.remove_card(model.queue.size()-1)
	selected = -1
	inspected = -1
	route.clear()
	refresh()

func run_plan() -> void:
	if busy or confirm.disabled:
		return
	busy = true
	selected = -1
	inspected = -1
	route.clear()
	var playback: Array = model.execute()
	for child in tray.get_children():
		child.disabled = true
	for child in hand_row.get_children():
		child.disabled = true
	for frame in playback:
		if not is_inside_tree():
			return
		shown = frame
		say(frame.message)
		refresh()
		await get_tree().create_timer(0.38).timeout
	busy = false
	refresh()

func restart() -> void:
	if busy:
		say("请等待本组指令演出结束。")
		return
	get_tree().reload_current_scene()

func back() -> void:
	if busy:
		say("请等待本组指令演出结束。")
		return
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")

func _draw() -> void:
	if shown.is_empty():
		return
	var font := get_theme_default_font()
	for y in range(7):
		for x in range(9):
			var cell := Vector2i(x,y)
			var rect := Rect2(ORIGIN + Vector2(cell)*CELL, Vector2.ONE*(CELL-2))
			var color := Color("203344") if (x+y)%2 == 0 else Color("1a2b3d")
			if cell in model.obstacles:
				color = Color("626777")
			draw_rect(rect, color)
			if cell in model.obstacles:
				draw_string(font, rect.position+Vector2(16,35), "墙", HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
	for enemy in shown.enemies:
		if enemy.hp > 0 and enemy.intent == "attack" and enemy.mode == "lock":
			draw_rect(Rect2(ORIGIN+Vector2(enemy.target)*CELL+Vector2(3,3),Vector2.ONE*(CELL-8)),Color("f0ac5a"),false,3)
	var path_position: Vector2i = model.player
	if not busy:
		for card in model.queue:
			if card.kind == "dash" and card.valid:
				for cell in card.path:
					draw_line(center(path_position), center(cell), Color("4c9e91"), 3)
					path_position = cell
				# A small dot identifies the endpoint, including a stationary move.
				draw_circle(center(card.target), 5, Color("8ee5bd"))
		if inspected >= 0 and inspected < model.queue.size():
			var inspected_card: Dictionary = model.queue[inspected]
			var origin: Vector2i = model.projected_position(inspected)
			var offsets: Array = []
			if inspected_card.kind == "slash":
				for dy in range(-1,2):
					for dx in range(-1,2):
						if dx != 0 or dy != 0:
							offsets.append(Vector2i(dx,dy))
			elif inspected_card.kind == "rage":
				offsets = [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]
			for offset in offsets:
				var cell: Vector2i = origin+offset
				if model.inside(cell):
					draw_rect(Rect2(ORIGIN+Vector2(cell)*CELL+Vector2(3,3),Vector2.ONE*(CELL-8)),Color(1.0,0.4,0.35,0.28))
			if inspected_card.kind == "slash" and inspected_card.valid:
				var target_center := center(inspected_card.target)
				draw_circle(target_center,22,Color("ffae89"),false,3)
				draw_line(target_center-Vector2(9,9),target_center+Vector2(9,9),Color("ffae89"),2)
				draw_line(target_center-Vector2(-9,9),target_center+Vector2(-9,9),Color("ffae89"),2)
		if selected >= 0:
			path_position = model.projected_position(selected)
			draw_circle(center(path_position), 24, Color("80cbd2"), false, 2)
			for cell in route:
				draw_line(center(path_position),center(cell), Color("e4cc75"),4)
				path_position = cell
			if model.queue[selected].kind == "dash":
				draw_circle(center(path_position),5,Color("ffe69b"))
	for i in range(shown.enemies.size()):
		var e: Dictionary = shown.enemies[i]
		if e.hp <= 0:
			continue
		var pos := center(e.pos)
		draw_circle(pos,20,Color("d56f72") if e.mode == "lock" else Color("ba82d6"))
		draw_string(font,pos+Vector2(-6,7),str(i+1),HORIZONTAL_ALIGNMENT_LEFT,-1,20)
	draw_circle(center(shown.player),18,Color("58c5cb"))
	if shown.super_armor:
		draw_circle(center(shown.player),23,Color("ffe69b"),false,3)
	draw_string(font,center(shown.player)+Vector2(-10,7),"我",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("102538"))
	# Endpoints stay visible even when a character occupies that tile.
	if not busy:
		for card in model.queue:
			if card.kind == "dash" and card.valid:
				draw_circle(center(card.target),5,Color("8ee5bd"))
		if selected >= 0 and model.queue[selected].kind == "dash":
			var endpoint: Vector2i = model.projected_position(selected) if route.is_empty() else route.back()
			draw_circle(center(endpoint),5,Color("ffe69b"))

func center(cell: Vector2i) -> Vector2:
	return ORIGIN+Vector2(cell)*CELL+Vector2.ONE*(CELL/2)
