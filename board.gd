extends Node2D
@onready var magic_system = %MagicDrawingSystem
@onready var closed_scroll_btn = %ClosedScrollButton
func _ready():
	var logic = $logicgame
	magic_system.spell_resolver = logic.spell_resolver
	magic_system.cast_requested.connect(logic.request_cast)
	logic.spell_resolved.connect(magic_system.apply_cast_result)
	$UI_Layer.spell_catalog = logic.spell_resolver.catalog
	magic_system.scroll_closed.connect(_on_magic_scroll_closed)
func _on_magic_scroll_closed():
	if magic_system.can_prepare_spell():
		closed_scroll_btn.show()
func _on_closed_scroll_button_pressed():
	if not magic_system.can_prepare_spell():
		return
	SoundManager.play_sound(SoundManager.sfx_open_scroll)
	closed_scroll_btn.hide()
	magic_system.show_scroll()
	Global.tutorial_scroll_opened.emit()
