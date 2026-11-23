extends CanvasLayer

@onready var closed_book_btn: TextureButton = $ClosedBookButton
@onready var opened_book_panel: Control = $OpenedBookPanel
@onready var close_btn: Button = $OpenedBookPanel/CloseButton
@onready var tab_basic: Button = $OpenedBookPanel/BookmarkTabs/TabBasic
@onready var tab_basis: Button = $OpenedBookPanel/BookmarkTabs/TabBasis
@onready var tab_enemy: Button = $OpenedBookPanel/BookmarkTabs/Tabenemy
@onready var tab_enhanced: Button = $OpenedBookPanel/BookmarkTabs/TabEnhanced
@onready var tab_combine: Button = $OpenedBookPanel/BookmarkTabs/TabCombine
@onready var illustration: TextureRect = $OpenedBookPanel/LeftPage/Illustration
@onready var title_label: Label = $OpenedBookPanel/LeftPage/TitleLabel
@onready var info_label: Label = $OpenedBookPanel/RightPage/InfoLabel
@onready var prev_btn: TextureButton = $OpenedBookPanel/PrevButton
@onready var next_btn: TextureButton = $OpenedBookPanel/NextButton
@onready var left_arrow: TextureRect = $OpenedBookPanel/LeftArrow
@onready var right_arrow: TextureRect = $OpenedBookPanel/RightArrow
var current_page: int = 0
var spell_catalog: SpellCatalog = preload("res://data/spells/catalog.tres")
var tutorial_pages: Array = [
	{
		"title": "Vòng tròn phép thuật",
		"info": "1. Lớp ấn: chứa chú ngữ của các loại ấn.
		2. Lớp tọa độ ngang: chứa các trục tọa độ ngang (1,2,..,8).
		3. Lớp tọa độ dọc: chứa các trục tọa độ dọc (A,B,...,H).
		4. Lớp hướng: chứa chú ngữ hướng.",
		"image": preload("res://spellbook/circle tuto.png")
	},
	{
		"title": "Sagta",
		"info": "Ấn hướng: Sau khi phép được phát động tại ô chỉ định, kèm theo một số hiệu ứng theo hướng chỉ định.",
		"image": preload("res://spell/arrow.png")
	},
	{"spell_id": &"fire"},
	{"spell_id": &"water"},
	{"spell_id": &"earth"},
	{"spell_id": &"wind"},
	{"spell_id": &"fire_fire"},
	{"spell_id": &"water_water"},
	{"spell_id": &"earth_earth"},
	{"spell_id": &"wind_wind"},
	{"spell_id": &"fire_earth"},
	{"spell_id": &"fire_water"},
	{"spell_id": &"fire_wind"},
	{"spell_id": &"water_earth"},
	{"spell_id": &"water_wind"},
	{"spell_id": &"wind_earth"},
	{
		"title": "Binh lính",
		"info": "Lớp kẻ địch cơ bản,có thể đi 8 ô xung quanh, gây sát thương thấp, chống chịu trung bình.",
		"image": preload("res://spellbook/pawn.png")
	},
	{
		"title": "Sát thủ",
		"info": "di chuyển và tấn công hình L, sau khi tấn công có thể lùi về sau 2 ô về hướng xa địch nhất, nếu bị khóa chân, lượt kế tiếp đẩy lùi kẻ địch và gây sát thương, thoát khỏi trạng thái trói chân.",
		"image": preload("res://spellbook/horse.png")
	},
	{
		"title": "Chú chồn xanh ?",
		"info": "Di chuyển 8 ô xung quanh, tấn công phạm vi chữ thập xung quanh bản thân. Đòn tấn công đẩy lùi kẻ địch phía trước và kẻ địch cạnh đó, nếu không thể bị đẩy lùi, gây thêm sát thương.
		Đòn tấn công phá hủy ô ngọn núi ngay lập tức. Sử dụng cơ chế đạn, bất động 1 lượt để tiến hành nạp đạn.",
		"image": preload("res://spellbook/rook.png")
	},
	{
		"title": "Lính đánh thuê",
		"info": "Di chuyển 8 ô xung quanh, tấn công theo chữ X, nếu bị khóa chân, lượt kế tiếp đẩy lùi kẻ địch và gây sát thương, thoát khỏi trạng thái trói chân.",
		"image": preload("res://spellbook/bishop.png")
	},
	{
		"title": "Nữ chiến binh",
		"info": "Di chuyển 8 ô xung quanh, có thể đánh xa trong phạm vi chữ thập và dấu X xung quanh mỗi 3 lần đánh xa sẽ ngưng trong 2 lượt kế tiếp, đánh cận chiến trong phạm vi 8 ô xung quanh, gây sát thương lên kẻ địch chính và 2 ô bên cạnh địch.",
		"image": preload("res://spellbook/queen.png")
	}
]

func _ready() -> void:
	opened_book_panel.hide()
	closed_book_btn.show()
	closed_book_btn.pressed.connect(open_book)
	if close_btn: close_btn.pressed.connect(close_book)
	if prev_btn: prev_btn.pressed.connect(turn_prev_page)
	if next_btn: next_btn.pressed.connect(turn_next_page)
	if tab_basis: tab_basis.pressed.connect(go_to_page.bind(0))
	if tab_basic: tab_basic.pressed.connect(go_to_page.bind(2))
	if tab_enhanced: tab_enhanced.pressed.connect(go_to_page.bind(6))
	if tab_combine: tab_combine.pressed.connect(go_to_page.bind(10))
	if tab_enemy: tab_enemy.pressed.connect(go_to_page.bind(16))
func open_book() -> void:
	SoundManager.play_sound(SoundManager.sfx_open_book)
	closed_book_btn.hide()
	opened_book_panel.show()
	update_page_ui()
func close_book() -> void:
	SoundManager.play_sound(SoundManager.sfx_open_book)
	opened_book_panel.hide()
	closed_book_btn.show()
func turn_next_page() -> void:
	SoundManager.play_sound(SoundManager.sfx_turnpage, -8)
	if current_page < tutorial_pages.size() - 1:
		current_page += 1
		update_page_ui()
func turn_prev_page() -> void:
	SoundManager.play_sound(SoundManager.sfx_turnpage, -8)
	if current_page > 0:
		current_page -= 1
		update_page_ui()
func update_page_ui() -> void:
	var page_data = tutorial_pages[current_page]
	if page_data.has("spell_id"):
		var definition: SpellDefinition = spell_catalog.get_by_id(page_data.spell_id)
		page_data = {"title": definition.title, "info": definition.describe(), "image": definition.icon}
	title_label.text = page_data["title"]
	info_label.text = page_data["info"]
	if page_data["image"] != null:
		illustration.texture = page_data["image"]
		illustration.show()
	else:
		illustration.hide()
	if prev_btn: prev_btn.visible = current_page > 0
	if next_btn: next_btn.visible = current_page < tutorial_pages.size() - 1
	if left_arrow: left_arrow.visible = current_page > 0
	if right_arrow: right_arrow.visible = current_page < tutorial_pages.size() - 1
func go_to_page(page_index: int) -> void:
	SoundManager.play_sound(SoundManager.sfx_turnpage)
	if page_index >= 0 and page_index < tutorial_pages.size():
		current_page = page_index
		update_page_ui()
	else:
		print("Trang này chưa được viết dữ liệu")
