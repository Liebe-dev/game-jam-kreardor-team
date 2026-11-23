class_name BattlePresentation
extends RefCounted
## Presentation events never decide damage or the number of attacks.

var board: Node

func _init(context: Node) -> void:
	board = context

func attack(attacker: Piece, target_pos: Vector2i) -> void:
	if is_instance_valid(attacker):
		attacker.play_attack_animation(target_pos)

func projectile(start_pos: Vector2, end_pos: Vector2) -> void:
	var bullet = ColorRect.new()
	bullet.color = Color.YELLOW
	bullet.size = Vector2(15, 15)

	bullet.global_position = start_pos - (bullet.size / 2)
	board.add_child(bullet)

	var t = board.create_tween()
	t.tween_property(bullet, "global_position", end_pos - (bullet.size / 2), 0.2)

	t.tween_callback(bullet.queue_free)
