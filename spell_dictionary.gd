extends Node

# Định nghĩa các Element để dễ gọi
enum Element { NONE, EARTH, FIRE, WIND, WATER }

# Bảng tra cứu Hợp Ấn (Combination Dictionary)
var spell_combinations = {
	# Cấu trúc: [Element1, Element2] : "Tên_File_Scene_Của_Phép"
	
	# --- ẤN GIA CƯỜNG ---
	[Element.EARTH, Element.EARTH]: "earth_enhanced",
	[Element.FIRE, Element.FIRE]: "fire_enhanced",
	[Element.WIND, Element.WIND]: "wind_enhanced",
	[Element.WATER, Element.WATER]: "water_enhanced",
	
	# --- HỢP ẤN (Luôn xếp theo ID từ nhỏ đến lớn để tránh lỗi Lửa+Đất khác Đất+Lửa) ---
	[Element.EARTH, Element.FIRE]: "magma_path", # Lửa + Đất
	[Element.FIRE, Element.WIND]: "fire_storm", # Lửa + Gió
	[Element.FIRE, Element.WATER]: "fog_screen", # Lửa + Nước
	[Element.WIND, Element.WATER]: "healing_rain", # Nước + Gió
	[Element.EARTH, Element.WATER]: "swamp_trap", # Nước + Đất
	[Element.EARTH, Element.WIND]: "earth_wall" # Gió + Đất
}

# Hàm để kiểm tra nét vẽ của người chơi tạo ra phép gì
func get_spell_scene_name(element_1: Element, element_2: Element = Element.NONE) -> String:
	# Nếu chỉ vẽ 1 ấn
	if element_2 == Element.NONE:
		match element_1:
			Element.EARTH: return "earth_basic"
			Element.FIRE: return "fire_basic"
			Element.WIND: return "wind_basic"
			Element.WATER: return "water_basic"
			_: return ""
			
	# Nếu vẽ 2 ấn (Sắp xếp lại ID để dò trong bảng Dictionary)
	var combo = [min(element_1, element_2), max(element_1, element_2)]
	
	if spell_combinations.has(combo):
		return spell_combinations[combo]
	
	return "fizzle" # Phép thất bại nếu chế ra cái không có trong danh sách
# res://scripts/spell_dictionary.gd
const SPELL_DATA = {
	Element.FIRE: {
		"name": "Lửa",
		"damage": 1, 
		"description": "Gây sát thương lên 1 ô"
	},
	Element.WATER: {
		"name": "Nước",
		"heal": 1,
		"ink_reward": 1,
		"description": "Hồi máu, nhận mực"
	},
	Element.EARTH: {
		"name": "Đất",
		"buff": "invulnerable_1_time",
		"paper_reward": 3,
		"description": "Miễn nhiễm 1 lần ST, nhận 3 giấy (nếu trúng địch thì địch được miễn ST từ đồng minh)"
	},
	Element.WIND: {
		"name": "Gió",
		"buff": "double_attack_next_turn",
		"special": "repeat_last_effect",
		"description": "Lặp lại hiệu ứng trước đó, tấn công 2 lần lượt sau"
	}
}
