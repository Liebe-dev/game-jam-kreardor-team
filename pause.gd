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
		if get_tree().paused == true:
			$zw.play()
func _on_resume_pressed() -> void:
	pause_and_unpause()
func _on_restart_pressed() -> void:
	pause_and_unpause() 
	Global.current_wave = 1 
	get_tree().reload_current_scene()
func _on_restart_2_pressed() -> void:
	pause_and_unpause()
	var logic = get_tree().get_first_node_in_group("logic_board")
	if logic != null:
		logic.restart_current_wave()
func _on_quit_pressed() -> void:
	get_tree().paused = false 
	$c.play()
	$fade_trans.show()
	$fade_trans/fade.play("fade_out")
	await $fade_trans/fade.animation_finished
	get_tree().change_scene_to_file("res://menu.tscn")
@onready var zw = $zw 
@onready var c=$c
@onready var mute_btn = $VBoxContain/mutez
func _on_mutez_toggled(toggled_on: bool) -> void:
	print("Đã click nút Mute! Trạng thái lún: ", toggled_on)
	if toggled_on == true:
		zw.volume_db = -80.0
		c.volume_db = -80.0
	else:
		zw.volume_db = 0.0
		c.volume_db = 0.0
func _on_pause_pressed() -> void:
	pause_and_unpause()


func _on_mute_bgm_check_box_toggled(toggled_on: bool):
	# Lấy ID của kênh âm thanh tổng (Nếu bạn tạo kênh riêng thì đổi "Master" thành tên kênh đó)
	var bus_idx = AudioServer.get_bus_index("Master")
	
	# Bật/tắt tiếng dựa vào trạng thái của dấu tick
	AudioServer.set_bus_mute(bus_idx, toggled_on)
	
	# Lưu vào Global để các chỗ khác biết là người chơi đang tắt nhạc
	if Global.get("is_bgm_muted") != null:
		Global.is_bgm_muted = toggled_on
