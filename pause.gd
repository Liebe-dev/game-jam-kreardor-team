extends Control

var pause_toggle = false


func _ready() -> void:
	visible = false 


func pause_and_unpause():
	get_tree().paused = !get_tree().paused
	visible = get_tree().paused

	if get_tree().paused:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		move_to_front()
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _input(event):
	if event.is_action_pressed("ui_cancel"):
		pause_and_unpause()
		
		# Kiểm tra xem game có đang bị pause không (Menu đang hiện)
		if get_tree().paused == true:
			$zw.play()
func _on_resume_pressed() -> void:
	pause_and_unpause()


func _on_restart_pressed() -> void:
	pause_and_unpause() 
	Global.current_wave = 1 
	get_tree().reload_current_scene()

func _on_restart_2_pressed() -> void:
	pause_and_unpause() # Đóng menu Pause lại
	
	# Đi tìm "bộ não" logicgame đang ẩn nấp trên bàn cờ
	var logic = get_tree().get_first_node_in_group("logic_board")
	
	# Nếu tìm thấy, ra lệnh cho nó chạy hàm phục hồi lính
	if logic != null:
		logic.restart_current_wave()
func _on_quit_pressed() -> void:
	# ---> THÊM DÒNG NÀY ĐỂ XẢ ĐÔNG THỜI GIAN <---
	get_tree().paused = false 
	
	$c.play()
	$fade_trans.show()
	$fade_trans/fade.play("fade_out")
	await $fade_trans/fade.animation_finished
	get_tree().change_scene_to_file("res://menu.tscn")
@onready var zw = $zw 
@onready var c=$c

# Giả sử nút của bạn tên là mute_btn
@onready var mute_btn = $VBoxContain/mutez 

func _on_mutezwc_toggled(toggled_on: bool) -> void:
	# Dòng print này để test xem nút có thực sự nhận click không
	print("Đã click nút Mute! Trạng thái lún: ", toggled_on)
	
	if toggled_on == true:
		# Nút ĐANG TÍCH -> Kéo âm lượng xuống -80 dB (Câm điếc hoàn toàn)
		zw.volume_db = -80.0
		c.volume_db = -80.0
	else:
		# Nút BỎ TÍCH -> Trả âm lượng về 0 dB (Mức bình thường)
		zw.volume_db = 0.0
		c.volume_db = 0.0
