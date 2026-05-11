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

var max_ink : float = 1000.0
var current_ink : float = 1000.0
var ink_cost_per_char : float = 5.0
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
		edit_node.set_meta("prev_len", 0)
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
	var text_lower = new_text.to_lower().strip_edges()
	
	if dict_elements.has(text_lower):
		elem_edits[index].text = "" 
		
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
		elem_edits[index].text = ""
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
		coord_edits[index].text = ""
func _on_dir_submitted(new_text: String, index: int):
	var text_lower = new_text.to_lower().strip_edges()
	if text_lower == "sagta":
		dir_edits[index].text = ""
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
func _on_end_turn_button_pressed():
	SoundManager.play_sound(SoundManager.sfx_castingspell)
	if cast_elements.is_empty(): 
		return 
	var final_coords_text = []
	if coord_edits[0].text != "" and coord_edits[1].text != "":
		final_coords_text.append(coord_edits[0].text.to_upper()) 
		final_coords_text.append(coord_edits[1].text)
		
	if coord_edits[2].text != "" and coord_edits[3].text != "":
		final_coords_text.append(coord_edits[2].text.to_upper())
		final_coords_text.append(coord_edits[3].text)
		
	Global.paper_count -= 1 
	update_ui() 
	print("Niệm: ", cast_elements, " | Tọa độ: ", final_coords_text, " | Hướng: ", cast_directions)
	Global.has_casted_spell = true
	spell_casted.emit(cast_elements, final_coords_text, cast_directions)
	
	get_tree().call_group("logic_board", "cast_complex_spell", cast_elements.duplicate(), final_coords_text.duplicate(), cast_directions.duplicate())
	clear_all_inputs()
	close_scroll()
	Global.tutorial_spell_cast.emit()
func update_ui():
	if paper_label: paper_label.text = "Giấy: " + str(Global.paper_count)
	if ink_bar: ink_bar.value = (current_ink / max_ink) * 100
func show_scroll():
	self.show()
	%UI_Container.size.x = max_scroll_width
func close_scroll():
	self.hide()
	scroll_closed.emit()
func _on_any_text_changed(new_text: String, edit_node: LineEdit):
	var current_len = new_text.length()
	var prev_len = edit_node.get_meta("prev_len")
	if current_len > prev_len:
		var chars_added = current_len - prev_len
		var ink_cost = (max_ink * 0.02) * chars_added 
		if current_ink >= ink_cost:
			current_ink -= ink_cost
		else:
			current_ink = 0
			edit_node.text = new_text.substr(0, prev_len) 
			edit_node.caret_column = prev_len 
			current_len = prev_len 
		update_ui()
	edit_node.set_meta("prev_len", current_len)

func clear_all_inputs():
	cast_elements.clear()
	cast_directions.clear()
	cast_elements_str.clear()
	
	var all_edits = elem_edits + coord_edits + dir_edits
	var all_icons = elem_icons + coord_icons + dir_icons
	
	for i in range(all_edits.size()):
		all_edits[i].text = ""
		all_edits[i].set_meta("prev_len", 0)
		all_edits[i].show()
		all_icons[i].hide()
	for i in range(all_edits.size()):
		all_edits[i].text = ""
		all_edits[i].set_meta("prev_len", 0) 
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
	current_ink = max_ink 
	update_ui()
func _on_close_area_button_pressed():
	SoundManager.play_sound(SoundManager.sfx_open_scroll)
	self.hide()
	scroll_closed.emit()
