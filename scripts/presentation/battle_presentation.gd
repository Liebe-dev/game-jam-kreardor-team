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

func create_tile_visual(grid_pos: Vector2i, effect_type: String, is_first_spawn: bool):
	var spawned_visual = board.SPELL_EFFECT_SCENE.instantiate()
	board.get_tree().current_scene.add_child(spawned_visual)
	var base_pos = board.grid_to_pixel(grid_pos)
	var final_offset = Vector2(0, 0)
	match effect_type:
		"water_tile":
			spawned_visual.play("nuocnuoc")
			final_offset = Vector2(0, 10)
			spawned_visual.z_index = 40
		"fire_tile":
			spawned_visual.play("lualua")
			final_offset = Vector2(0, -30)
			spawned_visual.z_index = 100
		"rain_tile":
			spawned_visual.play("nuocgio")
			spawned_visual.z_index = 100
		"lava_tile":
			spawned_visual.play("luadat")
			final_offset = Vector2(0, -30)
			spawned_visual.z_index = 100
		"swamp_tile":
			spawned_visual.play("nuocdat")
			final_offset = Vector2(0, -10)
			spawned_visual.z_index = 40
		"firestorm_tile":
			spawned_visual.play("luagio")
			final_offset = Vector2(0, -30)
			spawned_visual.z_index = 100
		"fog_tile":
			final_offset = Vector2(0, -20)
			spawned_visual.z_index = 150
			spawned_visual.play("luanuoc1")
			if is_first_spawn:
				spawned_visual.frame = 0
			else:
				spawned_visual.frame = 2
			var custom_loop = func():
				if is_instance_valid(spawned_visual) and spawned_visual.animation == "luanuoc1":
					spawned_visual.frame = 2
			if not spawned_visual.animation_looped.is_connected(custom_loop):
				spawned_visual.animation_looped.connect(custom_loop)
	spawned_visual.global_position = base_pos + final_offset
	return spawned_visual

func play_spell_animation(grid_pos: Vector2i, anim_name: String, target_unit = null):
	var effect = board.SPELL_EFFECT_SCENE.instantiate()
	effect.visible = false
	board.get_tree().current_scene.add_child(effect)
	var base_pos = Vector2.ZERO
	if target_unit != null:
		base_pos = target_unit.global_position
	else:
		base_pos = board.grid_to_pixel(grid_pos)
	effect.global_position = base_pos + Vector2(0, -30)
	effect.play(anim_name)
	effect.visible = true
	effect.animation_finished.connect(effect.queue_free)

func play_wind_visual(grid_pos: Vector2i, anim_name: String):
	var spawned_visual = board.SPELL_EFFECT_SCENE.instantiate()
	board.get_tree().current_scene.add_child(spawned_visual)
	spawned_visual.global_position = board.grid_to_pixel(grid_pos)
	spawned_visual.z_index = 150
	spawned_visual.play(anim_name)
	spawned_visual.animation_finished.connect(func(): spawned_visual.queue_free(), CONNECT_ONE_SHOT)
