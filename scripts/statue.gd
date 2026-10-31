extends CharacterBody3D

# Stone Observer / Weeping Statue (ported from HTML makeStatue & updateStatues)
# Spawns on Night 2+.
# Advances ONLY when BOTH unwatched by the player AND the player is moving!
# Also repels the Hunter within STATUE_FEAR_RADIUS (9.0m).

signal player_caught(reason: String)

const VisualMaterialFactory = preload("res://scripts/visual_material_factory.gd")

var player: CharacterBody3D = null
var active: bool = false
var frozen_by_dev: bool = false
var is_killing: bool = false
var kill_anim_timer: float = 0.0
var kill_threat_timer: float = 0.0
var move_speed: float = 7.4
var sound_cooldown: float = 0.0
var presence_sound_timer: float = randf_range(2.5, 5.5)

var mesh_root: Node3D = null
var left_arm: Node3D = null
var right_arm: Node3D = null
var head_node: Node3D = null

func _ready() -> void:
	add_to_group("statues")
	collision_layer = 4
	collision_mask = 1 | 8
	_build_statue_mesh()

func activate() -> void:
	active = true
	is_killing = false

func set_freeze(val: bool) -> void:
	frozen_by_dev = val

func _build_statue_mesh() -> void:
	mesh_root = Node3D.new()
	mesh_root.name = "StatueVisual"
	add_child(mesh_root)

	var stone_mat = VisualMaterialFactory.create_stone_material(Color(0.40, 0.39, 0.37))
	var dark_stone_mat = VisualMaterialFactory.create_stone_material(Color(0.22, 0.21, 0.20))
	var hollow_mat = StandardMaterial3D.new()
	hollow_mat.albedo_color = Color(0.015, 0.005, 0.008)
	hollow_mat.roughness = 1.0
	var blood_tear_mat = VisualMaterialFactory.create_flesh_material(Color(0.38, 0.02, 0.04), true)

	# Base Plinth + Dust Ring
	var plinth = MeshInstance3D.new()
	var plinth_cyl = CylinderMesh.new()
	plinth_cyl.top_radius = 0.40
	plinth_cyl.bottom_radius = 0.46
	plinth_cyl.height = 0.16
	plinth_cyl.radial_segments = 8
	plinth.mesh = plinth_cyl
	plinth.material_override = dark_stone_mat
	plinth.position = Vector3(0, 0.08, 0)
	mesh_root.add_child(plinth)

	# Two Stone Legs / Pillar Fold
	for side in [-1.0, 1.0]:
		var leg = MeshInstance3D.new()
		var leg_cyl = CylinderMesh.new()
		leg_cyl.top_radius = 0.12
		leg_cyl.bottom_radius = 0.15
		leg_cyl.height = 0.90
		leg_cyl.radial_segments = 7
		leg.mesh = leg_cyl
		leg.material_override = stone_mat
		leg.position = Vector3(side * 0.13, 0.56, 0.02 * side)
		mesh_root.add_child(leg)

	# Forward-leaning Cracked Stone Torso + Exposed Ribs
	var torso = MeshInstance3D.new()
	var torso_cyl = CylinderMesh.new()
	torso_cyl.top_radius = 0.25
	torso_cyl.bottom_radius = 0.19
	torso_cyl.height = 0.78
	torso_cyl.radial_segments = 8
	torso.mesh = torso_cyl
	torso.material_override = stone_mat
	torso.position = Vector3(0, 1.32, -0.04)
	torso.rotation.x = -0.14
	mesh_root.add_child(torso)

	# Jagged Cracks Across Chest
	for c in range(3):
		var crack = MeshInstance3D.new()
		var cb = BoxMesh.new()
		cb.size = Vector3(0.28, 0.018, 0.04)
		crack.mesh = cb
		crack.position = Vector3((c - 1) * 0.04, 1.18 + c * 0.14, -0.24)
		crack.rotation.z = 0.45 - c * 0.38
		crack.material_override = hollow_mat
		mesh_root.add_child(crack)

	# Draped Stone Shawl / Shoulders
	var shoulders = MeshInstance3D.new()
	var sh_box = BoxMesh.new()
	sh_box.size = Vector3(0.64, 0.20, 0.32)
	shoulders.mesh = sh_box
	shoulders.material_override = dark_stone_mat
	shoulders.position = Vector3(0, 1.62, -0.04)
	mesh_root.add_child(shoulders)

	# Outstretched Reaching Stone Arms with 5 Clawed Stone Fingers
	for side in [-1.0, 1.0]:
		var arm_pivot = Node3D.new()
		arm_pivot.position = Vector3(side * 0.30, 1.58, -0.08)
		mesh_root.add_child(arm_pivot)
		if side < 0:
			left_arm = arm_pivot
		else:
			right_arm = arm_pivot

		var upper_arm = MeshInstance3D.new()
		var ua_cyl = CylinderMesh.new()
		ua_cyl.top_radius = 0.075
		ua_cyl.bottom_radius = 0.06
		ua_cyl.height = 0.56
		upper_arm.mesh = ua_cyl
		upper_arm.material_override = stone_mat
		upper_arm.position = Vector3(0, -0.04, -0.26)
		upper_arm.rotation.x = PI * 0.42
		arm_pivot.add_child(upper_arm)

		var hand = MeshInstance3D.new()
		var h_box = BoxMesh.new()
		h_box.size = Vector3(0.09, 0.09, 0.12)
		hand.mesh = h_box
		hand.material_override = dark_stone_mat
		hand.position = Vector3(0, -0.08, -0.54)
		arm_pivot.add_child(hand)

		for f in range(5):
			var claw = MeshInstance3D.new()
			var cc = CylinderMesh.new()
			cc.top_radius = 0.0
			cc.bottom_radius = 0.012
			cc.height = 0.13
			claw.mesh = cc
			claw.position = Vector3((float(f) - 2.0) * 0.022, -0.09 - abs(f - 2) * 0.01, -0.64)
			claw.rotation.x = -PI * 0.38
			claw.material_override = dark_stone_mat
			arm_pivot.add_child(claw)

	# Neck & Elongated Screaming Head
	head_node = Node3D.new()
	head_node.position = Vector3(0, 1.94, -0.09)
	mesh_root.add_child(head_node)

	var head_mesh = MeshInstance3D.new()
	var h_sph = SphereMesh.new()
	h_sph.radius = 0.19
	h_sph.height = 0.46
	h_sph.radial_segments = 10
	h_sph.rings = 6
	head_mesh.mesh = h_sph
	head_mesh.material_override = stone_mat
	head_node.add_child(head_mesh)

	# Hollow Black Eye Sockets, Weeping Blood Tear Streaks & Screaming Gaping Mouth
	for side in [-1.0, 1.0]:
		var socket = MeshInstance3D.new()
		var s_sph = SphereMesh.new()
		s_sph.radius = 0.042
		s_sph.height = 0.084
		socket.mesh = s_sph
		socket.material_override = hollow_mat
		socket.position = Vector3(side * 0.065, 0.04, -0.165)
		head_node.add_child(socket)

		var tear = MeshInstance3D.new()
		var tb = BoxMesh.new()
		tb.size = Vector3(0.018, 0.14, 0.015)
		tear.mesh = tb
		tear.position = Vector3(side * 0.065, -0.04, -0.178)
		tear.material_override = blood_tear_mat
		head_node.add_child(tear)

	var mouth = MeshInstance3D.new()
	var m_box = BoxMesh.new()
	m_box.size = Vector3(0.095, 0.13, 0.06)
	mouth.mesh = m_box
	mouth.material_override = hollow_mat
	mouth.position = Vector3(0, -0.08, -0.165)
	head_node.add_child(mouth)

func _physics_process(delta: float) -> void:
	if is_killing:
		velocity = Vector3.ZERO
		kill_anim_timer += delta
		# Animate stone arms gripping the player's head and wrenching sideways at t = 0.72s
		if left_arm and right_arm and head_node:
			if kill_anim_timer < 0.72:
				var grip = clampf(kill_anim_timer / 0.72, 0.0, 1.0)
				left_arm.rotation = Vector3(lerpf(0.0, -0.32, grip), lerpf(0.0, 0.26, grip), lerpf(0.0, -0.25, grip))
				right_arm.rotation = Vector3(lerpf(0.0, -0.32, grip), lerpf(0.0, -0.26, grip), lerpf(0.0, -0.25, grip))
				head_node.rotation = Vector3(0.15 * grip, 0.0, sin(kill_anim_timer * 38.0) * 0.12)
			else:
				# Violent wrenching snap motion
				var snap_t = min(1.0, (kill_anim_timer - 0.72) * 9.0)
				left_arm.rotation = Vector3(-0.48, lerpf(0.26, -0.55, snap_t), -0.65 * snap_t)
				right_arm.rotation = Vector3(-0.18, lerpf(-0.26, -0.68, snap_t), 0.55 * snap_t)
				head_node.rotation = Vector3(0.22, -0.25 * snap_t, 0.38 * snap_t)
		return

	if not active or frozen_by_dev or not player:
		velocity = Vector3.ZERO
		return

	if sound_cooldown > 0.0:
		sound_cooldown -= delta

	if has_meta("_cloak_repel_timer") and float(get_meta("_cloak_repel_timer")) > 0.0:
		var rt: float = float(get_meta("_cloak_repel_timer")) - delta
		set_meta("_cloak_repel_timer", rt)
		var rdir: Vector3 = get_meta("_cloak_repel_dir", Vector3.FORWARD)
		velocity.x = rdir.x * (move_speed * 0.65)
		velocity.z = rdir.z * (move_speed * 0.65)
		velocity.y = 0.0
		move_and_slide()
		rotation.y = atan2(-rdir.x, -rdir.z)
		return

	if player.get("is_hiding") or player.get("is_inside_cloak") or player.get("in_death_sequence") or player.get("is_dead") or player.get("in_secret_corridor"):
		velocity = Vector3.ZERO
		return

	var dir = player.global_position - global_position
	dir.y = 0.0
	var dist = dir.length()

	# Deep stone scraping across the floor to alert player to Observer presence nearby
	if dist < 14.0 and not is_killing and not (player and (player.get("is_dead") == true)):
		presence_sound_timer -= delta
		if presence_sound_timer <= 0.0:
			presence_sound_timer = randf_range(5.5, 9.5)
			var vol = lerpf(0.0, -18.0, clampf(dist / 14.0, 0.0, 1.0))
			SoundEffects.play_stone_drag(vol, randf_range(0.85, 0.98))

	var observed := _is_observed_by_player()
	if not observed:
		var is_scrubbing_work = player != null and (player.get("is_scrubbing") == true)
		if dist < 1.65 and abs(player.global_position.y - global_position.y) < 2.2:
			if is_scrubbing_work:
				# Protected while scrubbing floor spills: warn player with dragging sound instead of unfair instant death
				if sound_cooldown <= 0.0:
					SoundEffects.play_stone_drag(2.0, 1.1)
					sound_cooldown = 1.5
				kill_threat_timer = 0.0
			else:
				kill_threat_timer += delta
				if kill_threat_timer >= 0.85:
					_trigger_statue_kill()
					return
		else:
			kill_threat_timer = max(0.0, kill_threat_timer - delta * 2.0)

		# =========================================================================
		# STEP-LINKED MOVEMENT RULE:
		# Statues only glide forward when unwatched AND the player is moving!
		# =========================================================================
		var player_moved_dist: float = float(player.get("last_frame_move_dist")) if "last_frame_move_dist" in player else 0.0
		var mp_active: bool = false
		var mp_freeze: bool = false
		var net_mgr = get_node_or_null("/root/NetworkManager")
		if net_mgr and (net_mgr.get("is_multiplayer_active") == true):
			mp_active = true
			if net_mgr.has_method("is_any_player_in_locker") and net_mgr.is_any_player_in_locker():
				mp_freeze = false
			elif net_mgr.has_method("should_monsters_freeze"):
				mp_freeze = net_mgr.should_monsters_freeze(global_position)

		if mp_active:
			if mp_freeze:
				velocity = Vector3.ZERO
				return
		elif player_moved_dist <= 0.0015 or is_scrubbing_work:
			velocity = Vector3.ZERO
			return

		if dist > 0.01 and dist < 28.0:
			var player_spd_ratio = clampf((player_moved_dist / max(delta, 0.001)) / 4.2, 0.45, 1.7)
			dir = dir.normalized()
			velocity.x = dir.x * move_speed * player_spd_ratio
			velocity.z = dir.z * move_speed * player_spd_ratio
			velocity.y = 0.0
			move_and_slide()

			rotation.y = atan2(-dir.x, -dir.z)

			if left_arm and right_arm:
				var p = Time.get_ticks_msec() * 0.01
				left_arm.rotation.x = sin(p) * 0.22
				right_arm.rotation.x = -sin(p) * 0.22
			if head_node:
				head_node.rotation.z = sin(Time.get_ticks_msec() * 0.007) * 0.16

			if sound_cooldown <= 0.0 and dist < 18.0:
				var vol = lerpf(0.0, -18.0, clampf(dist / 18.0, 0.0, 1.0))
				SoundEffects.play_stone_drag(vol, randf_range(0.90, 1.05))
				sound_cooldown = randf_range(1.6, 2.6)
	else:
		kill_threat_timer = 0.0
		velocity = Vector3.ZERO

func _trigger_statue_kill() -> void:
	if is_killing or (player and (player.get("god_mode") or player.get("is_dead"))):
		return
	is_killing = true
	kill_anim_timer = 0.0
	active = false
	velocity = Vector3.ZERO
	var reason = "YOU STOPPED WATCHING — THE WEEPING OBSERVER SNAPPED YOUR NECK."
	if player and is_instance_valid(player):
		var dir = (global_position - player.global_position)
		dir.y = 0.0
		if dir.length_squared() < 0.05:
			dir = -player.global_transform.basis.z
		global_position = player.global_position + dir.normalized() * 0.96
		global_position.y = player.global_position.y
		var to_p = player.global_position - global_position
		rotation.y = atan2(-to_p.x, -to_p.z)

		SoundEffects.play_stone_drag(3.0, 0.88)
		SoundEffects.play(SoundEffects.snd_screech, 3.0, 1.2)
		var hud_node = get_tree().root.find_child("HUD", true, false)
		if hud_node and hud_node.has_method("flash_damage"):
			hud_node.flash_damage()
		if player.has_method("start_death_sequence"):
			player.start_death_sequence(self, "statue", 1.45, func():
				player_caught.emit(reason)
			)
			return
	player_caught.emit(reason)

func _is_observed_by_player() -> bool:
	var space_state = get_world_3d().direct_space_state
	var statue_head_pos = global_position + Vector3(0, 1.3, 0)

	# 1. Check local player camera
	var cam = get_viewport().get_camera_3d()
	if cam and (player and (player.get("is_dead") != true)):
		var to_statue = statue_head_pos - cam.global_position
		var dist = to_statue.length()
		if dist <= 24.0:
			var cam_forward = -cam.global_transform.basis.z
			var dot = cam_forward.dot(to_statue.normalized())
			if dot >= 0.26:
				var q = PhysicsRayQueryParameters3D.create(cam.global_position, statue_head_pos, 1)
				if space_state.intersect_ray(q).is_empty():
					return true

	# 2. Check remote players in multiplayer (quantum observation by teammates)
	for r_node in get_tree().get_nodes_in_group("remote_players"):
		if is_instance_valid(r_node) and (r_node.get("is_dead") != true):
			var r_head = r_node.global_position + Vector3(0, 1.55, 0)
			var to_st = statue_head_pos - r_head
			var r_dist = to_st.length()
			if r_dist <= 24.0:
				var r_forward = -r_node.global_transform.basis.z
				var r_dot = r_forward.dot(to_st.normalized())
				if r_dot >= 0.26:
					var rq = PhysicsRayQueryParameters3D.create(r_head, statue_head_pos, 1)
					if space_state.intersect_ray(rq).is_empty():
						return true
	return false

func on_repelled_by_cloak(cloak_pos: Vector3) -> void:
	var away = global_position - cloak_pos
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = Vector3.FORWARD
	set_meta("_cloak_repel_dir", away.normalized())
	set_meta("_cloak_repel_timer", 2.8)
