extends CharacterBody3D

signal step_taken()
signal locker_state_changed(hiding: bool, locker_node: Node3D)
signal mop_strike_requested()
signal weapon_attack_requested(weapon_type: int)
signal bait_toss_requested()
signal override_requested()
signal bite_sequence_finished(bite_count: int, fatal: bool)

@export var walk_speed: float = 4.2
@export var sprint_speed: float = 6.8
@export var mouse_sensitivity: float = 0.0024

var stamina: float = 100.0
var max_stamina: float = 100.0
var stamina_drain: float = 25.0
var stamina_recovery: float = 20.0
var god_mode: bool = false
var noclip: bool = false
var is_sprinting: bool = false
var is_hiding: bool = false
var is_inside_cloak: bool = false
var cloak_digest_timer: float = 0.0
var _cloak_touch_grace: float = 0.0
var _active_cloak_ref: Node3D = null
var _cloak_warn_cooldown: float = 0.0
var _cloak_breath_timer: float = 0.0
const CLOAK_MAX_DIGEST: float = 6.5
var current_locker: Node3D = null
var locker_base_yaw: float = 0.0
var locker_yaw_offset: float = 0.0
var interact_cooldown: float = 0.0
var current_floor: int = 1
var in_secret_corridor: bool = false

var camera_rotation_x: float = 0.0
var camera_roll: float = 0.0
var camera_shake_trauma: float = 0.0
var base_fov: float = 75.0
var fov_kick: float = 0.0

# Exact distance moved this physics frame (used for SUPERHOT-style step-linked enemy movement)
var last_frame_move_dist: float = 0.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var flashlight: SpotLight3D = $Head/Camera3D/Flashlight
@onready var fill_light: OmniLight3D = $Head/Camera3D/FillLight
@onready var interaction_ray: RayCast3D = $Head/Camera3D/InteractionRay
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

# --- TWO-HANDED JANITOR ARMS & MOP RIG ---
var arms_root: Node3D = null
var mop_mesh: Node3D = null
var left_arm_node: Node3D = null
var right_arm_node: Node3D = null
var mop_strands: Array[MeshInstance3D] = []

# --- WEAPONS & 2-SLOT INVENTORY ---
enum WeaponType { MOP, TASER, BATON }
var current_weapon: WeaponType = WeaponType.MOP

var has_taser: bool = false
var taser_ammo: int = 0
var has_baton: bool = false
var baton_durability: float = 0.0

var taser_mesh: Node3D = null
var baton_mesh: Node3D = null
var baton_glow_light: OmniLight3D = null
var taser_flash_light: OmniLight3D = null

# Baton Guard & Parry:
var is_guarding: bool = false
var guard_timer: float = 0.0
const PARRY_WINDOW: float = 0.25
var parry_recoil_timer: float = 0.0
var block_recoil_timer: float = 0.0

# Baton & Taser Animations:
var is_swinging_baton: bool = false
var baton_swing_timer: float = 0.0
const BATON_SWING_DURATION: float = 0.28
var is_firing_taser: bool = false
var taser_fire_timer: float = 0.0
const TASER_FIRE_DURATION: float = 0.25

var is_scrubbing: bool = false
var scrub_timer: float = 0.0
var _scrub_fade_sent: bool = false
const SCRUB_DURATION: float = 1.05

var is_swinging_mop: bool = false
var swing_timer: float = 0.0
var swing_hit_type: String = "miss"
const SWING_DURATION: float = 0.46

# --- 4-STAGE CRAWLER BITE / FACE-LATCH SEQUENCE (HTML triggerBite / updateBiteScene) ---
const BITE_LOCAL_POS: Vector3 = Vector3(0.18, -0.18, -0.58)
var in_bite_sequence: bool = false
var bite_stage: int = 0
var bite_timer: float = 0.0
var bite_hit_t: float = 0.0
var bite_next_pulse: float = 0.0
var bite_crawler: Node3D = null
var bite_vel: Vector3 = Vector3.ZERO
var bite_num: int = 0
var bite_fatal: bool = false

# --- DEATH / JUMPSCARE CAMERA SEQUENCE (HTML startKill / updateKill) ---
var is_dead: bool = false
var in_death_sequence: bool = false
var death_timer: float = 0.0
var death_duration: float = 1.3
var death_target_node: Node3D = null
var death_style: String = "claw"
var death_callback: Callable

# Hanger snaring state
var is_hanged_by_hanger: bool = false
var hanger_node: Node3D = null
var hanger_struggle_timer: float = 0.0
var hanger_struggle_count: int = 0
var hanger_required_struggles: int = 8

var step_timer: float = 0.0
var bob_timer: float = 0.0
var breath_timer: float = 0.0
var step_dist_accum: float = 0.0
var _last_flat_pos: Vector2 = Vector2.ZERO
var _has_last_pos: bool = false

func _ready() -> void:
	floor_max_angle = deg_to_rad(68.0)
	floor_snap_length = 0.25
	floor_constant_speed = true
	interaction_ray.target_position = Vector3(0, 0, -3.0)
	interaction_ray.collide_with_areas = true
	interaction_ray.collision_mask = 4
	flashlight.visible = true
	if fill_light:
		fill_light.visible = true
	if camera:
		base_fov = camera.fov
	_create_two_handed_arms_and_mop()
	_last_flat_pos = Vector2(global_position.x, global_position.z)
	_has_last_pos = true

func reset_step_tracker() -> void:
	step_dist_accum = 0.0
	last_frame_move_dist = 0.0
	_last_flat_pos = Vector2(global_position.x, global_position.z)
	_has_last_pos = true

func is_player_moving() -> bool:
	return last_frame_move_dist > 0.0015 and not is_hiding and not in_bite_sequence and not in_death_sequence and not is_dead

func add_camera_shake(amount: float) -> void:
	camera_shake_trauma = min(1.5, camera_shake_trauma + amount)

# Builds detailed two-handed janitor rig matching HTML buildFPSArms:
# Navy rolled sleeves, forearm cuff bands, wristwatch, stained rubber gloves with
# 4 articulated two-segment fingers + thumb on each hand, and 28-strand blood-speckled mop
func _create_two_handed_arms_and_mop() -> void:
	if arms_root and is_instance_valid(arms_root):
		arms_root.queue_free()
	mop_strands.clear()

	arms_root = Node3D.new()
	arms_root.name = "FPS_ARMS_ROOT"
	arms_root.position = Vector3(0.0, -0.22, -0.42)
	camera.add_child(arms_root)

	var sleeve_mat = StandardMaterial3D.new()
	sleeve_mat.albedo_color = Color(0.11, 0.16, 0.23)
	sleeve_mat.roughness = 0.85

	var cuff_mat = StandardMaterial3D.new()
	cuff_mat.albedo_color = Color(0.18, 0.25, 0.34)
	cuff_mat.roughness = 0.8

	var skin_mat = StandardMaterial3D.new()
	skin_mat.albedo_color = Color(0.76, 0.58, 0.45)
	skin_mat.roughness = 0.65

	var glove_mat = StandardMaterial3D.new()
	glove_mat.albedo_color = Color(0.48, 0.18, 0.12) # Heavy industrial rust-crimson rubber gloves
	glove_mat.roughness = 0.48
	glove_mat.metallic = 0.06

	var glove_dark = StandardMaterial3D.new()
	glove_dark.albedo_color = Color(0.32, 0.10, 0.07)
	glove_dark.roughness = 0.55

	var wood_mat = StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.54, 0.35, 0.16)
	wood_mat.roughness = 0.65

	var metal_mat = StandardMaterial3D.new()
	metal_mat.albedo_color = Color(0.45, 0.49, 0.54)
	metal_mat.metallic = 0.82
	metal_mat.roughness = 0.28

	var watch_glow = StandardMaterial3D.new()
	watch_glow.albedo_color = Color(0.15, 0.95, 0.55)
	watch_glow.emission_enabled = true
	watch_glow.emission = Color(0.1, 0.85, 0.45)
	watch_glow.emission_energy_multiplier = 2.0

	# Helper to build an articulated forearm + gloved hand with 4 segmented fingers & thumb
	var build_detailed_arm = func(is_right: bool) -> Node3D:
		var side := 1.0 if is_right else -1.0
		var arm_pivot = Node3D.new()
		if is_right:
			arm_pivot.position = Vector3(0.23, -0.07, 0.08)
			arm_pivot.rotation = Vector3(deg_to_rad(46), deg_to_rad(-19), deg_to_rad(-11))
		else:
			arm_pivot.position = Vector3(-0.16, -0.14, 0.04)
			arm_pivot.rotation = Vector3(deg_to_rad(53), deg_to_rad(28), deg_to_rad(14))

		# Upper rolled jumpsuit sleeve
		var sleeve = MeshInstance3D.new()
		var s_cyl = CylinderMesh.new()
		s_cyl.top_radius = 0.044
		s_cyl.bottom_radius = 0.056
		s_cyl.height = 0.24
		sleeve.mesh = s_cyl
		sleeve.position = Vector3(0, -0.07, 0)
		sleeve.material_override = sleeve_mat
		arm_pivot.add_child(sleeve)

		# Rolled sleeve cuff torus
		var cuff = MeshInstance3D.new()
		var c_tor = TorusMesh.new()
		c_tor.inner_radius = 0.036
		c_tor.outer_radius = 0.054
		cuff.mesh = c_tor
		cuff.position = Vector3(0, -0.18, 0)
		cuff.material_override = cuff_mat
		arm_pivot.add_child(cuff)

		# Exposed wrist / lower forearm + rubber glove gauntlet
		var gauntlet = MeshInstance3D.new()
		var g_cyl = CylinderMesh.new()
		g_cyl.top_radius = 0.038
		g_cyl.bottom_radius = 0.045
		g_cyl.height = 0.11
		gauntlet.mesh = g_cyl
		gauntlet.position = Vector3(0, -0.23, -0.005)
		gauntlet.material_override = glove_mat
		arm_pivot.add_child(gauntlet)

		# Digital janitor watch on left wrist
		if not is_right:
			var strap = MeshInstance3D.new()
			var st_cyl = CylinderMesh.new()
			st_cyl.top_radius = 0.041
			st_cyl.bottom_radius = 0.041
			st_cyl.height = 0.022
			strap.mesh = st_cyl
			strap.position = Vector3(0, -0.20, 0)
			strap.material_override = glove_dark
			arm_pivot.add_child(strap)

			var face = MeshInstance3D.new()
			var f_box = BoxMesh.new()
			f_box.size = Vector3(0.032, 0.022, 0.014)
			face.mesh = f_box
			face.position = Vector3(0.028, -0.20, -0.026)
			face.rotation.y = 0.5
			face.material_override = watch_glow
			arm_pivot.add_child(face)

		# Hand palm & back
		var hand_root = Node3D.new()
		hand_root.position = Vector3(0, -0.29, -0.018)
		arm_pivot.add_child(hand_root)

		var palm = MeshInstance3D.new()
		var p_box = BoxMesh.new()
		p_box.size = Vector3(0.078, 0.072, 0.042)
		palm.mesh = p_box
		palm.material_override = glove_mat
		hand_root.add_child(palm)

		var palm_pad = MeshInstance3D.new()
		var pp_box = BoxMesh.new()
		pp_box.size = Vector3(0.070, 0.064, 0.018)
		palm_pad.mesh = pp_box
		palm_pad.position = Vector3(0, 0, -0.022)
		palm_pad.material_override = glove_dark
		hand_root.add_child(palm_pad)

		# Knuckle ridge
		for f in range(4):
			var fx = (float(f) - 1.5) * 0.018
			var kn = MeshInstance3D.new()
			var k_sph = SphereMesh.new()
			k_sph.radius = 0.011
			k_sph.height = 0.022
			kn.mesh = k_sph
			kn.position = Vector3(fx, -0.032, 0.016)
			kn.material_override = glove_mat
			hand_root.add_child(kn)

			# Proximal + Distal finger phalanges curled around mop shaft
			var f_prox = MeshInstance3D.new()
			var fp_cyl = CylinderMesh.new()
			fp_cyl.top_radius = 0.0085
			fp_cyl.bottom_radius = 0.0095
			fp_cyl.height = 0.036
			f_prox.mesh = fp_cyl
			f_prox.position = Vector3(fx, -0.046, -0.004)
			f_prox.rotation.x = 1.05
			f_prox.material_override = glove_mat
			hand_root.add_child(f_prox)

			var f_dist = MeshInstance3D.new()
			var fd_cyl = CylinderMesh.new()
			fd_cyl.top_radius = 0.0075
			fd_cyl.bottom_radius = 0.0085
			fd_cyl.height = 0.030
			f_dist.mesh = fd_cyl
			f_dist.position = Vector3(fx, -0.042, -0.030)
			f_dist.rotation.x = 2.15
			f_dist.material_override = glove_dark
			hand_root.add_child(f_dist)

		# Opposable Thumb wrapping around the opposite side of the handle
		var thumb = MeshInstance3D.new()
		var th_cyl = CylinderMesh.new()
		th_cyl.top_radius = 0.010
		th_cyl.bottom_radius = 0.012
		th_cyl.height = 0.046
		thumb.mesh = th_cyl
		thumb.position = Vector3(-side * 0.042, -0.012, -0.022)
		thumb.rotation = Vector3(0.75, side * 0.45, side * 0.85)
		thumb.material_override = glove_mat
		hand_root.add_child(thumb)

		return arm_pivot

	right_arm_node = build_detailed_arm.call(true)
	left_arm_node = build_detailed_arm.call(false)
	arms_root.add_child(right_arm_node)
	arms_root.add_child(left_arm_node)

	# --- MOP OBJECT ---
	mop_mesh = Node3D.new()
	mop_mesh.name = "MOP"
	mop_mesh.position = Vector3(0.08, -0.15, -0.18)
	mop_mesh.rotation = Vector3(deg_to_rad(50), deg_to_rad(-12), deg_to_rad(6))

	var pole = MeshInstance3D.new()
	var p_cyl = CylinderMesh.new()
	p_cyl.top_radius = 0.014
	p_cyl.bottom_radius = 0.016
	p_cyl.height = 1.26
	pole.mesh = p_cyl
	pole.position = Vector3(0, -0.15, 0)
	pole.material_override = wood_mat
	mop_mesh.add_child(pole)

	# Rubberized upper grip collar on handle
	var grip_collar = MeshInstance3D.new()
	var gc_cyl = CylinderMesh.new()
	gc_cyl.top_radius = 0.0175
	gc_cyl.bottom_radius = 0.0175
	gc_cyl.height = 0.22
	grip_collar.mesh = gc_cyl
	grip_collar.position = Vector3(0, 0.24, 0)
	grip_collar.material_override = glove_dark
	mop_mesh.add_child(grip_collar)

	# Heavy metal jaw clamp + wingnuts
	var clamp_mesh = MeshInstance3D.new()
	var c_box = BoxMesh.new()
	c_box.size = Vector3(0.15, 0.075, 0.085)
	clamp_mesh.mesh = c_box
	clamp_mesh.position = Vector3(0, -0.73, 0)
	clamp_mesh.material_override = metal_mat
	mop_mesh.add_child(clamp_mesh)

	for s in [-1.0, 1.0]:
		var bolt = MeshInstance3D.new()
		var b_cyl = CylinderMesh.new()
		b_cyl.top_radius = 0.012
		b_cyl.bottom_radius = 0.012
		b_cyl.height = 0.11
		bolt.mesh = b_cyl
		bolt.position = Vector3(s * 0.055, -0.73, 0)
		bolt.rotation.x = PI * 0.5
		bolt.material_override = metal_mat
		mop_mesh.add_child(bolt)

	# 28 multi-toned damp / blood-stained yarn strands
	var yarn_colors = [
		Color(0.84, 0.82, 0.76),
		Color(0.72, 0.70, 0.64),
		Color(0.62, 0.58, 0.52),
		Color(0.52, 0.14, 0.12) # Dried blood-stained strands
	]
	var yarn_mats: Array[StandardMaterial3D] = []
	for yc in yarn_colors:
		var ym = StandardMaterial3D.new()
		ym.albedo_color = yc
		ym.roughness = 0.92
		yarn_mats.append(ym)

	for i in range(28):
		var strand = MeshInstance3D.new()
		var s_cyl = CylinderMesh.new()
		s_cyl.top_radius = 0.007
		s_cyl.bottom_radius = 0.011
		s_cyl.height = 0.25 + float(i % 3) * 0.025
		strand.mesh = s_cyl
		var angle = (float(i) / 28.0) * TAU
		var radius = 0.032 + float(i % 4) * 0.012
		strand.position = Vector3(cos(angle) * radius, -0.86, sin(angle) * radius)
		strand.rotation.z = cos(angle) * 0.24
		strand.rotation.x = sin(angle) * 0.24
		strand.material_override = yarn_mats[i % yarn_mats.size()]
		mop_mesh.add_child(strand)
		mop_strands.append(strand)

	arms_root.add_child(mop_mesh)

	# --- TASER (STUN GUN) OBJECT ---
	taser_mesh = Node3D.new()
	taser_mesh.name = "TASER"
	taser_mesh.position = Vector3(0.06, -0.14, -0.22)
	taser_mesh.rotation = Vector3(deg_to_rad(12), deg_to_rad(-4), 0.0)

	var taser_body_mat = StandardMaterial3D.new()
	taser_body_mat.albedo_color = Color(0.92, 0.74, 0.08) # Tactical safety yellow
	taser_body_mat.roughness = 0.45

	var taser_dark_mat = StandardMaterial3D.new()
	taser_dark_mat.albedo_color = Color(0.11, 0.12, 0.14)
	taser_dark_mat.roughness = 0.75

	var taser_copper_mat = StandardMaterial3D.new()
	taser_copper_mat.albedo_color = Color(0.85, 0.55, 0.25)
	taser_copper_mat.metallic = 0.95
	taser_copper_mat.roughness = 0.25

	var taser_led_mat = StandardMaterial3D.new()
	taser_led_mat.albedo_color = Color(0.1, 0.95, 0.9)
	taser_led_mat.emission_enabled = true
	taser_led_mat.emission = Color(0.1, 0.95, 0.9)
	taser_led_mat.emission_energy_multiplier = 2.2

	# Main upper yellow receiver body
	var t_receiver = MeshInstance3D.new()
	var t_rec_mesh = BoxMesh.new()
	t_rec_mesh.size = Vector3(0.065, 0.10, 0.22)
	t_receiver.mesh = t_rec_mesh
	t_receiver.position = Vector3(0, 0.03, -0.06)
	t_receiver.material_override = taser_body_mat
	taser_mesh.add_child(t_receiver)

	# Black hazard stripe on body
	var t_stripe = MeshInstance3D.new()
	var ts_mesh = BoxMesh.new()
	ts_mesh.size = Vector3(0.068, 0.03, 0.08)
	t_stripe.mesh = ts_mesh
	t_stripe.position = Vector3(0, 0.03, -0.06)
	t_stripe.material_override = taser_dark_mat
	taser_mesh.add_child(t_stripe)

	# Ergonomic pistol grip
	var t_grip = MeshInstance3D.new()
	var tg_mesh = BoxMesh.new()
	tg_mesh.size = Vector3(0.052, 0.14, 0.065)
	t_grip.mesh = tg_mesh
	t_grip.position = Vector3(0, -0.07, 0.02)
	t_grip.rotation.x = -deg_to_rad(15)
	t_grip.material_override = taser_dark_mat
	taser_mesh.add_child(t_grip)

	# Front cartridge faceplate
	var t_cartridge = MeshInstance3D.new()
	var tc_mesh = BoxMesh.new()
	tc_mesh.size = Vector3(0.062, 0.09, 0.05)
	t_cartridge.mesh = tc_mesh
	t_cartridge.position = Vector3(0, 0.03, -0.19)
	t_cartridge.material_override = taser_dark_mat
	taser_mesh.add_child(t_cartridge)

	# Twin electrode dart prongs
	for sx in [-0.016, 0.016]:
		var prong = MeshInstance3D.new()
		var prong_cyl = CylinderMesh.new()
		prong_cyl.top_radius = 0.003
		prong_cyl.bottom_radius = 0.004
		prong_cyl.height = 0.035
		prong.mesh = prong_cyl
		prong.position = Vector3(sx, 0.03, -0.23)
		prong.rotation.x = PI * 0.5
		prong.material_override = taser_copper_mat
		taser_mesh.add_child(prong)

	# Battery / ready LED
	var t_led = MeshInstance3D.new()
	var tl_mesh = BoxMesh.new()
	tl_mesh.size = Vector3(0.012, 0.008, 0.018)
	t_led.mesh = tl_mesh
	t_led.position = Vector3(0.025, 0.082, -0.02)
	t_led.material_override = taser_led_mat
	taser_mesh.add_child(t_led)

	# Muzzle flash light
	taser_flash_light = OmniLight3D.new()
	taser_flash_light.position = Vector3(0, 0.03, -0.26)
	taser_flash_light.light_color = Color(0.3, 0.85, 1.0)
	taser_flash_light.light_energy = 0.0
	taser_flash_light.omni_range = 4.5
	taser_mesh.add_child(taser_flash_light)

	taser_mesh.visible = false
	arms_root.add_child(taser_mesh)

	# --- SHOCK BATON OBJECT ---
	baton_mesh = Node3D.new()
	baton_mesh.name = "BATON"
	baton_mesh.position = Vector3(0.10, -0.16, -0.20)
	baton_mesh.rotation = Vector3(deg_to_rad(45), deg_to_rad(-15), deg_to_rad(5))

	var baton_grip_mat = StandardMaterial3D.new()
	baton_grip_mat.albedo_color = Color(0.12, 0.12, 0.14)
	baton_grip_mat.roughness = 0.85

	var baton_steel_mat = StandardMaterial3D.new()
	baton_steel_mat.albedo_color = Color(0.32, 0.35, 0.38)
	baton_steel_mat.metallic = 0.88
	baton_steel_mat.roughness = 0.28

	var baton_shock_mat = StandardMaterial3D.new()
	baton_shock_mat.albedo_color = Color(0.2, 0.85, 1.0)
	baton_shock_mat.emission_enabled = true
	baton_shock_mat.emission = Color(0.2, 0.85, 1.0)
	baton_shock_mat.emission_energy_multiplier = 2.8

	# Ribbed rubber handle
	var b_grip = MeshInstance3D.new()
	var bg_cyl = CylinderMesh.new()
	bg_cyl.top_radius = 0.021
	bg_cyl.bottom_radius = 0.021
	bg_cyl.height = 0.19
	b_grip.mesh = bg_cyl
	b_grip.position = Vector3(0, -0.06, 0)
	b_grip.material_override = baton_grip_mat
	baton_mesh.add_child(b_grip)

	# Handguard stopper disc
	var b_guard = MeshInstance3D.new()
	var bgu_cyl = CylinderMesh.new()
	bgu_cyl.top_radius = 0.036
	bgu_cyl.bottom_radius = 0.036
	bgu_cyl.height = 0.016
	b_guard.mesh = bgu_cyl
	b_guard.position = Vector3(0, 0.045, 0)
	b_guard.material_override = baton_grip_mat
	baton_mesh.add_child(b_guard)

	# Heavy steel baton shaft
	var b_shaft = MeshInstance3D.new()
	var bs_cyl = CylinderMesh.new()
	bs_cyl.top_radius = 0.015
	bs_cyl.bottom_radius = 0.017
	bs_cyl.height = 0.52
	b_shaft.mesh = bs_cyl
	b_shaft.position = Vector3(0, 0.31, 0)
	b_shaft.material_override = baton_steel_mat
	baton_mesh.add_child(b_shaft)

	# Dual electric stun rings at tip
	for y_ofs in [0.48, 0.54]:
		var b_ring = MeshInstance3D.new()
		var br_tor = TorusMesh.new()
		br_tor.inner_radius = 0.015
		br_tor.outer_radius = 0.022
		b_ring.mesh = br_tor
		b_ring.position = Vector3(0, y_ofs, 0)
		b_ring.rotation.x = PI * 0.5
		b_ring.material_override = baton_shock_mat
		baton_mesh.add_child(b_ring)

	# Baton tip electrode dome
	var b_dome = MeshInstance3D.new()
	var bd_sph = SphereMesh.new()
	bd_sph.radius = 0.017
	bd_sph.height = 0.024
	b_dome.mesh = bd_sph
	b_dome.position = Vector3(0, 0.58, 0)
	b_dome.material_override = baton_shock_mat
	baton_mesh.add_child(b_dome)

	# Subtle ambient blue electric glow on tip
	baton_glow_light = OmniLight3D.new()
	baton_glow_light.position = Vector3(0, 0.58, 0)
	baton_glow_light.light_color = Color(0.2, 0.75, 1.0)
	baton_glow_light.light_energy = 0.8
	baton_glow_light.omni_range = 2.2
	baton_mesh.add_child(baton_glow_light)

	baton_mesh.visible = false
	arms_root.add_child(baton_mesh)

	_update_weapon_visuals()

func _update_weapon_visuals() -> void:
	if mop_mesh:
		mop_mesh.visible = (current_weapon == WeaponType.MOP)
	if taser_mesh:
		taser_mesh.visible = (current_weapon == WeaponType.TASER)
	if baton_mesh:
		baton_mesh.visible = (current_weapon == WeaponType.BATON)

	if right_arm_node and left_arm_node:
		match current_weapon:
			WeaponType.MOP:
				right_arm_node.position = Vector3(0.23, -0.07, 0.08)
				right_arm_node.rotation = Vector3(deg_to_rad(46), deg_to_rad(-19), deg_to_rad(-11))
				left_arm_node.position = Vector3(-0.16, -0.14, 0.04)
				left_arm_node.rotation = Vector3(deg_to_rad(53), deg_to_rad(28), deg_to_rad(14))
			WeaponType.TASER:
				right_arm_node.position = Vector3(0.12, -0.12, 0.10)
				right_arm_node.rotation = Vector3(deg_to_rad(28), deg_to_rad(-6), 0)
				left_arm_node.position = Vector3(-0.06, -0.14, 0.08)
				left_arm_node.rotation = Vector3(deg_to_rad(34), deg_to_rad(16), deg_to_rad(10))
			WeaponType.BATON:
				if is_guarding:
					# Braced cross-chest guard
					right_arm_node.position = Vector3(0.08, -0.06, 0.06)
					right_arm_node.rotation = Vector3(deg_to_rad(56), deg_to_rad(-24), deg_to_rad(22))
					left_arm_node.position = Vector3(-0.08, -0.08, 0.04)
					left_arm_node.rotation = Vector3(deg_to_rad(62), deg_to_rad(32), deg_to_rad(-18))
				else:
					# Alert low-ready baton stance
					right_arm_node.position = Vector3(0.18, -0.09, 0.09)
					right_arm_node.rotation = Vector3(deg_to_rad(42), deg_to_rad(-12), deg_to_rad(-6))
					left_arm_node.position = Vector3(-0.15, -0.15, 0.04)
					left_arm_node.rotation = Vector3(deg_to_rad(46), deg_to_rad(22), deg_to_rad(8))

	_sync_hud_inventory()

func _get_hud() -> Node:
	if get_tree() and get_tree().root:
		return get_tree().root.find_child("HUD", true, false)
	return null

func _sync_hud_inventory() -> void:
	var hud_node = _get_hud()
	if hud_node and hud_node.has_method("update_weapon_inventory"):
		hud_node.update_weapon_inventory(
			int(current_weapon),
			has_taser,
			taser_ammo,
			has_baton,
			baton_durability,
			is_guarding,
			is_baton_parrying()
		)

func trigger_scrub_animation() -> void:
	if is_scrubbing and scrub_timer < 0.4:
		return
	is_scrubbing = true
	scrub_timer = 0.0
	SoundEffects.play(SoundEffects.snd_scrub, -3.0, randf_range(0.95, 1.05))

func trigger_mop_swing_animation(hit_type: String = "miss") -> void:
	if is_swinging_mop and swing_timer < 0.18:
		return
	is_swinging_mop = true
	swing_timer = 0.0
	swing_hit_type = hit_type
	SoundEffects.play(SoundEffects.snd_scrub, 2.0, 1.28 if hit_type == "miss" else 0.88)
	if hit_type != "miss":
		add_camera_shake(0.55 if hit_type == "hunter" else 0.38)
		_spawn_mop_hit_burst(hit_type)

func _spawn_mop_hit_burst(hit_type: String) -> void:
	var burst_root = Node3D.new()
	burst_root.position = global_position - camera.global_transform.basis.z * 1.45 + Vector3(0, 1.25, 0)
	get_parent().add_child(burst_root)

	var col = Color(0.55, 0.04, 0.06) if hit_type != "miss" else Color(0.8, 0.8, 0.7)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col * 0.6
	mat.roughness = 0.3

	var droplets: Array[Dictionary] = []
	for i in range(12):
		var drop = MeshInstance3D.new()
		var sph = SphereMesh.new()
		var r = randf_range(0.025, 0.06)
		sph.radius = r
		sph.height = r * 2.0
		drop.mesh = sph
		drop.material_override = mat
		burst_root.add_child(drop)
		var vel = Vector3(randf_range(-2.6, 2.6), randf_range(0.8, 3.2), randf_range(-2.6, 2.6))
		droplets.append({"node": drop, "vel": vel})

	var tw = create_tween()
	tw.tween_method(func(t: float):
		if not is_instance_valid(burst_root):
			return
		for d in droplets:
			var n: Node3D = d["node"]
			var v: Vector3 = d["vel"]
			if is_instance_valid(n):
				n.position = v * t + Vector3(0, -6.5 * t * t, 0)
				n.scale = Vector3.ONE * max(0.05, 1.0 - t * 1.6)
	, 0.0, 0.55, 0.55)
	tw.tween_callback(burst_root.queue_free)

# --- WEAPON INVENTORY, PICKUP & COMBAT DEFENSE METHODS ---
func pickup_weapon(weapon_name: String, val: float) -> void:
	var hud_node = _get_hud()
	match weapon_name.to_lower():
		"taser":
			if has_taser:
				taser_ammo = 1
				if hud_node and hud_node.has_method("show_toast"):
					hud_node.show_toast("⚡ STUN GUN RELOADED (1 SHOT — 11 STEPS)", Color(0.3, 0.9, 1.0))
			else:
				has_taser = true
				taser_ammo = 1
				if hud_node and hud_node.has_method("show_toast"):
					hud_node.show_toast("⚡ ACQUIRED STUN GUN [2] (1 SHOT — 11 STEPS RANGE)", Color(0.3, 0.9, 1.0))
				equip_weapon(WeaponType.TASER)
			SoundEffects.play(SoundEffects.snd_pickup, 0.0, 1.15)
		"baton":
			if has_baton:
				if val > baton_durability:
					baton_durability = val
					if hud_node and hud_node.has_method("show_toast"):
						hud_node.show_toast("🛡 SHOCK BATON REPLACED (DURABILITY RESTORED TO %d%%)" % int(baton_durability), Color(0.4, 0.9, 1.0))
				else:
					if hud_node and hud_node.has_method("show_toast"):
						hud_node.show_toast("EXISTING BATON HAS HIGHER DURABILITY (%d%%)" % int(baton_durability), Color(0.8, 0.8, 0.8))
			else:
				has_baton = true
				baton_durability = val
				if hud_node and hud_node.has_method("show_toast"):
					hud_node.show_toast("🛡 ACQUIRED SHOCK BATON [3] (100% DURABILITY / RMB=BLOCK & PARRY)", Color(0.4, 0.9, 1.0))
				equip_weapon(WeaponType.BATON)
			SoundEffects.play(SoundEffects.snd_pickup, 0.0, 0.95)
	_sync_hud_inventory()

func equip_weapon(w_type: WeaponType) -> void:
	if w_type == WeaponType.TASER and not has_taser:
		var hud = _get_hud()
		if hud and hud.has_method("show_toast"):
			hud.show_toast("NO STUN GUN IN INVENTORY", Color(0.8, 0.5, 0.2))
		return
	if w_type == WeaponType.BATON and (not has_baton or baton_durability <= 0.0):
		var hud = _get_hud()
		if hud and hud.has_method("show_toast"):
			hud.show_toast("NO SHOCK BATON IN INVENTORY", Color(0.8, 0.5, 0.2))
		return

	current_weapon = w_type
	is_guarding = false
	guard_timer = 0.0
	_update_weapon_visuals()
	SoundEffects.play(SoundEffects.snd_click, -3.0, 1.25)

func consume_taser() -> void:
	has_taser = false
	taser_ammo = 0
	var hud = _get_hud()
	if hud and hud.has_method("show_toast"):
		hud.show_toast("STUN GUN DISCHARGED & DISCARDED — EQUIPPED MOP [Q]", Color(0.9, 0.85, 0.3))
	equip_weapon(WeaponType.MOP)
	_sync_hud_inventory()

func consume_baton_durability(cost: float) -> void:
	baton_durability = max(0.0, baton_durability - cost)
	if baton_durability <= 0.0:
		has_baton = false
		baton_durability = 0.0
		is_guarding = false
		guard_timer = 0.0
		SoundEffects.play(SoundEffects.snd_shatter, 2.0)
		var hud = _get_hud()
		if hud and hud.has_method("show_toast"):
			hud.show_toast("💥 CRACK! SHOCK BATON SHATTERED — RETURNING TO MOP [Q]", Color(1.0, 0.25, 0.25))
		equip_weapon(WeaponType.MOP)
	_sync_hud_inventory()

func reset_weapons() -> void:
	has_taser = false
	taser_ammo = 0
	has_baton = false
	baton_durability = 0.0
	is_guarding = false
	guard_timer = 0.0
	current_weapon = WeaponType.MOP
	_update_weapon_visuals()

func is_baton_defending() -> bool:
	return current_weapon == WeaponType.BATON and is_guarding and has_baton and baton_durability > 0.0

func is_baton_parrying() -> bool:
	return is_baton_defending() and guard_timer <= PARRY_WINDOW

func is_baton_blocking() -> bool:
	return is_baton_defending() and guard_timer > PARRY_WINDOW

func on_successful_parry(monster_node: Node3D) -> void:
	SoundEffects.play(SoundEffects.snd_parry, 3.5, randf_range(0.96, 1.04))
	add_camera_shake(0.48)
	parry_recoil_timer = 0.22
	var spark_pos = monster_node.global_position + Vector3(0, 1.2, 0) if is_instance_valid(monster_node) else (global_position - camera.global_transform.basis.z * 1.5 + Vector3(0, 1.2, 0))
	_spawn_parry_spark(spark_pos)

func on_successful_block(monster_node: Node3D) -> void:
	SoundEffects.play(SoundEffects.snd_block, 2.8, randf_range(0.92, 1.05))
	consume_baton_durability(8.0)
	add_camera_shake(0.62)
	block_recoil_timer = 0.28

	# Bounces monster and player away from each other by 3 steps (5.4m total separation)
	if is_instance_valid(monster_node):
		var push = (global_position - monster_node.global_position)
		push.y = 0.0
		if push.length_squared() < 0.02:
			push = -camera.global_transform.basis.z
			push.y = 0.0
		push = push.normalized()

		# Player pushed backward 2.7m
		var test_p = global_position + push * 2.7
		global_position = test_p
		# Monster pushed backward 2.7m
		monster_node.global_position -= push * 2.7

	_spawn_block_burst(global_position - camera.global_transform.basis.z * 1.1 + Vector3(0, 1.1, 0))

func trigger_baton_swing_animation(hit_type: String = "miss") -> void:
	if is_swinging_baton and baton_swing_timer < 0.12:
		return
	is_swinging_baton = true
	baton_swing_timer = 0.0
	SoundEffects.play(SoundEffects.snd_swing, 2.0, 1.45 if hit_type == "miss" else 1.1)
	if hit_type != "miss":
		add_camera_shake(0.52 if hit_type == "hunter" else 0.35)
		_spawn_mop_hit_burst(hit_type)

func trigger_taser_fire_animation() -> void:
	is_firing_taser = true
	taser_fire_timer = 0.0
	add_camera_shake(0.35)
	camera_rotation_x = clampf(camera_rotation_x + 0.05, -deg_to_rad(85), deg_to_rad(85))
	if taser_flash_light:
		taser_flash_light.light_energy = 3.5

func _spawn_parry_spark(pos: Vector3) -> void:
	var spark_root = Node3D.new()
	spark_root.position = pos
	get_parent().add_child(spark_root)

	var light = OmniLight3D.new()
	light.light_color = Color(0.4, 0.9, 1.0)
	light.light_energy = 3.5
	light.omni_range = 4.0
	spark_root.add_child(light)

	var spark_mat = StandardMaterial3D.new()
	spark_mat.albedo_color = Color(0.6, 0.95, 1.0)
	spark_mat.emission_enabled = true
	spark_mat.emission = Color(0.7, 0.98, 1.0)
	spark_mat.emission_energy_multiplier = 4.0

	var sparks: Array[Dictionary] = []
	for i in range(16):
		var sp = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(0.02, 0.02, 0.08)
		sp.mesh = box
		sp.material_override = spark_mat
		spark_root.add_child(sp)
		var v = Vector3(randf_range(-4.5, 4.5), randf_range(-2.0, 5.0), randf_range(-4.5, 4.5))
		sparks.append({"node": sp, "vel": v})

	var tw = create_tween()
	tw.tween_method(func(t: float):
		if not is_instance_valid(spark_root):
			return
		light.light_energy = max(0.0, 3.5 * (1.0 - t * 3.5))
		for s in sparks:
			var n: Node3D = s["node"]
			var v: Vector3 = s["vel"]
			if is_instance_valid(n):
				n.position = v * t
				n.scale = Vector3.ONE * max(0.02, 1.0 - t * 3.0)
	, 0.0, 0.35, 0.35)
	tw.tween_callback(spark_root.queue_free)

func _spawn_block_burst(pos: Vector3) -> void:
	var root = Node3D.new()
	root.position = pos
	get_parent().add_child(root)

	var ring = MeshInstance3D.new()
	var tor = TorusMesh.new()
	tor.inner_radius = 0.15
	tor.outer_radius = 0.22
	ring.mesh = tor
	var r_mat = StandardMaterial3D.new()
	r_mat.albedo_color = Color(0.3, 0.7, 1.0, 0.8)
	r_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	r_mat.emission_enabled = true
	r_mat.emission = Color(0.2, 0.7, 1.0)
	r_mat.emission_energy_multiplier = 2.0
	ring.material_override = r_mat
	root.add_child(ring)

	var tw = create_tween()
	tw.tween_method(func(t: float):
		if not is_instance_valid(root): return
		ring.scale = Vector3.ONE * (1.0 + t * 4.5)
		r_mat.albedo_color.a = max(0.0, 0.8 * (1.0 - t * 2.5))
	, 0.0, 0.35, 0.35)
	tw.tween_callback(root.queue_free)

# Starts the 4-stage Crawler face-latch & rip-off sequence matching HTML triggerBite / updateBiteScene
func start_crawler_bite_sequence(crawler_node: Node3D, p_bite_num: int, p_fatal: bool = false) -> void:
	if in_bite_sequence or in_death_sequence:
		return
	in_bite_sequence = true
	bite_stage = 0
	bite_timer = 0.0
	bite_hit_t = 0.0
	bite_next_pulse = 0.0
	bite_crawler = crawler_node
	bite_num = p_bite_num
	bite_fatal = p_fatal
	last_frame_move_dist = 0.0
	velocity = Vector3.ZERO

	if is_instance_valid(bite_crawler):
		bite_crawler.set("active", false)
		bite_crawler.set("is_active", false)
		bite_crawler.set("latched", true)
		var wp = bite_crawler.global_position
		if bite_crawler.get_parent():
			bite_crawler.get_parent().remove_child(bite_crawler)
		camera.add_child(bite_crawler)
		bite_crawler.global_position = wp
		bite_crawler.rotation = Vector3(0, PI, 0)
		bite_crawler.scale = Vector3.ONE

	SoundEffects.play(SoundEffects.snd_screech, 2.0, 1.35)
	add_camera_shake(0.75)

func _update_bite_sequence(delta: float) -> void:
	bite_timer += delta
	var t = bite_timer
	var hud_node = get_tree().root.find_child("HUD", true, false)

	if not is_instance_valid(bite_crawler):
		in_bite_sequence = false
		bite_sequence_finished.emit(bite_num, bite_fatal)
		return

	if bite_stage == 0:
		# Stage 0 (0.0 - 0.3s): Leaps onto camera face
		bite_crawler.position = bite_crawler.position.lerp(BITE_LOCAL_POS, min(1.0, delta * 14.0))
		bite_crawler.rotation = Vector3(0.25, PI, 0.0)
		add_camera_shake(0.35)
		if t > 0.30:
			bite_stage = 1
			SoundEffects.play(SoundEffects.snd_screech, 3.0, 1.5)
	elif bite_stage == 1:
		# Stage 1 (0.3 - 1.85s): Thrashing violently in player's face while arms struggle
		bite_crawler.position = Vector3(
			BITE_LOCAL_POS.x + sin(t * 38.0) * 0.032,
			BITE_LOCAL_POS.y + cos(t * 31.0) * 0.026,
			BITE_LOCAL_POS.z + sin(t * 22.0) * 0.040
		)
		bite_crawler.rotation = Vector3(sin(t * 23.0) * 0.28, PI + sin(t * 19.0) * 0.2, sin(t * 29.0) * 0.45)
		camera_roll = sin(t * 17.0) * 0.075
		add_camera_shake(0.45 * delta * 10.0)
		if arms_root:
			arms_root.position = Vector3(sin(t * 24.0) * 0.04, -0.14 + cos(t * 20.0) * 0.03, -0.34)
			arms_root.rotation = Vector3(-0.28 + sin(t * 19.0) * 0.20, 0.0, sin(t * 15.0) * 0.14)
		if t > bite_next_pulse:
			bite_next_pulse = t + 0.36
			SoundEffects.play_heartbeat()
			SoundEffects.play(SoundEffects.snd_growl, 2.0, 1.55)
			if hud_node and hud_node.has_method("flash_damage"):
				hud_node.flash_damage()
		if t > 1.85:
			# Stage 2: Player rips crawler off and slams/throws it forward with the mop!
			bite_stage = 2
			var world_xform = bite_crawler.global_transform
			camera.remove_child(bite_crawler)
			get_parent().add_child(bite_crawler)
			bite_crawler.global_transform = world_xform

			var fwd = -camera.global_transform.basis.z
			fwd.y = 0.0
			if fwd.length_squared() < 0.01:
				fwd = Vector3.FORWARD
			else:
				fwd = fwd.normalized()
			bite_vel = fwd * 8.2 + Vector3(randf_range(-1.2, 1.2), 3.2, randf_range(-1.2, 1.2))
			camera_rotation_x = clampf(camera_rotation_x + 0.14, -deg_to_rad(85), deg_to_rad(85))
			if arms_root:
				arms_root.rotation.x = -0.85
			add_camera_shake(0.85)
			SoundEffects.play(SoundEffects.snd_scrub, 3.0, 0.85)
			SoundEffects.play_Wet_Squish()
			if hud_node and hud_node.has_method("flash_damage"):
				hud_node.flash_damage()
			if hud_node and hud_node.has_method("show_toast"):
				hud_node.show_toast("YOU TORE IT OFF! BITTEN (%d / %d)" % [bite_num, GameData.CRAWLER_BITE_MAX], Color(1.0, 0.25, 0.25))
	elif bite_stage == 2:
		# Stage 2: Crawler tumbles through the air until hitting floor or wall
		bite_vel.y -= 14.5 * delta
		var next_pos = bite_crawler.global_position + bite_vel * delta
		var space_state = get_world_3d().direct_space_state
		var q = PhysicsRayQueryParameters3D.create(bite_crawler.global_position + Vector3(0, 0.2, 0), next_pos + Vector3(0, 0.2, 0), 1)
		var hit = space_state.intersect_ray(q)
		if not hit.is_empty():
			bite_vel.x *= -0.25
			bite_vel.z *= -0.25
		else:
			bite_crawler.global_position.x = next_pos.x
			bite_crawler.global_position.z = next_pos.z
		bite_crawler.global_position.y = min(3.4, next_pos.y)
		bite_crawler.rotation.x += 12.0 * delta
		bite_crawler.rotation.z += 9.0 * delta
		if arms_root:
			arms_root.rotation.x = lerpf(arms_root.rotation.x, 0.0, delta * 6.0)
		camera_roll = lerpf(camera_roll, 0.0, delta * 6.0)
		if bite_crawler.global_position.y <= 0.12 or not hit.is_empty():
			bite_stage = 3
			bite_hit_t = t
			bite_crawler.global_position.y = 0.06
			bite_crawler.rotation = Vector3(0, randf() * TAU, 0)
			bite_crawler.scale = Vector3(1.5, 0.18, 1.5)
			_spawn_floor_splat(bite_crawler.global_position)
			SoundEffects.play_Wet_Squish()
	elif bite_stage == 3:
		# Stage 3: Splat on floor, then return control to player
		if arms_root:
			arms_root.rotation = arms_root.rotation.lerp(Vector3.ZERO, delta * 8.0)
			arms_root.position = arms_root.position.lerp(Vector3(0.0, -0.22, -0.42), delta * 8.0)
		camera_roll = lerpf(camera_roll, 0.0, delta * 8.0)
		if t - bite_hit_t > 0.65:
			if is_instance_valid(bite_crawler):
				bite_crawler.set("is_dead", true)
				bite_crawler.queue_free()
			bite_crawler = null
			camera_roll = 0.0
			in_bite_sequence = false
			reset_step_tracker()
			bite_sequence_finished.emit(bite_num, bite_fatal)

func _spawn_floor_splat(pos: Vector3) -> void:
	var splat = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.55
	cyl.bottom_radius = 0.58
	cyl.height = 0.012
	splat.mesh = cyl
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.01, 0.03, 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.2
	splat.material_override = mat
	splat.position = Vector3(pos.x, 0.02, pos.z)
	get_parent().add_child(splat)

# Locks camera and whips view toward killer for a terrifying jumpscare before GameOverScreen
func start_death_sequence(killer_node: Node3D, style: String, duration: float, on_done: Callable) -> void:
	if is_dead:
		return
	is_dead = true
	if is_hiding:
		is_hiding = false
		var hud_node = get_tree().root.find_child("HUD", true, false)
		if hud_node and hud_node.has_method("set_locker_overlay"):
			hud_node.set_locker_overlay(false)
	in_death_sequence = true
	death_timer = 0.0
	death_duration = duration
	death_target_node = killer_node
	death_style = style
	death_callback = on_done
	set_meta("_statue_snapped", false)
	set_meta("_strangle_snapped", false)
	set_meta("_suffocate_gasp_t", 0.0)
	set_meta("_hanger_snapped", false)
	set_meta("_locker_stabbed", false)
	last_frame_move_dist = 0.0
	velocity = Vector3.ZERO
	if arms_root:
		# Keep arms visible during cloak_strangle so player sees their arms struggling against the coiling cloth!
		arms_root.visible = (style == "cloak_strangle")
	add_camera_shake(0.55 if style == "cloak_suffocate" else 1.1)

func notify_inside_cloak(cloak_node: Node3D, delta: float) -> void:
	if in_death_sequence or in_bite_sequence or is_hiding:
		return
	is_inside_cloak = true
	_cloak_touch_grace = 0.20
	_active_cloak_ref = cloak_node
	if not god_mode:
		cloak_digest_timer += delta
		var ratio: float = clampf(cloak_digest_timer / CLOAK_MAX_DIGEST, 0.0, 1.0)

		# Accelerating labored breathing -> rapid hyperventilation as oxygen runs out
		if ratio > 0.16:
			_cloak_breath_timer -= delta
			if _cloak_breath_timer <= 0.0:
				# Interval shrinks from 1.05s down to 0.25s (rapid hyperventilation!)
				_cloak_breath_timer = lerpf(1.05, 0.25, pow(ratio, 1.25))
				SoundEffects.play_breath_gasp(ratio)
				if ratio > 0.45:
					add_camera_shake(0.08 + ratio * 0.14)

		if _cloak_warn_cooldown > 0.0:
			_cloak_warn_cooldown = max(0.0, _cloak_warn_cooldown - delta)
		if cloak_digest_timer >= 2.6 and _cloak_warn_cooldown <= 0.0:
			_cloak_warn_cooldown = 1.6
			var hud_node = get_tree().root.find_child("HUD", true, false)
			if hud_node and hud_node.has_method("show_toast"):
				if ratio < 0.65:
					hud_node.show_toast("⚠ HARD TO BREATHE INSIDE THE CLOAK — VISION BLURRING! (%.1fs)" % max(0.0, CLOAK_MAX_DIGEST - cloak_digest_timer), Color(0.92, 0.55, 1.0))
				else:
					hud_node.show_toast("⚠ HYPERVENTILATING — STEP OUT OF THE CLOAK BEFORE YOU SUFFOCATE! (%.1fs)" % max(0.0, CLOAK_MAX_DIGEST - cloak_digest_timer), Color(1.0, 0.25, 0.35))

		if cloak_digest_timer >= CLOAK_MAX_DIGEST:
			cloak_digest_timer = CLOAK_MAX_DIGEST
			if is_instance_valid(cloak_node) and cloak_node.has_method("trigger_suffocation_kill"):
				cloak_node.trigger_suffocation_kill()

func snare_by_hanger(hanger_ref: Node3D) -> void:
	if in_death_sequence or is_hiding or god_mode:
		return
	is_hanged_by_hanger = true
	hanger_node = hanger_ref
	hanger_struggle_timer = 0.0
	hanger_struggle_count = 0
	SoundEffects.play_cloth_wrap()
	SoundEffects.play_breath_gasp(0.8)
	add_camera_shake(0.8)

func break_free_from_hanger() -> void:
	is_hanged_by_hanger = false
	var h_ref = hanger_node
	hanger_node = null
	hanger_struggle_timer = 0.0
	hanger_struggle_count = 0
	SoundEffects.play_Wet_Squish()
	SoundEffects.play_breath_gasp(0.5)
	add_camera_shake(0.6)
	var hud_node = get_tree().root.find_child("HUD", true, false)
	if hud_node:
		if hud_node.has_method("hide_hanger_struggle"):
			hud_node.hide_hanger_struggle()
		if hud_node.has_method("show_toast"):
			hud_node.show_toast("YOU SNAPPED THE HANGER'S TONGUE AND BROKE FREE!", Color(0.2, 1.0, 0.4))
		if hud_node.has_method("set_interaction_prompt"):
			hud_node.set_interaction_prompt("")
	if is_instance_valid(h_ref) and h_ref.has_method("on_player_escaped"):
		h_ref.on_player_escaped()

func mark_dead() -> void:
	is_dead = true
	velocity = Vector3.ZERO
	last_frame_move_dist = 0.0

func reset_special_sequences() -> void:
	is_dead = false
	if in_bite_sequence and is_instance_valid(bite_crawler):
		bite_crawler.queue_free()
	bite_crawler = null
	in_bite_sequence = false
	in_death_sequence = false
	is_hanged_by_hanger = false
	hanger_node = null
	hanger_struggle_timer = 0.0
	hanger_struggle_count = 0
	is_inside_cloak = false
	cloak_digest_timer = 0.0
	_cloak_touch_grace = 0.0
	_cloak_breath_timer = 0.0
	camera_roll = 0.0
	var hud_node = get_tree().root.find_child("HUD", true, false)
	if hud_node:
		if hud_node.has_method("hide_hanger_struggle"):
			hud_node.hide_hanger_struggle()
		if hud_node.has_method("set_cloak_overlay"):
			hud_node.set_cloak_overlay("none", 0.0)
	if camera:
		camera.rotation.z = 0.0
		camera.fov = base_fov
	if arms_root:
		arms_root.visible = not is_hiding
		arms_root.position = Vector3(0.0, -0.22, -0.42)
		arms_root.rotation = Vector3.ZERO

func set_noclip(val: bool) -> void:
	noclip = val
	if not is_hiding:
		collision_shape.disabled = noclip

func enter_locker(locker_node: Node3D) -> void:
	if interact_cooldown > 0.0 or is_hiding or in_bite_sequence or in_death_sequence:
		return
	is_hiding = true
	current_locker = locker_node
	interact_cooldown = 0.28
	collision_shape.disabled = true
	velocity = Vector3.ZERO
	last_frame_move_dist = 0.0

	global_position = locker_node.to_global(Vector3(0.0, -0.05, -0.18))
	locker_base_yaw = locker_node.global_rotation.y + PI
	locker_yaw_offset = 0.0
	rotation.y = locker_base_yaw
	camera_rotation_x = 0.0
	camera.rotation.x = 0.0

	if arms_root:
		arms_root.visible = false

	SoundEffects.play(SoundEffects.snd_stone, -2.0)
	locker_state_changed.emit(true, locker_node)
	reset_step_tracker()

func exit_locker() -> void:
	if not is_hiding:
		return
	var prev_locker = current_locker
	is_hiding = false
	interact_cooldown = 0.28
	collision_shape.disabled = noclip

	if is_instance_valid(prev_locker):
		global_position = prev_locker.to_global(Vector3(0.0, 0.15, 2.8))
		rotation.y = locker_base_yaw

	current_locker = null
	if arms_root:
		arms_root.visible = true

	SoundEffects.play(SoundEffects.snd_stone, -2.0)
	locker_state_changed.emit(false, prev_locker)
	reset_step_tracker()

var flashlight_suppressed: bool = false

func set_flashlight_suppressed(suppressed: bool) -> void:
	if flashlight_suppressed == suppressed:
		return
	flashlight_suppressed = suppressed
	if flashlight_suppressed:
		flashlight.visible = false
		if fill_light:
			fill_light.visible = false
		var hud_node = get_tree().root.find_child("HUD", true, false)
		if hud_node and hud_node.has_method("update_flashlight_status"):
			hud_node.update_flashlight_status(false)
	else:
		flashlight.visible = true
		if fill_light:
			fill_light.visible = true
		var hud_node = get_tree().root.find_child("HUD", true, false)
		if hud_node and hud_node.has_method("update_flashlight_status"):
			hud_node.update_flashlight_status(true)

func _unhandled_input(event: InputEvent) -> void:
	if is_dead or in_death_sequence or in_bite_sequence:
		return

	var hud_popup = get_tree().root.find_child("HUD", true, false)
	if hud_popup and (hud_popup.game_over_screen.visible or hud_popup.note_popup.visible or hud_popup.cutscene_player.visible or hud_popup.main_menu.visible or hud_popup.pause_menu.visible):
		return

	if is_hiding:
		if event is InputEventMouseMotion and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)):
			locker_yaw_offset = clampf(locker_yaw_offset - event.relative.x * mouse_sensitivity, -0.65, 0.65)
			rotation.y = locker_base_yaw + locker_yaw_offset
			camera_rotation_x = clampf(camera_rotation_x - event.relative.y * mouse_sensitivity, -0.40, 0.40)
			camera.rotation.x = camera_rotation_x
		if interact_cooldown <= 0.0:
			var leave_key = event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E
			var leave_click = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
			if leave_key or leave_click:
				exit_locker()
		return

	if event is InputEventMouseMotion and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)):
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera_rotation_x = clampf(camera_rotation_x - event.relative.y * mouse_sensitivity, -deg_to_rad(85), deg_to_rad(85))
		camera.rotation.x = camera_rotation_x

	if event.is_action_pressed("flashlight") or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F):
		if flashlight_suppressed:
			SoundEffects.play(SoundEffects.snd_click, -4.0, 0.5)
			var hud_node = get_tree().root.find_child("HUD", true, false)
			if hud_node and hud_node.has_method("show_toast"):
				hud_node.show_toast("FLASHLIGHT FAILING — ANOMALOUS LIGHT DRAIN NEARBY!", Color(0.85, 0.4, 1.0))
			return
		flashlight.visible = !flashlight.visible
		if fill_light:
			fill_light.visible = flashlight.visible
		SoundEffects.play(SoundEffects.snd_click, -4.0)
		var hud_node = get_tree().root.find_child("HUD", true, false)
		if hud_node and hud_node.has_method("update_flashlight_status"):
			hud_node.update_flashlight_status(flashlight.visible)

	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_B:
		bait_toss_requested.emit()

	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
		override_requested.emit()

	# --- WEAPON SELECTION & INVENTORY SWAPPING (Q / 1 / 2 / 3) ---
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_Q:
			if current_weapon != WeaponType.MOP:
				equip_weapon(WeaponType.MOP)
			else:
				if has_baton:
					equip_weapon(WeaponType.BATON)
				elif has_taser:
					equip_weapon(WeaponType.TASER)
		elif event.physical_keycode == KEY_1:
			equip_weapon(WeaponType.MOP)
		elif event.physical_keycode == KEY_2:
			equip_weapon(WeaponType.TASER)
		elif event.physical_keycode == KEY_3:
			equip_weapon(WeaponType.BATON)

	# --- SHOCK BATON GUARD & PARRY (RMB) ---
	if current_weapon == WeaponType.BATON and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			is_guarding = true
			guard_timer = 0.0
			_update_weapon_visuals()
		else:
			is_guarding = false
			guard_timer = 0.0
			_update_weapon_visuals()

	if interact_cooldown <= 0.0:
		var is_e = event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E
		var is_lmb = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
		if is_e or is_lmb:
			var interacted = _handle_interaction()
			if not interacted and is_lmb and not is_guarding:
				if current_weapon == WeaponType.MOP:
					mop_strike_requested.emit()
				elif current_weapon == WeaponType.BATON:
					weapon_attack_requested.emit(int(WeaponType.BATON))
				elif current_weapon == WeaponType.TASER:
					weapon_attack_requested.emit(int(WeaponType.TASER))

func _physics_process(delta: float) -> void:
	# Keep current_floor synchronized based on vertical elevation (Floor 2 is at 11.4m, Floor 1 is at 0.0m)
	current_floor = 2 if global_position.y >= 6.0 else 1

	if interact_cooldown > 0.0:
		interact_cooldown = max(0.0, interact_cooldown - delta)

	if is_guarding:
		guard_timer += delta
	if parry_recoil_timer > 0.0:
		parry_recoil_timer = max(0.0, parry_recoil_timer - delta)
	if block_recoil_timer > 0.0:
		block_recoil_timer = max(0.0, block_recoil_timer - delta)

	if _cloak_touch_grace > 0.0:
		_cloak_touch_grace = max(0.0, _cloak_touch_grace - delta)
		is_inside_cloak = true
	else:
		is_inside_cloak = false
		cloak_digest_timer = max(0.0, cloak_digest_timer - delta * 1.8)

	if not in_death_sequence:
		var hud_clk = get_tree().root.find_child("HUD", true, false)
		if hud_clk and hud_clk.has_method("set_cloak_overlay"):
			if is_inside_cloak or cloak_digest_timer > 0.01:
				var vis_r: float = clampf(max(0.18 if is_inside_cloak else 0.0, cloak_digest_timer / CLOAK_MAX_DIGEST), 0.0, 1.0)
				hud_clk.set_cloak_overlay("suffocate", vis_r)
			else:
				hud_clk.set_cloak_overlay("none", 0.0)

	if camera_shake_trauma > 0.0:
		camera_shake_trauma = max(0.0, camera_shake_trauma - delta * 2.4)
		var shake = camera_shake_trauma * camera_shake_trauma * 0.055
		camera.h_offset = randf_range(-shake, shake)
		camera.v_offset = randf_range(-shake, shake)
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0

	if in_death_sequence:
		last_frame_move_dist = 0.0
		death_timer += delta
		var base_killer_yaw: float = rotation.y
		var want_pitch: float = 0.0
		if is_instance_valid(death_target_node) and death_style != "cloak_suffocate" and death_style != "cloak_strangle":
			var target_face = death_target_node.global_position + Vector3(0, 2.05 if death_style != "statue" else 1.88, 0)
			var to_killer = target_face - camera.global_position
			if Vector2(to_killer.x, to_killer.z).length_squared() > 0.002:
				base_killer_yaw = atan2(-to_killer.x, -to_killer.z)
			var flat_len = max(0.01, Vector2(to_killer.x, to_killer.z).length())
			want_pitch = clampf(atan2(to_killer.y, flat_len), -0.8, 0.85)

		if death_style == "cloak_suffocate":
			# Suffocation Death (hiding inside Cloak too long):
			# Rapid hyperventilation gasps, dizzy swaying head, vision blurring completely into black
			var p: float = clampf(death_timer / max(0.01, death_duration), 0.0, 1.0)
			var hud_node = get_tree().root.find_child("HUD", true, false)
			if hud_node and hud_node.has_method("set_cloak_overlay"):
				hud_node.set_cloak_overlay("suffocate", lerpf(0.82, 1.0, p))

			var gasp_t: float = float(get_meta("_suffocate_gasp_t", 0.0)) - delta
			if gasp_t <= 0.0 and death_timer < 1.35:
				gasp_t = 0.24
				SoundEffects.play_breath_gasp(1.0)
				add_camera_shake(0.22)
			set_meta("_suffocate_gasp_t", gasp_t)

			# Head sways dizzily with hyperventilation then droops forward as player blacks out
			camera_rotation_x = lerpf(camera_rotation_x, -0.58 * ease(p, 1.6) + sin(death_timer * 24.0) * 0.06 * (1.0 - p), min(1.0, delta * 10.0))
			camera_roll = lerpf(camera_roll, 0.46 * ease(p, 1.4) + cos(death_timer * 18.0) * 0.08, min(1.0, delta * 10.0))
			if camera:
				camera.fov = lerpf(camera.fov, base_fov - 18.0, min(1.0, delta * 8.0))

		elif death_style == "cloak_strangle":
			# Strangulation Death (player hit Cloak -> cloth coils around body, then strangles neck):
			# Stage 1 (0.0s -> 1.10s): Dark cloth bands wrap tightly around torso & arms while hands struggle
			# Stage 2 (1.10s -> 1.95s): Cloth cinches violently around the throat and snaps/strangles the neck!
			var p_all: float = clampf(death_timer / max(0.01, death_duration), 0.0, 1.0)
			var hud_node = get_tree().root.find_child("HUD", true, false)
			if hud_node and hud_node.has_method("set_cloak_overlay"):
				hud_node.set_cloak_overlay("strangle", p_all)

			if death_timer < 1.10:
				var wrap_p: float = clampf(death_timer / 1.10, 0.0, 1.0)
				var gasp_t: float = float(get_meta("_suffocate_gasp_t", 0.0)) - delta
				if gasp_t <= 0.0:
					gasp_t = 0.30
					SoundEffects.play_cloth_wrap()
					SoundEffects.play_breath_gasp(0.95)
				set_meta("_suffocate_gasp_t", gasp_t)

				# Camera shudders as cloth coils tighten around chest and neck
				camera_rotation_x = lerpf(camera_rotation_x, 0.14 * wrap_p + sin(death_timer * 32.0) * 0.04, min(1.0, delta * 14.0))
				camera_roll = sin(death_timer * 28.0) * 0.14 * wrap_p
				add_camera_shake(0.32 * delta * 10.0)
				if arms_root:
					arms_root.visible = true
					arms_root.position = Vector3(sin(death_timer * 36.0) * 0.045, -0.10 + sin(death_timer * 24.0) * 0.03, -0.34)
					arms_root.rotation = Vector3(0.42 + sin(death_timer * 30.0) * 0.12, 0.0, cos(death_timer * 26.0) * 0.22)
			else:
				if not get_meta("_strangle_snapped", false):
					set_meta("_strangle_snapped", true)
					SoundEffects.play_cloth_wrap()
					SoundEffects.play(SoundEffects.snd_click, 6.0, 0.44)
					SoundEffects.play_Wet_Squish()
					add_camera_shake(1.45)
					if hud_node and hud_node.has_method("flash_damage"):
						hud_node.flash_damage()
				# Violent neck strangulation wrench upward & sideways as windpipe is crushed
				camera_rotation_x = lerpf(camera_rotation_x, 0.44, min(1.0, delta * 24.0))
				camera_roll = lerpf(camera_roll, -1.12, min(1.0, delta * 24.0))
				if camera:
					camera.fov = lerpf(camera.fov, base_fov - 16.0, min(1.0, delta * 12.0))
				if arms_root:
					arms_root.position = arms_root.position.lerp(Vector3(0.0, -0.48, -0.40), min(1.0, delta * 10.0))

		elif death_style == "statue":
			# 2-Stage Weeping Statue Neck-Snap Animation:
			# Stage 1 (0.0s -> 0.72s): Stone hands grip the player's head and gradually force it sideways horizontally.
			# Stage 2 (0.72s -> 1.45s): Violent horizontal neck-snap (+100 deg yaw wrench + 82 deg roll + crunch SFX).
			if death_timer < 0.72:
				var p = clampf(death_timer / 0.72, 0.0, 1.0)
				var slow_turn = ease(p, 1.8) * 0.92 # Gradually twists head ~53 degrees sideways
				rotation.y = lerp_angle(rotation.y, base_killer_yaw + slow_turn, min(1.0, delta * 14.0))
				camera_rotation_x = lerpf(camera_rotation_x, want_pitch + 0.08 * p, min(1.0, delta * 14.0))
				camera_roll = lerpf(camera_roll, 0.42 * p + sin(death_timer * 45.0) * 0.025, min(1.0, delta * 14.0))
				add_camera_shake(0.28 * delta * 10.0)
			else:
				if not get_meta("_statue_snapped", false):
					set_meta("_statue_snapped", true)
					SoundEffects.play(SoundEffects.snd_click, 6.0, 0.42)
					SoundEffects.play_stone_grind()
					add_camera_shake(1.45)
					var hud_node = get_tree().root.find_child("HUD", true, false)
					if hud_node and hud_node.has_method("flash_damage"):
						hud_node.flash_damage()
				# Violent snap sideways horizontally (~102 degrees yaw + ~82 degrees roll)
				rotation.y = lerp_angle(rotation.y, base_killer_yaw + 1.78, min(1.0, delta * 32.0))
				camera_rotation_x = lerpf(camera_rotation_x, -0.22, min(1.0, delta * 26.0))
				camera_roll = lerpf(camera_roll, 1.42, min(1.0, delta * 28.0))
				if camera:
					camera.fov = lerpf(camera.fov, base_fov - 12.0, min(1.0, delta * 12.0))
		elif death_style == "hanger":
			camera_rotation_x = lerpf(camera_rotation_x, deg_to_rad(75.0), min(1.0, delta * 12.0))
			camera_roll = sin(death_timer * 18.0) * 0.22
			add_camera_shake(0.45 * delta * 10.0)
			if death_timer > 0.65 and not get_meta("_hanger_snapped", false):
				set_meta("_hanger_snapped", true)
				SoundEffects.play(SoundEffects.snd_click, 6.0, 0.44)
				SoundEffects.play_Wet_Squish()
				add_camera_shake(1.5)
				var hud_node = get_tree().root.find_child("HUD", true, false)
				if hud_node and hud_node.has_method("flash_damage"):
					hud_node.flash_damage()
		elif death_style == "locker_stab":
			camera_rotation_x = lerpf(camera_rotation_x, deg_to_rad(-15.0), min(1.0, delta * 10.0))
			camera_roll = sin(death_timer * 35.0) * 0.35
			add_camera_shake(1.2 * delta * 10.0)
			if death_timer > 0.25 and not get_meta("_locker_stabbed", false):
				set_meta("_locker_stabbed", true)
				SoundEffects.play_hunter_screech()
				SoundEffects.play_Wet_Squish()
				SoundEffects.play(SoundEffects.snd_click, 6.0, 0.35)
				add_camera_shake(1.8)
				var hud_node = get_tree().root.find_child("HUD", true, false)
				if hud_node and hud_node.has_method("flash_damage"):
					hud_node.flash_damage()
		else:
			rotation.y = lerp_angle(rotation.y, base_killer_yaw, min(1.0, delta * 18.0))
			camera_rotation_x = lerpf(camera_rotation_x, want_pitch, min(1.0, delta * 18.0))
			camera_roll = sin(death_timer * 28.0) * 0.08
			add_camera_shake(0.35 * delta * 10.0)

		camera.rotation.x = camera_rotation_x
		camera.rotation.z = camera_roll
		if death_timer >= death_duration:
			in_death_sequence = false
			if death_callback.is_valid():
				death_callback.call()
		return

	if is_dead:
		velocity = Vector3.ZERO
		last_frame_move_dist = 0.0
		return

	if in_bite_sequence:
		last_frame_move_dist = 0.0
		_update_bite_sequence(delta)
		camera.rotation.x = camera_rotation_x
		camera.rotation.z = camera_roll
		return

	if is_hanged_by_hanger:
		velocity = Vector3.ZERO
		last_frame_move_dist = 0.0
		hanger_struggle_timer += delta

		# Look upward toward Hanger hanging from ceiling
		camera_rotation_x = lerpf(camera_rotation_x, deg_to_rad(65.0), min(1.0, delta * 8.0))
		camera.rotation.x = camera_rotation_x
		camera_roll = sin(hanger_struggle_timer * 12.0) * 0.08
		camera.rotation.z = camera_roll

		var hud_node = get_tree().root.find_child("HUD", true, false)
		var time_left = max(0.0, 5.0 - hanger_struggle_timer)
		if hud_node:
			if hud_node.has_method("show_hanger_struggle"):
				hud_node.show_hanger_struggle(time_left, hanger_struggle_count, hanger_required_struggles)
			if hud_node.has_method("set_interaction_prompt"):
				hud_node.set_interaction_prompt("⚠ HANGED FROM CEILING! SPAM [SPACE] TO BREAK FREE! (%.1fs) [%d/%d]" % [time_left, hanger_struggle_count, hanger_required_struggles])

		# Player struggles by spamming Space
		if Input.is_action_just_pressed("jump") or Input.is_physical_key_pressed(KEY_SPACE):
			hanger_struggle_count += 1
			add_camera_shake(0.35)
			SoundEffects.play_breath_gasp(1.0)
			if hanger_struggle_count >= hanger_required_struggles:
				break_free_from_hanger()
				return

		if hanger_struggle_timer >= 5.0:
			is_hanged_by_hanger = false
			if hud_node and hud_node.has_method("hide_hanger_struggle"):
				hud_node.hide_hanger_struggle()
			var h_ref = hanger_node
			start_death_sequence(h_ref, "hanger", 1.8, func():
				var main_node = get_tree().root.find_child("Main", true, false)
				if main_node and main_node.has_method("game_over"):
					main_node.game_over("STRANGLED AND HUNG FROM THE CEILING BY THE HANGER.")
			)
			return
		return

	_update_interaction_prompt()

	if is_hiding:
		velocity = Vector3.ZERO
		last_frame_move_dist = 0.0
		return

	if not noclip and not is_on_floor():
		velocity.y -= 18.0 * delta
	elif noclip:
		velocity.y = 0.0

	# Support Arrow-Key camera look (especially convenient while F9 Debug Panel is open)
	var look_yaw := 0.0
	var look_pitch := 0.0
	if Input.is_physical_key_pressed(KEY_LEFT): look_yaw += 1.0
	if Input.is_physical_key_pressed(KEY_RIGHT): look_yaw -= 1.0
	if Input.is_physical_key_pressed(KEY_UP): look_pitch += 1.0
	if Input.is_physical_key_pressed(KEY_DOWN): look_pitch -= 1.0
	if look_yaw != 0.0 or look_pitch != 0.0:
		rotate_y(look_yaw * 2.1 * delta)
		camera_rotation_x = clampf(camera_rotation_x + look_pitch * 1.6 * delta, -deg_to_rad(85), deg_to_rad(85))
		camera.rotation.x = camera_rotation_x

	var wants_sprint = (Input.is_action_pressed("sprint") or Input.is_physical_key_pressed(KEY_SHIFT)) and (stamina > 5.0 or god_mode)
	var input_dir = Vector2.ZERO
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if Input.is_action_pressed("move_forward") or Input.is_physical_key_pressed(KEY_W): input_dir.y -= 1
		if Input.is_action_pressed("move_backward") or Input.is_physical_key_pressed(KEY_S): input_dir.y += 1
		if Input.is_action_pressed("move_left") or Input.is_physical_key_pressed(KEY_A): input_dir.x -= 1
		if Input.is_action_pressed("move_right") or Input.is_physical_key_pressed(KEY_D): input_dir.x += 1
		input_dir = input_dir.normalized()

	is_sprinting = wants_sprint and input_dir.length() > 0.1
	var current_speed = sprint_speed if is_sprinting else walk_speed
	if noclip:
		current_speed *= 1.65

	if god_mode or noclip:
		stamina = max_stamina
	elif is_sprinting:
		stamina = max(0.0, stamina - stamina_drain * delta)
	else:
		stamina = min(max_stamina, stamina + stamina_recovery * delta)

	# Smooth sprint FOV kick (matching HTML _fovKick += ((isSprinting ? 9 : 0) - _fovKick) * delta * 6)
	var target_fov_kick = 8.5 if is_sprinting else 0.0
	fov_kick = lerpf(fov_kick, target_fov_kick, min(1.0, delta * 6.0))
	if camera:
		camera.fov = base_fov + fov_kick

	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	breath_timer += delta * 1.4
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed

		bob_timer += delta * (14.0 if is_sprinting else 9.0)
		camera.position.y = sin(bob_timer) * (0.065 if is_sprinting else 0.038)
		camera_roll = sin(bob_timer * 0.5) * (0.015 if is_sprinting else 0.006)

		step_timer += delta * (current_speed / walk_speed)
		if step_timer > 0.44:
			step_timer = 0.0
			SoundEffects.play(SoundEffects.snd_step, -12.0, randf_range(0.95, 1.05))
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed * 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0, current_speed * 10.0 * delta)
		if Vector2(velocity.x, velocity.z).length() < 0.08:
			velocity.x = 0.0
			velocity.z = 0.0
		camera.position.y = lerpf(camera.position.y, 0.0, delta * 10.0)
		camera_roll = lerpf(camera_roll, 0.0, delta * 10.0)

	camera.rotation.z = camera_roll
	move_and_slide()

	# Track actual horizontal distance walked for the STEP counter & step-linked enemy AI
	var cur_flat = Vector2(global_position.x, global_position.z)
	if _has_last_pos:
		var moved = cur_flat.distance_to(_last_flat_pos)
		if input_dir.length() < 0.05 and moved < 0.008:
			moved = 0.0
		if moved > 0.001 and moved < 4.0:
			last_frame_move_dist = moved
			step_dist_accum += moved
			while step_dist_accum >= GameData.STEP_THRESH:
				step_dist_accum -= GameData.STEP_THRESH
				step_taken.emit()
		else:
			last_frame_move_dist = 0.0
	else:
		last_frame_move_dist = 0.0
	_last_flat_pos = cur_flat
	_has_last_pos = true

	_update_two_handed_arms_animation(delta, direction.length() > 0.1)

func _update_interaction_prompt() -> void:
	var hud_node = get_tree().root.find_child("HUD", true, false)
	if not hud_node or not hud_node.has_method("set_interaction_prompt"):
		return

	if is_hiding:
		hud_node.set_interaction_prompt("[E] Leave Locker  •  Move Mouse to Peek")
		return

	interaction_ray.force_raycast_update()
	if interaction_ray.is_colliding():
		var collider = interaction_ray.get_collider()
		if collider and collider.get("prompt_text"):
			hud_node.set_interaction_prompt(str(collider.get("prompt_text")))
			return

	for obj in get_tree().get_nodes_in_group("spills"):
		if is_instance_valid(obj) and not obj.get_meta("_cleaned", false):
			if global_position.distance_to(obj.global_position) < 2.6:
				hud_node.set_interaction_prompt(str(obj.get("prompt_text")))
				return

	if is_inside_cloak:
		var rem = max(0.0, CLOAK_MAX_DIGEST - cloak_digest_timer)
		if cloak_digest_timer >= 2.8:
			hud_node.set_interaction_prompt("⚠ [SUFFOCATING — VISION BLURRING & HYPERVENTILATING! STEP OUT! (%.1fs)]" % rem)
		else:
			hud_node.set_interaction_prompt("[INSIDE CLOAK CAMOUFLAGE — BREATH REMAINING: %.1fs]" % rem)
		return

	hud_node.set_interaction_prompt("")

func _update_two_handed_arms_animation(delta: float, is_moving: bool) -> void:
	if arms_root == null:
		return

	if is_swinging_mop:
		swing_timer += delta
		var p = clampf(swing_timer / SWING_DURATION, 0.0, 1.0)
		if p < 0.24:
			# Wind-up: raise mop high to the right
			var w = p / 0.24
			arms_root.position = Vector3(0.14 * w, -0.22 + 0.14 * w, -0.42 + 0.08 * w)
			arms_root.rotation = Vector3(deg_to_rad(28.0 * w), deg_to_rad(-24.0 * w), deg_to_rad(-32.0 * w))
		elif p < 0.62:
			# Heavy diagonal strike across view
			var s = (p - 0.24) / 0.38
			var arc = sin(s * PI * 0.5)
			arms_root.position = Vector3(lerpf(0.14, -0.22, arc), lerpf(-0.08, -0.28, arc), lerpf(-0.34, -0.72, sin(s * PI)))
			arms_root.rotation = Vector3(deg_to_rad(lerpf(28.0, -48.0, arc)), deg_to_rad(lerpf(-24.0, 42.0, arc)), deg_to_rad(lerpf(-32.0, 38.0, arc)))
		else:
			# Recover back to stance
			var r = (p - 0.62) / 0.38
			arms_root.position = arms_root.position.lerp(Vector3(0.0, -0.22, -0.42), r)
			arms_root.rotation = arms_root.rotation.lerp(Vector3.ZERO, r)

		# Jiggle mop yarn strands during strike
		for i in range(mop_strands.size()):
			var st = mop_strands[i]
			if is_instance_valid(st):
				st.rotation.z = sin(p * TAU * 2.0 + i) * 0.45

		if p >= 1.0:
			is_swinging_mop = false
			arms_root.position = Vector3(0.0, -0.22, -0.42)
			arms_root.rotation = Vector3.ZERO
		return

	if is_swinging_baton:
		baton_swing_timer += delta
		var p = clampf(baton_swing_timer / BATON_SWING_DURATION, 0.0, 1.0)
		var swing_sin = sin(p * PI)
		arms_root.position = Vector3(0.08 - swing_sin * 0.22, -0.18 + swing_sin * 0.06, -0.38)
		arms_root.rotation = Vector3(-swing_sin * 0.35, swing_sin * 0.65, -swing_sin * 0.75)
		if p >= 1.0:
			is_swinging_baton = false
			arms_root.position = Vector3(0.0, -0.22, -0.42)
			arms_root.rotation = Vector3.ZERO
		return

	if is_firing_taser:
		taser_fire_timer += delta
		var p = clampf(taser_fire_timer / TASER_FIRE_DURATION, 0.0, 1.0)
		var rec = (1.0 - p) * 0.12
		if taser_flash_light:
			taser_flash_light.light_energy = max(0.0, 3.5 * (1.0 - p))
		arms_root.position = Vector3(0.04, -0.18 + rec, -0.34 - rec * 0.5)
		arms_root.rotation = Vector3(rec * 1.6, -0.05, 0.0)
		if p >= 1.0:
			is_firing_taser = false
			if taser_flash_light:
				taser_flash_light.light_energy = 0.0
			arms_root.position = Vector3(0.0, -0.22, -0.42)
			arms_root.rotation = Vector3.ZERO
		return

	if is_scrubbing:
		scrub_timer += delta
		var progress = clampf(scrub_timer / SCRUB_DURATION, 0.0, 1.0)
		var scrub = sin(progress * PI * 6.0)
		var down = sin(min(1.0, progress * 2.0) * PI * 0.5)

		var pos_x = scrub * 0.15
		var pos_y = -0.22 - (down * 0.24)
		var pos_z = -0.42 - (down * 0.18)
		arms_root.position = Vector3(pos_x, pos_y, pos_z)

		var rot_x = down * deg_to_rad(36.0)
		var rot_z = scrub * deg_to_rad(22.0)
		arms_root.rotation = Vector3(rot_x, 0.0, rot_z)

		if progress >= 0.55 and not _scrub_fade_sent:
			_scrub_fade_sent = true
			for obj in get_tree().get_nodes_in_group("spills"):
				if is_instance_valid(obj) and obj.has_meta("begin_fade_fn"):
					if global_position.distance_to(obj.global_position) < 2.8:
						obj.get_meta("begin_fade_fn").call()
						break

		if progress >= 1.0:
			is_scrubbing = false
			_scrub_fade_sent = false
			arms_root.position = Vector3(0.0, -0.22, -0.42)
			arms_root.rotation = Vector3.ZERO
	else:
		if current_weapon == WeaponType.BATON and is_guarding:
			var breath_y = sin(breath_timer) * 0.003
			if guard_timer <= PARRY_WINDOW:
				# Tightly braced parry posture
				var recoil = parry_recoil_timer * 0.15
				arms_root.position = Vector3(0.0, -0.10 + breath_y, -0.32 - recoil)
				arms_root.rotation = Vector3(-0.35, 0.40, 0.52)
			else:
				# Steady block posture across chest
				var recoil = block_recoil_timer * 0.20
				arms_root.position = Vector3(0.0, -0.12 + breath_y, -0.35 - recoil)
				arms_root.rotation = Vector3(-0.25, 0.32, 0.44)
		elif current_weapon == WeaponType.TASER:
			var breath_y = sin(breath_timer) * 0.005
			var sway_x = cos(bob_timer * 0.5) * (0.015 if is_sprinting else 0.008) if is_moving else 0.0
			var sway_y = sin(bob_timer) * (0.014 if is_sprinting else 0.006) if is_moving else breath_y
			arms_root.position = Vector3(0.04 + sway_x, -0.18 + sway_y, -0.36)
			arms_root.rotation = Vector3(0.05, -0.05, 0.0)
		elif is_moving:
			var sway_x = cos(bob_timer * 0.5) * (0.024 if is_sprinting else 0.015)
			var sway_y = sin(bob_timer) * (0.022 if is_sprinting else 0.012)
			arms_root.position = Vector3(sway_x, -0.22 + sway_y, -0.42)
			arms_root.rotation.z = sin(bob_timer * 0.5) * (0.035 if is_sprinting else 0.018)
			arms_root.rotation.x = 0.0
		else:
			var breath_y = sin(breath_timer) * 0.006
			arms_root.position = Vector3(0.0, -0.22 + breath_y, -0.42)
			arms_root.rotation = Vector3.ZERO

func _handle_interaction() -> bool:
	interaction_ray.force_raycast_update()
	if interaction_ray.is_colliding():
		var collider = interaction_ray.get_collider()
		if collider and collider.has_method("interact"):
			if collider.is_in_group("spills"):
				trigger_scrub_animation()
			collider.interact(self)
			return true

	for obj in get_tree().get_nodes_in_group("spills"):
		if is_instance_valid(obj) and obj.has_method("interact") and not obj.get_meta("_cleaned", false):
			if global_position.distance_to(obj.global_position) < 2.8:
				trigger_scrub_animation()
				obj.interact(self)
				return true

	return false
