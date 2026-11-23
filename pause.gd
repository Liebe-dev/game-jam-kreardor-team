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
func _on_resume_pressed() -> void:
	SoundManager.play_sound(SoundManager.sfx_attack, -5)
	pause_and_unpause()
func _on_restart_pressed() -> void:
	var logic = get_tree().get_first_node_in_group("logic_board")
	if logic != null and logic.is_resolving_turn:
		return
	SoundManager.play_sound(SoundManager.sfx_attack, -5)
	pause_and_unpause() 
	Global.reset_run()
	get_tree().reload_current_scene()
func _on_restart_2_pressed() -> void:
	SoundManager.play_sound(SoundManager.sfx_attack, -5)
	var logic = get_tree().get_first_node_in_group("logic_board")
	if logic != null and logic.is_resolving_turn:
		return
	pause_and_unpause()
	if logic != null:
		logic.restart_current_wave()
func _on_quit_pressed() -> void:
	SoundManager.play_sound(SoundManager.sfx_attack, -5)
	get_tree().paused = false 
	$fade_trans.show()
	$fade_trans/fade.play("fade_out")
	await $fade_trans/fade.animation_finished
	get_tree().change_scene_to_file("res://menu.tscn")
func _on_pause_pressed() -> void:
	SoundManager.play_sound(SoundManager.sfx_attack, -5)
	pause_and_unpause()
func _on_mute_bgm_check_box_toggled(toggled_on: bool):
	var bus_idx = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus_idx, toggled_on)
	if Global.get("is_bgm_muted") != null:
		Global.is_bgm_muted = toggled_on
	SoundManager.play_sound(SoundManager.sfx_attack, -5)
