extends CanvasLayer

signal scroll_closed
signal spell_casted(elements, coordinates, directions_list)

@onready var ink_bar = %InkBar
@onready var paper_label = %PaperLabel
@onready var spell_scroll = %SpellScroll
@onready var elem_edits = [%ElemEdit1, %ElemEdit2]
@onready var elem_icons = [%ElemIcon1, %ElemIcon2]
@onready var coord_edits = [%CoordTop, %CoordLeft, %CoordBottom, %CoordRight]
@onready var coord_icons = [%IconTop, %IconLeft, %IconBot, %IconRight]
@onready var dir_edits = [%Dir1, %Dir2, %Dir3, %Dir4, %Dir5, %Dir6, %Dir7, %Dir8]
@onready var dir_icons = [%IconDir1, %IconDir2, %IconDir3, %IconDir4, %IconDir5, %IconDir6, %IconDir7, %IconDir8]

@export_group("Hình ảnh Ấn Chú")
@export var icon_fire: Texture2D
@export var icon_water: Texture2D
@export var icon_earth: Texture2D
@export var icon_wind: Texture2D
@export var icon_success_text: Texture2D 
@export var icon_direction: Texture2D
@export var icon_fire_fire: Texture2D
@export var icon_water_water: Texture2D
@export var icon_earth_earth: Texture2D
@export var icon_wind_wind: Texture2D
@export var icon_fire_water: Texture2D
@export var icon_fire_earth: Texture2D
@export var icon_fire_wind: Texture2D
@export var icon_water_earth: Texture2D
@export var icon_water_wind: Texture2D
@export var icon_earth_wind: Texture2D

var max_ink: float:
	get:
		return Global.max_ink
var current_ink: float:
	get:
		return Global.current_ink
	set(value):
		Global.add_ink(value - Global.current_ink)
const INK_COST_PER_CHAR: float = 20.0
var max_scroll_width: float = 0.0
var cast_elements = []
var cast_directions = []
var cast_elements_str = []
var dict_elements = {
	"ignis": "fire", "fire": "fire",
	"aqua": "water", "water": "water",
	"terra": "earth", "earth": "earth",
	"ventus": "wind", "wind": "wind"
}
var index_to_direction = {
	0: Vector2(0, -1),
	1: Vector2(1, -1),
	2: Vector2(1, 0),
	3: Vector2(1, 1),
	4: Vector2(0, 1),
	5: Vector2(-1, 1),
	6: Vector2(-1, 0),
	7: Vector2(-1, -1) 
}
func _ready(): 
	Global.magic_system = self
	max_scroll_width = %UI_Container.size.x
	clear_all_inputs() 
	update_ui()
	var all_edits = elem_edits + coord_edits + dir_edits
	for edit_node in all_edits:
		edit_node.set_meta("prev_text", "")
		edit_node.text_changed.connect(_on_any_text_changed.bind(edit_node))
		
	for i in range(elem_edits.size()):
		elem_edits[i].text_submitted.connect(_on_element_submitted.bind(i))
		elem_edits[i].focus_exited.connect(func(): if elem_edits[i].text != "": _on_element_submitted(elem_edits[i].text, i))
		
	for i in range(coord_edits.size()):
		coord_edits[i].text_submitted.connect(_on_coord_submitted.bind(i))
		coord_edits[i].focus_exited.connect(func(): if coord_edits[i].text != "": _on_coord_submitted(coord_edits[i].text, i))
		
	for i in range(dir_edits.size()):
		dir_edits[i].text_submitted.connect(_on_dir_submitted.bind(i))
		dir_edits[i].focus_exited.connect(func(): if dir_edits[i].text != "": _on_dir_submitted(dir_edits[i].text, i))
func _on_element_submitted(new_text: String, index: int):
	if not can_prepare_spell() or not elem_edits[index].visible:
		return
	var text_lower = new_text.to_lower().strip_edges()
	
	if dict_elements.has(text_lower):
		_clear_edit(elem_edits[index])
		
		var elem_str = dict_elements[text_lower]
		
		match elem_str:
			"fire": cast_elements.append(SpellDictionary.Element.FIRE)
			"water": cast_elements.append(SpellDictionary.Element.WATER)
			"earth": cast_elements.append(SpellDictionary.Element.EARTH)
			"wind": cast_elements.append(SpellDictionary.Element.WIND)
			
		cast_elements_str.append(elem_str)
		
		elem_edits[index].hide()
		
		if cast_elements_str.size() == 1:
			elem_icons[0].texture = get_single_icon(elem_str)
			elem_icons[0].show()
			Global.tutorial_rune_ignis_drawn.emit()
		elif cast_elements_str.size() == 2:
			elem_icons[0].texture = get_combined_icon(cast_elements_str[0], cast_elements_str[1])
			elem_icons[1].hide()
			
	else:
		_clear_edit(elem_edits[index])
	SoundManager.play_sound(SoundManager.sfx_mantra)
func _on_coord_submitted(new_text: String, index: int):
	var text_upper = new_text.to_upper().strip_edges()
	var is_valid = false
	
	if (index == 0 or index == 2) and text_upper.length() == 1 and "ABCDEFGH".contains(text_upper):
		is_valid = true
	elif (index == 1 or index == 3) and text_upper.length() == 1 and "12345678".contains(text_upper):
		is_valid = true
		
	if is_valid:
		coord_edits[index].text = text_upper
		coord_edits[index].set_meta("prev_text", text_upper)
		coord_edits[index].release_focus()
		if text_upper == "B" and index == 0: 
			Global.tutorial_rune_B_drawn.emit()
			
		elif text_upper == "2" and index == 1: 
			Global.tutorial_rune_2_drawn.emit()
			
		elif text_upper == "2" and index == 3: 
			Global.tutorial_rune_2_right_drawn.emit()
			
		elif text_upper == "D" and index == 2:
			Global.tutorial_rune_D_drawn.emit() 
	else:
		_clear_edit(coord_edits[index])
func _on_dir_submitted(new_text: String, index: int):
	if not can_prepare_spell() or not dir_edits[index].visible:
		return
	var text_lower = new_text.to_lower().strip_edges()
	if text_lower == "sagta":
		_clear_edit(dir_edits[index])
		var final_dir = index_to_direction[index]
		cast_directions.append(final_dir)
		var custom_size = Vector2(70, 70) 
		dir_icons[index].size = custom_size
		var center_of_edit = dir_edits[index].global_position + (dir_edits[index].size / 2.0)
		dir_icons[index].global_position = center_of_edit - (custom_size / 2.0)
		dir_icons[index].pivot_offset = custom_size / 2.0
		dir_icons[index].texture = icon_direction
		dir_icons[index].rotation_degrees = index * 45.0
		dir_edits[index].hide()
		dir_icons[index].show()
	SoundManager.play_sound(SoundManager.sfx_mantra)
func _on_end_turn_button_pressed() -> void:
	if not can_prepare_spell() or Global.paper_count < 1 or cast_elements.is_empty():
		return
	var final_coords_text: Array = []
	for pair in [[0, 1], [2, 3]]:
		var column: String = coord_edits[pair[0]].text.strip_edges().to_upper()
		var row: String = coord_edits[pair[1]].text.strip_edges()
		if column.is_empty() and row.is_empty():
			continue
		if column.length() != 1 or not "ABCDEFGH".contains(column):
			return
		if row.length() != 1 or not "12345678".contains(row):
			return
		final_coords_text.append_array([column, row])
	if final_coords_text.is_empty():
		return
	SoundManager.play_sound(SoundManager.sfx_castingspell)
	Global.add_paper(-1)
	Global.has_casted_spell = true
	spell_casted.emit(cast_elements.duplicate(), final_coords_text.duplicate(), cast_directions.duplicate())
	get_tree().call_group("logic_board", "cast_complex_spell", cast_elements.duplicate(), final_coords_text.duplicate(), cast_directions.duplicate())
	clear_all_inputs()
	close_scroll()
	Global.tutorial_spell_cast.emit()

func can_prepare_spell() -> bool:
	if Global.has_casted_spell:
		return false
	var logic = get_tree().get_first_node_in_group("logic_board")
	return logic == null or (not logic.is_resolving_turn and not logic.game_finished)
func update_ui():
	if paper_label: paper_label.text = "Giấy: " + str(Global.paper_count)
	if ink_bar: ink_bar.value = (current_ink / max_ink) * 100
func show_scroll() -> void:
	if not can_prepare_spell():
		return
	self.show()
	%UI_Container.size.x = max_scroll_width
func close_scroll():
	self.hide()
	scroll_closed.emit()
func _on_any_text_changed(new_text: String, edit_node: LineEdit) -> void:
	var previous: String = edit_node.get_meta("prev_text", "")
	if not can_prepare_spell():
		edit_node.text = previous
		return
	# Count inserted/replaced characters, including paste and equal-length edits.
	var prefix: int = 0
	while prefix < mini(previous.length(), new_text.length()) and previous[prefix] == new_text[prefix]:
		prefix += 1
	var suffix: int = 0
	while suffix < mini(previous.length(), new_text.length()) - prefix and previous[previous.length() - 1 - suffix] == new_text[new_text.length() - 1 - suffix]:
		suffix += 1
	var cost: float = (new_text.length() - prefix - suffix) * INK_COST_PER_CHAR
	if cost > current_ink:
		edit_node.text = previous
		edit_node.caret_column = previous.length()
		return
	if cost > 0.0:
		Global.add_ink(-cost)
	edit_node.set_meta("prev_text", new_text)

func _clear_edit(edit_node: LineEdit) -> void:
	edit_node.text = ""
	edit_node.set_meta("prev_text", "")
func clear_all_inputs() -> void:
	cast_elements.clear()
	cast_directions.clear()
	cast_elements_str.clear()
	var all_edits = elem_edits + coord_edits + dir_edits
	var all_icons = elem_icons + coord_icons + dir_icons
	for i in range(all_edits.size()):
		_clear_edit(all_edits[i])
		all_edits[i].show()
		all_icons[i].hide()
func get_single_icon(elem_str: String) -> Texture2D:
	match elem_str:
		"fire": return icon_fire
		"water": return icon_water
		"earth": return icon_earth
		"wind": return icon_wind
	return null
func get_combined_icon(e1: String, e2: String) -> Texture2D:
	var combo = [e1, e2]
	combo.sort() 
	var combo_str = combo[0] + "_" + combo[1]
	match combo_str:
		"fire_fire": return icon_fire_fire
		"water_water": return icon_water_water
		"earth_earth": return icon_earth_earth
		"wind_wind": return icon_wind_wind
		"earth_fire": return icon_fire_earth 
		"fire_water": return icon_fire_water 
		"fire_wind": return icon_fire_wind   
		"earth_water": return icon_water_earth 
		"earth_wind": return icon_earth_wind 
		"water_wind": return icon_water_wind 
	return null
func _on_undo_button_pressed():
	SoundManager.play_sound(SoundManager.sfx_undo)
	clear_all_inputs()
	update_ui()
func _on_close_area_button_pressed():
	SoundManager.play_sound(SoundManager.sfx_open_scroll)
	self.hide()
	scroll_closed.emit()

func _exit_tree() -> void:
	if Global.magic_system == self:
		Global.magic_system = null
