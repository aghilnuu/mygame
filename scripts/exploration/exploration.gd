extends Control

const BattleScene = preload("res://scenes/battle/battle.tscn")
const ROOMS := ["入梦回廊", "回声庭院", "星门之间"]
const WALLS := [
	[Vector2i(4,2), Vector2i(4,3), Vector2i(8,5), Vector2i(8,6)],
	[Vector2i(3,2), Vector2i(4,2), Vector2i(8,6), Vector2i(9,6)],
	[Vector2i(5,2), Vector2i(7,2), Vector2i(5,6), Vector2i(7,6)]
]
const LEFT_DOOR := Vector2i(0,4)
const RIGHT_DOOR := Vector2i(12,4)
const SHADE := Vector2i(6,4)
const PORTAL := Vector2i(8,4)
const ORIGIN := Vector2(72,148)
const TILE := 53.0
const ROOM_FLOOR := Rect2i(1,1,11,7)
const DIRECTIONS := {KEY_W: Vector2i.UP, KEY_A: Vector2i.LEFT, KEY_S: Vector2i.DOWN, KEY_D: Vector2i.RIGHT}

var depth := 1
var room := 0
var player := Vector2i(2,4)
var cleared := false
var health := 30
var encounter: Control
var menu := Button.new()
var note := ""
var next_step_ms := 0

func _ready() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC"])
	var ui_theme := Theme.new()
	ui_theme.default_font = font
	theme = ui_theme
	menu.text = "返回菜单"
	menu.position = Vector2(1090,28)
	menu.size = Vector2(140,40)
	add_child(menu)
	menu.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn"))

func _unhandled_key_input(event: InputEvent) -> void:
	if is_instance_valid(encounter) or not event is InputEventKey or not event.pressed:
		return
	var key: int = event.physical_keycode
	if key == KEY_O and not event.echo:
		interact()
	elif DIRECTIONS.has(key):
		var now := Time.get_ticks_msec()
		if not event.echo or now >= next_step_ms:
			step(DIRECTIONS[key])
			next_step_ms = now + 130
	else:
		return
	get_viewport().set_input_as_handled()

func step(direction: Vector2i) -> void:
	var target := player + direction
	if not ROOM_FLOOR.has_point(target) or target in WALLS[room]:
		return
	if (room == 1 and not cleared and target == SHADE) or (room == 2 and target == PORTAL):
		return
	player = target
	note = ""
	queue_redraw()

func near(cell: Vector2i) -> bool:
	var delta := player - cell
	return absi(delta.x) + absi(delta.y) == 1

func interact() -> void:
	if is_instance_valid(encounter):
		return
	if room == 1 and not cleared and near(SHADE):
		start_encounter()
	elif room == 2 and near(PORTAL):
		depth += 1
		room = 0
		player = Vector2i(2,4)
		cleared = false
		note = "抵达下一层。"
	elif room > 0 and near(LEFT_DOOR):
		room -= 1
		player = Vector2i(11,4)
		note = ""
	elif room < 2 and near(RIGHT_DOOR):
		if room == 1 and not cleared:
			note = "梦魇封住了东门。靠近庭院中央的梦魇，按 O 迎战。"
		else:
			room += 1
			player = Vector2i(1,4)
			note = ""
	else:
		note = "靠近门或印记后，按 O 交互。"
	queue_redraw()

func start_encounter() -> void:
	if is_instance_valid(encounter) or cleared:
		return
	encounter = BattleScene.instantiate()
	encounter.exploration_battle = true
	encounter.board_origin = ORIGIN
	encounter.cell_size = TILE
	encounter.model.floor_bounds = ROOM_FLOOR
	encounter.model.obstacles = WALLS[room].duplicate()
	encounter.model.player = player
	encounter.model.enemies[0].pos = SHADE
	encounter.model.enemies[1].pos = Vector2i(9,3)
	encounter.model.hp = health
	encounter.model.refresh_intents()
	encounter.exploration_won.connect(finish_encounter)
	encounter.retry_encounter.connect(retry)
	menu.hide()
	add_child(encounter)
	queue_redraw()

func detach_battle() -> void:
	remove_child(encounter)
	encounter.queue_free()
	encounter = null

func retry() -> void:
	detach_battle()
	start_encounter()

func finish_encounter(remaining_hp: int, final_cell: Vector2i) -> void:
	detach_battle()
	player = final_cell
	health = remaining_hp
	cleared = true
	note = "梦魇消散，东门已开启。WASD 继续探索。"
	menu.show()
	queue_redraw()

func prompt() -> String:
	if room == 1 and not cleared and near(SHADE):
		return "O   迎战梦魇"
	if room == 2 and near(PORTAL):
		return "O   进入下一层"
	if room > 0 and near(LEFT_DOOR):
		return "O   返回上一间"
	if room < 2 and near(RIGHT_DOOR):
		return "O   查看封印" if room == 1 and not cleared else "O   打开东门"
	return "W A S D   移动"

func text_at(pos: Vector2, value: String, px: int, color := Color("d9e8ec")) -> void:
	draw_string(get_theme_default_font(), pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)

func glyph(cell: Vector2i, value: String, color: Color) -> void:
	var p := ORIGIN + Vector2(cell)*TILE
	draw_rect(Rect2(p+Vector2(3,3),Vector2(45,45)),color.darkened(0.64))
	draw_rect(Rect2(p+Vector2(3,3),Vector2(45,45)),color,false,2)
	text_at(p+Vector2(14,34), value, 22, color)

func _draw() -> void:
	var fighting := is_instance_valid(encounter)
	draw_rect(Rect2(Vector2.ZERO, size), Color("0a1220"))
	var accent: Color = [Color("81d6cb"), Color("cf9ac5"), Color("b4a5eb")][room]
	text_at(Vector2(72,49),"清醒梦     /     指令战斗" if fighting else "清醒梦     /     梦境探索",20,Color("94aabe"))
	text_at(Vector2(72,111),ROOMS[room],38)
	text_at(Vector2(780,111),"第 %02d 层" % depth,28,accent)
	for y in range(9):
		for x in range(13):
			var cell := Vector2i(x,y)
			var edge := x == 0 or x == 12 or y == 0 or y == 8
			var tile_color := Color("243846") if (x+y)%2 == 0 else Color("21333e")
			if edge:
				tile_color = Color("172531")
			elif cell in WALLS[room]:
				tile_color = Color("506471")
			var p := ORIGIN+Vector2(cell)*TILE
			draw_rect(Rect2(p,Vector2.ONE*(TILE-2)),tile_color)
			if cell in WALLS[room]:
				draw_line(p+Vector2(5,8),p+Vector2(46,8),Color("8a9da2"),3)
	if room > 0:
		glyph(LEFT_DOOR,"门",accent)
	if room < 2:
		glyph(RIGHT_DOOR,"封" if room == 1 and not cleared else "门",accent)
	if fighting:
		return
	if room == 1 and not cleared:
		glyph(SHADE,"魇",Color("fa899b"))
	if room == 2:
		glyph(PORTAL,"星",Color("e0b6ff"))
	var pos := ORIGIN + (Vector2(player)+Vector2(0.5,0.5))*TILE
	draw_circle(pos,17,Color("81d6cb"))
	text_at(pos+Vector2(-10,7),"我",20,Color("142935"))
	text_at(Vector2(800,187),"楼层路径",20,Color("9bb0bf"))
	for i in range(3):
		var y := 246+i*63
		if i < 2:
			draw_line(Vector2(818,y),Vector2(818,y+63),Color("364958"),2)
		draw_circle(Vector2(818,y),10,accent if i == room else Color("445668"))
		text_at(Vector2(850,y+7),ROOMS[i],22,accent if i == room else Color("8fa3b4"))
	text_at(Vector2(800,460),"生命   %d / 30" % health,21)
	var goals := ["前往东门，进入庭院。","靠近梦魇，按 O 迎战。","靠近星门，按 O 下潜。"]
	text_at(Vector2(800,510),"东门已开，前往星门。" if room == 1 and cleared else goals[room],20)
	text_at(Vector2(800,588),prompt(),21,accent)
	text_at(Vector2(72,672),note if note != "" else "WASD 移动    ·    在门、梦魇或星门旁按 O 交互",18,Color("acbfcc"))
