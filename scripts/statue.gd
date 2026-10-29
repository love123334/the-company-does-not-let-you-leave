extends CharacterBody3D

# Stone Observer / Weeping Statue (ported from HTML makeStatue & updateStatues)
# Spawns on Night 2+.
# Advances ONLY when BOTH unwatched by the player AND the player is moving!
# Also repels the Hunter within STATUE_FEAR_RADIUS (9.0m).

signal player_caught(reason: String)

var player: CharacterBody3D = null
var active: bool = false
var frozen_by_dev: bool = false
var is_killing: bool = false
var kill_anim_timer: float = 0.0
var move_speed: float = 7.4
var sound_cooldown: float = 0.0

var mesh_root: Node3D = null
var left_arm: Node3D = null
var right_arm: Node3D = null
var head_node: Node3D = null

func _ready() -> void:
	add_to_group("statues")
	collision_layer = 4
	collision_mask = 1
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

	var stone_mat = StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.40, 0.39, 0.37)
	stone_mat.roughness = 0.94
	stone_mat.metallic = 0.04

	var dark_stone_mat = StandardMaterial3D.new()
	dark_stone_mat.albedo_color = Color(0.22, 0.21, 0.20)
	dark_stone_mat.roughness = 0.97

	var hollow_mat = StandardMaterial3D.new()
	hollow_mat.albedo_color = Color(0.015, 0.005, 0.008)
	hollow_mat.roughness = 1.0

	var blood_tear_mat = StandardMaterial3D.new()
	blood_tear_mat.albedo_color = Color(0.38, 0.02, 0.04)
	blood_tear_mat.roughness = 0.35
	blood_tear_mat.emission_enabled = true
	blood_tear_mat.emission = Color(0.12, 0.0, 0.01)

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

	if player.get("is_hiding") or player.get("is_inside_cloak") or player.get("in_death_sequence") or player.get("in_secret_corridor"):
		velocity = Vector3.ZERO
		return

	var dir = player.global_position - global_position
	dir.y = 0.0
	var dist = dir.length()

	var observed := _is_observed_by_player()
	if not observed:
		if dist < 1.58 and abs(player.global_position.y - global_position.y) < 2.2:
			_trigger_statue_kill()
			return

		# =========================================================================
		# STEP-LINKED MOVEMENT RULE:
		# Statues only glide forward when unwatched AND the player is moving!
		# =========================================================================
		var player_moved_dist: float = float(player.get("last_frame_move_dist")) if "last_frame_move_dist" in player else 0.0
		if player_moved_dist <= 0.0015:
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

			if sound_cooldown <= 0.0 and dist < 16.0:
				SoundEffects.play_stone_grind()
				sound_cooldown = randf_range(0.65, 1.25)
	else:
		velocity = Vector3.ZERO

func _trigger_statue_kill() -> void:
	if is_killing or (player and player.get("god_mode")):
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

		SoundEffects.play_stone_grind()
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
	var cam = get_viewport().get_camera_3d()
	if not cam:
		return false

	var to_statue = (global_position + Vector3(0, 1.2, 0)) - cam.global_position
	var dist = to_statue.length()
	if dist > 23.0:
		return false

	var cam_forward = -cam.global_transform.basis.z
	var dot = cam_forward.dot(to_statue.normalized())
	if dot < 0.28:
		return false

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		cam.global_position,
		global_position + Vector3(0, 1.3, 0),
		1
	)
	var result = space_state.intersect_ray(query)
	if result.is_empty():
		return true
	return false

func on_repelled_by_cloak(cloak_pos: Vector3) -> void:
	var away = global_position - cloak_pos
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = Vector3.FORWARD
	set_meta("_cloak_repel_dir", away.normalized())
	set_meta("_cloak_repel_timer", 2.8)
