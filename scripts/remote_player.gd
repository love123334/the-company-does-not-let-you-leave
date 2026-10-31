extends CharacterBody3D

var peer_id: int = 0
var player_name: String = "Janitor"
var target_pos: Vector3 = Vector3.ZERO
var target_rot_y: float = 0.0
var target_cam_x: float = 0.0
var is_moving: bool = false
var is_sprinting: bool = false
var is_dead: bool = false

var name_tag: Label3D = null
var flashlight_spot: SpotLight3D = null
var mesh_root: Node3D = null

# Articulated humanoid skeleton nodes
var pelvis_node: Node3D = null
var spine_node: Node3D = null
var head_node: Node3D = null
var shoulder_left: Node3D = null
var forearm_left: Node3D = null
var shoulder_right: Node3D = null
var forearm_right: Node3D = null
var hip_left: Node3D = null
var knee_left: Node3D = null
var hip_right: Node3D = null
var knee_right: Node3D = null

var weapon_mount: Node3D = null
var held_weapon_mesh: MeshInstance3D = null
var current_weapon_type: int = 0 # 0=Mop, 1=Taser, 2=Baton
var is_defending: bool = false

var walk_cycle: float = 0.0
var idle_time: float = 0.0
var action_anim_timer: float = 0.0
var current_action: String = ""

func _ready() -> void:
	add_to_group("remote_players")
	collision_layer = 2 # Player layer
	collision_mask = 1  # Environment only
	_build_humanoid_visuals()

func setup_peer(id: int, p_name: String, start_pos: Vector3) -> void:
	peer_id = id
	player_name = p_name
	global_position = start_pos
	target_pos = start_pos
	if name_tag:
		name_tag.text = player_name + "\n$0"

func update_state(state: Dictionary) -> void:
	if is_dead:
		return
	var new_pos = state.get("pos", target_pos)
	if target_pos == Vector3.ZERO or global_position.distance_squared_to(new_pos) > 36.0:
		global_position = new_pos
	target_pos = new_pos
	target_rot_y = state.get("rot_y", target_rot_y)
	target_cam_x = state.get("cam_x", target_cam_x)
	is_moving = state.get("moving", false)
	is_sprinting = state.get("sprint", false)
	var flash_on = state.get("flash", true)
	if flashlight_spot:
		flashlight_spot.visible = flash_on
	var w_type = state.get("weapon", 0)
	if w_type != current_weapon_type:
		current_weapon_type = w_type
		_update_weapon_visual()
	is_defending = state.get("guard", false)

func update_wages_display(wages: int) -> void:
	if name_tag:
		name_tag.text = player_name + "\n$" + str(wages)

func mark_peer_dead() -> void:
	is_dead = true
	visible = false
	collision_layer = 0
	collision_mask = 0

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	var dist_to_target = global_position.distance_to(target_pos)
	if dist_to_target > 6.0:
		global_position = target_pos
	else:
		global_position = global_position.lerp(target_pos, min(1.0, delta * 18.0))
	rotation.y = lerp_angle(rotation.y, target_rot_y, min(1.0, delta * 18.0))

	# Humanoid Procedural Animation
	var is_anim_moving = is_moving or (dist_to_target > 0.05)
	if is_anim_moving:
		var speed_mult = 13.5 if is_sprinting else 8.5
		walk_cycle += delta * speed_mult
		
		# Legs swing opposite each other
		if hip_left and hip_right and knee_left and knee_right:
			var swing = sin(walk_cycle) * 0.52
			hip_left.rotation.x = swing
			knee_left.rotation.x = max(0.0, -swing * 0.7)
			hip_right.rotation.x = -swing
			knee_right.rotation.x = max(0.0, swing * 0.7)
		
		# Left arm swings opposite left leg (natural counter-balance)
		if shoulder_left:
			shoulder_left.rotation.x = -sin(walk_cycle) * 0.32
		
		# Subtle vertical torso bob
		if pelvis_node:
			pelvis_node.position.y = 0.82 + abs(sin(walk_cycle * 2.0)) * 0.04
	else:
		# Return legs smoothly to standing stance
		if hip_left and hip_right and knee_left and knee_right:
			hip_left.rotation.x = lerp_angle(hip_left.rotation.x, 0.0, delta * 9.0)
			knee_left.rotation.x = lerp_angle(knee_left.rotation.x, 0.0, delta * 9.0)
			hip_right.rotation.x = lerp_angle(hip_right.rotation.x, 0.0, delta * 9.0)
			knee_right.rotation.x = lerp_angle(knee_right.rotation.x, 0.0, delta * 9.0)
		
		# Subtle idle breathing motion
		idle_time += delta * 2.4
		if pelvis_node:
			pelvis_node.position.y = 0.82 + sin(idle_time) * 0.012

	# Upper body pitch tilts with where player is looking (looking up at ceiling / down at floor)
	if spine_node and head_node:
		spine_node.rotation.x = lerp_angle(spine_node.rotation.x, target_cam_x * 0.65, delta * 12.0)
		head_node.rotation.x = lerp_angle(head_node.rotation.x, target_cam_x * 0.35, delta * 12.0)

	# Right arm tool / weapon stance & actions
	if shoulder_right:
		if action_anim_timer > 0.0:
			action_anim_timer -= delta
			if current_action == "mop_swing":
				var prog = 1.0 - (action_anim_timer / 0.35)
				shoulder_right.rotation.x = lerp_angle(shoulder_right.rotation.x, deg_to_rad(-65.0 + sin(prog * PI) * 55.0), delta * 20.0)
				shoulder_right.rotation.z = deg_to_rad(-15.0)
		elif is_defending:
			# Raised defensive blocking guard
			shoulder_right.rotation.x = lerp_angle(shoulder_right.rotation.x, deg_to_rad(-55.0), delta * 12.0)
			shoulder_right.rotation.y = lerp_angle(shoulder_right.rotation.y, deg_to_rad(-40.0), delta * 12.0)
			shoulder_right.rotation.z = lerp_angle(shoulder_right.rotation.z, deg_to_rad(30.0), delta * 12.0)
		else:
			# Relaxed standard tool carrying stance
			shoulder_right.rotation.x = lerp_angle(shoulder_right.rotation.x, deg_to_rad(-25.0) + target_cam_x * 0.4, delta * 10.0)
			shoulder_right.rotation.y = lerp_angle(shoulder_right.rotation.y, 0.0, delta * 10.0)
			shoulder_right.rotation.z = lerp_angle(shoulder_right.rotation.z, deg_to_rad(-12.0), delta * 10.0)

func play_action_animation(action: String, _data: Dictionary = {}) -> void:
	current_action = action
	action_anim_timer = 0.35
	if action == "parry":
		SoundEffects.play(SoundEffects.snd_parry, 2.5)

func _build_humanoid_visuals() -> void:
	mesh_root = Node3D.new()
	mesh_root.name = "HumanoidJanitor"
	add_child(mesh_root)

	# --- UNIFORM MATERIALS ---
	var navy_suit_mat = StandardMaterial3D.new()
	navy_suit_mat.albedo_color = Color(0.12, 0.20, 0.36) # Facility Janitor Navy Blue
	navy_suit_mat.roughness = 0.85

	var vest_mat = StandardMaterial3D.new()
	vest_mat.albedo_color = Color(0.95, 0.82, 0.10) # Bright safety hazard neon
	vest_mat.emission_enabled = true
	vest_mat.emission = Color(0.95, 0.82, 0.10)
	vest_mat.emission_energy_multiplier = 0.4

	var skin_mat = StandardMaterial3D.new()
	skin_mat.albedo_color = Color(0.86, 0.71, 0.58)

	var glove_mat = StandardMaterial3D.new()
	glove_mat.albedo_color = Color(0.92, 0.78, 0.14) # Heavy-duty yellow rubber chemical gloves
	glove_mat.roughness = 0.45

	var boot_mat = StandardMaterial3D.new()
	boot_mat.albedo_color = Color(0.11, 0.11, 0.13) # Steel-toe work boots
	boot_mat.roughness = 0.7

	var metal_mat = StandardMaterial3D.new()
	metal_mat.albedo_color = Color(0.65, 0.68, 0.72)
	metal_mat.metallic = 0.8
	metal_mat.roughness = 0.35

	# 1. PELVIS ROOT (Waist level ~0.82m)
	pelvis_node = Node3D.new()
	pelvis_node.position.y = 0.82
	mesh_root.add_child(pelvis_node)

	# Pelvis / Hips mesh
	var pelvis_mesh = MeshInstance3D.new()
	var p_box = BoxMesh.new()
	p_box.size = Vector3(0.38, 0.18, 0.24)
	pelvis_mesh.mesh = p_box
	pelvis_mesh.material_override = navy_suit_mat
	pelvis_node.add_child(pelvis_mesh)

	# Heavy Utility Belt
	var belt = MeshInstance3D.new()
	var b_box = BoxMesh.new()
	b_box.size = Vector3(0.40, 0.07, 0.26)
	belt.mesh = b_box
	belt.position.y = 0.06
	var belt_mat = StandardMaterial3D.new()
	belt_mat.albedo_color = Color(0.18, 0.15, 0.12)
	belt.material_override = belt_mat
	pelvis_node.add_child(belt)

	# Belt buckle
	var buckle = MeshInstance3D.new()
	var bu_box = BoxMesh.new()
	bu_box.size = Vector3(0.08, 0.08, 0.04)
	buckle.mesh = bu_box
	buckle.position = Vector3(0.0, 0.06, -0.14)
	buckle.material_override = metal_mat
	pelvis_node.add_child(buckle)

	# 2. SPINE & TORSO
	spine_node = Node3D.new()
	spine_node.position.y = 0.10
	pelvis_node.add_child(spine_node)

	# Upper Torso / Chest jacket
	var chest = MeshInstance3D.new()
	var c_box = BoxMesh.new()
	c_box.size = Vector3(0.44, 0.42, 0.26)
	chest.mesh = c_box
	chest.position.y = 0.22
	chest.material_override = navy_suit_mat
	spine_node.add_child(chest)

	# High-vis Reflective Safety Vest: Horizontal stripe across chest & back
	var vest_stripe = MeshInstance3D.new()
	var vs_box = BoxMesh.new()
	vs_box.size = Vector3(0.46, 0.12, 0.28)
	vest_stripe.mesh = vs_box
	vest_stripe.position.y = 0.24
	vest_stripe.material_override = vest_mat
	spine_node.add_child(vest_stripe)

	# 2 Vertical reflective shoulder suspenders
	for sx in [-0.14, 0.14]:
		var susp = MeshInstance3D.new()
		var s_box = BoxMesh.new()
		s_box.size = Vector3(0.06, 0.43, 0.28)
		susp.mesh = s_box
		susp.position = Vector3(sx, 0.22, 0.0)
		susp.material_override = vest_mat
		spine_node.add_child(susp)

	# ID Security Badge pinned on chest
	var badge = MeshInstance3D.new()
	var ba_box = BoxMesh.new()
	ba_box.size = Vector3(0.08, 0.11, 0.02)
	badge.mesh = ba_box
	badge.position = Vector3(-0.14, 0.32, -0.15)
	var badge_mat = StandardMaterial3D.new()
	badge_mat.albedo_color = Color(0.9, 0.9, 0.95)
	badge.material_override = badge_mat
	spine_node.add_child(badge)

	# 3. NECK & HEAD
	var neck_node = Node3D.new()
	neck_node.position.y = 0.43
	spine_node.add_child(neck_node)

	head_node = Node3D.new()
	head_node.position.y = 0.14
	neck_node.add_child(head_node)

	# Head shape
	var head_mesh = MeshInstance3D.new()
	var h_sph = SphereMesh.new()
	h_sph.radius = 0.18
	h_sph.height = 0.36
	head_mesh.mesh = h_sph
	head_mesh.material_override = skin_mat
	head_node.add_child(head_mesh)

	# Face: 2 Eyes
	for ex in [-0.065, 0.065]:
		var eye = MeshInstance3D.new()
		var e_sph = SphereMesh.new()
		e_sph.radius = 0.028
		e_sph.height = 0.05
		eye.mesh = e_sph
		eye.position = Vector3(ex, 0.04, -0.16)
		var eye_mat = StandardMaterial3D.new()
		eye_mat.albedo_color = Color(0.1, 0.15, 0.2)
		eye.material_override = eye_mat
		head_node.add_child(eye)

	# Face: Nose
	var nose = MeshInstance3D.new()
	var n_box = BoxMesh.new()
	n_box.size = Vector3(0.035, 0.06, 0.04)
	nose.mesh = n_box
	nose.position = Vector3(0.0, 0.01, -0.18)
	nose.material_override = skin_mat
	head_node.add_child(nose)

	# Face: Hazardous Chemical Respirator Mask with dual canister filters
	var mask = MeshInstance3D.new()
	var m_box = BoxMesh.new()
	m_box.size = Vector3(0.18, 0.12, 0.11)
	mask.mesh = m_box
	mask.position = Vector3(0.0, -0.06, -0.14)
	var mask_mat = StandardMaterial3D.new()
	mask_mat.albedo_color = Color(0.24, 0.26, 0.28)
	mask.material_override = mask_mat
	head_node.add_child(mask)

	for fx in [-0.10, 0.10]:
		var filter_can = MeshInstance3D.new()
		var f_cyl = CylinderMesh.new()
		f_cyl.top_radius = 0.035
		f_cyl.bottom_radius = 0.035
		f_cyl.height = 0.05
		filter_can.mesh = f_cyl
		filter_can.position = Vector3(fx, -0.07, -0.14)
		filter_can.rotation.x = PI / 2.0
		var fc_mat = StandardMaterial3D.new()
		fc_mat.albedo_color = Color(0.75, 0.45, 0.12)
		filter_can.material_override = fc_mat
		head_node.add_child(filter_can)

	# Janitor Cap with extended visor / brim
	var cap_crown = MeshInstance3D.new()
	var cap_cyl = CylinderMesh.new()
	cap_cyl.top_radius = 0.18
	cap_cyl.bottom_radius = 0.19
	cap_cyl.height = 0.09
	cap_crown.mesh = cap_cyl
	cap_crown.position.y = 0.14
	cap_crown.material_override = navy_suit_mat
	head_node.add_child(cap_crown)

	var cap_brim = MeshInstance3D.new()
	var brim_box = BoxMesh.new()
	brim_box.size = Vector3(0.22, 0.02, 0.13)
	cap_brim.mesh = brim_box
	cap_brim.position = Vector3(0.0, 0.11, -0.19)
	cap_brim.rotation.x = deg_to_rad(12.0)
	cap_brim.material_override = navy_suit_mat
	head_node.add_child(cap_brim)

	# 4. LEFT ARM (Holds Heavy Flashlight)
	shoulder_left = Node3D.new()
	shoulder_left.position = Vector3(-0.28, 0.38, 0.0)
	spine_node.add_child(shoulder_left)

	var u_arm_l = MeshInstance3D.new()
	var ual_box = BoxMesh.new()
	ual_box.size = Vector3(0.11, 0.24, 0.11)
	u_arm_l.mesh = ual_box
	u_arm_l.position.y = -0.12
	u_arm_l.material_override = navy_suit_mat
	shoulder_left.add_child(u_arm_l)

	forearm_left = Node3D.new()
	forearm_left.position.y = -0.24
	shoulder_left.add_child(forearm_left)

	var l_arm_l = MeshInstance3D.new()
	var lal_box = BoxMesh.new()
	lal_box.size = Vector3(0.10, 0.22, 0.10)
	l_arm_l.mesh = lal_box
	l_arm_l.position.y = -0.10
	l_arm_l.material_override = navy_suit_mat
	forearm_left.add_child(l_arm_l)

	# Yellow chemical glove hand
	var hand_l = MeshInstance3D.new()
	var hl_sph = SphereMesh.new()
	hl_sph.radius = 0.055
	hl_sph.height = 0.10
	hand_l.mesh = hl_sph
	hand_l.position.y = -0.21
	hand_l.material_override = glove_mat
	forearm_left.add_child(hand_l)

	# Heavy Duty Flashlight held in left hand
	var flash_body = MeshInstance3D.new()
	var fb_cyl = CylinderMesh.new()
	fb_cyl.top_radius = 0.035
	fb_cyl.bottom_radius = 0.03
	fb_cyl.height = 0.26
	flash_body.mesh = fb_cyl
	flash_body.position = Vector3(0.0, -0.21, -0.10)
	flash_body.rotation.x = PI / 2.0
	var fb_mat = StandardMaterial3D.new()
	fb_mat.albedo_color = Color(0.2, 0.22, 0.24)
	fb_mat.roughness = 0.5
	flash_body.material_override = fb_mat
	forearm_left.add_child(flash_body)

	var flash_bezel = MeshInstance3D.new()
	var fbez_cyl = CylinderMesh.new()
	fbez_cyl.top_radius = 0.045
	fbez_cyl.bottom_radius = 0.045
	fbez_cyl.height = 0.04
	flash_bezel.mesh = fbez_cyl
	flash_bezel.position = Vector3(0.0, -0.21, -0.23)
	flash_bezel.rotation.x = PI / 2.0
	flash_bezel.material_override = metal_mat
	forearm_left.add_child(flash_bezel)

	# SpotLight3D emitting from the flashlight
	flashlight_spot = SpotLight3D.new()
	flashlight_spot.position = Vector3(0.0, -0.21, -0.26)
	flashlight_spot.spot_range = 24.0
	flashlight_spot.spot_angle = 38.0
	flashlight_spot.light_energy = 2.4
	flashlight_spot.light_color = Color(1.0, 0.96, 0.88)
	flashlight_spot.shadow_enabled = true
	forearm_left.add_child(flashlight_spot)

	# 5. RIGHT ARM (Tool / Weapon Arm)
	shoulder_right = Node3D.new()
	shoulder_right.position = Vector3(0.28, 0.38, 0.0)
	spine_node.add_child(shoulder_right)

	var u_arm_r = MeshInstance3D.new()
	var uar_box = BoxMesh.new()
	uar_box.size = Vector3(0.11, 0.24, 0.11)
	u_arm_r.mesh = uar_box
	u_arm_r.position.y = -0.12
	u_arm_r.material_override = navy_suit_mat
	shoulder_right.add_child(u_arm_r)

	forearm_right = Node3D.new()
	forearm_right.position.y = -0.24
	shoulder_right.add_child(forearm_right)

	var l_arm_r = MeshInstance3D.new()
	var lar_box = BoxMesh.new()
	lar_box.size = Vector3(0.10, 0.22, 0.10)
	l_arm_r.mesh = lar_box
	l_arm_r.position.y = -0.10
	l_arm_r.material_override = navy_suit_mat
	forearm_right.add_child(l_arm_r)

	var hand_r = MeshInstance3D.new()
	var hr_sph = SphereMesh.new()
	hr_sph.radius = 0.055
	hr_sph.height = 0.10
	hand_r.mesh = hr_sph
	hand_r.position.y = -0.21
	hand_r.material_override = glove_mat
	forearm_right.add_child(hand_r)

	weapon_mount = Node3D.new()
	weapon_mount.position = Vector3(0.0, -0.21, -0.05)
	forearm_right.add_child(weapon_mount)

	held_weapon_mesh = MeshInstance3D.new()
	weapon_mount.add_child(held_weapon_mesh)
	_update_weapon_visual()

	# 6. LEGS & WORK BOOTS
	hip_left = Node3D.new()
	hip_left.position = Vector3(-0.13, -0.05, 0.0)
	pelvis_node.add_child(hip_left)

	var thigh_l = MeshInstance3D.new()
	var tl_box = BoxMesh.new()
	tl_box.size = Vector3(0.14, 0.38, 0.15)
	thigh_l.mesh = tl_box
	thigh_l.position.y = -0.19
	thigh_l.material_override = navy_suit_mat
	hip_left.add_child(thigh_l)

	knee_left = Node3D.new()
	knee_left.position.y = -0.38
	hip_left.add_child(knee_left)

	var calf_l = MeshInstance3D.new()
	var cl_box = BoxMesh.new()
	cl_box.size = Vector3(0.13, 0.34, 0.13)
	calf_l.mesh = cl_box
	calf_l.position.y = -0.17
	calf_l.material_override = navy_suit_mat
	knee_left.add_child(calf_l)

	var boot_l = MeshInstance3D.new()
	var bl_box = BoxMesh.new()
	bl_box.size = Vector3(0.14, 0.13, 0.25)
	boot_l.mesh = bl_box
	boot_l.position = Vector3(0.0, -0.34, -0.04)
	boot_l.material_override = boot_mat
	knee_left.add_child(boot_l)

	# Right Leg
	hip_right = Node3D.new()
	hip_right.position = Vector3(0.13, -0.05, 0.0)
	pelvis_node.add_child(hip_right)

	var thigh_r = MeshInstance3D.new()
	var tr_box = BoxMesh.new()
	tr_box.size = Vector3(0.14, 0.38, 0.15)
	thigh_r.mesh = tr_box
	thigh_r.position.y = -0.19
	thigh_r.material_override = navy_suit_mat
	hip_right.add_child(thigh_r)

	knee_right = Node3D.new()
	knee_right.position.y = -0.38
	hip_right.add_child(knee_right)

	var calf_r = MeshInstance3D.new()
	var cr_box = BoxMesh.new()
	cr_box.size = Vector3(0.13, 0.34, 0.13)
	calf_r.mesh = cr_box
	calf_r.position.y = -0.17
	calf_r.material_override = navy_suit_mat
	knee_right.add_child(calf_r)

	var boot_r = MeshInstance3D.new()
	var br_box = BoxMesh.new()
	br_box.size = Vector3(0.14, 0.13, 0.25)
	boot_r.mesh = br_box
	boot_r.position = Vector3(0.0, -0.34, -0.04)
	boot_r.material_override = boot_mat
	knee_right.add_child(boot_r)

	# 7. FLOATING CALLSIGN / WAGES BILLBOARD
	name_tag = Label3D.new()
	name_tag.position = Vector3(0, 2.15, 0)
	name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_tag.text = player_name + "\n$0"
	name_tag.font_size = 20
	name_tag.pixel_size = 0.003
	name_tag.modulate = Color(0.25, 0.95, 0.9)
	name_tag.outline_modulate = Color(0, 0, 0)
	name_tag.outline_size = 4
	mesh_root.add_child(name_tag)

func _update_weapon_visual() -> void:
	if not weapon_mount:
		return
	for c in weapon_mount.get_children():
		c.queue_free()

	if current_weapon_type == 0:
		# Mop: Wood handle with scrub head
		var mop_node = Node3D.new()
		mop_node.rotation.x = deg_to_rad(65.0)

		var handle = MeshInstance3D.new()
		var cyl = CylinderMesh.new()
		cyl.top_radius = 0.018
		cyl.bottom_radius = 0.018
		cyl.height = 1.45
		handle.mesh = cyl
		handle.position.y = -0.15
		var w_mat = StandardMaterial3D.new()
		w_mat.albedo_color = Color(0.72, 0.62, 0.44)
		handle.material_override = w_mat
		mop_node.add_child(handle)

		var mop_head = MeshInstance3D.new()
		var mh_box = BoxMesh.new()
		mh_box.size = Vector3(0.16, 0.12, 0.22)
		mop_head.mesh = mh_box
		mop_head.position.y = 0.58
		var cl_mat = StandardMaterial3D.new()
		cl_mat.albedo_color = Color(0.85, 0.88, 0.85)
		mop_head.material_override = cl_mat
		mop_node.add_child(mop_head)

		weapon_mount.add_child(mop_node)
	elif current_weapon_type == 1:
		# Tactical Stun Taser Gun
		var taser_node = Node3D.new()
		var body = MeshInstance3D.new()
		var t_box = BoxMesh.new()
		t_box.size = Vector3(0.07, 0.13, 0.22)
		body.mesh = t_box
		body.position = Vector3(0, 0, -0.12)
		var t_mat = StandardMaterial3D.new()
		t_mat.albedo_color = Color(0.92, 0.78, 0.08) # Tactical yellow
		body.material_override = t_mat
		taser_node.add_child(body)

		# Spark electrodes
		var elec = MeshInstance3D.new()
		var e_box = BoxMesh.new()
		e_box.size = Vector3(0.05, 0.04, 0.04)
		elec.mesh = e_box
		elec.position = Vector3(0, 0.02, -0.24)
		var el_mat = StandardMaterial3D.new()
		el_mat.albedo_color = Color(0.2, 0.8, 1.0)
		el_mat.emission_enabled = true
		el_mat.emission = Color(0.2, 0.8, 1.0)
		el_mat.emission_energy_multiplier = 2.0
		elec.material_override = el_mat
		taser_node.add_child(elec)

		weapon_mount.add_child(taser_node)
	elif current_weapon_type == 2:
		# Shock Security Baton
		var baton_node = Node3D.new()
		baton_node.rotation.x = deg_to_rad(45.0)

		var shaft = MeshInstance3D.new()
		var b_cyl = CylinderMesh.new()
		b_cyl.top_radius = 0.025
		b_cyl.bottom_radius = 0.025
		b_cyl.height = 0.82
		shaft.mesh = b_cyl
		shaft.position.y = -0.10
		var b_mat = StandardMaterial3D.new()
		b_mat.albedo_color = Color(0.18, 0.20, 0.22)
		shaft.material_override = b_mat
		baton_node.add_child(shaft)

		# Electric shock emitter rings
		var ring = MeshInstance3D.new()
		var r_cyl = CylinderMesh.new()
		r_cyl.top_radius = 0.03
		r_cyl.bottom_radius = 0.03
		r_cyl.height = 0.28
		ring.mesh = r_cyl
		ring.position.y = 0.25
		var r_mat = StandardMaterial3D.new()
		r_mat.albedo_color = Color(0.2, 0.8, 1.0)
		r_mat.emission_enabled = true
		r_mat.emission = Color(0.2, 0.8, 1.0)
		r_mat.emission_energy_multiplier = 2.5
		ring.material_override = r_mat
		baton_node.add_child(ring)

		weapon_mount.add_child(baton_node)
