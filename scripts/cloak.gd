extends CharacterBody3D

# The Cloak (Floating Shroud Specimen — Night 4+)
# - Looks like a billowing, undulating dark fabric shroud drifting smoothly along corridors.
# - First sighting triggers a scare sting & toast, then reveals itself to be neutral.
# - Moving Camouflage: Player can walk inside the Cloak (matching its pace, no button press)
#   to hide from all other monsters.
# - Repulsion Field: Pushes away Hunter, Statues, Crawlers, and Cultists within 3.9m,
#   forcing Hunter and Statues to turn away and abandon pursuit.
# - Death 1 (Suffocation when hiding inside too long): Player gradually struggles to breathe,
#   vision progressively blurs/darkens, hyperventilates rapidly, and dies of asphyxiation.
# - Death 2 (Strangulation when struck by mop or witnessing another Cloak struck):
#   Turns hostile, rushes the player, wraps dark cloth coils tightly around the player's body,
#   and strangles their neck to death.

signal player_killed(reason: String)

const CLOAK_REPEL_RADIUS: float = 3.9
const HIDE_RADIUS: float = 1.65
const MAX_DIGEST_TIME: float = 6.5
const WITNESS_RADIUS: float = 18.0
const _N4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var player: CharacterBody3D = null
var maze_grid: Array = []
var active: bool = true
var frozen_by_dev: bool = false
var is_hostile: bool = false
var is_killing: bool = false
var kill_mode: String = "" # "suffocate" or "strangle"
var kill_anim_timer: float = 0.0

var patrol_speed: float = 3.45
var hostile_speed: float = 6.85
var anim_time: float = 0.0
var scare_check_timer: float = 0.0

# Grid-corridor waypoint state (prevents ever getting stuck on walls)
var cur_cell: Vector2i = Vector2i(-1, -1)
var target_cell: Vector2i = Vector2i(-1, -1)
var last_step_dir: Vector2i = Vector2i(0, 1)

var mesh_root: Node3D = null
var shroud_panels: Array[Node3D] = []
var ribbon_strips: Array[Node3D] = []
var strangle_coils: Array[Node3D] = []
var eye_nodes: Array[MeshInstance3D] = []
var cloth_mat: StandardMaterial3D = null
var inner_mat: StandardMaterial3D = null
var eye_mat: StandardMaterial3D = null
var aura_light: OmniLight3D = null

func _ready() -> void:
	add_to_group("cloaks")
	# Ethereal floating cloth: zero physical collision so it never snags on walls or blocks player
	collision_layer = 0
	collision_mask = 0
	_build_cloak_mesh()
	call_deferred("_init_corridor_navigation")

func activate() -> void:
	active = true

func set_freeze(val: bool) -> void:
	frozen_by_dev = val

func _init_corridor_navigation() -> void:
	if maze_grid.is_empty():
		var main_node = get_tree().root.find_child("Main", true, false)
		if main_node and "current_day" in main_node:
			var d_idx: int = clampi(int(main_node.get("current_day")) - 1, 0, GameData.ALL_MAZES.size() - 1)
			maze_grid = GameData.ALL_MAZES[d_idx]
		elif not GameData.ALL_MAZES.is_empty():
			maze_grid = GameData.ALL_MAZES[0]
	snap_to_nearest_open_corridor()
	_pick_next_corridor_cell(true)

func snap_to_nearest_open_corridor() -> void:
	if maze_grid.is_empty():
		return
	var S: int = maze_grid.size()
	var U: float = GameData.UNIT
	var r0: int = clampi(int(round(global_position.z / U)), 1, S - 2)
	var c0: int = clampi(int(round(global_position.x / U)), 1, S - 2)
	if maze_grid[r0][c0] != 1:
		cur_cell = Vector2i(r0, c0)
		global_position = Vector3(float(c0) * U, 0.05, float(r0) * U)
		return
	# Search outward for the closest open corridor tile
	var best_cell := Vector2i(1, 1)
	var best_d: float = 1e9
	for r in range(1, S - 1):
		for c in range(1, S - 1):
			if maze_grid[r][c] != 1:
				var wx: float = float(c) * U
				var wz: float = float(r) * U
				var d: float = Vector2(wx - global_position.x, wz - global_position.z).length()
				if d < best_d:
					best_d = d
					best_cell = Vector2i(r, c)
	cur_cell = best_cell
	global_position = Vector3(float(best_cell.y) * U, 0.05, float(best_cell.x) * U)

func _build_cloak_mesh() -> void:
	mesh_root = Node3D.new()
	mesh_root.name = "CloakVisual"
	add_child(mesh_root)

	cloth_mat = StandardMaterial3D.new()
	cloth_mat.albedo_color = Color(0.08, 0.07, 0.12, 0.93)
	cloth_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cloth_mat.roughness = 0.86
	cloth_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cloth_mat.emission_enabled = true
	cloth_mat.emission = Color(0.09, 0.06, 0.15)
	cloth_mat.emission_energy_multiplier = 0.35

	inner_mat = StandardMaterial3D.new()
	inner_mat.albedo_color = Color(0.14, 0.04, 0.18, 0.88)
	inner_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	inner_mat.roughness = 0.84
	inner_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	inner_mat.emission_enabled = true
	inner_mat.emission = Color(0.22, 0.04, 0.28)
	inner_mat.emission_energy_multiplier = 0.48

	eye_mat = StandardMaterial3D.new()
	eye_mat.albedo_color = Color(1.0, 0.12, 0.18)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(1.0, 0.08, 0.14)
	eye_mat.emission_energy_multiplier = 4.5

	# Upper billowing cowl / floating mantle dome
	var cowl = MeshInstance3D.new()
	var c_cyl = CylinderMesh.new()
	c_cyl.top_radius = 0.24
	c_cyl.bottom_radius = 0.86
	c_cyl.height = 0.72
	cowl.mesh = c_cyl
	cowl.scale = Vector3(1.12, 1.0, 1.05)
	cowl.position = Vector3(0, 2.22, 0)
	cowl.material_override = cloth_mat
	mesh_root.add_child(cowl)

	# 16 Overlapping draped fabric folds forming a cohesive hollow shroud
	var num_panels := 16
	for i in range(num_panels):
		var ang: float = float(i) * (TAU / float(num_panels))
		var pivot = Node3D.new()
		pivot.position = Vector3(cos(ang) * 0.72, 2.12, sin(ang) * 0.72)
		pivot.rotation.y = -ang + PI * 0.5
		pivot.set_meta("base_ang", ang)
		mesh_root.add_child(pivot)

		var panel = MeshInstance3D.new()
		var p_box = BoxMesh.new()
		p_box.size = Vector3(0.42, 1.92, 0.03)
		panel.mesh = p_box
		panel.position = Vector3(0, -0.90, 0)
		panel.material_override = cloth_mat if (i % 2 == 0) else inner_mat
		pivot.add_child(panel)
		shroud_panels.append(pivot)

		# Lower tattered hem streamer hanging from each fold
		var hem_pivot = Node3D.new()
		hem_pivot.position = Vector3(0, -1.82, 0)
		pivot.add_child(hem_pivot)

		var hem = MeshInstance3D.new()
		var h_box = BoxMesh.new()
		h_box.size = Vector3(0.30, 0.52 + float(i % 3) * 0.15, 0.024)
		hem.mesh = h_box
		hem.position = Vector3(0, -0.24, 0)
		hem.material_override = cloth_mat
		hem_pivot.add_child(hem)
		ribbon_strips.append(hem_pivot)

	# 6 3D Constriction Cloth Coils (used when wrapping around the player's body & strangling their neck!)
	for c_idx in range(6):
		var coil_piv = Node3D.new()
		coil_piv.position = Vector3(0, 0.75 + float(c_idx) * 0.18, 0)
		coil_piv.visible = false
		mesh_root.add_child(coil_piv)

		var coil_mesh = MeshInstance3D.new()
		var torus = TorusMesh.new()
		torus.inner_radius = 0.26
		torus.outer_radius = 0.34
		coil_mesh.mesh = torus
		coil_mesh.scale = Vector3(1.0, 1.35, 1.0)
		coil_mesh.rotation.z = deg_to_rad(float(c_idx % 2) * 16.0 - 8.0)
		coil_mesh.material_override = inner_mat if (c_idx == 5) else cloth_mat
		coil_piv.add_child(coil_mesh)
		strangle_coils.append(coil_piv)

	# Hidden crimson eyes inside the upper fold (invisible while neutral)
	for sx in [-1.0, 1.0]:
		var eye = MeshInstance3D.new()
		var es = SphereMesh.new()
		es.radius = 0.048
		es.height = 0.096
		eye.mesh = es
		eye.position = Vector3(sx * 0.16, 2.02, -0.62)
		eye.material_override = eye_mat
		eye.visible = false
		mesh_root.add_child(eye)
		eye_nodes.append(eye)

	aura_light = OmniLight3D.new()
	aura_light.light_color = Color(0.48, 0.28, 0.78)
	aura_light.light_energy = 0.85
	aura_light.omni_range = 5.8
	aura_light.position = Vector3(0, 1.5, 0)
	mesh_root.add_child(aura_light)

func hit_by_mop() -> bool:
	if is_killing:
		return false
	provoke_hostile(true)
	# Any other Cloak within 18m or with line-of-sight witnesses the player striking this Cloak!
	var space_state = get_world_3d().direct_space_state
	for other in get_tree().get_nodes_in_group("cloaks"):
		if other != self and is_instance_valid(other) and other.has_method("provoke_hostile"):
			var d: float = global_position.distance_to(other.global_position)
			var witnessed: bool = (d <= WITNESS_RADIUS)
			if not witnessed and player and is_instance_valid(player):
				var dp: float = player.global_position.distance_to(other.global_position)
				if dp <= 24.0:
					var q = PhysicsRayQueryParameters3D.create(
						other.global_position + Vector3(0, 1.5, 0),
						player.global_position + Vector3(0, 1.2, 0),
						1
					)
					if space_state.intersect_ray(q).is_empty():
						witnessed = true
			if witnessed:
				other.provoke_hostile(false)
	return true

func provoke_hostile(direct_hit: bool = false) -> void:
	if is_hostile:
		return
	is_hostile = true
	for e in eye_nodes:
		if is_instance_valid(e):
			e.visible = true
	if cloth_mat:
		cloth_mat.albedo_color = Color(0.24, 0.02, 0.05, 0.96)
		cloth_mat.emission = Color(0.35, 0.02, 0.06)
	if inner_mat:
		inner_mat.albedo_color = Color(0.48, 0.02, 0.06, 0.94)
		inner_mat.emission = Color(0.88, 0.05, 0.12)
		inner_mat.emission_energy_multiplier = 1.65
	if aura_light:
		aura_light.light_color = Color(1.0, 0.12, 0.18)
		aura_light.light_energy = 2.8
		aura_light.omni_range = 8.5
	if direct_hit:
		SoundEffects.play_hunter_screech()
		SoundEffects.play_cloth_wrap()
		var hud_node = get_tree().root.find_child("HUD", true, false)
		if hud_node and hud_node.has_method("show_toast"):
			hud_node.show_toast("⚠ YOU STRUCK THE CLOAK — IT IS LUNGING TO WRAP & STRANGLE YOU!", Color(1.0, 0.2, 0.25))

func _physics_process(delta: float) -> void:
	anim_time += delta
	_animate_cloth(delta)

	if is_killing:
		kill_anim_timer += delta
		velocity = Vector3.ZERO
		if player and is_instance_valid(player):
			# Keep Cloak wrapped directly around the player's body during the kill sequence!
			global_position = Vector3(player.global_position.x, player.global_position.y, player.global_position.z)
		return

	if not active or frozen_by_dev:
		velocity = Vector3.ZERO
		return

	# Always repel other monsters (Hunter, Statues, Crawlers, Cultists) that get too close!
	_repel_nearby_monsters(delta)

	# First-sighting scare check (only once per run when neutral)
	if not is_hostile and player and is_instance_valid(player):
		scare_check_timer -= delta
		if scare_check_timer <= 0.0:
			scare_check_timer = 0.25
			_check_first_sighting_scare()

	# Check if player is inside or touching this Cloak
	if player and is_instance_valid(player) and not bool(player.get("in_death_sequence")):
		var p_diff = player.global_position - global_position
		p_diff.y = 0.0
		var p_dist = p_diff.length()

		if is_hostile:
			if p_dist <= 1.55 and abs(player.global_position.y - global_position.y) < 2.3:
				_trigger_strangle_kill()
				return
		else:
			if p_dist <= HIDE_RADIUS and abs(player.global_position.y - global_position.y) < 2.3 and not bool(player.get("is_hiding")):
				if player.has_method("notify_inside_cloak"):
					player.notify_inside_cloak(self, delta)

	# Movement AI:
	# - If hostile: charge toward player along open corridors / direct line
	# - If neutral: glide smoothly along grid-corridor waypoints so it never hits walls
	var move_dir := Vector3.ZERO
	var cur_speed: float = hostile_speed if is_hostile else patrol_speed

	if is_hostile and player and is_instance_valid(player):
		var hunter = get_tree().get_first_node_in_group("hunter")
		if hunter and is_instance_valid(hunter) and hunter.has_method("_get_player_bfs_field"):
			var d: PackedInt32Array = hunter._get_player_bfs_field(false)
			var S: int = int(hunter.get("_bfs_grid_size"))
			var nb: Array = hunter._bfs_next_cell(global_position, d, S, true)
			if not nb.is_empty():
				var wx: float = float(nb[1]) * GameData.UNIT
				var wz: float = float(nb[0]) * GameData.UNIT
				var to_wp := Vector3(wx - global_position.x, 0.0, wz - global_position.z)
				if to_wp.length() > 0.1:
					move_dir = to_wp.normalized()
		if move_dir == Vector3.ZERO:
			var to_p = player.global_position - global_position
			to_p.y = 0.0
			if to_p.length() > 0.05:
				move_dir = to_p.normalized()
		global_position += move_dir * cur_speed * delta
	else:
		if target_cell.x < 0 or maze_grid.is_empty():
			_init_corridor_navigation()
		var U: float = GameData.UNIT
		var target_pos := Vector3(float(target_cell.y) * U, global_position.y, float(target_cell.x) * U)
		var to_target := target_pos - global_position
		to_target.y = 0.0
		var dist_to_wp: float = to_target.length()
		var step_len: float = cur_speed * delta
		if dist_to_wp <= step_len + 0.05:
			global_position.x = target_pos.x
			global_position.z = target_pos.z
			cur_cell = target_cell
			_pick_next_corridor_cell(false)
			var next_pos := Vector3(float(target_cell.y) * U, global_position.y, float(target_cell.x) * U)
			var rem_dir := next_pos - global_position
			rem_dir.y = 0.0
			if rem_dir.length() > 0.01:
				move_dir = rem_dir.normalized()
		else:
			move_dir = to_target.normalized()
			global_position += move_dir * step_len

	if move_dir.length_squared() > 0.01:
		var target_yaw = atan2(-move_dir.x, -move_dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, delta * (9.0 if is_hostile else 5.0))

func _pick_next_corridor_cell(allow_any: bool) -> void:
	if maze_grid.is_empty():
		return
	var S: int = maze_grid.size()
	var U: float = GameData.UNIT
	if cur_cell.x < 0 or cur_cell.y < 0 or cur_cell.x >= S or cur_cell.y >= S:
		cur_cell = Vector2i(
			clampi(int(round(global_position.z / U)), 1, S - 2),
			clampi(int(round(global_position.x / U)), 1, S - 2)
		)
	var forward_neighbors: Array[Vector2i] = []
	var all_neighbors: Array[Vector2i] = []
	var reverse_dir := Vector2i(-last_step_dir.x, -last_step_dir.y)

	for ofs in _N4:
		var nr: int = cur_cell.x + ofs.x
		var nc: int = cur_cell.y + ofs.y
		if nr <= 0 or nc <= 0 or nr >= S - 1 or nc >= S - 1:
			continue
		if maze_grid[nr][nc] == 1:
			continue
		all_neighbors.append(ofs)
		if ofs != reverse_dir:
			forward_neighbors.append(ofs)

	var chosen_ofs := Vector2i.ZERO
	if not allow_any and forward_neighbors.has(last_step_dir) and randf() < 0.68:
		# Prefer gliding straight down the corridor when possible so player can easily walk inside it
		chosen_ofs = last_step_dir
	elif not forward_neighbors.is_empty():
		chosen_ofs = forward_neighbors[randi() % forward_neighbors.size()]
	elif not all_neighbors.is_empty():
		chosen_ofs = all_neighbors[randi() % all_neighbors.size()]

	if chosen_ofs != Vector2i.ZERO:
		last_step_dir = chosen_ofs
		target_cell = Vector2i(cur_cell.x + chosen_ofs.x, cur_cell.y + chosen_ofs.y)
	else:
		target_cell = cur_cell

func _repel_nearby_monsters(delta: float) -> void:
	var groups_to_repel = ["hunter", "statues", "crawlers", "cultists"]
	for g_name in groups_to_repel:
		for m in get_tree().get_nodes_in_group(g_name):
			if not is_instance_valid(m) or not (m is CharacterBody3D):
				continue
			if not bool(m.get("active")):
				continue
			var diff: Vector3 = m.global_position - global_position
			diff.y = 0.0
			var dist: float = diff.length()
			if dist < CLOAK_REPEL_RADIUS:
				var push_dir: Vector3 = diff.normalized() if dist > 0.05 else -global_transform.basis.z.normalized()
				push_dir.y = 0.0
				var strength: float = ((CLOAK_REPEL_RADIUS - dist) / CLOAK_REPEL_RADIUS) * 8.5 + 3.5
				m.global_position += push_dir * strength * delta
				if m.has_method("on_repelled_by_cloak"):
					m.on_repelled_by_cloak(global_position)

func _check_first_sighting_scare() -> void:
	if get_tree().has_meta("_cloak_first_scare_done"):
		return
	if not player or not is_instance_valid(player):
		return
	var to_cloak: Vector3 = global_position - player.global_position
	to_cloak.y = 0.0
	var d: float = to_cloak.length()
	if d > 11.5 or d < 1.8:
		return
	var p_fwd: Vector3 = -player.global_transform.basis.z
	p_fwd.y = 0.0
	if p_fwd.normalized().dot(to_cloak.normalized()) < 0.45:
		return
	var space_state = get_world_3d().direct_space_state
	var q = PhysicsRayQueryParameters3D.create(
		player.global_position + Vector3(0, 1.5, 0),
		global_position + Vector3(0, 1.5, 0),
		1
	)
	if not space_state.intersect_ray(q).is_empty():
		return

	get_tree().set_meta("_cloak_first_scare_done", true)
	SoundEffects.play(SoundEffects.snd_whisper, 2.5, 0.78)
	if player.has_method("add_camera_shake"):
		player.add_camera_shake(0.32)
	var hud_node = get_tree().root.find_child("HUD", true, false)
	if hud_node and hud_node.has_method("show_toast"):
		hud_node.show_toast("⚠ WHAT IS THAT?! A floating black shroud drifting down the hall!", Color(0.85, 0.55, 1.0))
		get_tree().create_timer(3.4).timeout.connect(func():
			if is_instance_valid(hud_node) and not is_hostile:
				hud_node.show_toast("...It's neutral. Walk inside the Cloak at its pace to hide from other monsters—just don't stay until you suffocate!", Color(0.55, 0.9, 1.0))
		)

# Death 1: Player stayed inside the Cloak too long -> gradual asphyxiation, blurred vision, rapid gasping -> death
func trigger_suffocation_kill() -> void:
	if is_killing or (player and bool(player.get("god_mode"))):
		return
	is_killing = true
	kill_mode = "suffocate"
	kill_anim_timer = 0.0
	velocity = Vector3.ZERO
	var reason := "SUFFOCATED INSIDE THE CLOAK — YOU RAN OUT OF BREATH AND BLACKED OUT."
	SoundEffects.play_breath_gasp(1.0)
	if player and is_instance_valid(player) and player.has_method("start_death_sequence"):
		player.start_death_sequence(self, "cloak_suffocate", 1.85, func():
			player_killed.emit(reason)
		)
	else:
		player_killed.emit(reason)

# Death 2: Player hit the Cloak -> cloth coils tightly around player's body and strangles their neck to death
func _trigger_strangle_kill() -> void:
	if is_killing or (player and bool(player.get("god_mode"))):
		return
	is_killing = true
	is_hostile = true
	kill_mode = "strangle"
	kill_anim_timer = 0.0
	for e in eye_nodes:
		if is_instance_valid(e):
			e.visible = true
	for c_node in strangle_coils:
		if is_instance_valid(c_node):
			c_node.visible = true
	velocity = Vector3.ZERO
	var reason := "STRANGLED TO DEATH — THE CLOAK WRAPPED AROUND YOUR BODY AND CRUSHED YOUR THROAT."
	SoundEffects.play_cloth_wrap()
	SoundEffects.play_breath_gasp(0.95)
	var hud_node = get_tree().root.find_child("HUD", true, false)
	if hud_node and hud_node.has_method("flash_damage"):
		hud_node.flash_damage()
	if player and is_instance_valid(player) and player.has_method("start_death_sequence"):
		player.start_death_sequence(self, "cloak_strangle", 1.95, func():
			player_killed.emit(reason)
		)
	else:
		player_killed.emit(reason)

func _animate_cloth(_delta: float) -> void:
	if not mesh_root:
		return
	var wave_spd: float = 6.5 if is_hostile else 2.8
	mesh_root.position.y = 0.14 + sin(anim_time * wave_spd) * 0.09
	mesh_root.rotation.z = sin(anim_time * (wave_spd * 0.6)) * 0.05

	var wrap_tightness: float = 0.0
	if is_killing and kill_mode == "strangle":
		wrap_tightness = clampf(kill_anim_timer / 1.10, 0.0, 1.0)

	for i in range(shroud_panels.size()):
		var p = shroud_panels[i]
		var base_ang: float = float(p.get_meta("base_ang", float(i) * (TAU / 16.0)))
		var rad: float = lerpf(0.72, 0.25, wrap_tightness)
		var spin: float = wrap_tightness * 2.4
		p.position.x = cos(base_ang + spin) * rad
		p.position.z = sin(base_ang + spin) * rad
		p.rotation.y = -(base_ang + spin) + PI * 0.5
		p.rotation.x = 0.08 + sin(anim_time * wave_spd + float(i) * 0.65) * (0.24 if is_hostile else 0.13)
		p.rotation.z = cos(anim_time * (wave_spd * 0.8) + float(i) * 0.8) * 0.08

	for i in range(ribbon_strips.size()):
		var r = ribbon_strips[i]
		r.rotation.x = 0.16 + sin(anim_time * (wave_spd * 1.35) + float(i) * 1.1) * (0.36 if is_hostile else 0.20)
		r.rotation.z = cos(anim_time * (wave_spd * 1.1) + float(i) * 0.8) * 0.16

	if is_killing and kill_mode == "strangle":
		for c_idx in range(strangle_coils.size()):
			var coil = strangle_coils[c_idx]
			if is_instance_valid(coil):
				coil.rotation.y = anim_time * (10.0 if c_idx % 2 == 0 else -10.0)
				var s_rad: float = lerpf(1.45, 0.52 if c_idx == 5 else 0.68, wrap_tightness)
				coil.scale = Vector3(s_rad, 1.0 + wrap_tightness * 0.5, s_rad)
