extends Control
## Stage 1 startup scene. Combat and exploration are introduced in later stages.

var _time: float = 0.0


func _ready() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC"])
	var ui_theme := Theme.new()
	ui_theme.default_font = font
	ui_theme.default_font_size = 20
	theme = ui_theme

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 80)
	margin.add_theme_constant_override("margin_right", 80)
	margin.add_theme_constant_override("margin_top", 56)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	_add_label(column, "L U C I D   D R E A M", 16, Color("8fadc9"))
	var upper_space := Control.new()
	upper_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(upper_space)
	_add_label(column, "清醒梦", 72, Color("e7f2ff"))
	_add_label(column, "闭上双眼，走进另一种可能。", 20, Color("91a8c2"))
	var gap := Control.new()
	gap.custom_minimum_size.y = 32
	column.add_child(gap)

	var enter := Button.new()
	enter.text = "进入梦境"
	enter.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/battle/battle.tscn"))
	_style_button(enter)
	column.add_child(enter)
	var quit := Button.new()
	quit.name = "QuitButton"
	quit.text = "退出"
	_style_button(quit)
	quit.pressed.connect(_on_quit_pressed)
	column.add_child(quit)
	quit.grab_focus()

	var lower_space := Control.new()
	lower_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(lower_space)
	_add_label(column, "只有抵达梦的尽头，才能再次醒来。", 15, Color("617b99"))
	resized.connect(queue_redraw)
	print("LUCID_DREAM_STARTUP_OK")


func _add_label(parent: Node, content: String, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = content
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)


func _style_button(button: Button) -> void:
	button.custom_minimum_size = Vector2(310, 54)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("17263d") if state == "hover" else Color("0d1729")
		box.border_color = Color("72c6d5") if state == "focus" else Color("283c56")
		box.set_border_width_all(1)
		box.content_margin_left = 22
		box.content_margin_right = 22
		button.add_theme_stylebox_override(state, box)
	button.add_theme_color_override("font_color", Color("d0e0f3"))
	button.add_theme_color_override("font_disabled_color", Color("637c99"))


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	# Draw at a virtual canvas size so the composition scales with the window.
	draw_set_transform(Vector2.ZERO, 0.0, size / Vector2(1280, 720))
	draw_rect(Rect2(0, 0, 1280, 720), Color("090f20"))
	for index in range(55):
		var point := Vector2(32 + (index * 179) % 1216, 36 + (index * 83) % 530)
		var glow := 0.3 + 0.2 * sin(_time * 0.5 + index)
		draw_rect(Rect2(point, Vector2(2, 2)), Color(0.53, 0.75, 0.87, glow))
	for row in range(12):
		var y := 500.0 + row * row * 1.5
		draw_line(Vector2(600, y), Vector2(1280, y), Color(0.15, 0.26, 0.39, 0.35))
	for index in range(10):
		var x := 560.0 + index * 115
		draw_line(Vector2(945, 420), Vector2(x, 720), Color(0.15, 0.26, 0.39, 0.25))
	# A stepped portal assembled from solid blocks; no external image assets.
	draw_rect(Rect2(842, 194, 192, 330), Color("10263b"))
	draw_rect(Rect2(858, 210, 160, 310), Color("173b50"))
	draw_rect(Rect2(874, 226, 128, 294), Color("296477"))
	draw_rect(Rect2(890, 242, 96, 278), Color("091525"))
	draw_rect(Rect2(874, 514, 128, 6), Color("7fcbd1"))
	for step in range(5):
		draw_rect(Rect2(850 - step * 18, 526 + step * 12, 176 + step * 36, 8), Color("1a3449"))
	draw_rect(Rect2(934, 462, 12, 19), Color("c5e4e7"))
	draw_rect(Rect2(930, 481, 20, 27), Color("597e9c"))
	draw_rect(Rect2(931, 508, 6, 12), Color("30435e"))
	draw_rect(Rect2(943, 508, 6, 12), Color("30435e"))


func _on_quit_pressed() -> void:
	get_tree().quit()
