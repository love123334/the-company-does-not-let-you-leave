extends CharacterBody3D

const VisualMaterialFactory = preload("res://scripts/visual_material_factory.gd")

@export var move_speed: float = 3.1
@export var kill_distance: float = 2.15
@export var is_active: bool = false
var active: bool = false
var is_dead: bool = false
var latched: bool = false
var is_being_executed: bool = false
var exec_timer: float = 0.0
var exec_crushed: bool = false

var player: Node3D = null
var hunter: Node3D = null
var in_cage: bool = true
var home_pos: Vector3 = Vector3.ZERO
var cage_bars_node: Node3D = null
var dev_frozen: bool = false
var is_afraid: bool = false
var stun_timer: float = 0.0
var attack_cooldown: float = 0.0

# Surface crawling state ("floor", "wall", "ceil")
var surf: String = "floor"
var surf_timer: float = 3.0
var wall_side: float = 1.0
var roam_dir: Vector3 = Vector3.FORWARD
var roam_timer: float = 0.0
var sound_timer: float = 2.0
var is_snared_by_hanger: bool = false
var hanger_snare_timer: float = 0.0
var locker_banging_target: Node3D = null
var locker_knock_count: int = 0
var locker_knock_timer: float = 0.0

# Bait tracking
var bait_pos: Vector3 = Vector3.ZERO
var bait_active: bool = false

# Mesh & procedural animation nodes
var _mesh_root: Node3D = null
var _leg_hips: Array = []
var _mandibles: Array[Node3D] = []
var _body_mesh: MeshInstance3D = null
var _ab_mesh: MeshInstance3D = null
var _anim_t: float = 0.0

signal player_bitten(crawler_node)
signal devoured_by_hunter(world_pos)
signal fought_cultist(world_pos)

func _ready() -> void:
	add_to_group("crawlers")
	add_to_group("hunt_entities")
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	collision_layer = 4
	collision_mask = 1 | 8
	_build_crawler_mesh()
	_anim_t = randf() * 10.0
	sound_timer = randf_range(3.0, 8.0)

func setup_caged(caged_pos: Vector3, release_pos: Vector3, bars_node: Node3D = null, p_rot: float = 0.0) -> void:
	global_position = caged_pos
	rotation.y = p_rot
	home_pos = release_pos
	cage_bars_node = bars_node
	in_cage = true
	is_active = false
	active = false
	visible = true

func activate() -> void:
	if is_dead:
		return
	in_cage = false
	is_active = true
	active = true
	visible = true
	if cage_bars_node and is_instance_valid(cage_bars_node):
		var tw = create_tween()
		tw.tween_property(cage_bars_node, "position:y", 3.6, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if home_pos != Vector3.ZERO:
		global_position = Vector3(home_pos.x, 0.05, home_pos.z)
	surf = "floor"
	surf_timer = randf_range(2.5, 5.5)

func set_freeze(frozen: bool) -> void:
	dev_frozen = frozen

func set_bait(pos: Vector3, p_active: bool = true) -> void:
	bait_pos = pos
	bait_active = p_active

func clear_bait() -> void:
	bait_active = false

func hit_by_mop() -> bool:
	if is_dead or not active or latched or is_being_executed:
		return false
	is_dead = true
	active = false
	is_active = false
	SoundEffects.play(SoundEffects.snd_screech, -1.0, 1.45)
	SoundEffects.play_Wet_Squish()
	if _mesh_root:
		_mesh_root.position = Vector3.ZERO
		_mesh_root.rotation = Vector3.ZERO
	var tw = create_tween()
	tw.tween_property(self, "scale", Vector3(1.55, 0.16, 1.55), 0.14).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(0.9)
	tw.tween_callback(queue_free)
	return true

func stun(duration: float) -> void:
	if is_dead or latched:
		return

	if player and (player.get("is_dead") == true or player.get("in_death_sequence") == true):
		velocity = Vector3.ZERO
		return
	stun_timer = max(stun_timer, duration)
	velocity = Vector3.ZERO
	_spawn_electric_sparks(duration)
	SoundEffects.play(SoundEffects.snd_screech, -2.0, 1.6)

func _spawn_electric_sparks(duration: float) -> void:
	var spark_node = Node3D.new()
	spark_node.name = "StunSparks"
	spark_node.position = Vector3(0, 0.35, 0)
	add_child(spark_node)

	var light = OmniLight3D.new()
	light.light_color = Color(0.3, 0.85, 1.0)
	light.light_energy = 1.8
	light.omni_range = 2.5
	spark_node.add_child(light)

	var spark_mat = StandardMaterial3D.new()
	spark_mat.albedo_color = Color(0.4, 0.9, 1.0)
	spark_mat.emission_enabled = true
	spark_mat.emission = Color(0.5, 0.95, 1.0)
	spark_mat.emission_energy_multiplier = 3.0

	var sparks: Array[MeshInstance3D] = []
	for i in range(6):
		var sp = MeshInstance3D.new()
		var cyl = CylinderMesh.new()
		cyl.top_radius = 0.006
		cyl.bottom_radius = 0.006
		cyl.height = 0.14
		sp.mesh = cyl
		sp.material_override = spark_mat
		spark_node.add_child(sp)
		sparks.append(sp)

	var tw = create_tween()
	tw.tween_method(func(t: float):
		if not is_instance_valid(spark_node): return
		light.light_energy = randf_range(1.0, 2.0)
		for sp in sparks:
			if is_instance_valid(sp):
				sp.position = Vector3(randf_range(-0.3, 0.3), randf_range(-0.2, 0.3), randf_range(-0.3, 0.3))
				sp.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	, 0.0, duration, duration)
	tw.tween_callback(spark_node.queue_free)

func start_execution_by_hunter(hunter_node: Node3D) -> void:
	if is_dead or is_being_executed:
		return
	is_being_executed = true
	exec_timer = 0.0
	exec_crushed = false
	surf = "floor"
	velocity = Vector3.ZERO
	if _mesh_root:
		_mesh_root.position = Vector3.ZERO
		_mesh_root.rotation = Vector3.ZERO
	if is_instance_valid(hunter_node):
		var h_fwd = -hunter_node.global_transform.basis.z
		h_fwd.y = 0.0
		if h_fwd.length_squared() < 0.01:
			h_fwd = Vector3.FORWARD
		else:
			h_fwd = h_fwd.normalized()
		global_position = Vector3(
			hunter_node.global_position.x + h_fwd.x * 1.15,
			0.05,
			hunter_node.global_position.z + h_fwd.z * 1.15
		)
	SoundEffects.play(SoundEffects.snd_screech, 0.0, 1.5)

func _spawn_floor_blood() -> void:
	if not is_inside_tree() or get_parent() == null:
		return
	var splat = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.65
	cyl.bottom_radius = 0.68
	cyl.height = 0.014
	splat.mesh = cyl
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.38, 0.01, 0.03, 0.92)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.2
	splat.material_override = mat
	splat.position = Vector3(global_position.x, 0.02, global_position.z)
	get_parent().add_child(splat)

func on_repelled_by_cloak(cloak_pos: Vector3) -> void:
	var away = global_position - cloak_pos
	away.y = 0.0
	if away.length_squared() > 0.01:
		roam_dir = away.normalized()
		roam_timer = 2.5

func _physics_process(delta: float) -> void:
	_anim_t += delta
	_animate_crawler(_anim_t, delta)

	if is_being_executed:
		exec_timer += delta
		velocity = Vector3.ZERO
		if exec_timer < 0.52:
			_anim_t += delta * 5.0
			if _mesh_root:
				_mesh_root.rotation.z = sin(exec_timer * 48.0) * 0.28
				_mesh_root.position.y = abs(sin(exec_timer * 24.0)) * 0.08
		else:
			if not exec_crushed:
				exec_crushed = true
				SoundEffects.play(SoundEffects.snd_stone, 2.5, 0.85)
				SoundEffects.play_Wet_Squish()
				_spawn_floor_blood()
				if _mesh_root:
					_mesh_root.rotation = Vector3.ZERO
					_mesh_root.position = Vector3.ZERO
				scale = Vector3(1.85, 0.12, 1.85)
		if exec_timer >= 1.45:
			is_dead = true
			active = false
			is_active = false
			devoured_by_hunter.emit(global_position)
			queue_free()
		return

	if is_dead or latched:
		return

	if player and (player.get("is_dead") == true or player.get("in_death_sequence") == true):
		velocity = Vector3.ZERO
		return

	if attack_cooldown > 0.0:
		attack_cooldown -= delta

	# Ambient cage sounds during work shift
	if in_cage or not is_active:
		if player and is_instance_valid(player):
			sound_timer -= delta
			if sound_timer <= 0.0:
				sound_timer = randf_range(5.0, 10.0)
				var d_work = global_position.distance_to(player.global_position)
				if d_work < 16.0:
					var vol = lerp(-4.0, -18.0, d_work / 16.0)
					SoundEffects.play(SoundEffects.snd_growl, vol, randf_range(1.25, 1.5))
		return

	if dev_frozen:
		velocity = Vector3.ZERO
		return

	if stun_timer > 0.0:
		stun_timer -= delta
		is_afraid = false
		velocity = Vector3.ZERO
		return

	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return

	if hunter == null or not is_instance_valid(hunter):
		hunter = get_tree().get_first_node_in_group("hunter")

	if is_snared_by_hanger:
		hanger_snare_timer -= delta
		velocity = Vector3.ZERO
		if hanger_snare_timer <= 0.0:
			release_from_hanger()
		return

	# Check if caught and executed by the Hunter
	if hunter and is_instance_valid(hunter) and hunter.get("active"):
		var dist_to_hunter = Vector2(global_position.x - hunter.global_position.x, global_position.z - hunter.global_position.z).length()
		if dist_to_hunter < 1.85:
			if hunter.has_method("start_prey_execution"):
				if hunter.start_prey_execution(self, "crawler"):
					return

	var player_in_locker: bool = (player.get("is_hiding") == true)
	var player_hiding: bool = player_in_locker or (player.get("is_inside_cloak") == true)
	var p_floor: int = player.get("current_floor") if "current_floor" in player else 1
	var dist_to_player = Vector2(global_position.x - player.global_position.x, global_position.z - player.global_position.z).length()

	if player_in_locker and locker_banging_target == null and locker_knock_count == 0:
		var l_dist = global_position.distance_to(player.global_position)
		if l_dist < 12.0:
			locker_banging_target = player.get("current_locker")
			locker_knock_count = 3
			locker_knock_timer = 0.0

	var afraid_of_hunter: bool = false
	if hunter and is_instance_valid(hunter) and hunter.get("active"):
		var dh_fear = Vector2(global_position.x - hunter.global_position.x, global_position.z - hunter.global_position.z).length()
		if dh_fear < 13.5:
			afraid_of_hunter = true

	# Attack Player if already within strike distance (unless fleeing in terror from Hunter!)
	if not afraid_of_hunter and not player_hiding and player.get("in_bite_sequence") != true and player.get("in_death_sequence") != true and player.get("is_dead") != true and p_floor == 1 and dist_to_player <= kill_distance and attack_cooldown <= 0.0:
		if player.has_method("is_baton_defending") and player.is_baton_defending():
			if player.is_baton_parrying():
				stun(3.0)
				attack_cooldown = 3.5
				player.on_successful_parry(self)
				var hud_node = get_tree().root.find_child("HUD", true, false)
				if hud_node and hud_node.has_method("show_toast"):
					hud_node.show_toast("⚡ PERFECT PARRY! CRAWLER DEFLECTED & STUNNED (3.0s)!", Color(0.2, 1.0, 0.5))
				return
			elif player.is_baton_blocking():
				player.on_successful_block(self)
				attack_cooldown = 2.0
				return

		attack_cooldown = 2.5
		surf = "floor"
		if _mesh_root:
			_mesh_root.position = Vector3.ZERO
			_mesh_root.rotation = Vector3.ZERO
		player_bitten.emit(self)
		return

	# Pause pursuit while player is inside the Night 5 Secret Sanctuary Corridor
	if player.get("in_secret_corridor") == true:
		velocity = Vector3.ZERO
		return

	# =========================================================================
	# INDEPENDENT REAL-TIME PURSUIT RULE (Master Spec Section 4.1 & 4.2):
	# Unlike the main Hunter, Crawlers DO NOT freeze when the player stands still!
	# They continue hunting in real time so standing still is never completely safe.
	# =========================================================================
	var target_pos: Vector3 = player.global_position
	var mode: String = "player"

	# Crawlers strictly stay on Floor 1 (no crawlers on Floor 2!)
	if p_floor > 1 or player.global_position.y > 2.0:
		mode = "roam"

	# 1. Flee from Hunter if within 13m
	if hunter and is_instance_valid(hunter) and hunter.get("active"):
		var dh = Vector2(global_position.x - hunter.global_position.x, global_position.z - hunter.global_position.z).length()
		if dh < 13.0:
			mode = "flee"
			target_pos = hunter.global_position

	# 2. Lured by Bait if active
	if mode == "player" and bait_active:
		mode = "bait"
		target_pos = bait_pos

	# 3. Fight nearby Cultists
	var foe_cultist: Node3D = null
	if mode == "player":
		var best_cd: float = 8.5
		for c in get_tree().get_nodes_in_group("cultists"):
			if is_instance_valid(c) and c.get("active"):
				var cd = global_position.distance_to(c.global_position)
				if cd < best_cd:
					best_cd = cd
					foe_cultist = c
		if foe_cultist != null:
			mode = "fight"
			target_pos = foe_cultist.global_position

	# 4. If player is hiding in a locker, roam instead of camping locker
	if mode == "player" and player_hiding:
		mode = "roam"

	is_afraid = (mode == "flee")

	var move_dir: Vector3 = Vector3.ZERO

	# 0. Locker investigation: scuttle to locker, scratch 3 times, then roam away
	if is_instance_valid(locker_banging_target) and locker_knock_count > 0:
		var fwd_l = locker_banging_target.global_transform.basis.z
		var front_pos = locker_banging_target.global_position + fwd_l * 1.05
		front_pos.y = global_position.y
		var to_front = front_pos - global_position
		to_front.y = 0.0
		if to_front.length() > 0.35:
			move_dir = to_front.normalized()
		else:
			move_dir = Vector3.ZERO
			locker_knock_timer += delta
			if locker_knock_timer >= 0.55:
				locker_knock_timer = 0.0
				locker_knock_count -= 1
				SoundEffects.play(SoundEffects.snd_click, 3.2, 0.48)
				if locker_knock_count <= 0:
					locker_banging_target = null
					mode = "roam"
	elif mode == "roam":
		roam_timer -= delta
		if roam_timer <= 0.0 or is_on_wall():
			roam_timer = randf_range(2.0, 4.5)
			var ang = randf() * TAU
			roam_dir = Vector3(cos(ang), 0.0, sin(ang))
		move_dir = roam_dir
	elif mode == "player":
		# If close to player (< 4.2m), charge directly at player without stopping at cell centers!
		if dist_to_player <= 4.2:
			var to_p = Vector3(player.global_position.x - global_position.x, 0.0, player.global_position.z - global_position.z)
			if to_p.length() > 0.05:
				move_dir = to_p.normalized()
		elif hunter and is_instance_valid(hunter) and hunter.has_method("_get_player_bfs_field"):
			# Follow BFS shortest path around maze corners toward player!
			var d: PackedInt32Array = hunter._get_player_bfs_field(true)
			var S: int = int(hunter.get("_bfs_grid_size"))
			var nb: Array = hunter._bfs_next_cell(global_position, d, S)
			if not nb.is_empty():
				var wx = float(nb[1]) * GameData.UNIT
				var wz = float(nb[0]) * GameData.UNIT
				var to_wp = Vector3(wx - global_position.x, 0.0, wz - global_position.z)
				if to_wp.length() > 0.05:
					move_dir = to_wp.normalized()
			else:
				# Gate blocks BFS path: do not charge into closed gate
				move_dir = Vector3.ZERO
			if move_dir == Vector3.ZERO:
				var to_p = Vector3(target_pos.x - global_position.x, 0.0, target_pos.z - global_position.z)
				if to_p.length() > 0.05 and not nb.is_empty():
					move_dir = to_p.normalized()
	else:
		var to_target = Vector3(target_pos.x - global_position.x, 0.0, target_pos.z - global_position.z)
		if to_target.length() > 0.05:
			move_dir = to_target.normalized()
			if mode == "flee":
				move_dir = -move_dir

	var cur_spd: float = move_speed * (1.45 if mode == "flee" else 1.0)
	velocity.x = move_dir.x * cur_spd
	velocity.z = move_dir.z * cur_spd
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = 0.0

	if move_dir.length_squared() > 0.01:
		var look_pt = global_position - move_dir
		look_at(Vector3(look_pt.x, global_position.y, look_pt.z), Vector3.UP)

	move_and_slide()

	if is_on_wall() and move_dir.length_squared() > 0.01:
		var slide_dir = Vector3(-move_dir.z, 0.0, move_dir.x) * wall_side
		velocity.x = slide_dir.x * cur_spd
		velocity.z = slide_dir.z * cur_spd
		move_and_slide()
		if is_on_wall():
			wall_side = -wall_side

	# Update surface crawling (floor / wall / ceiling) visual offset on _mesh_root
	surf_timer -= delta
	if surf_timer <= 0.0:
		surf_timer = randf_range(2.5, 5.0)
		if mode == "flee" or dist_to_player > 5.5:
			var choices = ["floor", "wall", "ceil", "floor", "ceil"]
			surf = choices[randi() % choices.size()]
			wall_side = 1.0 if randf() < 0.5 else -1.0
		else:
			surf = "floor"
	if dist_to_player < 2.8 and mode == "player":
		surf = "floor"

	# Periodic skitter / growl sound
	sound_timer -= delta
	if sound_timer <= 0.0 and dist_to_player < 22.0:
		sound_timer = randf_range(3.2, 6.8)
		var vol = lerp(-2.0, -16.0, dist_to_player / 22.0)
		SoundEffects.play(SoundEffects.snd_growl, vol, randf_range(1.35, 1.65))

	# Attack Cultist if fighting
	if mode == "fight" and foe_cultist and is_instance_valid(foe_cultist):
		var d_foe = Vector2(global_position.x - foe_cultist.global_position.x, global_position.z - foe_cultist.global_position.z).length()
		if d_foe <= 1.55 and attack_cooldown <= 0.0:
			attack_cooldown = 1.2
			fought_cultist.emit(global_position)
			if foe_cultist.has_method("take_crawler_attack"):
				foe_cultist.take_crawler_attack()

func _build_crawler_mesh() -> void:
	_mesh_root = Node3D.new()
	_mesh_root.name = "CrawlerMeshRoot"
	add_child(_mesh_root)

	var sk_mat = VisualMaterialFactory.create_chitin_material(Color(0.18, 0.22, 0.24), 0.35, 0.22)
	var meat_mat = VisualMaterialFactory.create_flesh_material(Color(0.48, 0.05, 0.08), true)
	var dark_mat = VisualMaterialFactory.create_chitin_material(Color(0.04, 0.02, 0.03), 0.45, 0.15)
	var bone_mat = VisualMaterialFactory.create_bone_material(Color(0.82, 0.78, 0.70))

	var eye_mat = StandardMaterial3D.new()
	eye_mat.albedo_color = Color(1.0, 0.72, 0.22)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(1.0, 0.45, 0.10)
	eye_mat.emission_energy_multiplier = 3.2

	# Deformed Cephalothorax
	var body_node = MeshInstance3D.new()
	var body_sph = SphereMesh.new()
	body_sph.radius = 0.40
	body_sph.height = 0.80
	body_node.mesh = body_sph
	body_node.scale = Vector3(1.22, 0.72, 1.12)
	body_node.position.y = 0.48
	body_node.material_override = sk_mat
	_mesh_root.add_child(body_node)
	_body_mesh = body_node

	# 6 Asymmetric Fleshy Blisters / Tumors on Carapace
	var lump_offsets = [
		Vector3(-0.22, 0.68, 0.08),
		Vector3(0.24, 0.65, -0.05),
		Vector3(-0.14, 0.72, -0.22),
		Vector3(0.16, 0.70, 0.18),
		Vector3(0.0, 0.74, -0.08),
		Vector3(-0.28, 0.56, -0.14)
	]
	for lo in lump_offsets:
		var lump = MeshInstance3D.new()
		var ls = SphereMesh.new()
		ls.radius = 0.095
		ls.height = 0.19
		lump.mesh = ls
		lump.scale = Vector3(1.2, 0.7, 1.1)
		lump.position = lo
		lump.material_override = meat_mat
		_mesh_root.add_child(lump)

	# Glistening Blood-Sack Abdomen
	var ab_node = MeshInstance3D.new()
	var ab_sph = SphereMesh.new()
	ab_sph.radius = 0.32
	ab_sph.height = 0.64
	ab_node.mesh = ab_sph
	ab_node.scale = Vector3(1.05, 0.82, 1.45)
	ab_node.position = Vector3(0, 0.42, -0.42)
	ab_node.material_override = meat_mat
	_mesh_root.add_child(ab_node)
	_ab_mesh = ab_node

	# Gaping Circular Maw + 8 Inner Fang Teeth + 2 Snapping Mandibles
	var maw = MeshInstance3D.new()
	var maw_sph = SphereMesh.new()
	maw_sph.radius = 0.16
	maw_sph.height = 0.32
	maw.mesh = maw_sph
	maw.scale = Vector3(1.1, 0.85, 0.5)
	maw.position = Vector3(0, 0.38, 0.42)
	maw.material_override = dark_mat
	_mesh_root.add_child(maw)

	for f in range(8):
		var fa = (float(f) / 8.0) * TAU
		var fang = MeshInstance3D.new()
		var fc = CylinderMesh.new()
		fc.top_radius = 0.0
		fc.bottom_radius = 0.015
		fc.height = 0.11
		fang.mesh = fc
		fang.position = Vector3(cos(fa) * 0.12, 0.38 + sin(fa) * 0.09, 0.46)
		fang.rotation = Vector3(PI * 0.58, 0, -fa)
		fang.material_override = bone_mat
		_mesh_root.add_child(fang)

	for s in [-1.0, 1.0]:
		var md_piv = Node3D.new()
		md_piv.position = Vector3(s * 0.15, 0.35, 0.42)
		_mesh_root.add_child(md_piv)

		var md = MeshInstance3D.new()
		var mdc = CylinderMesh.new()
		mdc.top_radius = 0.002
		mdc.bottom_radius = 0.055
		mdc.height = 0.42
		md.mesh = mdc
		md.position = Vector3(-s * 0.03, 0.0, 0.16)
		md.rotation = Vector3(PI / 2.0 + 0.18, 0, s * 0.38)
		md.material_override = bone_mat
		md_piv.add_child(md)
		_mandibles.append(md_piv)

	# 6 Asymmetric Glowing Eyes in Black Sockets
	var eye_data = [
		[-0.20, 0.62, 0.34, 0.052],
		[-0.07, 0.66, 0.38, 0.038],
		[0.07, 0.66, 0.38, 0.038],
		[0.20, 0.62, 0.34, 0.052],
		[-0.13, 0.50, 0.45, 0.028],
		[0.13, 0.50, 0.45, 0.028]
	]
	for ed in eye_data:
		var sock = MeshInstance3D.new()
		var ss = SphereMesh.new()
		ss.radius = ed[3] * 1.35
		ss.height = ed[3] * 2.7
		sock.mesh = ss
		sock.position = Vector3(ed[0], ed[1], ed[2] - 0.015)
		sock.material_override = dark_mat
		_mesh_root.add_child(sock)

		var e = MeshInstance3D.new()
		var es = SphereMesh.new()
		es.radius = ed[3]
		es.height = ed[3] * 2.0
		e.mesh = es
		e.position = Vector3(ed[0], ed[1], ed[2])
		e.material_override = eye_mat
		_mesh_root.add_child(e)

	# 6 Multi-Jointed Spider Legs (Hip -> Upper -> Knee -> Lower -> Claw Tip)
	for k in range(3):
		for s in [-1.0, 1.0]:
			var hip = Node3D.new()
			hip.position = Vector3(s * 0.32, 0.50, 0.30 - float(k) * 0.30)
			hip.rotation.z = s * 1.02

			var upper = MeshInstance3D.new()
			var uc = CylinderMesh.new()
			uc.top_radius = 0.032
			uc.bottom_radius = 0.052
			uc.height = 0.56
			upper.mesh = uc
			upper.position.y = -0.275
			upper.material_override = sk_mat
			hip.add_child(upper)

			var knee = Node3D.new()
			knee.position.y = -0.55
			knee.rotation.z = -s * 1.62
			var lower = MeshInstance3D.new()
			var lc = CylinderMesh.new()
			lc.top_radius = 0.012
			lc.bottom_radius = 0.034
			lc.height = 0.58
			lower.mesh = lc
			lower.position.y = -0.285
			lower.material_override = sk_mat
			knee.add_child(lower)

			var claw = MeshInstance3D.new()
			var cc = CylinderMesh.new()
			cc.top_radius = 0.0
			cc.bottom_radius = 0.018
			cc.height = 0.18
			claw.mesh = cc
			claw.position.y = -0.62
			claw.rotation.x = PI
			claw.material_override = bone_mat
			knee.add_child(claw)

			hip.add_child(knee)
			_mesh_root.add_child(hip)
			_leg_hips.append({"node": hip, "k": k, "s": s})

	# 6 Dorsal Bone Spines
	for i in range(6):
		var sp = MeshInstance3D.new()
		var spc = CylinderMesh.new()
		spc.top_radius = 0.002
		spc.bottom_radius = 0.042
		spc.height = 0.26 + float(i % 2) * 0.08
		sp.mesh = spc
		sp.position = Vector3((float(i) - 2.5) * 0.09, 0.78, -0.05 - float(i) * 0.08)
		sp.rotation.x = -0.45
		sp.material_override = bone_mat
		_mesh_root.add_child(sp)

	var eye_glow = OmniLight3D.new()
	eye_glow.light_color = Color(1.0, 0.65, 0.18)
	eye_glow.light_energy = 1.05
	eye_glow.omni_range = 3.5
	eye_glow.position = Vector3(0, 0.55, 0.45)
	_mesh_root.add_child(eye_glow)

func _animate_crawler(t: float, delta: float) -> void:
	var is_moving = velocity.length_squared() > 0.05 or latched
	var spd = 22.0 if latched else (16.0 if is_afraid else (11.0 if is_moving else 3.2))
	for entry in _leg_hips:
		var h: Node3D = entry["node"]
		var k: int = entry["k"]
		var s: float = entry["s"]
		var phase = float(k) * 1.6 + (PI if s > 0.0 else 0.0)
		h.rotation.x = sin(t * spd + phase) * (0.48 if is_moving else 0.10)

	for i in range(_mandibles.size()):
		var md = _mandibles[i]
		var s = -1.0 if i == 0 else 1.0
		md.rotation.y = s * (0.15 + abs(sin(t * (14.0 if latched else 6.5))) * 0.35)

	if _body_mesh:
		_body_mesh.scale.y = 0.72 + 0.05 * sin(t * 6.5)
	if _ab_mesh:
		_ab_mesh.rotation.x = 0.12 * sin(t * 3.5)

	if _mesh_root and is_active and not latched:
		var target_y: float = 0.0
		var target_rot_z: float = 0.0
		var target_x: float = 0.0
		if surf == "ceil":
			target_y = 3.5
			target_rot_z = PI
		elif surf == "wall":
			target_y = 1.45
			target_rot_z = wall_side * (PI / 2.0)
			target_x = -wall_side * 0.85
		_mesh_root.position.y = lerp(_mesh_root.position.y, target_y, min(1.0, delta * 6.0))
		_mesh_root.position.x = lerp(_mesh_root.position.x, target_x, min(1.0, delta * 6.0))
		_mesh_root.rotation.z = lerp_angle(_mesh_root.rotation.z, target_rot_z, min(1.0, delta * 6.0))

func freeze_by_hanger(duration: float = 3.5) -> void:
	is_snared_by_hanger = true
	hanger_snare_timer = duration
	velocity = Vector3.ZERO

func release_from_hanger() -> void:
	is_snared_by_hanger = false
	hanger_snare_timer = 0.0
	stun_timer = 2.5
