extends SceneTree
var failures := 0
func verify(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://scenes/battle/battle.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	verify(scene.intent_buttons.size() == 2, "Intent hit targets exist")
	scene.show_intent(0)
	verify("移动" in scene.intent_popup.dialog_text, "Movement detail")
	scene.intent_popup.hide()
	scene.model.enemies[0].intent = "attack"
	scene.refresh()
	scene.show_intent(0)
	verify("第3列、第5行" in scene.intent_popup.dialog_text, "Locked target detail")
	scene.intent_popup.hide()
	scene.choose("dash")
	scene.route = [Vector2i(2,3)]
	scene.finish_route()
	scene.choose("slash")
	scene.model.set_target(1,Vector2i(3,3))
	scene.selected = -1
	scene.edit_target(0)
	verify(scene.model.queue[1].valid, "Viewing earlier card preserves later target")
	scene.route = [Vector2i(2,3)]
	scene.finish_route()
	verify(scene.model.queue[1].valid, "Accepting identical route preserves target")
	scene.edit_target(0)
	scene.route = [Vector2i(1,4)]
	scene.finish_route()
	verify(not scene.model.queue[1].valid, "Changed route invalidates later target")
	scene.clear_tray()
	scene.choose("rage",scene.model.hand[0])
	scene.edit_target(0)
	verify(scene.inspected == 0 and scene.selected == -1, "Area card inspection")
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	var before_count: int = scene.model.queue.size()
	scene.actions[2].gui_input.emit(right_click)
	verify("移动3" in scene.card_popup.dialog_text and scene.model.queue.size() == before_count, "Right clicking basic card shows details without playing")
	scene.card_popup.hide()
	var hand_count: int = scene.model.hand.size()
	scene.hand_row.get_child(0).gui_input.emit(right_click)
	verify("多造成一次伤害" in scene.card_popup.dialog_text and scene.model.hand.size() == hand_count, "Right clicking special card shows combo without consuming")
	scene.card_popup.hide()
	scene.tray.get_child(0).gui_input.emit(right_click)
	verify(scene.return_card_button.visible and scene.model.queue.size() == before_count, "Right clicking tray shows details without removing card")
	scene.card_popup.custom_action.emit("return_card")
	verify(scene.model.queue.is_empty() and scene.model.hand.size() == hand_count+1, "Detail action returns tray special card to hand")
	scene.choose("sleep")
	scene.run_plan()
	verify(scene.busy and scene.hand_row.get_child_count() == 8 and scene.hand_row.get_child(7).disabled, "Drawn cards appear before enemy playback while planning stays locked")
	while scene.busy:
		await process_frame
	print("BATTLE_UI: 12 checks, %d failures" % failures)
	quit(0 if failures == 0 else 1)
