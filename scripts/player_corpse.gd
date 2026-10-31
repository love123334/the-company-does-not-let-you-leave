extends Node3D

var player_name: String = "Janitor"
var death_reason: String = ""

func setup_corpse(p_name: String, reason: String, death_rot_y: float) -> void:
	player_name = p_name
	death_reason = reason
	rotation.y = death_rot_y
	_build_corpse_mesh()

func _build_corpse_mesh() -> void:
	# Materials matching the live Janitor uniform
	var navy_mat = StandardMaterial3D.new()
	navy_mat.albedo_color = Color(0.12, 0.20, 0.34)
	navy_mat.roughness = 0.85

	var vest_mat = StandardMaterial3D.new()
	vest_mat.albedo_color = Color(0.92, 0.75, 0.08)
	vest_mat.emission_enabled = true
	vest_mat.emission = Color(0.92, 0.75, 0.08)
	vest_mat.emission_energy_multiplier = 0.2

	var skin_mat = StandardMaterial3D.new()
	skin_mat.albedo_color = Color(0.85, 0.70, 0.58)

	var glove_mat = StandardMaterial3D.new()
	glove_mat.albedo_color = Color(0.88, 0.76, 0.14)

	var boot_mat = StandardMaterial3D.new()
	boot_mat.albedo_color = Color(0.12, 0.12, 0.14)
	boot_mat.roughness = 0.6

	# 1. Dark expanding pool of blood underneath body
	var blood = MeshInstance3D.new()
	var b_cyl = CylinderMesh.new()
	b_cyl.top_radius = 0.75
	b_cyl.bottom_radius = 0.82
	b_cyl.height = 0.02
	blood.mesh = b_cyl
	blood.position = Vector3(0.1, 0.01, 0.1)
	var blood_mat = StandardMaterial3D.new()
	blood_mat.albedo_color = Color(0.42, 0.04, 0.05, 0.95)
	blood_mat.roughness = 0.15 # Wet glossy reflection
	blood.material_override = blood_mat
	add_child(blood)

	# 2. Downed Pelvis & Torso collapsed on the floor
	var body_root = Node3D.new()
	body_root.position = Vector3(0.0, 0.18, 0.0)
	body_root.rotation = Vector3(deg_to_rad(85.0), deg_to_rad(15.0), deg_to_rad(-20.0))
	add_child(body_root)

	# Torso & Chest
	var chest = MeshInstance3D.new()
	var c_box = BoxMesh.new()
	c_box.size = Vector3(0.42, 0.44, 0.26)
	chest.mesh = c_box
	chest.position = Vector3(0, 0.35, 0)
	chest.material_override = navy_mat
	body_root.add_child(chest)

	# Reflective vest band across chest
	var vest = MeshInstance3D.new()
	var v_box = BoxMesh.new()
	v_box.size = Vector3(0.44, 0.16, 0.28)
	vest.mesh = v_box
	vest.position = Vector3(0, 0.38, 0)
	vest.material_override = vest_mat
	body_root.add_child(vest)

	# Head turned sideways on floor
	var head = MeshInstance3D.new()
	var h_sph = SphereMesh.new()
	h_sph.radius = 0.18
	h_sph.height = 0.36
	head.mesh = h_sph
	head.position = Vector3(0.08, 0.68, 0.05)
	head.rotation = Vector3(deg_to_rad(25.0), deg_to_rad(45.0), 0)
	head.material_override = skin_mat
	body_root.add_child(head)

	# Respirator mask
	var mask = MeshInstance3D.new()
	var m_box = BoxMesh.new()
	m_box.size = Vector3(0.18, 0.14, 0.12)
	mask.mesh = m_box
	mask.position = Vector3(0.08, 0.64, -0.1)
	var mask_mat = StandardMaterial3D.new()
	mask_mat.albedo_color = Color(0.25, 0.28, 0.30)
	mask.material_override = mask_mat
	body_root.add_child(mask)

	# Knocked off janitor cap lying nearby
	var cap = MeshInstance3D.new()
	var cap_c = CylinderMesh.new()
	cap_c.top_radius = 0.16
	cap_c.bottom_radius = 0.18
	cap_c.height = 0.10
	cap.mesh = cap_c
	cap.position = Vector3(0.45, 0.05, 0.3)
	cap.rotation = Vector3(deg_to_rad(40.0), deg_to_rad(20.0), deg_to_rad(-60.0))
	cap.material_override = navy_mat
	add_child(cap)

	# 3. Flung out arms with yellow rubber gloves
	var arm_l = MeshInstance3D.new()
	var al_box = BoxMesh.new()
	al_box.size = Vector3(0.11, 0.45, 0.11)
	arm_l.mesh = al_box
	arm_l.position = Vector3(-0.35, 0.07, 0.22)
	arm_l.rotation = Vector3(0, deg_to_rad(45.0), deg_to_rad(80.0))
	arm_l.material_override = glove_mat
	add_child(arm_l)

	var arm_r = MeshInstance3D.new()
	var ar_box = BoxMesh.new()
	ar_box.size = Vector3(0.11, 0.45, 0.11)
	arm_r.mesh = ar_box
	arm_r.position = Vector3(0.38, 0.07, -0.15)
	arm_r.rotation = Vector3(0, deg_to_rad(-35.0), deg_to_rad(-75.0))
	arm_r.material_override = glove_mat
	add_child(arm_r)

	# 4. Sprawled legs with boots
	var leg_l = MeshInstance3D.new()
	var ll_box = BoxMesh.new()
	ll_box.size = Vector3(0.13, 0.55, 0.13)
	leg_l.mesh = ll_box
	leg_l.position = Vector3(-0.25, 0.07, -0.42)
	leg_l.rotation = Vector3(deg_to_rad(-15.0), deg_to_rad(20.0), deg_to_rad(85.0))
	leg_l.material_override = navy_mat
	add_child(leg_l)

	var boot_l = MeshInstance3D.new()
	var bl_box = BoxMesh.new()
	bl_box.size = Vector3(0.14, 0.12, 0.24)
	boot_l.mesh = bl_box
	boot_l.position = Vector3(-0.52, 0.07, -0.45)
	boot_l.material_override = boot_mat
	add_child(boot_l)

	var leg_r = MeshInstance3D.new()
	var lr_box = BoxMesh.new()
	lr_box.size = Vector3(0.13, 0.55, 0.13)
	leg_r.mesh = lr_box
	leg_r.position = Vector3(0.20, 0.07, -0.50)
	leg_r.rotation = Vector3(deg_to_rad(10.0), deg_to_rad(-25.0), deg_to_rad(-80.0))
	leg_r.material_override = navy_mat
	add_child(leg_r)

	var boot_r = MeshInstance3D.new()
	var br_box = BoxMesh.new()
	br_box.size = Vector3(0.14, 0.12, 0.24)
	boot_r.mesh = br_box
	boot_r.position = Vector3(0.48, 0.07, -0.58)
	boot_r.material_override = boot_mat
	add_child(boot_r)

	# 5. Dropped cleaning mop beside body
	var mop = Node3D.new()
	mop.position = Vector3(-0.55, 0.04, 0.2)
	mop.rotation = Vector3(deg_to_rad(10.0), deg_to_rad(65.0), deg_to_rad(85.0))
	add_child(mop)

	var handle = MeshInstance3D.new()
	var h_cyl = CylinderMesh.new()
	h_cyl.top_radius = 0.02
	h_cyl.bottom_radius = 0.02
	h_cyl.height = 1.4
	handle.mesh = h_cyl
	var wood_mat = StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.68, 0.58, 0.40)
	handle.material_override = wood_mat
	mop.add_child(handle)

	var head_m = MeshInstance3D.new()
	var m_box_inst = BoxMesh.new()
	m_box_inst.size = Vector3(0.18, 0.14, 0.22)
	head_m.mesh = m_box_inst
	head_m.position = Vector3(0, 0.7, 0)
	var cloth_mat = StandardMaterial3D.new()
	cloth_mat.albedo_color = Color(0.75, 0.78, 0.75)
	head_m.material_override = cloth_mat
	mop.add_child(head_m)

	# 6. Dropped flashlight on the ground flickering dimly
	var flash_node = Node3D.new()
	flash_node.position = Vector3(0.55, 0.05, 0.15)
	flash_node.rotation = Vector3(0, deg_to_rad(115.0), 0)
	add_child(flash_node)

	var flash_body = MeshInstance3D.new()
	var f_cyl = CylinderMesh.new()
	f_cyl.top_radius = 0.04
	f_cyl.bottom_radius = 0.03
	f_cyl.height = 0.28
	flash_body.mesh = f_cyl
	flash_body.rotation.x = PI / 2.0
	var f_mat = StandardMaterial3D.new()
	f_mat.albedo_color = Color(0.18, 0.20, 0.22)
	flash_body.material_override = f_mat
	flash_node.add_child(flash_body)

	var flash_spot = SpotLight3D.new()
	flash_spot.position = Vector3(0, 0, 0.15)
	flash_spot.spot_range = 8.0
	flash_spot.spot_angle = 45.0
	flash_spot.light_energy = 0.8
	flash_spot.light_color = Color(1.0, 0.95, 0.8)
	flash_node.add_child(flash_spot)

	# 7. Red Fallen Marker Tag
	var tag = Label3D.new()
	tag.position = Vector3(0, 0.85, 0)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.text = "✖ %s (TỬ NẠN)" % player_name
	tag.font_size = 18
	tag.pixel_size = 0.003
	tag.modulate = Color(1.0, 0.25, 0.25)
	tag.outline_modulate = Color(0, 0, 0)
	tag.outline_size = 4
	add_child(tag)
