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
	# 1. Kết nối toàn bộ tín hiệu
	Global.tutorial_pawn_moved.connect(resume_after_move)
	Global.tutorial_attack_performed.connect(resume_after_attack)
	Global.tutorial_scroll_opened.connect(resume_after_scroll)
	Global.tutorial_rune_ignis_drawn.connect(resume_after_ignis)
	Global.tutorial_rune_B_drawn.connect(resume_after_B)
	Global.tutorial_rune_2_drawn.connect(resume_after_2)
	
	# Load 20 ảnh
	for i in range(1, 23):
		if i == 11:
			tutorial_images.append(null)
		else:
			tutorial_images.append(load("res://tutorial/tutorial" + str(i) + ".png"))
	
	self.hide()
	await get_tree().create_timer(3.0).timeout
	
	show_tutorial(0) # Hiện ảnh 1
	lock_input_temp(2.0)

func _input(event):
	if input_locked or waiting_for_action:
		return

	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event.is_action_pressed("ui_accept")):
		handle_next_logic()

func handle_next_logic():
	current_index += 1
	
	# ĐIỂM NGẮT 1: Hết ảnh 4 -> Đi lính
	if current_index == 4:
		pause_for_interaction("Đợi di chuyển lính...")
		return
	
	# ĐIỂM NGẮT 2: Hết ảnh 6 -> Nhấn Attack
	if current_index == 6:
		pause_for_interaction("Đợi nhấn nút Attack...")
		return

	# ĐIỂM NGẮT 3: Hết ảnh 8 (Index 7 nhảy lên 8) -> Mở cuộn giấy
	if current_index == 8:
		pause_for_interaction("Đợi người chơi mở cuộn giấy...")
		return

	# ĐIỂM NGẮT 4: Hết ảnh 10 (Index 9 nhảy lên 10) -> Nhập "ignis"
	if current_index == 10:
		pause_for_interaction("Đợi người chơi nhập 'ignis'...")
		return

	# ĐIỂM NGẮT 5: Hết ảnh 12 (Index 11 nhảy lên 12) -> Nhập "B"
	if current_index == 12:
		pause_for_interaction("Đợi người chơi nhập 'B'...")
		return

	# ĐIỂM NGẮT 6: Hết ảnh 13 (Index 12 nhảy lên 13) -> Nhập "2"
	if current_index == 13:
		pause_for_interaction("Đợi người chơi nhập '2'...")
		return
	# ĐIỂM NGẮT 7: Hết ảnh 15 (Index nhảy lên 15) -> Nhập "2" bên phải
	if current_index == 15:
		pause_for_interaction("Đợi người chơi nhập '2' bên phải...")
		return

	# ĐIỂM NGẮT 8: Hết ảnh 16 (Index nhảy lên 16) -> Nhập "D" bên dưới
	if current_index == 16:
		pause_for_interaction("Đợi người chơi nhập 'D' bên dưới...")
		return
	# ĐIỂM NGẮT 9: Hết ảnh 19 (Index 18 nhảy lên 19) -> Nhấn sử dụng phép
	if current_index == 19:
		pause_for_interaction("Đợi người chơi nhấn nút sử dụng phép...")
		return

	# ĐIỂM NGẮT 10: Hết ảnh 21 (Index 20 nhảy lên 21) -> Nhấn End Turn
	if current_index == 21:
		pause_for_interaction("Đợi người chơi nhấn End Turn...")
		return
	# --- HIỂN THỊ CÁC ẢNH BÌNH THƯỜNG ---
	if current_index < tutorial_images.size():
		show_tutorial(current_index)
		
		# Khóa 2s cho ảnh 5 và 6
		if current_index == 4 or current_index == 5:
			lock_input_temp(2.0)
	else:
		finish_tutorial()

# --- CÁC HÀM TIỆN ÍCH ---
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

# ========================================================
# --- CÁC HÀM "RESUME" SAU KHI PLAYER HOÀN THÀNH NHIỆM VỤ ---
# ========================================================

func resume_after_move():
	if waiting_for_action and current_index == 4:
		waiting_for_action = false
		show_tutorial(4) # Hiện Ảnh 5
		lock_input_temp(2.0) 

func resume_after_attack():
	if waiting_for_action and current_index == 6:
		waiting_for_action = false
		show_tutorial(6) # Hiện Ảnh 7

func resume_after_scroll():
	if waiting_for_action and current_index == 8:
		waiting_for_action = false
		show_tutorial(8) # Hiện Ảnh 9

func resume_after_ignis():
	if waiting_for_action and current_index == 10:
		waiting_for_action = false
		current_index = 11 # Ép nhảy index qua Ảnh 11, tiến thẳng tới Ảnh 12
		show_tutorial(11) # Hiện Ảnh 12

func resume_after_B():
	if waiting_for_action and current_index == 12:
		waiting_for_action = false
		show_tutorial(12) # Hiện Ảnh 13

func resume_after_2():
	if waiting_for_action and current_index == 13:
		waiting_for_action = false
		show_tutorial(13) # Hiện Ảnh 14 (hoặc bất cứ logic nào bạn muốn tiếp theo)

func finish_tutorial():
	Global.is_tutorial_done = true
	queue_free()
func resume_after_2_right():
	# Đang đợi sau ảnh 15
	if waiting_for_action and current_index == 15:
		waiting_for_action = false
		show_tutorial(15) # Hiện Ảnh 16

func resume_after_D():
	# Đang đợi sau ảnh 16
	if waiting_for_action and current_index == 16:
		waiting_for_action = false
		show_tutorial(16) 
func resume_after_spell():
	# Đang đợi sau ảnh 19
	if waiting_for_action and current_index == 19:
		waiting_for_action = false
		print("Đã dùng phép! Chờ 2 giây để xem hiệu ứng...")
		
		# Đợi 2 giây như bạn yêu cầu để người chơi kịp nhìn hiệu ứng phép trên bàn cờ
		await get_tree().create_timer(2.0).timeout
		
		show_tutorial(19) # Hiện Ảnh 20
		# Sau đó player click xem tiếp ảnh 21 bình thường

func resume_after_end_turn():
	# Đang đợi sau ảnh 21
	if waiting_for_action and current_index == 21:
		waiting_for_action = false
		show_tutorial(21) # Hiện Ảnh 22 (Ảnh cuối cùng)


func _on_skip_button_pressed() -> void:
	finish_tutorial()
