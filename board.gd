extends Node2D
@onready var magic_system = %MagicDrawingSystem 
@onready var closed_scroll_btn = %ClosedScrollButton
func _ready():
	magic_system.scroll_closed.connect(_on_magic_scroll_closed)
func _on_magic_scroll_closed():
	if not Global.has_casted_spell:
		closed_scroll_btn.show()
func _on_closed_scroll_button_pressed():
	SoundManager.play_sound(SoundManager.sfx_open_scroll)
	closed_scroll_btn.hide()
	magic_system.show_scroll()
	Global.tutorial_scroll_opened.emit()
