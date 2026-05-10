extends CanvasLayer

@onready var tutorial_rect = $TutorialRect
var tutorial_images = []
var current_index = 0
var input_locked = true # Khóa mặc định

func _ready():
	# 1. Nạp 13 ảnh từ thư mục
	for i in range(1, 21):
		tutorial_images.append(load("res://tutorial/tutorial" + str(i) + ".png"))
	
	# 2. Ẩn toàn bộ UI lúc đầu
	tutorial_rect.hide()
	
	# 3. Đợi 3 giây ban đầu
	await get_tree().create_timer(3.0).timeout
	
	# 4. Hiện Tutorial 1
	tutorial_rect.texture = tutorial_images[0]
	tutorial_rect.show()
	
	# 5. Khóa tương tác trong 2 giây
	input_locked = true
	await get_tree().create_timer(2.0).timeout
	input_locked = false # Mở khóa sau 2s

func _input(event):
	# Chỉ nhận click chuột trái hoặc phím Enter khi đã mở khóa
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event.is_action_pressed("ui_accept")):
		# Chuyển sang ảnh tiếp theo
		current_index += 1
		
		if current_index < tutorial_images.size():
			tutorial_rect.texture = tutorial_images[current_index]
		else:
			finish_tutorial()

func finish_tutorial():
	# Kết thúc hướng dẫn
	queue_free()
