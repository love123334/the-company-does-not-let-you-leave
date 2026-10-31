class_name LightEater
extends CharacterBody3D

signal player_spotted(player_pos: Vector3)

@export var move_speed: float = 2.2
@export var supercharge_speed: float = 24.0
@export var is_active: bool = false
var active: bool = false

var player: CharacterBody3D = null
var is_supercharged: bool = false
var supercharge_dist_left: float = 0.0
var supercharge_dir: Vector3 = Vector3.ZERO
var supercharge_start_pos: Vector3 = Vector3.ZERO

var alarm_cooldown: float = 0.0
var hum_timer: float = 0.0
var stunned_targets_hit: Dictionary = {}

var _mesh_root: Node3D = null
var _core_mesh: MeshInstance3D = null
var _ring_mesh: MeshInstance3D = null
var _dark_light: OmniLight3D = null
var _supercharge_light: OmniLight3D = null
var _spark_mesh: MeshInstance3D = null

func _ready() -> void:
	collision_layer = 4 # Monster layer
	collision_mask = 1 | 8  # Environment & monster-blocking barriers
	_build_visuals()

func _build_visuals() -> void:
	_mesh_root = Node3D.new()
	_mesh_root.name = "Visuals"
	add_child(_mesh_root)

	# 1. Dark Abyssal Body
	_core_mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.55
	sphere.height = 1.3
	_core_mesh.mesh = sphere
	_core_mesh.position.y = 1.0

	var void_mat = StandardMaterial3D.new()
	void_mat.albedo_color = Color(0.03, 0.01, 0.07, 0.95)
	void_mat.metallic = 0.2
	void_mat.roughness = 0.9
	void_mat.emission_enabled = true
	void_mat.emission = Color(0.35, 0.05, 0.55)
	void_mat.emission_energy_multiplier = 0.6
	_core_mesh.material_override = void_mat
	_mesh_root.add_child(_core_mesh)

	# 2. Orbital Absorption Rings
	_ring_mesh = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.75
	torus.outer_radius = 0.95
	_ring_mesh.mesh = torus
	_ring_mesh.position.y = 1.0
	_ring_mesh.rotation.x = deg_to_rad(35.0)

	var ring_mat = StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.2, 0.02, 0.35, 0.5)
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(0.5, 0.1, 0.8)
	ring_mat.emission_energy_multiplier = 1.2
	_ring_mesh.material_override = ring_mat
	_mesh_root.add_child(_ring_mesh)

	# 3. Ambient Dark Void Light
	_dark_light = OmniLight3D.new()
	_dark_light.light_color = Color(0.4, 0.08, 0.6)
	_dark_light.light_energy = 0.8
	_dark_light.omni_range = 6.0
	_dark_light.position.y = 1.0
	_mesh_root.add_child(_dark_light)

	# 4. Supercharge High-Voltage Electric Light
	_supercharge_light = OmniLight3D.new()
	_supercharge_light.light_color = Color(0.2, 0.95, 1.0)
	_supercharge_light.light_energy = 0.0
	_supercharge_light.omni_range = 14.0
	_supercharge_light.position.y = 1.0
	_mesh_root.add_child(_supercharge_light)

	# 5. Collision Shape
	var col = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = 0.55
	shape.height = 1.4
	col.shape = shape
	col.position.y = 1.0
	add_child(col)

func activate() -> void:
	is_active = true
	active = true
	visible = true

func _physics_process(delta: float) -> void:
	if not active:
		return

	if alarm_cooldown > 0.0:
		alarm_cooldown -= delta

	# Subtle floating hover bobbing
	var time_val = Time.get_ticks_msec() * 0.003
	if _mesh_root:
		_mesh_root.position.y = sin(time_val * 2.0) * 0.15
	if _ring_mesh:
		_ring_mesh.rotation.y += delta * 2.5
		_ring_mesh.rotation.z = sin(time_val) * 0.3

	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return

	# --- SUPERCHARGED STATE (Taser Bowling Run) ---
	if is_supercharged:
		_process_supercharge(delta)
		return

	# --- NORMAL STATE: FLOOR 2 LIGHT ABSORPTION & ALARM ---
	var p_pos = player.global_position
	# Light Eater operates on Floor 2 (y > 5.0)
	var on_same_floor = abs(p_pos.y - global_position.y) < 5.5
	var dist_to_player = Vector2(global_position.x - p_pos.x, global_position.z - p_pos.z).length()

	# 20m Light Absorption Aura:
	# Shuts off player flashlight & causes darkness in Floor 2 sector
	var in_aura = on_same_floor and dist_to_player <= 20.0
	if player.has_method("set_flashlight_suppressed"):
		player.set_flashlight_suppressed(in_aura)

	if in_aura:
		hum_timer -= delta
		if hum_timer <= 0.0:
			hum_timer = randf_range(3.0, 5.5)
			SoundEffects.play(SoundEffects.snd_click, -4.0, 0.45)

	# 12m Proximity Alarm: Light Eater detects player & screams, alerting monsters!
	if on_same_floor and dist_to_player <= 12.0 and alarm_cooldown <= 0.0:
		_trigger_alarm()

	# Slowly glide towards player along floor 2 walkways
	if on_same_floor and dist_to_player > 1.2:
		var dir_to_p = Vector3(p_pos.x - global_position.x, 0.0, p_pos.z - global_position.z).normalized()
		velocity.x = dir_to_p.x * move_speed
		velocity.z = dir_to_p.z * move_speed
		rotation.y = lerp_angle(rotation.y, atan2(-dir_to_p.x, -dir_to_p.z), delta * 4.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 4.0)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * delta * 4.0)

	move_and_slide()

func _trigger_alarm() -> void:
	alarm_cooldown = 14.0
	SoundEffects.play_hunter_screech()
	var hud_node = get_tree().root.find_child("HUD", true, false)
	if hud_node and hud_node.has_method("show_toast"):
		hud_node.show_toast("⚠ LIGHT EATER CONSUMED THE AREA'S LIGHT & BROADCASTED YOUR POSITION!", Color(0.85, 0.35, 1.0), 5.0)
		hud_node.flash_damage()

	player_spotted.emit(player.global_position)

	# Direct alert to Floor 2 Cultists, Hangers, and Hunter
	for cultist in get_tree().get_nodes_in_group("cultists"):
		if is_instance_valid(cultist) and cultist.has_method("alert_to_position"):
			cultist.alert_to_position(player.global_position)
	for hanger in get_tree().get_nodes_in_group("hangers"):
		if is_instance_valid(hanger) and hanger.has_method("alert_to_position"):
			hanger.alert_to_position(player.global_position)
	var hunter_node = get_tree().get_first_node_in_group("hunter")
	if is_instance_valid(hunter_node) and hunter_node.has_method("alert_to_player_noise"):
		hunter_node.alert_to_player_noise(player.global_position)

func trigger_taser_supercharge(dart_fwd: Vector3) -> void:
	is_supercharged = true
	supercharge_dist_left = 50.0
	supercharge_start_pos = global_position
	supercharge_dir = Vector3(dart_fwd.x, 0.0, dart_fwd.z).normalized()
	if supercharge_dir.length_squared() < 0.01:
		supercharge_dir = -global_transform.basis.z
	stunned_targets_hit.clear()

	# Light emission flares intensely
	if _supercharge_light:
		_supercharge_light.light_energy = 5.0
	if _core_mesh and _core_mesh.material_override is StandardMaterial3D:
		var mat: StandardMaterial3D = _core_mesh.material_override
		mat.albedo_color = Color(0.2, 0.95, 1.0)
		mat.emission = Color(0.2, 0.95, 1.0)
		mat.emission_energy_multiplier = 4.0

	SoundEffects.play(SoundEffects.snd_taser, 4.0, 1.4)
	SoundEffects.play(SoundEffects.snd_screech, 2.0, 1.25)

func _process_supercharge(delta: float) -> void:
	var step_dist = supercharge_speed * delta
	supercharge_dist_left -= step_dist

	velocity = supercharge_dir * supercharge_speed
	move_and_slide()

	# Bowling Effect: Any entity in its charging path is bowled over and stunned for 5.0s!
	_sweep_and_stun_entities()

	if supercharge_dist_left <= 0.0 or is_on_wall():
		_end_supercharge()

func _sweep_and_stun_entities() -> void:
	var sweep_radius = 2.4
	# 1. Check all other monsters in Entities
	var main_scene = get_tree().root.find_child("Main", true, false)
	if not main_scene:
		return

	var all_monsters = []
	all_monsters.append_array(get_tree().get_nodes_in_group("cultists"))
	all_monsters.append_array(get_tree().get_nodes_in_group("crawlers"))
	all_monsters.append_array(get_tree().get_nodes_in_group("hangers"))
	all_monsters.append_array(get_tree().get_nodes_in_group("statues"))
	var hunter = get_tree().get_first_node_in_group("hunter")
	if hunter:
		all_monsters.append(hunter)

	for m in all_monsters:
		if is_instance_valid(m) and m != self:
			var m_id = m.get_instance_id()
			if not stunned_targets_hit.has(m_id):
				var d = global_position.distance_to(m.global_position)
				if d <= sweep_radius:
					stunned_targets_hit[m_id] = true
					if m.has_method("stun"):
						m.stun(5.0)
					SoundEffects.play(SoundEffects.snd_taser, 2.5, 0.9)
					var net_mgr = get_node_or_null("/root/NetworkManager")
					if net_mgr:
						if m == hunter and net_mgr.has_method("record_boss_stun"):
							net_mgr.record_boss_stun()
						elif net_mgr.has_method("record_monster_kill"):
							net_mgr.record_monster_kill()

func _end_supercharge() -> void:
	is_supercharged = false
	velocity = Vector3.ZERO
	if _supercharge_light:
		_supercharge_light.light_energy = 0.0
	if _core_mesh and _core_mesh.material_override is StandardMaterial3D:
		var mat: StandardMaterial3D = _core_mesh.material_override
		mat.albedo_color = Color(0.03, 0.01, 0.07, 0.95)
		mat.emission = Color(0.35, 0.05, 0.55)
		mat.emission_energy_multiplier = 0.6
	SoundEffects.play(SoundEffects.snd_click, 2.0, 0.8)
