extends CharacterBody3D

# Cultist — Night 3+ robed ritual entity (ported from HTML makeCultist & updateCultists)
# Sits inside cages during Work shift, released during Chase shift.
# Obeys step-linked movement (pauses advance when player stands still).
# Wields a glowing sacrificial dagger and swinging chain censer lantern.

signal player_killed(reason: String)

const VisualMaterialFactory = preload("res://scripts/visual_material_factory.gd")

var player: CharacterBody3D = null
var active: bool = false
var is_caged: bool = false
var frozen_by_dev: bool = false
var is_dead: bool = false
var is_killing: bool = false
var is_being_executed: bool = false
var exec_timer: float = 0.0
var exec_snapped: bool = false
var head_pivot: Node3D = null

var is_snared_by_hanger: bool = false
var hanger_snare_timer: float = 0.0
var locker_banging_target: Node3D = null
var locker_knock_count: int = 0
var locker_knock_timer: float = 0.0

var move_speed: float = 4.6
var hp: int = 3
var stun_timer: float = 0.0
var chant_timer: float = 3.0
var roam_timer: float = 0.0
var roam_dir: Vector3 = Vector3.FORWARD

var caged_pos: Vector3 = Vector3.ZERO
var release_pos: Vector3 = Vector3.ZERO
var cage_bars: Node3D = null
var bait_pos: Vector3 = Vector3.ZERO
var has_bait: bool = false

var mesh_root: Node3D = null
var lantern_pivot: Node3D = null
var dagger_pivot: Node3D = null
var sigil_mesh: Node3D = null
var sigil_mat: StandardMaterial3D = null
var motes: Array[MeshInstance3D] = []
var cultist_light: OmniLight3D = null
var anim_phase: float = 0.0

func _ready() -> void:
	add_to_group("cultists")
	collision_layer = 4
	collision_mask = 1 | 8
	anim_phase = randf() * TAU
	chant_timer = randf_range(2.5, 6.0)
	_choose_new_roam_dir()
	_build_cultist_mesh()

func setup_caged(p_caged_pos: Vector3, p_release_pos: Vector3, p_bars: Node3D, p_rot: float = 0.0) -> void:
	is_caged = true
	active = false
	caged_pos = p_caged_pos
	release_pos = p_release_pos
	cage_bars = p_bars
	global_position = caged_pos
	rotation.y = p_rot

func activate() -> void:
	if is_dead:
		return
	active = true
	if is_caged:
		is_caged = false
		if is_instance_valid(cage_bars):
			var tw = create_tween()
			tw.tween_property(cage_bars, "position:y", 3.6, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		global_position = release_pos

func set_freeze(val: bool) -> void:
	frozen_by_dev = val

func set_bait(pos: Vector3) -> void:
	bait_pos = pos
	has_bait = true

func clear_bait() -> void:
	has_bait = false

func hit_by_mop() -> bool:
	if is_dead or not active or is_killing:
		return false
	stun_timer = 3.5
	SoundEffects.play_cultist_chant()
	return true

func stun(duration: float) -> void:
	if is_dead:
		return
	stun_timer = max(stun_timer, duration)
	velocity = Vector3.ZERO
	_spawn_electric_sparks(duration)
	SoundEffects.play_cultist_chant()

func _spawn_electric_sparks(duration: float) -> void:
	var spark_node = Node3D.new()
	spark_node.name = "StunSparks"
	spark_node.position = Vector3(0, 1.0, 0)
	add_child(spark_node)

	var light = OmniLight3D.new()
	light.light_color = Color(0.3, 0.85, 1.0)
	light.light_energy = 2.0
	light.omni_range = 3.5
	spark_node.add_child(light)

	var spark_mat = StandardMaterial3D.new()
	spark_mat.albedo_color = Color(0.4, 0.9, 1.0)
	spark_mat.emission_enabled = true
	spark_mat.emission = Color(0.5, 0.95, 1.0)
	spark_mat.emission_energy_multiplier = 3.0

	var sparks: Array[MeshInstance3D] = []
	for i in range(8):
		var sp = MeshInstance3D.new()
		var cyl = CylinderMesh.new()
		cyl.top_radius = 0.007
		cyl.bottom_radius = 0.007
		cyl.height = 0.18
		sp.mesh = cyl
		sp.material_override = spark_mat
		spark_node.add_child(sp)
		sparks.append(sp)

	var tw = create_tween()
	tw.tween_method(func(t: float):
		if not is_instance_valid(spark_node): return
		light.light_energy = randf_range(1.0, 2.5)
		for sp in sparks:
			if is_instance_valid(sp):
				sp.position = Vector3(randf_range(-0.4, 0.4), randf_range(-0.4, 0.4), randf_range(-0.4, 0.4))
				sp.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	, 0.0, duration, duration)
	tw.tween_callback(spark_node.queue_free)

func take_crawler_attack() -> void:
	if is_dead:
		return
	hp -= 1
	stun_timer = max(stun_timer, 1.4)
	if hp <= 0:
		die()

func die() -> void:
	if is_dead:
		return
	is_dead = true
	active = false
	collision_layer = 0
	collision_mask = 0
	var tw = create_tween()
	if mesh_root:
		tw.tween_property(mesh_root, "rotation:x", -PI * 0.48, 0.35)
		tw.parallel().tween_property(mesh_root, "position:y", -0.5, 0.35)
	if cultist_light:
		tw.parallel().tween_property(cultist_light, "light_energy", 0.0, 0.4)
	tw.tween_callback(queue_free).set_delay(2.0)

# Full ritual Cultist model ported from HTML makeCultist (lines 1718-1806)
func _build_cultist_mesh() -> void:
	mesh_root = Node3D.new()
	mesh_root.name = "CultistVisual"
	add_child(mesh_root)

	var robe_mat = VisualMaterialFactory.create_robe_fabric(Color(0.08, 0.015, 0.03), Color(0.03, 0.0, 0.008))
	var trim_mat = VisualMaterialFactory.create_robe_fabric(Color(0.60, 0.06, 0.09), Color(0.22, 0.01, 0.03))
	var dark_mat = VisualMaterialFactory.create_chitin_material(Color(0.02, 0.004, 0.008), 0.1, 0.85)
	var mask_mat = VisualMaterialFactory.create_stone_material(Color(0.85, 0.80, 0.72))
	var bone_mat = VisualMaterialFactory.create_bone_material(Color(0.80, 0.75, 0.64))

	var eye_mat = StandardMaterial3D.new()
	eye_mat.albedo_color = Color(1.0, 0.14, 0.0)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(1.0, 0.14, 0.0)
	eye_mat.emission_energy_multiplier = 3.8

	var gold_mat = StandardMaterial3D.new()
	gold_mat.albedo_color = Color(0.78, 0.57, 0.16)
	gold_mat.metallic = 0.85
	gold_mat.roughness = 0.25

	var steel_mat = StandardMaterial3D.new()
	steel_mat.albedo_color = Color(0.78, 0.81, 0.86)
	steel_mat.metallic = 0.92
	steel_mat.roughness = 0.18

	sigil_mat = StandardMaterial3D.new()
	sigil_mat.albedo_color = Color(1.0, 0.23, 0.04)
	sigil_mat.emission_enabled = true
	sigil_mat.emission = Color(1.0, 0.20, 0.02)
	sigil_mat.emission_energy_multiplier = 2.8

	# Align +Z Three.js coordinates to -Z Godot forward
	var align = Node3D.new()
	align.rotation.y = PI
	mesh_root.add_child(align)

	# Outer Skirt & 18 Tattered Hem Strips
	var skirt = MeshInstance3D.new()
	var skirt_cyl = CylinderMesh.new()
	skirt_cyl.top_radius = 0.26
	skirt_cyl.bottom_radius = 0.58
	skirt_cyl.height = 1.15
	skirt_cyl.radial_segments = 14
	skirt.mesh = skirt_cyl
	skirt.material_override = robe_mat
	skirt.position = Vector3(0, 0.57, 0)
	align.add_child(skirt)

	for i in range(18):
		var a = (float(i) / 18.0) * TAU
		var r = 0.50 + (i % 2) * 0.05
		var strip = MeshInstance3D.new()
		var sb = BoxMesh.new()
		sb.size = Vector3(0.09, 0.38 + (i % 3) * 0.08, 0.05)
		strip.mesh = sb
		strip.position = Vector3(cos(a) * r, 0.22, sin(a) * r)
		strip.rotation.y = -a + PI * 0.5
		strip.material_override = trim_mat if (i % 4 == 0) else robe_mat
		align.add_child(strip)

	# Inner Crimson Front Tabard Panel
	var panel = MeshInstance3D.new()
	var panel_box = BoxMesh.new()
	panel_box.size = Vector3(0.26, 1.48, 0.04)
	panel.mesh = panel_box
	panel.material_override = trim_mat
	panel.position = Vector3(0, 0.92, 0.30)
	align.add_child(panel)

	# Upper Torso + Cowl + Spiked Pauldrons
	var torso = MeshInstance3D.new()
	var torso_cyl = CylinderMesh.new()
	torso_cyl.top_radius = 0.22
	torso_cyl.bottom_radius = 0.34
	torso_cyl.height = 0.78
	torso_cyl.radial_segments = 12
	torso.mesh = torso_cyl
	torso.material_override = robe_mat
	torso.position = Vector3(0, 1.32, 0)
	align.add_child(torso)

	var cowl = MeshInstance3D.new()
	var cowl_cyl = CylinderMesh.new()
	cowl_cyl.top_radius = 0.44
	cowl_cyl.bottom_radius = 0.28
	cowl_cyl.height = 0.28
	cowl_cyl.radial_segments = 12
	cowl.mesh = cowl_cyl
	cowl.material_override = trim_mat
	cowl.position = Vector3(0, 1.58, 0)
	align.add_child(cowl)

	for s in [-1.0, 1.0]:
		var pauldron = MeshInstance3D.new()
		var p_sph = SphereMesh.new()
		p_sph.radius = 0.17
		p_sph.height = 0.34
		pauldron.mesh = p_sph
		pauldron.scale = Vector3(1.1, 0.65, 1.0)
		pauldron.position = Vector3(s * 0.30, 1.56, 0)
		pauldron.material_override = trim_mat
		align.add_child(pauldron)

		for k in range(2):
			var sp = MeshInstance3D.new()
			var sc = CylinderMesh.new()
			sc.top_radius = 0.0
			sc.bottom_radius = 0.032
			sc.height = 0.20 + k * 0.04
			sp.mesh = sc
			sp.position = Vector3(s * (0.28 + k * 0.08), 1.68, -0.02 + k * 0.04)
			sp.rotation.z = -s * (0.45 + k * 0.2)
			sp.material_override = bone_mat
			align.add_child(sp)

	# Rope Belt & 3 Hanging Blood Talismans
	var belt = MeshInstance3D.new()
	var b_tor = TorusMesh.new()
	b_tor.inner_radius = 0.25
	b_tor.outer_radius = 0.31
	belt.mesh = b_tor
	belt.position.y = 1.04
	belt.material_override = gold_mat
	align.add_child(belt)

	for i in range(3):
		var a = -0.5 + i * 0.5
		var tal = MeshInstance3D.new()
		var tc = CylinderMesh.new()
		tc.top_radius = 0.025
		tc.bottom_radius = 0.032
		tc.height = 0.14
		tal.mesh = tc
		tal.position = Vector3(sin(a) * 0.32, 0.90, cos(a) * 0.32)
		tal.material_override = sigil_mat if i == 1 else gold_mat
		align.add_child(tal)

	# Glowing Chest Sigil (Ring + Triangle + Eye)
	sigil_mesh = Node3D.new()
	sigil_mesh.position = Vector3(0, 1.36, 0.33)
	align.add_child(sigil_mesh)

	var s_ring = MeshInstance3D.new()
	var srt = TorusMesh.new()
	srt.inner_radius = 0.095
	srt.outer_radius = 0.125
	s_ring.mesh = srt
	s_ring.rotation.x = PI * 0.5
	s_ring.material_override = sigil_mat
	sigil_mesh.add_child(s_ring)

	var s_eye = MeshInstance3D.new()
	var ses = SphereMesh.new()
	ses.radius = 0.035
	ses.height = 0.07
	s_eye.mesh = ses
	s_eye.material_override = eye_mat
	sigil_mesh.add_child(s_eye)

	# Deep Peaked Hood + Porcelain Mask + Stitched Mouth + 7-Spike Bone Crown (grouped under head_pivot for neck-snap execution)
	head_pivot = Node3D.new()
	head_pivot.position = Vector3(0, 1.72, 0)
	align.add_child(head_pivot)

	var head_offset = Node3D.new()
	head_offset.position = Vector3(0, -1.72, 0)
	head_pivot.add_child(head_offset)

	var hood = MeshInstance3D.new()
	var hood_cone = CylinderMesh.new()
	hood_cone.top_radius = 0.01
	hood_cone.bottom_radius = 0.27
	hood_cone.height = 0.65
	hood.mesh = hood_cone
	hood.position = Vector3(0, 1.98, -0.02)
	hood.rotation.x = 0.18
	hood.material_override = robe_mat
	head_offset.add_child(hood)

	var face_void = MeshInstance3D.new()
	var fvs = SphereMesh.new()
	fvs.radius = 0.17
	fvs.height = 0.34
	face_void.mesh = fvs
	face_void.position = Vector3(0, 1.82, 0.08)
	face_void.material_override = dark_mat
	head_offset.add_child(face_void)

	var mask = MeshInstance3D.new()
	var mc = CylinderMesh.new()
	mc.top_radius = 0.13
	mc.bottom_radius = 0.105
	mc.height = 0.28
	mask.mesh = mc
	mask.scale = Vector3(1.0, 1.0, 0.58)
	mask.position = Vector3(0, 1.82, 0.14)
	mask.material_override = mask_mat
	head_offset.add_child(mask)

	for s in [-1.0, 1.0]:
		var sock = MeshInstance3D.new()
		var ss = SphereMesh.new()
		ss.radius = 0.036
		ss.height = 0.072
		sock.mesh = ss
		sock.position = Vector3(s * 0.052, 1.85, 0.215)
		sock.material_override = dark_mat
		head_offset.add_child(sock)

		var eye = MeshInstance3D.new()
		var es = SphereMesh.new()
		es.radius = 0.024
		es.height = 0.048
		eye.mesh = es
		eye.position = Vector3(s * 0.052, 1.85, 0.232)
		eye.material_override = eye_mat
		head_offset.add_child(eye)

	# 3 Forehead Blood Stripes on Mask
	for i in range(-1, 2):
		var stripe = MeshInstance3D.new()
		var stb = BoxMesh.new()
		stb.size = Vector3(0.014, 0.12 if i == 0 else 0.08, 0.01)
		stripe.mesh = stb
		stripe.position = Vector3(i * 0.04, 1.90, 0.225)
		stripe.material_override = trim_mat
		head_offset.add_child(stripe)

	# Stitched Mouth (Slit + 6 Vertical Stitches)
	var slit = MeshInstance3D.new()
	var slb = BoxMesh.new()
	slb.size = Vector3(0.11, 0.012, 0.01)
	slit.mesh = slb
	slit.position = Vector3(0, 1.74, 0.222)
	slit.material_override = dark_mat
	head_offset.add_child(slit)

	for i in range(6):
		var st = MeshInstance3D.new()
		var sb = BoxMesh.new()
		sb.size = Vector3(0.006, 0.036, 0.012)
		st.mesh = sb
		st.position = Vector3(-0.045 + i * 0.018, 1.74, 0.225)
		st.material_override = dark_mat
		head_offset.add_child(st)

	# 7-Spike Bone Crown + Gold Circlet
	for k in range(7):
		var a = -0.9 + k * 0.30
		var sp = MeshInstance3D.new()
		var sc = CylinderMesh.new()
		sc.top_radius = 0.0
		sc.bottom_radius = 0.022
		sc.height = 0.28 if k == 3 else (0.18 + (1 if (k % 2 == 1) else 0) * 0.05)
		sp.mesh = sc
		sp.position = Vector3(sin(a) * 0.17, 2.08, cos(a) * 0.08 + 0.05)
		sp.rotation = Vector3(0.15, 0, -a * 0.55)
		sp.material_override = bone_mat
		head_offset.add_child(sp)

	var circlet = MeshInstance3D.new()
	var ct = TorusMesh.new()
	ct.inner_radius = 0.165
	ct.outer_radius = 0.195
	circlet.mesh = ct
	circlet.position = Vector3(0, 1.98, 0.05)
	circlet.material_override = gold_mat
	head_offset.add_child(circlet)

	# Articulated Arms + Bony 5-Fingered Hands
	for s in [-1.0, 1.0]:
		var sh = Node3D.new()
		sh.position = Vector3(s * 0.30, 1.52, 0.02)
		sh.rotation = Vector3(-0.55 if s > 0.0 else -0.35, 0, -s * 0.22)
		align.add_child(sh)

		var u_arm = MeshInstance3D.new()
		var uc = CylinderMesh.new()
		uc.top_radius = 0.075
		uc.bottom_radius = 0.11
		uc.height = 0.42
		u_arm.mesh = uc
		u_arm.position.y = -0.20
		u_arm.material_override = robe_mat
		sh.add_child(u_arm)

		var elb = Node3D.new()
		elb.position.y = -0.40
		elb.rotation.x = -0.75 if s > 0.0 else -0.55
		sh.add_child(elb)

		var sleeve = MeshInstance3D.new()
		var sc = CylinderMesh.new()
		sc.top_radius = 0.095
		sc.bottom_radius = 0.16
		sc.height = 0.42
		sleeve.mesh = sc
		sleeve.position.y = -0.20
		sleeve.material_override = robe_mat
		elb.add_child(sleeve)

		var hand = Node3D.new()
		hand.position.y = -0.42
		elb.add_child(hand)

		var palm = MeshInstance3D.new()
		var pb = BoxMesh.new()
		pb.size = Vector3(0.07, 0.08, 0.03)
		palm.mesh = pb
		palm.material_override = bone_mat
		hand.add_child(palm)

		for f in range(5):
			var fg = MeshInstance3D.new()
			var fc = CylinderMesh.new()
			fc.top_radius = 0.005
			fc.bottom_radius = 0.009
			fc.height = 0.09
			fg.mesh = fc
			fg.position = Vector3((float(f) - 2.0) * 0.015, -0.07, 0.01)
			fg.rotation.x = 0.35
			fg.material_override = bone_mat
			hand.add_child(fg)

		if s > 0.0:
			dagger_pivot = elb
			var guard = MeshInstance3D.new()
			var gb = BoxMesh.new()
			gb.size = Vector3(0.16, 0.025, 0.035)
			guard.mesh = gb
			guard.position = Vector3(0, -0.08, 0.08)
			guard.material_override = gold_mat
			hand.add_child(guard)

			var blade = MeshInstance3D.new()
			var bc = CylinderMesh.new()
			bc.top_radius = 0.0
			bc.bottom_radius = 0.036
			bc.height = 0.46
			blade.mesh = bc
			blade.scale = Vector3(0.35, 1.0, 1.0)
			blade.position = Vector3(0, -0.08, 0.31)
			blade.rotation.x = PI * 0.5
			blade.material_override = steel_mat
			hand.add_child(blade)

			var groove = MeshInstance3D.new()
			var grb = BoxMesh.new()
			grb.size = Vector3(0.012, 0.015, 0.36)
			groove.mesh = grb
			groove.position = Vector3(0, -0.08, 0.27)
			groove.material_override = sigil_mat
			hand.add_child(groove)
		else:
			lantern_pivot = Node3D.new()
			lantern_pivot.position = Vector3(0, -0.06, 0.06)
			hand.add_child(lantern_pivot)

			var chain = MeshInstance3D.new()
			var cc = CylinderMesh.new()
			cc.top_radius = 0.008
			cc.bottom_radius = 0.008
			cc.height = 0.22
			chain.mesh = cc
			chain.position.y = -0.11
			chain.material_override = gold_mat
			lantern_pivot.add_child(chain)

			var core = MeshInstance3D.new()
			var cs = SphereMesh.new()
			cs.radius = 0.075
			cs.height = 0.15
			core.mesh = cs
			core.position.y = -0.29
			core.material_override = sigil_mat
			lantern_pivot.add_child(core)

			for r in range(4):
				var ra = r * (PI * 0.5)
				var rib = MeshInstance3D.new()
				var rb = BoxMesh.new()
				rb.size = Vector3(0.015, 0.16, 0.015)
				rib.mesh = rb
				rib.position = Vector3(cos(ra) * 0.085, -0.29, sin(ra) * 0.085)
				rib.material_override = gold_mat
				lantern_pivot.add_child(rib)

	# 6 Orbiting Crimson Motes
	for m in range(6):
		var mote = MeshInstance3D.new()
		var m_sph = SphereMesh.new()
		m_sph.radius = 0.025
		m_sph.height = 0.05
		mote.mesh = m_sph
		mote.material_override = eye_mat
		align.add_child(mote)
		motes.append(mote)

	cultist_light = OmniLight3D.new()
	cultist_light.light_color = Color(1.0, 0.18, 0.04)
	cultist_light.light_energy = 1.35
	cultist_light.omni_range = 7.5
	cultist_light.position = Vector3(0, 1.5, -0.2)
	mesh_root.add_child(cultist_light)

func start_execution_by_hunter(hunter_node: Node3D) -> void:
	if is_dead or is_being_executed:
		return
	is_being_executed = true
	exec_timer = 0.0
	exec_snapped = false
	velocity = Vector3.ZERO
	if is_instance_valid(hunter_node):
		var h_fwd = -hunter_node.global_transform.basis.z
		h_fwd.y = 0.0
		if h_fwd.length_squared() < 0.01:
			h_fwd = Vector3.FORWARD
		else:
			h_fwd = h_fwd.normalized()
		global_position = Vector3(
			hunter_node.global_position.x + h_fwd.x * 1.15,
			hunter_node.global_position.y,
			hunter_node.global_position.z + h_fwd.z * 1.15
		)
		var to_h = hunter_node.global_position - global_position
		rotation.y = atan2(-to_h.x, -to_h.z)
	SoundEffects.play_cultist_chant()

func _spawn_floor_blood() -> void:
	if not is_inside_tree() or get_parent() == null:
		return
	var splat = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.72
	cyl.bottom_radius = 0.75
	cyl.height = 0.014
	splat.mesh = cyl
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.01, 0.03, 0.92)
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
		roam_timer = 2.6

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	anim_phase += delta * 3.2
	_animate_visuals(delta)

	if is_being_executed:
		exec_timer += delta
		velocity = Vector3.ZERO
		if exec_timer < 0.82:
			# Lifted off the floor by the throat while kicking helplessly
			var lift_p = clampf(exec_timer / 0.62, 0.0, 1.0)
			if mesh_root:
				mesh_root.position.y = lerpf(0.0, 0.86, ease(lift_p, 0.6))
				mesh_root.rotation.z = sin(exec_timer * 36.0) * 0.22
				mesh_root.rotation.x = -0.18 * lift_p
			if head_pivot:
				head_pivot.rotation = Vector3(-0.22 * lift_p, sin(exec_timer * 28.0) * 0.25, 0.0)
		else:
			if not exec_snapped:
				exec_snapped = true
				# Violent 180-degree neck wrench ("vặt cổ cultist")
				SoundEffects.play(SoundEffects.snd_click, 6.0, 0.44)
				SoundEffects.play_Wet_Squish()
				_spawn_floor_blood()
				if head_pivot:
					head_pivot.rotation = Vector3(-0.35, PI * 0.88, 1.18)
			var drop_p = clampf((exec_timer - 0.88) / 0.45, 0.0, 1.0)
			if mesh_root:
				mesh_root.position.y = lerpf(0.86, 0.0, drop_p)
				mesh_root.rotation.z = lerpf(0.15, 0.0, drop_p)
		if exec_timer >= 1.65:
			die()
		return

	if is_killing:
		velocity = Vector3.ZERO
		return

	if player and (player.get("is_dead") == true or player.get("in_death_sequence") == true):
		velocity = Vector3.ZERO
		return

	if is_caged or not active:
		if mesh_root:
			mesh_root.position.y = sin(anim_phase * 0.8) * 0.04
		return

	if frozen_by_dev:
		velocity = Vector3.ZERO
		return

	if stun_timer > 0.0:
		stun_timer -= delta
		velocity = Vector3.ZERO
		if mesh_root:
			mesh_root.rotation.z = sin(anim_phase * 8.0) * 0.22
		return
	elif mesh_root:
		mesh_root.rotation.z = lerpf(mesh_root.rotation.z, 0.0, delta * 6.0)

	# Periodic ritual chant
	chant_timer -= delta
	if chant_timer <= 0.0:
		chant_timer = randf_range(4.5, 9.0)
		if player and global_position.distance_to(player.global_position) < 22.0:
			SoundEffects.play_cultist_chant()

	# Check if caught and executed by Hunter
	var hunter = get_tree().get_first_node_in_group("hunter")
	var afraid_of_hunter: bool = false
	if hunter and hunter.get("active"):
		var h_diff = global_position - hunter.global_position
		h_diff.y = 0.0
		var h_len = h_diff.length()
		if h_len < 13.5:
			afraid_of_hunter = true
		if h_len < 1.9:
			if hunter.has_method("start_prey_execution"):
				if hunter.start_prey_execution(self, "cultist"):
					return

	if is_snared_by_hanger:
		hanger_snare_timer -= delta
		velocity = Vector3.ZERO
		rotation.y += sin(anim_phase * 6.0) * delta * 2.0
		if hanger_snare_timer <= 0.0:
			release_from_hanger()
		return

	# Check player kill contact (unless fleeing in terror from Hunter or player is hidden in locker/cloak)
	var player_in_locker: bool = player != null and player.get("is_hiding") == true
	var player_hiding: bool = player != null and (player_in_locker or player.get("is_inside_cloak") == true)
	if player_in_locker and locker_banging_target == null and locker_knock_count == 0:
		var l_dist = global_position.distance_to(player.global_position)
		if l_dist < 14.0:
			locker_banging_target = player.get("current_locker")
			locker_knock_count = 3
			locker_knock_timer = 0.0

	if not afraid_of_hunter and player and not player_hiding and player.get("in_death_sequence") != true and player.get("is_dead") != true:
		var p_diff = player.global_position - global_position
		p_diff.y = 0.0
		if p_diff.length() < 1.95 and abs(player.global_position.y - global_position.y) < 2.2:
			_trigger_cultist_kill()
			return

	# Pause pursuit while player is inside the Night 5 Secret Sanctuary Corridor
	if player and player.get("in_secret_corridor") == true:
		velocity = Vector3.ZERO
		return

	# =========================================================================
	# INDEPENDENT REAL-TIME PURSUIT RULE (Master Spec Section 4.1 & 4.2):
	# Cultists pursue the player in real time even when the player stands still!
	# =========================================================================
	var move_dir := Vector3.ZERO
	var cur_speed: float = move_speed

	# 0. Locker investigation: bang on locker door 3 times then walk away
	if is_instance_valid(locker_banging_target) and locker_knock_count > 0:
		var fwd_l = locker_banging_target.global_transform.basis.z
		var front_pos = locker_banging_target.global_position + fwd_l * 1.35
		front_pos.y = global_position.y
		var to_front = front_pos - global_position
		to_front.y = 0.0
		if to_front.length() > 0.45:
			move_dir = to_front.normalized()
			cur_speed = move_speed * 0.92
		else:
			move_dir = Vector3.ZERO
			rotation.y = lerp_angle(rotation.y, atan2(-fwd_l.x, -fwd_l.z), delta * 12.0)
			locker_knock_timer += delta
			if locker_knock_timer >= 0.65:
				locker_knock_timer = 0.0
				locker_knock_count -= 1
				SoundEffects.play(SoundEffects.snd_click, 3.2, 0.42)
				if locker_knock_count <= 0:
					locker_banging_target = null
					_choose_new_roam_dir()

	# 1. Flee in terror from Hunter if Hunter is nearby (< 13.5m)
	elif hunter and hunter.get("active"):
		var h_diff = global_position - hunter.global_position
		h_diff.y = 0.0
		var h_dist = h_diff.length()
		if h_dist < 13.5 and h_dist > 0.01:
			move_dir = h_diff.normalized()
			cur_speed *= 1.32

	# 2. Lured by Bait
	if move_dir == Vector3.ZERO and has_bait:
		var b_diff = bait_pos - global_position
		b_diff.y = 0.0
		if b_diff.length() < 18.0 and b_diff.length() > 0.8:
			move_dir = b_diff.normalized()
			cur_speed *= 1.1

	# 3. Pursue Player along BFS shortest path (matching HTML cultistWaypoint)
	if move_dir == Vector3.ZERO and player and not player_hiding:
		var p_diff = player.global_position - global_position
		p_diff.y = 0.0
		if p_diff.length() < 24.0:
			if hunter and is_instance_valid(hunter) and hunter.has_method("_get_player_bfs_field"):
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
					# Closed gate blocks BFS path to player: do not charge into closed gate
					move_dir = Vector3.ZERO
			if move_dir == Vector3.ZERO and p_diff.length() > 0.05:
				move_dir = p_diff.normalized()

	# 4. Patrol roam fallback
	if move_dir == Vector3.ZERO:
		roam_timer -= delta
		if roam_timer <= 0.0:
			_choose_new_roam_dir()
		move_dir = roam_dir
		cur_speed *= 0.72

	velocity.x = move_dir.x * cur_speed
	velocity.z = move_dir.z * cur_speed
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = 0.0
	move_and_slide()

	if get_slide_collision_count() > 0 and roam_timer < 1.8:
		_choose_new_roam_dir()

	if move_dir.length_squared() > 0.01:
		var target_yaw = atan2(-move_dir.x, -move_dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, delta * 8.0)

func _trigger_cultist_kill() -> void:
	if is_killing or (player and (player.get("god_mode") or player.get("is_dead"))):
		return
	is_killing = true
	velocity = Vector3.ZERO
	var reason = "SACRIFICED BY A CULTIST OF THE LOWER RINGS — RITUAL DAGGER THROUGH THE RIBS."
	if player and is_instance_valid(player):
		var to_p = player.global_position - global_position
		rotation.y = atan2(-to_p.x, -to_p.z)

		# Baton Guard & Parry Check
		if player.has_method("is_baton_defending") and player.is_baton_defending():
			if player.is_baton_parrying():
				stun(3.0)
				player.on_successful_parry(self)
				var hud_node = get_tree().root.find_child("HUD", true, false)
				if hud_node and hud_node.has_method("show_toast"):
					hud_node.show_toast("⚡ PERFECT PARRY! CULTIST DEFLECTED & STUNNED (3.0s)!", Color(0.2, 1.0, 0.5))
				return
			elif player.is_baton_blocking():
				player.on_successful_block(self)
				stun_timer = 1.5
				return

		var hud_node = get_tree().root.find_child("HUD", true, false)
		if hud_node and hud_node.has_method("flash_damage"):
			hud_node.flash_damage()
		SoundEffects.play_cultist_chant()
		SoundEffects.play_Wet_Squish()
		if player.has_method("start_death_sequence"):
			player.start_death_sequence(self, "cultist", 0.85, func():
				player_killed.emit(reason)
			)
			return
	player_killed.emit(reason)

func _choose_new_roam_dir() -> void:
	var dirs = [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]
	roam_dir = dirs[randi() % dirs.size()].rotated(Vector3.UP, randf_range(-0.35, 0.35)).normalized()
	roam_timer = randf_range(2.0, 4.5)

func _animate_visuals(_delta: float) -> void:
	if mesh_root and not is_being_executed:
		mesh_root.position.y = abs(sin(anim_phase * 1.6)) * 0.06
	if sigil_mesh:
		sigil_mesh.rotation.z = anim_phase * 0.9
	if lantern_pivot:
		lantern_pivot.rotation.z = sin(anim_phase * 2.2) * 0.25
		lantern_pivot.rotation.x = cos(anim_phase * 1.7) * 0.18
	if dagger_pivot:
		if is_killing:
			dagger_pivot.rotation.x = -0.15 + sin(anim_phase * 16.0) * 0.75
		else:
			dagger_pivot.rotation.x = -0.75 + sin(anim_phase * 2.8) * 0.25
	for i in range(motes.size()):
		var m = motes[i]
		var a = anim_phase * 1.8 + i * (TAU / 6.0)
		m.position = Vector3(cos(a) * 0.48, 0.9 + sin(a * 1.5 + i) * 0.45, sin(a) * 0.48)

func freeze_by_hanger(duration: float = 3.5) -> void:
	is_snared_by_hanger = true
	hanger_snare_timer = duration
	velocity = Vector3.ZERO

func release_from_hanger() -> void:
	is_snared_by_hanger = false
	hanger_snare_timer = 0.0
	stun_timer = 2.5
