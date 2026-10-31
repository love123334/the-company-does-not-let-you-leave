extends CharacterBody3D

# The Hanger (Ceiling-bound Lurker Specimen)
# - Pure ceiling dweller: clings to the ceiling, crawls along overhead conduits and rafters.
# - The slowest moving entity in the game (0.65 m/s).
# - Weapon: A grotesque, elongated muscular tongue that shoots downwards to snare and hang prey.
# - When grabbing the player: lifts them by the neck; player must spam [SPACE] to break free within 5.0 seconds.
# - Specimen Interactions:
#   * Hunter (Main Monster): 100% fail rate. Holds Hunter suspended for 6.0s before Hunter breaks free.
#   * Cloak: 100% fail rate. Holds Cloak for 8.0s. If Cloak was hostile, snaring resets Cloak to neutral!
#   * Cultists & Crawlers: 50% chance of successfully devouring them (instant kill); 50% fail rate (drops them stunned).

signal target_devoured(monster_name: String)

@export var move_speed: float = 0.65
@export var snare_radius: float = 3.2
@export var ceiling_y: float = 15.4

var active: bool = true
var frozen_by_dev: bool = false
var state: String = "PATROL" # "PATROL", "SNARE_PULL", "HOLD_TARGET", "DEVOUR", "STUNNED"

var anim_time: float = 0.0
var roam_dir: Vector3 = Vector3.FORWARD
var roam_timer: float = 0.0

var current_target: Node3D = null
var target_type: String = "" # "player", "hunter", "cloak", "cultist", "crawler"
var target_start_pos: Vector3 = Vector3.ZERO
var snare_timer: float = 0.0
var max_snare_duration: float = 5.0
var stun_timer: float = 0.0
var will_devour: bool = false

# Procedural Visual Rig
var mesh_root: Node3D = null
var tongue_root: Node3D = null
var tongue_segments: Array[MeshInstance3D] = []
var eye_lights: Array[OmniLight3D] = []
var maw_node: Node3D = null

var flesh_mat: StandardMaterial3D = null
var tongue_mat: StandardMaterial3D = null
var eye_mat: StandardMaterial3D = null

func _ready() -> void:
	add_to_group("hangers")
	collision_layer = 0
	collision_mask = 1 # Collides with walls to avoid clipping outside corridors
	_build_hanger_mesh()
	roam_timer = randf_range(2.0, 5.0)
	var ang = randf() * TAU
	roam_dir = Vector3(cos(ang), 0.0, sin(ang))

func _build_hanger_mesh() -> void:
	mesh_root = Node3D.new()
	mesh_root.name = "HangerVisual"
	add_child(mesh_root)

	flesh_mat = StandardMaterial3D.new()
	flesh_mat.albedo_color = Color(0.18, 0.08, 0.10)
	flesh_mat.roughness = 0.35
	flesh_mat.metallic = 0.15
	flesh_mat.emission_enabled = true
	flesh_mat.emission = Color(0.08, 0.02, 0.04)

	tongue_mat = StandardMaterial3D.new()
	tongue_mat.albedo_color = Color(0.65, 0.12, 0.22)
	tongue_mat.roughness = 0.22
	tongue_mat.metallic = 0.10
	tongue_mat.emission_enabled = true
	tongue_mat.emission = Color(0.25, 0.04, 0.08)

	eye_mat = StandardMaterial3D.new()
	eye_mat.albedo_color = Color(0.9, 0.95, 0.2)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(0.95, 1.0, 0.25)
	eye_mat.emission_energy_multiplier = 3.5

	# 1. Ceiling Mount / Flesh Anchor
	var anchor = MeshInstance3D.new()
	var a_mesh = CylinderMesh.new()
	a_mesh.top_radius = 0.95
	a_mesh.bottom_radius = 0.65
	a_mesh.height = 0.22
	anchor.mesh = a_mesh
	anchor.material_override = flesh_mat
	anchor.position.y = 0.1
	mesh_root.add_child(anchor)

	# 2. Inverted Torso / Suspended Spinal Column
	var spine = MeshInstance3D.new()
	var s_mesh = CylinderMesh.new()
	s_mesh.top_radius = 0.35
	s_mesh.bottom_radius = 0.22
	s_mesh.height = 1.35
	spine.mesh = s_mesh
	spine.material_override = flesh_mat
	spine.position.y = -0.65
	mesh_root.add_child(spine)

	# Inverted Ribs (6 pairs curving downward)
	for i in range(6):
		for s in [-1.0, 1.0]:
			var rib = MeshInstance3D.new()
			var r_box = BoxMesh.new()
			r_box.size = Vector3(0.08, 0.06, 0.48)
			rib.mesh = r_box
			rib.material_override = flesh_mat
			var r_y = -0.25 - float(i) * 0.18
			rib.position = Vector3(s * 0.28, r_y, 0.0)
			rib.rotation = Vector3(deg_to_rad(15.0 + i * 5.0), deg_to_rad(s * 35.0), deg_to_rad(s * 25.0))
			mesh_root.add_child(rib)

	# 3. Grotesque Upside-down Head with Gaping Maw
	maw_node = Node3D.new()
	maw_node.position.y = -1.45
	mesh_root.add_child(maw_node)

	var head = MeshInstance3D.new()
	var h_mesh = SphereMesh.new()
	h_mesh.radius = 0.38
	h_mesh.height = 0.72
	head.mesh = h_mesh
	head.material_override = flesh_mat
	maw_node.add_child(head)

	# 4 Glowing Eyes
	for i in range(4):
		var eye = MeshInstance3D.new()
		var e_mesh = SphereMesh.new()
		e_mesh.radius = 0.06
		e_mesh.height = 0.12
		eye.mesh = e_mesh
		eye.material_override = eye_mat
		var ang = float(i) * (PI / 2.0) + PI / 4.0
		eye.position = Vector3(cos(ang) * 0.26, -0.12, sin(ang) * 0.26)
		maw_node.add_child(eye)

	var o_light = OmniLight3D.new()
	o_light.position = Vector3(0, -0.25, 0)
	o_light.omni_range = 4.5
	o_light.omni_attenuation = 1.4
	o_light.light_color = Color(0.95, 1.0, 0.25)
	o_light.light_energy = 1.8
	maw_node.add_child(o_light)
	eye_lights.append(o_light)

	# 4. Segmented Procedural Tongue (8 articulated cylinder segments)
	tongue_root = Node3D.new()
	tongue_root.position.y = -1.65
	mesh_root.add_child(tongue_root)

	for i in range(12):
		var seg = MeshInstance3D.new()
		var seg_mesh = CylinderMesh.new()
		seg_mesh.top_radius = 0.09 - float(i) * 0.004
		seg_mesh.bottom_radius = 0.08 - float(i) * 0.004
		seg_mesh.height = 0.42
		seg.mesh = seg_mesh
		seg.material_override = tongue_mat
		seg.position.y = -float(i) * 0.38
		tongue_root.add_child(seg)
		tongue_segments.append(seg)

func _physics_process(delta: float) -> void:
	if not active or frozen_by_dev:
		return

	anim_time += delta
	_update_tongue_visuals(delta)

	# Keep Hanger anchored to ceiling height
	_anchor_to_ceiling(delta)

	if state == "STUNNED":
		stun_timer -= delta
		velocity = Vector3.ZERO
		if stun_timer <= 0.0:
			state = "PATROL"
			current_target = null
		return

	if state == "DEVOUR":
		snare_timer -= delta
		velocity = Vector3.ZERO
		# Crunch / jaw chewing motion
		if maw_node:
			maw_node.scale = Vector3(1.0 + sin(anim_time * 16.0) * 0.18, 1.0 - abs(sin(anim_time * 16.0)) * 0.25, 1.0 + sin(anim_time * 16.0) * 0.18)
		if snare_timer <= 0.0:
			state = "PATROL"
			current_target = null
			if maw_node:
				maw_node.scale = Vector3.ONE
		return

	if state == "SNARE_PULL" or state == "HOLD_TARGET":
		_process_snare_target(delta)
		return

	# State == "PATROL"
	_process_patrol_and_scan(delta)

func _anchor_to_ceiling(delta: float) -> void:
	# Cast ray upwards to find exact ceiling surface
	var space = get_world_3d().direct_space_state
	var up_query = PhysicsRayQueryParameters3D.create(
		global_position,
		global_position + Vector3(0, 6.0, 0),
		1
	)
	var up_hit = space.intersect_ray(up_query)
	var target_ceil_y = ceiling_y
	if up_hit and not up_hit.is_empty():
		target_ceil_y = up_hit.position.y - 0.1
	global_position.y = lerpf(global_position.y, target_ceil_y, min(1.0, delta * 8.0))

func _process_patrol_and_scan(delta: float) -> void:
	roam_timer -= delta
	if roam_timer <= 0.0 or is_on_wall():
		roam_timer = randf_range(3.5, 7.0)
		var dirs = [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]
		roam_dir = dirs[randi() % dirs.size()].rotated(Vector3.UP, randf_range(-0.5, 0.5)).normalized()

	velocity.x = roam_dir.x * move_speed
	velocity.z = roam_dir.z * move_speed
	velocity.y = 0.0
	move_and_slide()

	if roam_dir.length_squared() > 0.01:
		var target_yaw = atan2(-roam_dir.x, -roam_dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, delta * 3.5)

	# Scan for any target underneath within horizontal snare_radius
	var target = _find_snare_target()
	if target != null:
		_snare_target(target)

func _has_line_of_sight_to(target: Node3D) -> bool:
	if not is_instance_valid(target):
		return false
	var space = get_world_3d().direct_space_state
	var from_pos = global_position + Vector3(0.0, -1.2, 0.0)
	var to_pos = target.global_position + Vector3(0.0, 1.0, 0.0)
	var query = PhysicsRayQueryParameters3D.create(from_pos, to_pos, 1)
	var hit = space.intersect_ray(query)
	# If hit is empty or hit.collider is the target itself, LOS is clear!
	if hit.is_empty():
		return true
	if hit.collider == target:
		return true
	return false

func _find_snare_target() -> Node3D:
	# Hanger is strictly a 2nd Floor ceiling predator!
	# Will NEVER snare targets on Floor 1 (below y = 10.0m) or through solid walls/ceilings.
	
	# 1. Check Player
	var player = get_tree().root.find_child("Player", true, false)
	if player and is_instance_valid(player):
		var p_hiding = bool(player.get("is_hiding"))
		var p_dead = bool(player.get("in_death_sequence")) or bool(player.get("is_dead"))
		var p_snared = bool(player.get("is_hanged_by_hanger"))
		var p_floor = int(player.get("current_floor"))
		if not p_hiding and not p_dead and not p_snared and p_floor == 2 and player.global_position.y >= 10.0:
			var h_dist = Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z).length()
			if h_dist <= snare_radius and player.global_position.y < global_position.y - 1.0:
				if _has_line_of_sight_to(player):
					return player

	# 2. Check Hunter (Main Monster) - Must be on Floor 2!
	var hunter = get_tree().root.find_child("Hunter", true, false)
	if hunter and is_instance_valid(hunter) and hunter.get("active") and hunter.global_position.y >= 10.0:
		var h_state = hunter.get("state")
		if h_state != 0 and h_state != 7: # Not DORMANT or KILL
			var h_dist = Vector2(hunter.global_position.x - global_position.x, hunter.global_position.z - global_position.z).length()
			if h_dist <= snare_radius and hunter.global_position.y < global_position.y - 1.0:
				if _has_line_of_sight_to(hunter):
					return hunter

	# 3. Check Cloaks (Ghost Girls) - Must be on Floor 2!
	for clk in get_tree().get_nodes_in_group("cloaks"):
		if is_instance_valid(clk) and clk.get("active") and not clk.get("is_snared_by_hanger") and clk.global_position.y >= 10.0:
			var d = Vector2(clk.global_position.x - global_position.x, clk.global_position.z - global_position.z).length()
			if d <= snare_radius and clk.global_position.y < global_position.y - 1.0:
				if _has_line_of_sight_to(clk):
					return clk

	# 4. Check Cultists - Must be on Floor 2!
	for cu in get_tree().get_nodes_in_group("cultists"):
		if is_instance_valid(cu) and cu.get("active") and not cu.get("is_snared_by_hanger") and cu.global_position.y >= 10.0:
			var d = Vector2(cu.global_position.x - global_position.x, cu.global_position.z - global_position.z).length()
			if d <= snare_radius and cu.global_position.y < global_position.y - 1.0:
				if _has_line_of_sight_to(cu):
					return cu

	# 5. Check Crawlers - Must be on Floor 2!
	for cr in get_tree().get_nodes_in_group("crawlers"):
		if is_instance_valid(cr) and cr.get("is_active") and not cr.get("is_snared_by_hanger") and cr.global_position.y >= 10.0:
			var d = Vector2(cr.global_position.x - global_position.x, cr.global_position.z - global_position.z).length()
			if d <= snare_radius and cr.global_position.y < global_position.y - 1.0:
				if _has_line_of_sight_to(cr):
					return cr

	return null

func _snare_target(target: Node3D) -> void:
	current_target = target
	target_start_pos = target.global_position
	snare_timer = 0.0
	state = "SNARE_PULL"
	velocity = Vector3.ZERO

	SoundEffects.play_cloth_wrap()
	SoundEffects.play_hunter_screech()

	if target.is_in_group("players") or target.name == "Player":
		target_type = "player"
		max_snare_duration = 5.0
		# Perfect Parry Check against Hanger Tongue Snare
		if target.has_method("is_baton_parrying") and target.is_baton_parrying():
			_enter_stun(3.0)
			target.on_successful_parry(self)
			var hud_node = get_tree().root.find_child("HUD", true, false)
			if hud_node and hud_node.has_method("show_toast"):
				hud_node.show_toast("⚡ PERFECT PARRY! HANGER'S TONGUE DEFLECTED & STUNNED (3.0s)!", Color(0.2, 1.0, 0.5))
			return
		if target.has_method("snare_by_hanger"):
			target.snare_by_hanger(self)
	elif target.is_in_group("hunters") or target.name == "Hunter":
		target_type = "hunter"
		max_snare_duration = 6.0
		will_devour = false # 100% fail on Hunter!
		if target.has_method("freeze_by_hanger"):
			target.freeze_by_hanger(6.0)
	elif target.is_in_group("cloaks"):
		target_type = "cloak"
		max_snare_duration = 8.0
		will_devour = false # 100% fail on Cloak!
		if target.has_method("freeze_by_hanger"):
			target.freeze_by_hanger(8.0)
	elif target.is_in_group("cultists"):
		target_type = "cultist"
		max_snare_duration = 3.5
		will_devour = (randf() < 0.50) # 50% catch & devour!
		if target.has_method("freeze_by_hanger"):
			target.freeze_by_hanger(3.5)
	elif target.is_in_group("crawlers"):
		target_type = "crawler"
		max_snare_duration = 3.2
		will_devour = (randf() < 0.50) # 50% catch & devour!
		if target.has_method("freeze_by_hanger"):
			target.freeze_by_hanger(3.2)
	else:
		target_type = "monster"
		max_snare_duration = 3.5
		will_devour = (randf() < 0.50)

func _process_snare_target(delta: float) -> void:
	if not is_instance_valid(current_target):
		state = "PATROL"
		current_target = null
		return

	snare_timer += delta

	# Hoist target upward towards Hanger's maw
	var pull_ratio = clampf(snare_timer / 1.5, 0.0, 1.0)
	var lift_y = lerpf(target_start_pos.y, global_position.y - 1.8, pull_ratio)
	current_target.global_position.y = lift_y

	# Face towards target
	var to_t = current_target.global_position - global_position
	to_t.y = 0.0
	if to_t.length_squared() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-to_t.x, -to_t.z), delta * 8.0)

	if target_type == "player":
		# Player struggles in player.gd; if time runs out, player.gd triggers death.
		return

	if target_type == "hunter":
		if snare_timer >= max_snare_duration:
			# Hunter breaks free!
			if is_instance_valid(current_target) and current_target.has_method("release_from_hanger"):
				current_target.release_from_hanger()
			_enter_stun(5.0)
		return

	if target_type == "cloak":
		if snare_timer >= max_snare_duration:
			# Cloak breaks free and resets hostility!
			if is_instance_valid(current_target):
				if current_target.has_method("release_from_hanger"):
					current_target.release_from_hanger()
				if current_target.has_method("reset_hostility"):
					current_target.reset_hostility()
			var hud_node = get_tree().root.find_child("HUD", true, false)
			if hud_node and hud_node.has_method("show_toast"):
				hud_node.show_toast("The Cloak broke free from the Hanger — its wrath has calmed.", Color(0.85, 0.65, 1.0))
			_enter_stun(4.5)
		return

	# Cultist or Crawler
	if snare_timer >= max_snare_duration:
		if will_devour:
			# 50% Success: Devour the specimen!
			SoundEffects.play_Wet_Squish()
			SoundEffects.play(SoundEffects.snd_click, 6.0, 0.35)
			var devoured_name = target_type.capitalize()
			current_target.queue_free()
			current_target = null
			state = "DEVOUR"
			snare_timer = 2.5
			var hud_node = get_tree().root.find_child("HUD", true, false)
			if hud_node and hud_node.has_method("show_toast"):
				hud_node.show_toast("The Hanger caught and devoured a %s!" % devoured_name, Color(0.95, 0.2, 0.3))
		else:
			# 50% Fail: Release target stunned
			if is_instance_valid(current_target) and current_target.has_method("release_from_hanger"):
				current_target.release_from_hanger()
			_enter_stun(4.0)

func on_player_escaped() -> void:
	# Called by player.gd when player breaks free via Space spam
	_enter_stun(6.5)

func stun(duration: float) -> void:
	_enter_stun(duration)
	_spawn_electric_sparks(duration)

func _spawn_electric_sparks(duration: float) -> void:
	var spark_node = Node3D.new()
	spark_node.name = "StunSparks"
	spark_node.position = Vector3(0, 0, 0)
	add_child(spark_node)

	var light = OmniLight3D.new()
	light.light_color = Color(0.3, 0.85, 1.0)
	light.light_energy = 2.2
	light.omni_range = 3.5
	spark_node.add_child(light)

	var spark_mat = StandardMaterial3D.new()
	spark_mat.albedo_color = Color(0.4, 0.9, 1.0)
	spark_mat.emission_enabled = true
	spark_mat.emission = Color(0.5, 0.95, 1.0)
	spark_mat.emission_energy_multiplier = 3.5

	var sparks: Array[MeshInstance3D] = []
	for i in range(8):
		var sp = MeshInstance3D.new()
		var cyl = CylinderMesh.new()
		cyl.top_radius = 0.007
		cyl.bottom_radius = 0.007
		cyl.height = 0.20
		sp.mesh = cyl
		sp.material_override = spark_mat
		spark_node.add_child(sp)
		sparks.append(sp)

	var tw = create_tween()
	tw.tween_method(func(t: float):
		if not is_instance_valid(spark_node): return
		light.light_energy = randf_range(1.2, 2.6)
		for sp in sparks:
			if is_instance_valid(sp):
				sp.position = Vector3(randf_range(-0.5, 0.5), randf_range(-0.3, 0.3), randf_range(-0.5, 0.5))
				sp.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	, 0.0, duration, duration)
	tw.tween_callback(spark_node.queue_free)

func _enter_stun(duration: float) -> void:
	state = "STUNNED"
	stun_timer = duration
	current_target = null
	SoundEffects.play_hunter_screech()

func _update_tongue_visuals(delta: float) -> void:
	if tongue_segments.is_empty():
		return

	var tip_world: Vector3
	if (state == "SNARE_PULL" or state == "HOLD_TARGET") and is_instance_valid(current_target):
		tip_world = current_target.global_position + Vector3(0, 1.2, 0)
	else:
		# Idle pendulous sway
		var sway_x = sin(anim_time * 2.2) * 0.18
		var sway_z = cos(anim_time * 1.8) * 0.18
		tip_world = global_position + Vector3(sway_x, -1.8, sway_z)

	var start_world = global_position + Vector3(0, -1.45, 0)
	var diff = tip_world - start_world
	var total_len = diff.length()
	var seg_count = tongue_segments.size()
	var step_len = total_len / float(seg_count)

	for i in range(seg_count):
		var seg = tongue_segments[i]
		var frac = float(i) / float(seg_count)
		var p_local = diff * frac
		seg.position = p_local + Vector3(0, -1.45, 0)
		if diff.length_squared() > 0.01:
			seg.rotation.x = atan2(diff.z, -diff.y)
			seg.rotation.z = -atan2(diff.x, -diff.y)
		seg.scale = Vector3(1.0, step_len / 0.42, 1.0)
