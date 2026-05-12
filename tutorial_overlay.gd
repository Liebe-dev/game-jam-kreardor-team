extends CanvasLayer

@onready var tutorial_rect = $TutorialRect
var tutorial_images = []
var current_index = 0
var input_locked = true 
var waiting_for_action = false 
func _ready():
	Global.tutorial_spell_cast.connect(resume_after_spell)
	Global.tutorial_end_turn_pressed.connect(resume_after_end_turn)
	Global.tutorial_rune_2_right_drawn.connect(resume_after_2_right)
	Global.tutorial_rune_D_drawn.connect(resume_after_D)
	if Global.is_tutorial_done:
		queue_free()
		return
	Global.tutorial_pawn_moved.connect(resume_after_move)
	Global.tutorial_attack_performed.connect(resume_after_attack)
	Global.tutorial_scroll_opened.connect(resume_after_scroll)
	Global.tutorial_rune_ignis_drawn.connect(resume_after_ignis)
	Global.tutorial_rune_B_drawn.connect(resume_after_B)
	Global.tutorial_rune_2_drawn.connect(resume_after_2)
	for i in range(1, 23):
		if i == 11:
			tutorial_images.append(null)
		else:
			tutorial_images.append(load("res://tutorial/tutorial" + str(i) + ".png"))
	self.hide()
	await get_tree().create_timer(1.3).timeout
	show_tutorial(0)
	lock_input_temp(2.0)
func _input(event):
	if input_locked or waiting_for_action:
		return
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event.is_action_pressed("ui_accept")):
		handle_next_logic()
func handle_next_logic():
	current_index += 1
	if current_index == 4:
		pause_for_interaction("Đợi di chuyển lính...")
		return
	if current_index == 6:
		pause_for_interaction("Đợi nhấn nút Attack...")
		return
	if current_index == 8:
		pause_for_interaction("Đợi người chơi mở cuộn giấy...")
		return
	if current_index == 10:
		pause_for_interaction("Đợi người chơi nhập 'ignis'...")
		return
	if current_index == 12:
		pause_for_interaction("Đợi người chơi nhập 'B'...")
		return
	if current_index == 13:
		pause_for_interaction("Đợi người chơi nhập '2'...")
		return
	if current_index == 15:
		pause_for_interaction("Đợi người chơi nhập '2' bên phải...")
		return
	if current_index == 16:
		pause_for_interaction("Đợi người chơi nhập 'D' bên dưới...")
		return
	if current_index == 19:
		pause_for_interaction("Đợi người chơi nhấn nút sử dụng phép...")
		return
	if current_index == 21:
		pause_for_interaction("Đợi người chơi nhấn End Turn...")
		return
	if current_index < tutorial_images.size():
		show_tutorial(current_index)
		if current_index == 4 or current_index == 5:
			lock_input_temp(2.0)
	else:
		finish_tutorial()
func show_tutorial(index):
	tutorial_rect.texture = tutorial_images[index]
	self.show()
func lock_input_temp(duration):
	input_locked = true
	await get_tree().create_timer(duration).timeout
	input_locked = false
func pause_for_interaction(msg):
	self.hide()
	waiting_for_action = true
	print(msg)
func resume_after_move():
	if waiting_for_action and current_index == 4:
		waiting_for_action = false
		show_tutorial(4)
		lock_input_temp(2.0) 
func resume_after_attack():
	if waiting_for_action and current_index == 6:
		waiting_for_action = false
		show_tutorial(6)
func resume_after_scroll():
	if waiting_for_action and current_index == 8:
		waiting_for_action = false
		show_tutorial(8)
func resume_after_ignis():
	if waiting_for_action and current_index == 10:
		waiting_for_action = false
		current_index = 11
		show_tutorial(11)
func resume_after_B():
	if waiting_for_action and current_index == 12:
		waiting_for_action = false
		show_tutorial(12)
func resume_after_2():
	if waiting_for_action and current_index == 13:
		waiting_for_action = false
		show_tutorial(13)
func finish_tutorial():
	Global.is_tutorial_done = true
	queue_free()
func resume_after_2_right():
	if waiting_for_action and current_index == 15:
		waiting_for_action = false
		show_tutorial(15)
func resume_after_D():
	if waiting_for_action and current_index == 16:
		waiting_for_action = false
		show_tutorial(16) 
func resume_after_spell():
	if waiting_for_action and current_index == 19:
		waiting_for_action = false
		await get_tree().create_timer(2.0).timeout
		show_tutorial(19)
func resume_after_end_turn():
	if waiting_for_action and current_index == 21:
		waiting_for_action = false
		show_tutorial(21)
func _on_skip_button_pressed() -> void:
	finish_tutorial()
