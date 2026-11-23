class_name SpellDefinition
extends Resource
## Gameplay and spellbook read the same immutable spell data.

@export var id: StringName
@export var elements: PackedInt32Array
@export var title: String
@export_multiline var description: String
@export var icon: Texture2D
@export var power: float = 0.0
@export var duration: int = 0
@export var paper_cost: int = 1
@export var paper_reward: int = 0
@export var ink_reward: float = 0.0
@export var settings: Dictionary = {}

func param(key: StringName, fallback = 0):
	return settings.get(String(key), fallback)

func describe() -> String:
	var lines: PackedStringArray = [description]
	if power > 0.0:
		if id in [&"earth", &"earth_earth"]:
			lines.append("Giảm sát thương cơ bản: %s%%." % (power * 100.0))
		elif id == &"wind_earth":
			lines.append("Sinh lực tường cơ bản: %s." % power)
		else:
			lines.append("Giá trị cơ bản: %s." % power)
	if duration > 0:
		lines.append("Thời hạn cơ bản: %d lượt." % duration)
	if ink_reward > 0.0:
		lines.append("Nhận %s mực." % ink_reward)
	if paper_reward > 0:
		lines.append("Nhận %d giấy." % paper_reward)
	if settings.has("multi_target_reduction"):
		lines.append("Hai tọa độ: giảm %d lượt." % int(settings.multi_target_reduction))
	if settings.has("tick_damage"):
		lines.append("Sát thương ô mỗi lượt: %s." % settings.tick_damage)
	if settings.has("tick_heal"):
		lines.append("Hồi máu ô mỗi lượt: %s." % settings.tick_heal)
	if settings.has("tick_ink"):
		lines.append("Đồng minh trên ô nhận %s mực mỗi lượt." % settings.tick_ink)
	lines.append("Chi phí: %d giấy, thêm mực khi nhập chú ngữ." % paper_cost)
	return "\n".join(lines)
