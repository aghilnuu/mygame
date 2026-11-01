extends SceneTree

var failures := 0

func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		push_error(what)

func _initialize() -> void:
	call_deferred("run")

func key(world: Control, code: int, count: int = 1) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	for i in range(count):
		world._unhandled_key_input(event)

func run() -> void:
	Engine.time_scale = 20
	change_scene_to_file("res://scenes/ui/title_screen.tscn")
	await scene_changed
	current_scene.find_child("EnterDream",true,false).pressed.emit()
	await scene_changed
	var world = current_scene
	check(world.room == 0 and world.depth == 1, "Title opens first room")
	key(world,KEY_W,6)
	check(world.player.y == 1, "Wall stops movement")
	key(world,KEY_S,3)
	key(world,KEY_D,9)
	key(world,KEY_O)
	check(world.room == 1 and world.player.x == 1, "East door")
	key(world,KEY_O)
	check(world.room == 0 and world.player.x == 11, "Return door")
	key(world,KEY_O)
	key(world,KEY_W)
	key(world,KEY_D,10)
	key(world,KEY_S)
	key(world,KEY_O)
	check(world.room == 1 and not world.cleared, "Exit sealed before encounter")
	key(world,KEY_A,4)
	key(world,KEY_O)
	var battle = world.encounter
	check(is_instance_valid(battle), "Encounter opens")
	if not is_instance_valid(battle):
		quit(1)
		return
	battle.model.hp = 0
	battle.model.check_result()
	if battle.model.result != "梦境破碎":
		quit(1)
		return
	battle.restart()
	battle = world.encounter
	check(battle.model.hp == world.health and not world.cleared, "Retry restores encounter entry")
	for turn in range(25):
		if battle.model.result != "":
			break
		var next_card := "sleep"
		var target := Vector2i.ZERO
		for enemy in battle.model.enemies:
			if enemy.hp <= 0:
				continue
			var delta: Vector2i = (enemy.pos-battle.model.player).abs()
			if maxi(delta.x,delta.y) == 1:
				target = enemy.pos
				next_card = "slash"
				if delta.x+delta.y == 1 and not battle.model.hand.is_empty():
					next_card = "rage"
				break
		if next_card == "rage":
			battle.choose("rage",battle.model.hand[0])
			if not battle.model.hand.is_empty():
				battle.choose("rage",battle.model.hand[0])
		else:
			battle.choose(next_card)
			if next_card == "slash":
				var click := InputEventMouseButton.new()
				click.button_index = MOUSE_BUTTON_LEFT
				click.pressed = true
				click.position = battle.center(target)
				battle._gui_input(click)
		await battle.run_plan()
	check(battle.model.result == "战斗胜利", "Win actual encounter with cards")
	if battle.model.result != "战斗胜利":
		quit(1)
		return
	var hp: int = battle.model.hp
	battle.confirm.pressed.emit()
	check(world.cleared and world.encounter == null and world.health == hp and world.player == Vector2i(7,4), "Victory restores room and health")
	key(world,KEY_O)
	check(world.encounter == null, "Cleared encounter cannot respawn")
	key(world,KEY_D,4)
	key(world,KEY_O)
	check(world.room == 2, "Exit unlocked")
	key(world,KEY_D,6)
	key(world,KEY_O)
	check(world.depth == 2 and world.room == 0 and not world.cleared and world.health == hp, "Portal reaches next floor")
	print("EXPLORATION_ROUTE failures=",failures)
	quit(1 if failures else 0)
