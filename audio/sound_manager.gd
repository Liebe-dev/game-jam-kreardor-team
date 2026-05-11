extends Node
var sfx_select_pawn = preload("res://audio/select.wav")
var sfx_move_pawn = preload("res://audio/move.wav")
var sfx_attack = preload("res://audio/attack.wav")
var sfx_defend = preload("res://audio/defend.wav")
var sfx_end_turn = preload("res://audio/end_turn.wav")
var sfx_open_book = preload("res://audio/open_book.wav")
var sfx_open_scroll = preload("res://audio/open_scroll.wav")
var sfx_turnpage = preload("res://audio/turnpage.wav")
var sfx_buffspell = preload("res://audio/buffspell.wav")
var sfx_castingspell = preload("res://audio/castingspell.wav")
var sfx_earthwind = preload("res://audio/earth+wind.wav")
var sfx_fire = preload("res://audio/fire.wav")
var sfx_water = preload("res://audio/water.wav")
var sfx_wind = preload("res://audio/wind.wav")
var sfx_undo = preload("res://audio/undo.wav")
var bgm_wave1 = preload("res://audio/wave1.wav")
var bgm_wave2 = preload("res://audio/wave2.wav")
var bgm_wave3 = preload("res://audio/wave3.wav")
var bgm_wave4 = preload("res://audio/wave4.wav")
var bgm_wave5 = preload("res://audio/wave5.wav")
var sfx_mantra = preload("res://audio/mantra.wav")
var sfx_victory = preload("res://audio/victory.wav")
var sfx_defeat = preload("res://audio/lose.wav")
var bgm_player = AudioStreamPlayer.new()

func _ready():
	add_child(bgm_player)
	bgm_player.volume_db = -15.0
func play_sound(sound_stream: AudioStream):
	if sound_stream == null:
		return
	var player = AudioStreamPlayer.new()
	player.stream = sound_stream
	player.finished.connect(player.queue_free) 
	add_child(player)
	player.play()
func play_bgm(stream: AudioStream):
	if stream == null:
		return
	if bgm_player.stream == stream and bgm_player.playing:
		return 
	bgm_player.stream = stream
	bgm_player.play()
func stop_bgm():
	bgm_player.stop()
