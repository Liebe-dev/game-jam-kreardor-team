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
var tutorial_pages = [
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
	{
		"title": "Ignis",
		"info": "Ấn lửa: thiêu đốt mục tiêu, gây sát thương.",
		"image": preload("res://spell/fire.png") 
	},
	{
		"title": "Aqua",
		"info": "Ấn nước: Hồi phục sinh lực, nhận 1 mực.",
		"image": preload("res://spell/water.png")
	},
	{
		"title": "Terra",
		"info": "Ấn đất: tạo lá chắn, nhận 1 giấy.",
		"image": preload("res://spell/earth.png")
	},
	{
		"title": "Ventus",
		"info": "Ấn gió: khiến mục tiêu tấn công 2 lần vào lượt kế tiếp.",
		"image": preload("res://spell/wind.png")
	},
	{
		"title": "Ignis+Ignis",
		"info": "Ấn hỏa gia cường: gây thêm sát thương lên mục tiêu để lại ô lửa tồn tại trong 2 lượt.",
		"image": preload("res://spell/fire fire.png")
	},
	{
		"title": "Aqua+Aqua",
		"info": "Ấn nước gia cường: tạo ra ô hồi phục tồn tại trong 3 lượt.
		Ô hồi phục: liên tục hồi máu cho mục tiêu,mỗi lượt có đồng minh trên ô đó sẽ nhận được 1 mực.",
		"image": preload("res://spell/water water.png")
	},
	{
		"title": "Terra+Terra",
		"info": "Ấn đất gia cường: Tạo lá chắn bảo hộ tồn tại trong 3 lượt, nhận 3 giấy.",
		"image": preload("res://spell/earth earth.png")
	},
	{
		"title": "Ventus+Ventus",
		"info": "Ấn gió gia cường: vô hiệu hóa mục tiêu trên ô đó 1 lượt.",
		"image": preload("res://spell/wind wind.png")
	},
	{
		"title": "Ignis+Terra",
		"info": "Hợp ấn nham thạch: nhận 1 giấy, tạo ra ô lửa, tồn tại 8 lượt, giảm 1 lượt với mỗi hướng, giảm 4 lượt nếu chọn 2 tọa độ..
		Ô lửa: mỗi lượt gây sát thương lên mục tiêu trên nó, mất 1 giấy nếu là đồng minh.
		Lây lan: Mỗi lượt sẽ biến ô theo hướng chỉ định thành ô lửa, thời gian tồn tại của ô đó bằng ô trước đó.",
		"image": preload("res://spell/earth+fire.png")
	},
	{
		"title": "Ignis+Aqua",
		"info": "Hợp ấn sương mù: nhận 1 mực, tạo ra ô sương mù tồn tại 4 lượt, giảm 2 lượt nếu chọn 2 tọa độ.
		Ô sương mù: mục tiêu trong đó không thể bị chỉ định, dùng lên người chơi thì màn hình bị che phủ trừ cuộn giấy phép.
		Di chuyển: Chỉ được chọn 1 hướng, mỗi lượt sẽ di chuyển theo hướng chỉ định.",
		"image": preload("res://spell/water+fire.png")
	},
	{
		"title": "Ignis+Ventus",
		"info": "Hợp ấn lốc lửa: tạo ra cơn bão lửa 3x3 quanh ô chỉ định, tồn tại 4 lượt, giảm 2 lượt nếu chọn 2 tọa độ.
		Ô lốc lửa: Đẩy lùi mục tiêu trong tầm 1 ô, ở trong ô trung tâm không bị đẩy. Nếu không thể bị đẩy lùi sẽ nhận thêm sát thương.
		Di chuyển: Chỉ được chọn 1 hướng, mỗi lượt sẽ di chuyển theo hướng chỉ định.",
		"image": preload("res://spell/wind+fire.png")
	},
	{
		"title": "Aqua+Terra",
		"info": "Hợp ấn đầm lầy: nhận 1 mực và 1 giấy tạo ra ô đầm lầy, tồn tại 8 lượt, giảm 1 lượt với mỗi hướng, giảm 4 lượt nếu chọn 2 tọa độ.
		Ô đầm lầy: mục tiêu bên trong không thể di chuyển trong 1 lượt, hồi máu cho mục tiêu bên trong qua mỗi lượt.
		Lây lan: Mỗi lượt sẽ biến ô theo hướng chỉ định thành ô đầm lầy, thời gian tồn tại của ô đó bằng ô trước đó.",
		"image": preload("res://spell/water+earth.png")
	},
	{
		"title": "Aqua+Ventus",
		"info": "Hợp ấn mưa rào: nhận 1 mực tạo ra ô mưa, tồn tại 8 lượt, giảm 1 lượt với mỗi hướng, giảm 4 lượt nếu chọn 2 tọa độ.
		Ô mưa: hồi máu mục tiêu trên đó, cưỡng chế loại bỏ	 các phép hiệu ứng trên ô đó.
		Lây lan: Mỗi lượt sẽ biến ô theo hướng chỉ định thành ô mưa, thời gian tồn tại của ô đó bằng ô trước đó.",
		"image": preload("res://spell/water+wind.png")
	},
	{
		"title": "Terra+Ventus",
		"info": "Hợp ấn ngọn núi: nhận 1 giấy, tạo ra ô ngọn núi, tồn tại 8 lượt, giảm 1 lượt với mỗi hướng, giảm 4 lượt nếu chọn 2 tọa độ.
		Ô ngọn núi: chặn di chuyển trên ô đó (không thể tạo ra ô ngọn núi trên ô đã có kẻ địch hoặc đồng minh chiếm giữ) đồng minh xung quanh nó được giảm sát thương nhận phải,
		Tường lũy: Biến ô theo hướng chỉ định thành ô ngọn núi, thời gian tồn tại của ô đó giảm 1 với mỗi ô núi được tạo ra.",
		"image": preload("res://spell/wind+earth.png")
	},
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
	},
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
	SoundManager.play_sound(SoundManager.sfx_turnpage)
	if current_page < tutorial_pages.size() - 1:
		current_page += 1
		update_page_ui()
func turn_prev_page() -> void:
	SoundManager.play_sound(SoundManager.sfx_turnpage)
	if current_page > 0:
		current_page -= 1
		update_page_ui()
func update_page_ui() -> void:
	var page_data = tutorial_pages[current_page]
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
