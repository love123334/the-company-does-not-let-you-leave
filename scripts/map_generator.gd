extends Node3D

const U: float = GameData.UNIT
const H: float = GameData.WALL_HEIGHT

const InteractableScript = preload("res://scripts/interactable.gd")

signal spill_cleaned(is_blood: bool)
signal terminal_checked()
signal keycard_collected()
signal relic_collected(val: int)
signal exit_reached()
signal note_inspected(note_id: String)
signal gate_toggled(is_closed: bool)
signal secret_corridor_state_changed(inside: bool)
signal pedestal_activated(pedestal_idx: int, total_activated: int)
signal f2_terminal_shutdown(done_count: int, total_count: int)
signal f2_usb_picked_up()
signal f2_usb_deposited()
signal f2_dossier_picked_up()
signal f2_dossier_archived()
signal f2_coolant_picked_up()
signal f2_coolant_injected()

var biotank_node: Node3D = null
var emergency_lights: Array[OmniLight3D] = []
var active_gates: Array[Dictionary] = []
var floor2_walkway_positions: Array[Vector3] = []
var stair_positions: Array[Vector3] = []
var active_interactables: Array = []
var keycard_entries: Array[Dictionary] = []
var cage_slots: Array[Dictionary] = []
var pedestals_activated_count: int = 0
var weapon_candidate_slots: Array[Vector3] = []
var statue_fences: Array[Node3D] = []

# Floor 2 Lab Task Progress Variables
var f2_rogue_terminals_shut: int = 0
var f2_rogue_terminals_total: int = 2
var f2_usb_carried: bool = false
var f2_usb_is_archived: bool = false
var f2_dossier_carried: bool = false
var f2_dossier_is_archived: bool = false
var f2_coolant_carried: bool = false
var f2_coolant_is_injected: bool = false
var active_day: int = 1
var f2_vault_waypoint: Node3D = null
var f2_archive_waypoint: Node3D = null
var f2_server_waypoint: Node3D = null
var f2_station_positions: Dictionary = {}

# Weapon Spawning Limits (Max 1 Baton, Max 3 Tasers per night)
var batons_spawned: int = 0
var tasers_spawned: int = 0
const MAX_BATONS_PER_MAP: int = 1
const MAX_TASERS_PER_MAP: int = 3

func _load_tex(p: String) -> Texture2D:
	if ResourceLoader.exists(p):
		return load(p)
	return null

func build_map(in_grid: Array, player: Node3D, current_day: int) -> Dictionary:
	var grid: Array = in_grid.duplicate(true)
	for c in get_children():
		c.queue_free()
	emergency_lights.clear()
	active_gates.clear()
	floor2_walkway_positions.clear()
	stair_positions.clear()
	active_interactables.clear()
	keycard_entries.clear()
	cage_slots.clear()
	weapon_candidate_slots.clear()
	statue_fences.clear()
	pedestals_activated_count = 0
	batons_spawned = 0
	tasers_spawned = 0

	# Reset Floor 2 Task States
	active_day = current_day
	f2_rogue_terminals_shut = 0
	f2_rogue_terminals_total = 2
	f2_usb_carried = false
	f2_usb_is_archived = false
	f2_dossier_carried = false
	f2_dossier_is_archived = false
	f2_coolant_carried = false
	f2_coolant_is_injected = false
	f2_vault_waypoint = null
	f2_archive_waypoint = null
	f2_server_waypoint = null

	if not f2_usb_picked_up.is_connected(_on_internal_f2_usb_picked_up):
		f2_usb_picked_up.connect(_on_internal_f2_usb_picked_up)
		f2_usb_deposited.connect(_on_internal_f2_usb_deposited)
		f2_dossier_picked_up.connect(_on_internal_f2_dossier_picked_up)
		f2_dossier_archived.connect(_on_internal_f2_dossier_archived)
		f2_coolant_picked_up.connect(_on_internal_f2_coolant_picked_up)
		f2_coolant_injected.connect(_on_internal_f2_coolant_injected)

	var S = grid.size()
	var results = {
		"hunter_pos": Vector3(6.0 * U, 0, 1.0 * U),
		"statue_positions": [],
		"open_positions": [],
		"cage_slots": []
	}

	var wall_tex = _load_tex("res://textures/wall.png")
	var floor_tex = _load_tex("res://textures/floor.png")
	var ceil_tex = _load_tex("res://textures/ceiling.png")

	var wall_mat = StandardMaterial3D.new()
	if wall_tex:
		wall_mat.albedo_texture = wall_tex
		wall_mat.uv1_scale = Vector3(1, 1, 1)
	else:
		wall_mat.albedo_color = Color(0.2, 0.22, 0.25)
	wall_mat.roughness = 0.65

	var floor_mat = StandardMaterial3D.new()
	if floor_tex:
		floor_mat.albedo_texture = floor_tex
		floor_mat.uv1_scale = Vector3(float(S), float(S), 1)
	else:
		floor_mat.albedo_color = Color(0.12, 0.14, 0.16)
	floor_mat.roughness = 0.8

	var ceil_mat = StandardMaterial3D.new()
	ceil_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if ceil_tex:
		ceil_mat.albedo_texture = ceil_tex
		ceil_mat.uv1_scale = Vector3(float(S) / 2.0, float(S) / 2.0, 1)
	else:
		ceil_mat.albedo_color = Color(0.1, 0.11, 0.13)

	# Ensure map center has an open 4-way corridor hub for the central spiral staircase
	var r_c = S / 2
	var c_c = S / 2
	grid[r_c][c_c] = 0
	if r_c > 1: grid[r_c - 1][c_c] = 0
	if r_c < S - 2: grid[r_c + 1][c_c] = 0
	if c_c > 1: grid[r_c][c_c - 1] = 0
	if c_c < S - 2: grid[r_c][c_c + 1] = 0

	var niche_map = _plan_niches(grid)

	# Floor Mesh & Solid Floor StaticBody
	var floor_inst = MeshInstance3D.new()
	var floor_mesh = PlaneMesh.new()
	floor_mesh.size = Vector2(float(S) * U, float(S) * U)
	floor_inst.mesh = floor_mesh
	floor_inst.position = Vector3((float(S) * U) / 2.0 - U / 2.0, 0.0, (float(S) * U) / 2.0 - U / 2.0)
	floor_inst.material_override = floor_mat

	var floor_body = StaticBody3D.new()
	var floor_col = CollisionShape3D.new()
	var floor_shape = BoxShape3D.new()
	floor_shape.size = Vector3(float(S) * U, 0.2, float(S) * U)
	floor_col.shape = floor_shape
	floor_col.position.y = -0.1
	floor_body.add_child(floor_col)
	floor_inst.add_child(floor_body)
	add_child(floor_inst)

	# Ceiling Mesh
	if current_day < 3:
		var ceil_inst = MeshInstance3D.new()
		var ceil_mesh = PlaneMesh.new()
		ceil_mesh.size = Vector2(float(S) * U, float(S) * U)
		ceil_inst.mesh = ceil_mesh
		ceil_inst.rotation.x = PI
		ceil_inst.position = Vector3((float(S) * U) / 2.0 - U / 2.0, H, (float(S) * U) / 2.0 - U / 2.0)
		ceil_inst.material_override = ceil_mat
		add_child(ceil_inst)
	else:
		# On Night 3+, cut an exact rectangular opening for the enclosed stairwell shaft
		# Shaft is centered at (c_c * U, r_c * U), footprint: X in [-2.0, 2.0], Z in [-3.75, 3.75]
		var total_map_size = float(S) * U
		var map_min_x = -U * 0.5
		var map_max_x = map_min_x + total_map_size
		var map_min_z = -U * 0.5
		var map_max_z = map_min_z + total_map_size
		var c_x = float(c_c) * U
		var c_z = float(r_c) * U
		var hole_hw = 2.0
		var hole_hl = 3.75

		var add_ceil_slab = func(cx: float, cz: float, sx: float, sz: float):
			if sx <= 0.01 or sz <= 0.01:
				return
			var ci = MeshInstance3D.new()
			var cm = PlaneMesh.new()
			cm.size = Vector2(sx, sz)
			ci.mesh = cm
			ci.rotation.x = PI
			ci.position = Vector3(cx, H, cz)
			ci.material_override = ceil_mat
			add_child(ci)

		# 1. North slab (full width in X, from map_min_z to c_z - hole_hl)
		var n_len = (c_z - hole_hl) - map_min_z
		add_ceil_slab.call((map_min_x + map_max_x) * 0.5, map_min_z + n_len * 0.5, total_map_size, n_len)

		# 2. South slab (full width in X, from c_z + hole_hl to map_max_z)
		var s_len = map_max_z - (c_z + hole_hl)
		add_ceil_slab.call((map_min_x + map_max_x) * 0.5, (c_z + hole_hl) + s_len * 0.5, total_map_size, s_len)

		# 3. West slab (between c_z - hole_hl and c_z + hole_hl, from map_min_x to c_x - hole_hw)
		var w_len = (c_x - hole_hw) - map_min_x
		add_ceil_slab.call(map_min_x + w_len * 0.5, c_z, w_len, hole_hl * 2.0)

		# 4. East slab (between c_z - hole_hl and c_z + hole_hl, from c_x + hole_hw to map_max_x)
		var e_len = map_max_x - (c_x + hole_hw)
		add_ceil_slab.call((c_x + hole_hw) + e_len * 0.5, c_z, e_len, hole_hl * 2.0)

	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(U, H, U)

	var day_note_pools = {
		1: ["note_entry", "note_warning", "note_map", "note_trap"],
		2: ["n2_1", "n2_2", "note_warning", "note_map"],
		3: ["n3_1", "n3_2", "n2_1", "n2_2"],
		4: ["n4_1", "n3_2", "n3_1", "n2_1"],
		5: ["n5_1", "n4_1", "n3_2", "n2_1"]
	}
	var note_keys: Array = day_note_pools.get(current_day, ["note_entry", "note_warning", "note_map", "note_trap"])
	var note_idx = 0
	var main_biotank_found = false

	# Grid placement using exact HTML tile codes
	for r in range(S):
		for c in range(S):
			var type = grid[r][c]
			var pos = Vector3(float(c) * U, 0.0, float(r) * U)

			if type == 1:
				var cell_coord = Vector2i(r, c)
				if current_day == 5 and r == 0 and c == 13:
					# Leave open doorway at (r=0, c=13) leading north into the Night 5 Secret Sanctuary Corridor!
					_build_night5_secret_corridor(pos, wall_mat, floor_mat, ceil_mat)
				elif niche_map.has(cell_coord):
					_build_niche(niche_map[cell_coord], wall_mat)
				else:
					var body = StaticBody3D.new()
					body.position = pos + Vector3(0, H / 2.0, 0)

					var col = CollisionShape3D.new()
					var shape = BoxShape3D.new()
					shape.size = Vector3(U, H, U)
					col.shape = shape
					body.add_child(col)

					var wall = MeshInstance3D.new()
					wall.mesh = box_mesh
					wall.material_override = wall_mat
					body.add_child(wall)

					add_child(body)
			else:
				if (r + c) % 4 == 0:
					var is_stair_zone = current_day >= 3 and abs(r - r_c) <= 2 and abs(c - c_c) <= 2
					if not is_stair_zone:
						_create_fluorescent_light(pos)

				match type:
					GameData.TileType.KEYCARD: # 2
						_create_keycard(pos)
					GameData.TileType.TRAP: # 3: Security Gate Trap
						_create_security_gate(pos, r, c, grid)
					GameData.TileType.EXIT: # 4
						_create_exit(c, r, grid)
					GameData.TileType.BIOTANK: # 5
						var is_main = not main_biotank_found
						if is_main:
							main_biotank_found = true
						var tank_h_pos = _create_biotank(pos, is_main, r, c, grid)
						if is_main:
							results["hunter_pos"] = tank_h_pos
					GameData.TileType.SPILL: # 6
						_create_spill(pos, false)
					GameData.TileType.TERMINAL: # 7
						_create_terminal(pos, r, c, grid)
					GameData.TileType.LORE_NOTE: # 8
						var note_id = note_keys[(current_day - 1 + note_idx) % note_keys.size()]
						note_idx += 1
						_create_lore_note(pos, note_id)
					GameData.TileType.MAP_FRAGMENT: # 9
						_create_map_fragment(pos)
					GameData.TileType.ARTIFACT: # 10
						_create_artifact(pos)

	# Ensure Hunter is always securely sealed in a BioTank during work shift on every map
	if not main_biotank_found:
		var bt_cell = Vector3(6.0 * U, 0, 1.0 * U)
		var bt_r = 1
		var bt_c = 6
		for r in range(S - 2, 1, -1):
			var found_open = false
			for c in range(S - 2, 1, -1):
				if grid[r][c] == 0:
					bt_cell = Vector3(float(c) * U, 0, float(r) * U)
					bt_r = r
					bt_c = c
					found_open = true
					break
			if found_open:
				break
		main_biotank_found = true
		results["hunter_pos"] = _create_biotank(bt_cell, true, bt_r, bt_c, grid)

	_build_ceiling_pipes(grid)

	# Spawn blood stains (at least 3 per night for bonus +$15 objective)
	var blood_count = 0
	for r in range(1, S - 1):
		for c in range(1, S - 1):
			if grid[r][c] == 0 and ((r * 31 + c * 17) % 23 == 3):
				_create_spill(Vector3(float(c) * U, 0.0, float(r) * U), true)
				blood_count += 1
	if blood_count < 3:
		for r in range(2, S - 2):
			for c in range(2, S - 2):
				if grid[r][c] == 0 and blood_count < 3 and (r + c) > 5:
					_create_spill(Vector3(float(c) * U, 0.0, float(r) * U), true)
					blood_count += 1

	# Build Floor 2 Observation Lab & Central Spiral Stairs (Stairs appear from Night 3+)
	results["floor2_grid"] = _build_floor2_level(S, current_day)
	if current_day >= 3:
		var center_stair_pos = Vector3(float(c_c) * U, 0.0, float(r_c) * U)
		stair_positions.append(center_stair_pos)
		_create_switchback_staircase(center_stair_pos)

	player.global_position = Vector3(1.0 * U, 0.6, 1.0 * U)
	if "current_floor" in player:
		player.current_floor = 1

	# Collect valid open corridor spawn positions far from player start (1, 1)
	var open_cells: Array[Vector3] = []
	for r in range(2, S - 2):
		for c in range(2, S - 2):
			if grid[r][c] == 0:
				var wx = float(c) * U
				var wz = float(r) * U
				if Vector2(wx - U, wz - U).length() > 14.0:
					open_cells.append(Vector3(wx, 0, wz))
	open_cells.shuffle()
	results["open_positions"] = open_cells
	results["cage_slots"] = cage_slots
	results["floor2_walkways"] = floor2_walkway_positions
	results["stair_positions"] = stair_positions

	# Collect statue containment candidates snapped against corridor walls (never blocking hallway center)
	var statue_wall_candidates: Array[Vector3] = []
	for r in range(2, S - 2):
		for c in range(2, S - 2):
			if grid[r][c] == 0:
				var wx = float(c) * U
				var wz = float(r) * U
				if Vector2(wx - U, wz - U).length() > 14.0:
					var d4 = [
						{"dr": -1, "dc": 0, "off": Vector3(0, 0, -1.25)},
						{"dr": 1, "dc": 0, "off": Vector3(0, 0, 1.25)},
						{"dr": 0, "dc": -1, "off": Vector3(-1.25, 0, 0)},
						{"dr": 0, "dc": 1, "off": Vector3(1.25, 0, 0)}
					]
					for d in d4:
						if grid[r + d["dr"]][c + d["dc"]] == 1:
							statue_wall_candidates.append(Vector3(wx, 0, wz) + d["off"])
							break
	statue_wall_candidates.shuffle()

	var day_meta = GameData.DAY_META[clampi(current_day - 1, 0, GameData.DAY_META.size() - 1)]
	var st_count = int(day_meta.get("statues", 0))
	for i in range(min(st_count, statue_wall_candidates.size())):
		results["statue_positions"].append(statue_wall_candidates[i])
	if results["statue_positions"].size() < st_count:
		for i in range(min(st_count - results["statue_positions"].size(), open_cells.size())):
			results["statue_positions"].append(open_cells[i])

	# Spawn facility weapons (Guaranteed 1 Shock Baton and 2-3 Stun Guns every night)
	_spawn_facility_weapons(open_cells)

	return results

func _plan_niches(g: Array) -> Dictionary:
	var m = {}
	var S = g.size()
	var d4 = [Vector2i(-1,0), Vector2i(1,0), Vector2i(0,-1), Vector2i(0,1)]
	var kinds = ["cage", "locker", "booth", "locker", "cage", "gurney", "locker", "cage", "desk"]
	var count = 0
	for r in range(1, S - 1):
		for c in range(1, S - 1):
			if g[r][c] != 1 or (r + c) < 4:
				continue
			var open_neighbors = []
			for d in d4:
				if g[r + d.x][c + d.y] == 0:
					open_neighbors.append(d)
			if open_neighbors.size() == 0:
				continue
			var chosen = open_neighbors[(r + c) % open_neighbors.size()]
			# Prioritize at least 14 cages first so all monsters on Floor 1 are 100% caged
			var kind = "cage" if count < 14 else kinds[count % kinds.size()]
			count += 1
			m[Vector2i(r, c)] = { "r": r, "c": c, "a": chosen.x, "b": chosen.y, "kind": kind }
	return m

# Dynamic fallback holding cage created in-world if niche slots are ever exhausted
func create_holding_cage(pos: Vector3, rot_y: float = 0.0) -> Dictionary:
	var group = Node3D.new()
	group.position = pos
	group.rotation.y = rot_y
	add_child(group)

	var wall_mat = StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.18, 0.20, 0.24)
	wall_mat.roughness = 0.7

	var metal_mat = StandardMaterial3D.new()
	metal_mat.albedo_color = Color(0.35, 0.38, 0.42)
	metal_mat.metallic = 0.8
	metal_mat.roughness = 0.3

	# Back wall, side walls, and solid ceiling
	_add_box(group, Vector3(2.8, 3.2, 0.2), Vector3(0, 1.6, -1.0), wall_mat, true)
	_add_box(group, Vector3(0.2, 3.2, 2.0), Vector3(-1.3, 1.6, 0.0), wall_mat, true)
	_add_box(group, Vector3(0.2, 3.2, 2.0), Vector3(1.3, 1.6, 0.0), wall_mat, true)
	_add_box(group, Vector3(2.8, 0.2, 2.0), Vector3(0, 3.2, 0.0), wall_mat, true)

	var bars_node = Node3D.new()
	bars_node.name = "HoldingBars"
	group.add_child(bars_node)

	for bi in range(9):
		var bar_x = -1.0 + float(bi) * 0.25
		var bar_inst = MeshInstance3D.new()
		var bar_c = CylinderMesh.new()
		bar_c.top_radius = 0.02
		bar_c.bottom_radius = 0.02
		bar_c.height = 2.4
		bar_inst.mesh = bar_c
		bar_inst.position = Vector3(bar_x, 1.2, 0.95)
		bar_inst.material_override = metal_mat
		bars_node.add_child(bar_inst)

	# 3 Horizontal rings around cage
	for ri in range(3):
		var r_mesh = MeshInstance3D.new()
		var torus = TorusMesh.new()
		torus.inner_radius = 0.72
		torus.outer_radius = 0.76
		r_mesh.mesh = torus
		r_mesh.position = Vector3(0, 0.4 + float(ri) * 0.7, 0)
		r_mesh.material_override = metal_mat
		bars_node.add_child(r_mesh)

	# Placard
	var placard = MeshInstance3D.new()
	var p_box = BoxMesh.new()
	p_box.size = Vector3(0.7, 0.35, 0.04)
	placard.mesh = p_box
	placard.position = Vector3(0, 1.6, 0.98)
	var p_mat = StandardMaterial3D.new()
	p_mat.albedo_color = Color(0.12, 0.15, 0.22)
	placard.material_override = p_mat

	var p_label = Label3D.new()
	p_label.text = "SPECIMEN FILE: SECURED\nHOLDING CAGE CLASS A\nACTIVE BARS • DANGER\nCLEARANCE: RESTRICTED"
	p_label.font = preload("res://fonts/ShareTechMono-Regular.ttf")
	p_label.font_size = 18
	p_label.pixel_size = 0.0022
	p_label.modulate = Color(0.95, 0.25, 0.25)
	p_label.outline_modulate = Color(0, 0, 0)
	p_label.outline_size = 3
	p_label.position = Vector3(0, 0, 0.024)
	placard.add_child(p_label)
	bars_node.add_child(placard)

	var caged_world = group.to_global(Vector3(0, 0.06, 0.0))
	var forward_dir = Vector3(sin(rot_y), 0, cos(rot_y))
	var release_world = pos + forward_dir * 2.2

	# External Security Weapon Console beside holding cage (clearly visible in corridor)
	_add_box(group, Vector3(0.5, 0.85, 0.4), Vector3(1.4, 0.425, 0.6), wall_mat, true)
	weapon_candidate_slots.append(group.to_global(Vector3(1.4, 0.88, 0.6)))

	var slot = {
		"caged_pos": caged_world,
		"release_pos": release_world,
		"bars_node": bars_node,
		"rot": rot_y,
		"label": p_label
	}
	cage_slots.append(slot)
	return slot

func _build_niche(n: Dictionary, wall_mat: Material) -> void:
	var group = Node3D.new()
	group.position = Vector3(float(n.c) * U, 0.0, float(n.r) * U)
	group.rotation.y = atan2(float(n.b), float(n.a))
	add_child(group)

	var dark_mat = StandardMaterial3D.new()
	dark_mat.albedo_color = Color(0.1, 0.12, 0.15)
	dark_mat.roughness = 0.8

	var metal_mat = StandardMaterial3D.new()
	metal_mat.albedo_color = Color(0.35, 0.38, 0.42)
	metal_mat.metallic = 0.7
	metal_mat.roughness = 0.4

	_add_box(group, Vector3(4.0, 3.8, 1.4), Vector3(0, 1.9, -1.3), wall_mat, true)
	_add_box(group, Vector3(0.7, 3.8, 2.6), Vector3(-1.65, 1.9, 0.7), wall_mat, true)
	_add_box(group, Vector3(0.7, 3.8, 2.6), Vector3(1.65, 1.9, 0.7), wall_mat, true)
	_add_box(group, Vector3(2.6, 1.1, 2.6), Vector3(0, 3.25, 0.7), wall_mat, false)
	_add_box(group, Vector3(4.0, 3.8, 0.6), Vector3(0, 1.9, -1.8), wall_mat, true)

	# Monster-blocking barrier across niche mouth on Layer 8 (keeps Hunter, Statues and Crawlers in corridors)
	var m_barrier = StaticBody3D.new()
	m_barrier.position = Vector3(0, 1.9, 1.85)
	m_barrier.collision_layer = 8
	m_barrier.collision_mask = 0
	var mb_col = CollisionShape3D.new()
	var mb_shape = BoxShape3D.new()
	mb_shape.size = Vector3(2.8, 3.8, 0.4)
	mb_col.shape = mb_shape
	m_barrier.add_child(mb_col)
	group.add_child(m_barrier)

	match n.kind:
		"locker":
			# Left and Right closed lockers
			for x_offset in [-0.72, 0.72]:
				_add_box(group, Vector3(0.64, 2.1, 0.62), Vector3(x_offset, 1.05, -0.25), metal_mat, true)

			# Center openable hiding locker (hollow interior so camera sits cleanly inside)
			_add_box(group, Vector3(0.66, 2.1, 0.06), Vector3(0.0, 1.05, -0.55), dark_mat, false)
			_add_box(group, Vector3(0.66, 0.08, 0.62), Vector3(0.0, 2.08, -0.25), metal_mat, false)
			# Slightly ajar locker door with vent slits
			var door_pivot = Node3D.new()
			door_pivot.position = Vector3(-0.31, 1.05, 0.05)
			door_pivot.rotation.y = -0.78
			group.add_child(door_pivot)
			_add_box(door_pivot, Vector3(0.62, 2.02, 0.05), Vector3(0.31, 0, 0), metal_mat, false)

			var area = Area3D.new()
			area.set_script(InteractableScript)
			area.set("prompt_text", "[E] Hide in Locker")
			var col = CollisionShape3D.new()
			var shape = BoxShape3D.new()
			shape.size = Vector3(2.2, 2.4, 2.8)
			col.shape = shape
			col.position = Vector3(0, 1.1, 0.8)
			area.add_child(col)
			area.connect("interacted", func(p):
				if not p.get("is_hiding"):
					p.enter_locker(group)
					area.set("prompt_text", "[E] Exit Locker")
				else:
					p.exit_locker()
					area.set("prompt_text", "[E] Hide in Locker")
			)
			group.add_child(area)

		"desk":
			_add_box(group, Vector3(1.9, 0.8, 0.7), Vector3(0, 0.45, -0.2), metal_mat, true)
			var mon = _add_box(group, Vector3(0.55, 0.36, 0.06), Vector3(0, 1.05, -0.4), dark_mat, false)
			var scr = MeshInstance3D.new()
			var s_box = BoxMesh.new()
			s_box.size = Vector3(0.48, 0.28, 0.02)
			scr.mesh = s_box
			scr.position = Vector3(0, 0, 0.04)
			var scr_mat = StandardMaterial3D.new()
			scr_mat.albedo_color = Color(0.1, 0.85, 0.8)
			scr_mat.emission_enabled = true
			scr_mat.emission = Color(0.1, 0.85, 0.8)
			scr_mat.emission_energy_multiplier = 1.2
			scr.material_override = scr_mat
			mon.add_child(scr)
			_add_box(group, Vector3(0.45, 0.06, 0.45), Vector3(0, 0.45, 0.35), dark_mat, true)
			_add_box(group, Vector3(0.45, 0.5, 0.06), Vector3(0, 0.72, 0.55), dark_mat, false)
			weapon_candidate_slots.append(group.to_global(Vector3(0.45, 0.90, -0.2)))

		"booth":
			_add_box(group, Vector3(2.1, 0.15, 1.9), Vector3(0, 0.08, 0.6), metal_mat, true)
			_add_box(group, Vector3(2.1, 0.15, 1.9), Vector3(0, 2.55, 0.6), metal_mat, false)
			var g_mat = StandardMaterial3D.new()
			g_mat.albedo_color = Color(0.15, 0.8, 0.4, 0.25)
			g_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			g_mat.roughness = 0.08
			_add_box(group, Vector3(2.0, 2.3, 1.8), Vector3(0, 1.35, 0.6), g_mat, true)

			var spec = MeshInstance3D.new()
			var s_cyl = CylinderMesh.new()
			s_cyl.top_radius = 0.18
			s_cyl.bottom_radius = 0.12
			s_cyl.height = 1.4
			spec.mesh = s_cyl
			spec.position = Vector3(0, 1.35, 0.6)
			var sp_mat = StandardMaterial3D.new()
			sp_mat.albedo_color = Color(0.5, 0.1, 0.15)
			sp_mat.roughness = 0.7
			spec.material_override = sp_mat
			group.add_child(spec)

			var s_light = OmniLight3D.new()
			s_light.position = Vector3(0, 1.8, 0.6)
			s_light.light_color = Color(0.2, 0.95, 0.5)
			s_light.light_energy = 1.5
			s_light.omni_range = 4.0
			group.add_child(s_light)

		"gurney":
			_add_box(group, Vector3(1.8, 0.8, 0.7), Vector3(0, 0.45, 0.6), metal_mat, true)
			var bag = MeshInstance3D.new()
			var cyl = CylinderMesh.new()
			cyl.top_radius = 0.22
			cyl.bottom_radius = 0.18
			cyl.height = 1.55
			bag.mesh = cyl
			bag.rotation.z = PI / 2.0
			bag.position = Vector3(0, 0.98, 0.6)
			var bag_mat = StandardMaterial3D.new()
			bag_mat.albedo_color = Color(0.78, 0.8, 0.78)
			bag_mat.roughness = 0.85
			bag.material_override = bag_mat
			group.add_child(bag)

		_:
			# Observation Cage with raisable bars & placard for live Crawler/Cultist specimens
			var cage_root = Node3D.new()
			cage_root.position = Vector3(0, 0, 0.6)
			group.add_child(cage_root)

			# Cage floor base & high ceiling plate (placed high at 3.4m so it never snags tall monsters)
			_add_box(cage_root, Vector3(1.7, 0.1, 1.7), Vector3(0, 0.05, 0), metal_mat, false)
			_add_box(cage_root, Vector3(1.7, 0.1, 1.7), Vector3(0, 3.4, 0), metal_mat, false)

			var bars_node = Node3D.new()
			bars_node.name = "CageBars"
			cage_root.add_child(bars_node)

			# 8 Cylindrical vertical iron bars
			for bi in range(8):
				var ang = (float(bi) / 8.0) * TAU
				var bar_x = cos(ang) * 0.75
				var bar_z = sin(ang) * 0.75
				var bar_inst = MeshInstance3D.new()
				var bar_c = CylinderMesh.new()
				bar_c.top_radius = 0.025
				bar_c.bottom_radius = 0.025
				bar_c.height = 1.85
				bar_inst.mesh = bar_c
				bar_inst.position = Vector3(bar_x, 1.0, bar_z)
				bar_inst.material_override = metal_mat
				bars_node.add_child(bar_inst)

			# 3 Horizontal rings around cage
			for ri in range(3):
				var r_mesh = MeshInstance3D.new()
				var torus = TorusMesh.new()
				torus.inner_radius = 0.72
				torus.outer_radius = 0.76
				r_mesh.mesh = torus
				r_mesh.position = Vector3(0, 0.35 + float(ri) * 0.6, 0)
				r_mesh.material_override = metal_mat
				bars_node.add_child(r_mesh)

			# Observation Placard with crisp 3D text
			var placard = MeshInstance3D.new()
			var p_box = BoxMesh.new()
			p_box.size = Vector3(0.64, 0.34, 0.04)
			placard.mesh = p_box
			placard.position = Vector3(0, 1.45, 0.76)
			var p_mat = StandardMaterial3D.new()
			p_mat.albedo_color = Color(0.12, 0.15, 0.22)
			p_mat.roughness = 0.4
			placard.material_override = p_mat

			var p_label = Label3D.new()
			p_label.text = "SPECIMEN FILE: CLASSIFIED\nBIO / CRAWLER - CLASS A\nSEDATED • FEEDING RISK\nCLEARANCE: RESTRICTED"
			p_label.font = preload("res://fonts/ShareTechMono-Regular.ttf")
			p_label.font_size = 18
			p_label.pixel_size = 0.0022
			p_label.modulate = Color(0.95, 0.25, 0.25)
			p_label.outline_modulate = Color(0, 0, 0)
			p_label.outline_size = 3
			p_label.position = Vector3(0, 0, 0.024)
			placard.add_child(p_label)
			bars_node.add_child(placard)

			var caged_world = group.to_global(Vector3(0, 0.06, 0.6))
			var release_world = group.to_global(Vector3(0, 0.05, 3.8))
			cage_slots.append({
				"caged_pos": caged_world,
				"release_pos": release_world,
				"bars_node": bars_node,
				"rot": group.rotation.y,
				"label": p_label
			})
			# External Security Weapon Rack outside the niche cage
			_add_box(group, Vector3(0.5, 0.85, 0.4), Vector3(1.35, 0.425, 0.7), dark_mat, true)
			weapon_candidate_slots.append(group.to_global(Vector3(1.35, 0.88, 0.7)))

func _build_floor2_level(S: int, current_day: int = 1) -> Array:
	var mezz_root = Node3D.new()
	mezz_root.name = "Floor2ObservationLab"
	add_child(mezz_root)

	# High-Tech Sterile Observation Lab Materials (White, Clean, Futuristic, 100% Opaque)
	var lab_floor_mat = StandardMaterial3D.new()
	lab_floor_mat.albedo_color = Color(0.92, 0.94, 0.97)
	lab_floor_mat.metallic = 0.12
	lab_floor_mat.roughness = 0.20

	var lab_wall_mat = StandardMaterial3D.new()
	lab_wall_mat.albedo_color = Color(0.95, 0.96, 0.98)
	lab_wall_mat.metallic = 0.05
	lab_wall_mat.roughness = 0.25

	var lab_ceil_mat = StandardMaterial3D.new()
	lab_ceil_mat.albedo_color = Color(0.90, 0.92, 0.95)
	lab_ceil_mat.metallic = 0.05
	lab_ceil_mat.roughness = 0.35

	var column_mat = StandardMaterial3D.new()
	column_mat.albedo_color = Color(0.25, 0.28, 0.32)
	column_mat.metallic = 0.85
	column_mat.roughness = 0.30

	var steel_rail_mat = StandardMaterial3D.new()
	steel_rail_mat.albedo_color = Color(0.85, 0.88, 0.92)
	steel_rail_mat.metallic = 0.9
	steel_rail_mat.roughness = 0.18

	# Elevation parameters: Floor 2 deck is at 3x Floor 1 height (11.4m), ceiling at 15.6m (4.2m high walls)
	var f2_deck_y: float = 11.4
	var f2_ceil_y: float = 15.6
	var f2_wall_h: float = f2_ceil_y - f2_deck_y # 4.2m

	# Initialize 2D grid for Floor 2 (1 = wall/void, 0 = open corridor/lab hub, 2 = central spiral stair opening)
	var f2_grid: Array = []
	for r in range(S):
		var row: Array = []
		for c in range(S):
			row.append(1)
		f2_grid.append(row)

	var r_c: int = S / 2
	var c_c: int = S / 2

	# 1. Central CCTV Surveillance Control Hub (3x3 room around map center)
	for r in range(r_c - 1, r_c + 2):
		for c in range(c_c - 1, c_c + 2):
			if r >= 0 and r < S and c >= 0 and c < S:
				f2_grid[r][c] = 0
	# Center cell is the spiral staircase hole
	f2_grid[r_c][c_c] = 2

	# 2. Outer Ring Corridor Loop (Continuous closed circular corridor around the hub)
	var ring_dist: int = 4 if (r_c >= 5 and S - 1 - r_c >= 5) else 3
	var r1: int = r_c - ring_dist
	var r2: int = r_c + ring_dist
	var c1: int = c_c - ring_dist
	var c2: int = c_c + ring_dist

	for c in range(c1, c2 + 1):
		if r1 >= 0 and r1 < S and c >= 0 and c < S:
			f2_grid[r1][c] = 0
		if r2 >= 0 and r2 < S and c >= 0 and c < S:
			f2_grid[r2][c] = 0

	for r in range(r1, r2 + 1):
		if r >= 0 and r < S and c1 >= 0 and c1 < S:
			f2_grid[r][c1] = 0
		if r >= 0 and r < S and c2 >= 0 and c2 < S:
			f2_grid[r][c2] = 0

	# 3. Four Cardinal Linking Corridors (North, South, West, East connecting Hub to Outer Ring)
	for r in range(r1 + 1, r_c - 1):
		if r >= 0 and r < S:
			f2_grid[r][c_c] = 0
	for r in range(r_c + 2, r2):
		if r >= 0 and r < S:
			f2_grid[r][c_c] = 0
	for c in range(c1 + 1, c_c - 1):
		if c >= 0 and c < S:
			f2_grid[r_c][c] = 0
	for c in range(c_c + 2, c2):
		if c >= 0 and c < S:
			f2_grid[r_c][c] = 0

	# 4. Physical 3D Construction of Floor 2 (Solid Floor, Solid Ceiling, Enclosing 4.2m Lab Walls)
	var d4 = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
	var prop_idx: int = 0
	var cctv_idx: int = 0

	for r in range(S):
		for c in range(S):
			var tile_type = f2_grid[r][c]
			if tile_type != 0 and tile_type != 2:
				continue

			var wx = float(c) * U
			var wz = float(r) * U

			if tile_type == 0:
				floor2_walkway_positions.append(Vector3(wx, f2_deck_y, wz))
				# Clean Rectangular Opening cut cleanly through Floor 2 floor slab for the stairwell shaft
				# Shaft footprint: x in [-1.8, 1.8], z in [r_c * U - 3.7, r_c * U + 3.7]
				if c == c_c and r == r_c + 1:
					# Trim South border cell so floor slab does not penetrate into the stairwell opening
					var slab_z_start = float(r_c) * U + 3.75
					var slab_z_end = wz + U * 0.5 # r_c * U + 6.0
					var slab_len = slab_z_end - slab_z_start
					var slab_center_z = slab_z_start + slab_len * 0.5
					_add_box(mezz_root, Vector3(U, 0.35, slab_len), Vector3(wx, f2_deck_y - 0.175, slab_center_z), lab_floor_mat, true)
				elif c == c_c and r == r_c - 1:
					# Trim North border cell so floor slab does not penetrate into the stairwell opening
					var slab_z_end = float(r_c) * U - 3.75
					var slab_z_start = wz - U * 0.5 # r_c * U - 6.0
					var slab_len = slab_z_end - slab_z_start
					var slab_center_z = slab_z_start + slab_len * 0.5
					_add_box(mezz_root, Vector3(U, 0.35, slab_len), Vector3(wx, f2_deck_y - 0.175, slab_center_z), lab_floor_mat, true)
				else:
					# Standard solid 100% opaque floor slab (0.35m thick)
					_add_box(mezz_root, Vector3(U, 0.35, U), Vector3(wx, f2_deck_y - 0.175, wz), lab_floor_mat, true)
			elif tile_type == 2:
				# Stairwell shaft opening at map center: cleanly cut, seamlessly enclosed by full-height stairwell walls
				continue

			# Solid 100% Opaque Ceiling Slab (0.35m thick at 15.6m)
			_add_box(mezz_root, Vector3(U, 0.35, U), Vector3(wx, f2_ceil_y + 0.175, wz), lab_ceil_mat, true)

			# Solid Structural Columns extending down from Floor 2 to Floor 1 corners (skip hub perimeter to avoid blocking stairs)
			if (r + c) % 2 == 0 and tile_type == 0 and (abs(r - r_c) > 1 or abs(c - c_c) > 1):
				_add_box(mezz_root, Vector3(0.35, f2_deck_y, 0.35), Vector3(wx, f2_deck_y * 0.5, wz), column_mat, true)

			# Enclosing 4.2m Lab Walls on all borders with outside void
			for d in d4:
				var nr = r + d.x
				var nc = c + d.y
				# Do not generate walls between Floor 2 corridor and stairwell doorway at South
				if r == r_c + 1 and c == c_c and d.x == -1:
					continue
				var is_wall = (nr < 0 or nr >= S or nc < 0 or nc >= S) or (f2_grid[nr][nc] != 0 and f2_grid[nr][nc] != 2)
				if is_wall:
					var rx = wx + float(d.y) * (U * 0.5)
					var rz = wz + float(d.x) * (U * 0.5)
					var wsize = Vector3(U + 0.2, f2_wall_h, 0.25) if d.x != 0 else Vector3(0.25, f2_wall_h, U + 0.2)
					_add_box(mezz_root, wsize, Vector3(rx, f2_deck_y + f2_wall_h * 0.5, rz), lab_wall_mat, true)

			# Bright Lab Overhead Lighting
			if (r + c) % 2 == 0:
				_create_lab_overhead_lamp(mezz_root, Vector3(wx, f2_ceil_y - 0.15, wz))

			# Props and CCTV Monitors inside Central Surveillance Hub
			var is_hub = (abs(r - r_c) <= 1 and abs(c - c_c) <= 1 and tile_type == 0 and not (r == r_c + 1 and c == c_c))
			if is_hub:
				var offset_dir = Vector3(float(c - c_c) * 1.1, 0, float(r - r_c) * 1.1)
				var hub_prop_pos = Vector3(wx, f2_deck_y, wz) + offset_dir
				var facing_rot = atan2(-float(c - c_c), -float(r - r_c))
				if (r == r_c or c == c_c):
					_create_lab_cctv_surveillance_station(mezz_root, hub_prop_pos, facing_rot, cctv_idx)
					cctv_idx += 1
				else:
					_create_lab_server_rack(mezz_root, hub_prop_pos, facing_rot)
			elif tile_type == 0 and (r + c) % 3 == 0:
				# Outer Ring Corridor Props (Research Desks, Terminals, Computers)
				var prop_pos = Vector3(wx, f2_deck_y, wz)
				match prop_idx % 3:
					0:
						_create_lab_computer(mezz_root, prop_pos + Vector3(0.9, 0, 0), 0.0)
					1:
						_create_lab_research_table(mezz_root, prop_pos + Vector3(0, 0, 0.9), PI * 0.5)
					2:
						_create_lab_server_rack(mezz_root, prop_pos + Vector3(-0.9, 0, 0), PI)
				prop_idx += 1

	# When current_day >= 3, build the 4 dedicated Floor 2 Lab Shift Task Stations:
	if current_day >= 3:
		# 1. Rogue PC #1 inside Central Hub (North, facing South)
		var hub_n_pos = Vector3(float(c_c) * U, f2_deck_y, float(r_c - 1) * U - 0.7)
		_create_f2_rogue_terminal(mezz_root, hub_n_pos, PI, 1)

		# 2. Rogue PC #2 at far North corridor of Outer Ring
		var ring_n_pos = Vector3(float(c_c) * U, f2_deck_y, float(r1) * U - 0.7)
		_create_f2_rogue_terminal(mezz_root, ring_n_pos, PI, 2)

		# 3. Encrypted Research USB Workstation at far West of Outer Ring
		var ring_w_pos = Vector3(float(c1) * U - 0.7, f2_deck_y, float(r_c) * U)
		_create_f2_usb_workstation(mezz_root, ring_w_pos, PI * 0.5, current_day)

		# 4. Secure Data Vault inside Central Hub (West cell)
		var hub_w_pos = Vector3(float(c_c - 1) * U - 0.7, f2_deck_y, float(r_c) * U)
		_create_f2_usb_vault(mezz_root, hub_w_pos, PI * 0.5)

		# 5. Classified Dossier Desk at South corridor of Outer Ring
		var ring_s_pos = Vector3(float(c_c - 2) * U, f2_deck_y, float(r2) * U + 0.7)
		_create_f2_dossier_desk(mezz_root, ring_s_pos, 0.0, current_day)

		# 6. Archive Document Shelf inside Central Hub (East cell)
		var hub_e_pos = Vector3(float(c_c + 1) * U + 0.7, f2_deck_y, float(r_c) * U)
		_create_f2_archive_station(mezz_root, hub_e_pos, -PI * 0.5)

		# 7. Cryogenic Coolant Dispenser at far East of Outer Ring
		var ring_e_pos = Vector3(float(c2) * U + 0.7, f2_deck_y, float(r_c) * U)
		_create_f2_coolant_station(mezz_root, ring_e_pos, -PI * 0.5)

		# 8. Overheated Server Rack inside Central Hub (North-East cell)
		var hub_ne_pos = Vector3(float(c_c + 1) * U + 0.7, f2_deck_y, float(r_c - 1) * U)
		_create_f2_overheated_server(mezz_root, hub_ne_pos, -PI * 0.5)

		# 9. Dynamic 3D Floating Delivery Waypoints (visible when item is carried)
		f2_vault_waypoint = _create_3d_waypoint_beacon(mezz_root, hub_w_pos + Vector3(0, 2.3, 0), "SECTION A-1: DATA VAULT\n[E] DEPOSIT ENCRYPTED USB", Color(0.15, 0.85, 1.0))
		f2_archive_waypoint = _create_3d_waypoint_beacon(mezz_root, hub_e_pos + Vector3(0, 2.3, 0), "SECTION B-1: CENTRAL ARCHIVE\n[E] FILE CLASSIFIED DOSSIER", Color(1.0, 0.75, 0.2))
		f2_server_waypoint = _create_3d_waypoint_beacon(mezz_root, hub_ne_pos + Vector3(0, 2.3, 0), "SECTION C-1: SERVER CORE\n[E] INJECT NITROGEN COOLANT", Color(0.3, 0.95, 1.0))

		f2_station_positions = {
			"vault": hub_w_pos,
			"archive": hub_e_pos,
			"server": hub_ne_pos,
			"usb_source": ring_w_pos,
			"dossier_source": ring_s_pos,
			"coolant_source": ring_e_pos
		}

	return f2_grid

# =========================================================================
# REALISTIC MODERN ENCLOSED SWITCHBACK / DOG-LEG STAIRCASE
# - Completely enclosed within full-height 15.6m architectural shaft walls (zero outside void visible)
# - Two wide straight flights connected by a spacious halfway landing at 5.7m
# - Thick solid metal handrails on both sides (silver brushed metal & sturdy posts)
# - Wide comfortable steps with anti-slip yellow safety strips on tread edges
# - Clean rectangular door openings connecting seamlessly to Floor 1 and Floor 2
# - Double-sided smooth walkable trimesh ramps for 100% seamless move_and_slide() traversal
# =========================================================================
func _create_spiral_staircase(pos: Vector3) -> void:
	_create_switchback_staircase(pos)

func _create_switchback_staircase(pos: Vector3) -> void:
	var st_root = Node3D.new()
	st_root.name = "CentralSpiralStaircase" # Preserved name for backward compatibility
	st_root.position = pos
	add_child(st_root)

	# --- MATERIALS ---
	var wall_mat = StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.24, 0.26, 0.29) # Clean architectural concrete / lab panel
	wall_mat.roughness = 0.65

	var inner_wall_mat = StandardMaterial3D.new()
	inner_wall_mat.albedo_color = Color(0.28, 0.30, 0.34) # Slightly brighter inside shaft
	inner_wall_mat.roughness = 0.55

	var door_frame_mat = StandardMaterial3D.new()
	door_frame_mat.albedo_color = Color(0.12, 0.13, 0.15) # Black matte industrial frame
	door_frame_mat.metallic = 0.85
	door_frame_mat.roughness = 0.30

	var step_mat = StandardMaterial3D.new()
	step_mat.albedo_color = Color(0.16, 0.18, 0.21) # Dark metallic structural steel tread
	step_mat.metallic = 0.82
	step_mat.roughness = 0.32

	var hazard_mat = StandardMaterial3D.new()
	hazard_mat.albedo_color = Color(0.96, 0.82, 0.12) # Anti-slip luminous yellow hazard strip
	hazard_mat.metallic = 0.25
	hazard_mat.roughness = 0.40

	var rail_mat = StandardMaterial3D.new()
	rail_mat.albedo_color = Color(0.86, 0.89, 0.93) # Silver brushed solid metal
	rail_mat.metallic = 0.95
	rail_mat.roughness = 0.20

	var support_mat = StandardMaterial3D.new()
	support_mat.albedo_color = Color(0.10, 0.11, 0.13) # Black heavy central steel support
	support_mat.metallic = 0.92
	support_mat.roughness = 0.28

	var deck_mat = StandardMaterial3D.new()
	deck_mat.albedo_color = Color(0.20, 0.22, 0.25) # Diamond steel landing deck plate
	deck_mat.metallic = 0.85
	deck_mat.roughness = 0.38

	# --- DIMENSIONS ---
	var total_h: float = 11.4 # Height of Floor 2 deck
	var mid_h: float = 5.7    # Halfway mid-landing height
	var shaft_h: float = 15.6  # Total ceiling height enclosing Floor 2
	var shaft_w: float = 4.0   # Shaft width along X (x: -2.0 to +2.0, exact cell width)
	var shaft_l: float = 7.5   # Shaft length along Z (z: -3.75 to +3.75)
	var half_l: float = shaft_l * 0.5 # 3.75m
	var slope_z: float = 2.4   # Run from +2.4 to -2.4 (length 4.8m, comfortable 49.8° grade)

	# =========================================================================
	# 1. ENCLOSED STAIRWELL SHAFT (Full-Height 15.6m Solid Walls che kín 100%)
	# =========================================================================
	# West Outer Wall (x = -2.0)
	_add_box(st_root, Vector3(0.25, shaft_h, shaft_l + 0.25), Vector3(-2.0, shaft_h * 0.5, 0.0), wall_mat, true)
	# East Outer Wall (x = +2.0)
	_add_box(st_root, Vector3(0.25, shaft_h, shaft_l + 0.25), Vector3(2.0, shaft_h * 0.5, 0.0), wall_mat, true)
	# North Outer Wall (z = -half_l)
	_add_box(st_root, Vector3(shaft_w + 0.25, shaft_h, 0.25), Vector3(0.0, shaft_h * 0.5, -half_l), wall_mat, true)

	# South Wall (z = +half_l) with 2 Clean Architectural Door Openings:
	# Corner columns sealing East and West edges of South wall
	_add_box(st_root, Vector3(0.18, shaft_h, 0.25), Vector3(-1.91, shaft_h * 0.5, half_l), wall_mat, true)
	_add_box(st_root, Vector3(0.18, shaft_h, 0.25), Vector3(1.91, shaft_h * 0.5, half_l), wall_mat, true)
	# Center divider column between doors (x: -0.15 to +0.15)
	_add_box(st_root, Vector3(0.30, shaft_h, 0.25), Vector3(0.0, shaft_h * 0.5, half_l), wall_mat, true)
	# Floor 1 Doorway: Left side (x: -1.85 to -0.15), opening from y=0 to y=2.8m
	_add_box(st_root, Vector3(1.70, shaft_h - 2.8, 0.25), Vector3(-1.00, 2.8 + (shaft_h - 2.8) * 0.5, half_l), wall_mat, true)
	# Floor 1 Door Frame Trim & Header
	_add_box(st_root, Vector3(1.80, 0.15, 0.32), Vector3(-1.00, 2.8, half_l), door_frame_mat, false)
	_add_box(st_root, Vector3(0.12, 2.8, 0.32), Vector3(-1.86, 1.4, half_l), door_frame_mat, false)
	_add_box(st_root, Vector3(0.12, 2.8, 0.32), Vector3(-0.14, 1.4, half_l), door_frame_mat, false)

	# Floor 2 Doorway: Right side (x: +0.15 to +1.85), opening from y=11.4m to y=14.2m
	# Wall underneath Floor 2 doorway (y=0 to y=11.4m) sealing off Floor 1
	_add_box(st_root, Vector3(1.70, total_h, 0.25), Vector3(1.00, total_h * 0.5, half_l), wall_mat, true)
	# Wall above Floor 2 doorway (y=14.2m to y=15.6m)
	_add_box(st_root, Vector3(1.70, shaft_h - 14.2, 0.25), Vector3(1.00, 14.2 + (shaft_h - 14.2) * 0.5, half_l), wall_mat, true)
	# Floor 2 Door Frame Trim & Header
	_add_box(st_root, Vector3(1.80, 0.15, 0.32), Vector3(1.00, 14.2, half_l), door_frame_mat, false)
	_add_box(st_root, Vector3(0.12, 2.8, 0.32), Vector3(0.14, 12.8, half_l), door_frame_mat, false)
	_add_box(st_root, Vector3(0.12, 2.8, 0.32), Vector3(1.86, 12.8, half_l), door_frame_mat, false)

	# Shaft Solid Ceiling Slab (y = 15.6m)
	_add_box(st_root, Vector3(shaft_w + 0.25, 0.30, shaft_l + 0.25), Vector3(0.0, shaft_h + 0.15, 0.0), wall_mat, true)
	# Shaft Solid Floor Base (y = 0.0m)
	_add_box(st_root, Vector3(shaft_w + 0.25, 0.25, shaft_l + 0.25), Vector3(0.0, -0.125, 0.0), wall_mat, false)

	# Full-Height Central Structural Dividing Wall (along x = 0, z: -slope_z to +half_l, height 15.6m)
	# Completely divides Flight 1 and Flight 2, and closes off the 11.4m drop beside the upper landing!
	var div_len = half_l + slope_z # 3.75 + 2.4 = 6.15m
	var div_mid_z = (slope_z - slope_z + half_l - slope_z) * 0.5 # (-2.4 + 3.75) * 0.5 = 0.675m
	_add_box(st_root, Vector3(0.24, shaft_h, div_len), Vector3(0.0, shaft_h * 0.5, div_mid_z), wall_mat, true)

	# Emergency Illuminated Directional Signs on Doorways
	var sign_font = preload("res://fonts/ShareTechMono-Regular.ttf")
	var s1_label = Label3D.new()
	s1_label.text = "▲ LEVEL 2 OBSERVATION LAB\nEMERGENCY STAIRWELL 01"
	s1_label.font = sign_font
	s1_label.font_size = 18
	s1_label.pixel_size = 0.0022
	s1_label.modulate = Color(0.2, 0.95, 0.4)
	s1_label.outline_modulate = Color(0, 0, 0)
	s1_label.outline_size = 3
	s1_label.position = Vector3(-1.00, 3.12, half_l + 0.14)
	st_root.add_child(s1_label)

	var s2_label = Label3D.new()
	s2_label.text = "▼ SUB-LEVEL GROUND EXIT\nEMERGENCY STAIRWELL 01"
	s2_label.font = sign_font
	s2_label.font_size = 18
	s2_label.pixel_size = 0.0022
	s2_label.modulate = Color(0.2, 0.95, 0.4)
	s2_label.outline_modulate = Color(0, 0, 0)
	s2_label.outline_size = 3
	s2_label.position = Vector3(1.00, 14.48, half_l + 0.14)
	st_root.add_child(s2_label)

	# =========================================================================
	# 2. LANDINGS (Bottom Landing, Mid-Landing, Upper Landing)
	# =========================================================================
	var landing_depth = half_l - slope_z # 1.35m
	var landing_mid_z = slope_z + landing_depth * 0.5 # 3.075m

	# Floor 1 Bottom Landing (x: -1.88 to -0.12, z: slope_z to half_l, y = 0.0m)
	_add_box(st_root, Vector3(1.76, 0.06, landing_depth), Vector3(-1.00, -0.03, landing_mid_z), deck_mat, false)

	# Solid Ceiling Cap over Floor 1 entrance at y = 11.4m (sealing off void above entrance on West side)
	_add_box(st_root, Vector3(1.76, 0.25, landing_depth), Vector3(-1.00, total_h - 0.125, landing_mid_z), deck_mat, true)

	# Spacious Mid-Landing at halfway height 5.7m (spanning entire width x: -1.88 to +1.88, z: -half_l to -slope_z)
	_add_box(st_root, Vector3(3.76, 0.12, landing_depth), Vector3(0.0, mid_h - 0.06, -landing_mid_z), deck_mat, false)
	# Mid-landing heavy support steel beams underneath
	_add_box(st_root, Vector3(3.76, 0.35, 0.15), Vector3(0.0, mid_h - 0.28, -landing_mid_z), support_mat, true)

	# Floor 2 Upper Landing at 11.4m (x: +0.12 to +1.88, z: slope_z to half_l)
	_add_box(st_root, Vector3(1.76, 0.12, landing_depth), Vector3(1.00, total_h - 0.06, landing_mid_z), deck_mat, false)

	# =========================================================================
	# 3. TWO STRAIGHT FLIGHTS OF WIDE COMFORTABLE STEPS
	# =========================================================================
	var num_flight_steps: int = 20
	var run_z: float = slope_z * 2.0 # 4.8m run
	var d_step_z: float = run_z / float(num_flight_steps) # 0.24m comfortable depth
	var d_step_y: float = mid_h / float(num_flight_steps) # 0.285m riser

	# Flight 1 Steps: Left side (x = -1.00), ascending from South (z = +slope_z, y = 0) to North (z = -slope_z, y = 5.7)
	for i in range(num_flight_steps):
		var sy = (float(i) + 0.5) * d_step_y
		var sz = slope_z - (float(i) + 0.5) * d_step_z

		# Step Tread
		_add_box(st_root, Vector3(1.70, 0.05, 0.28), Vector3(-1.00, sy, sz), step_mat, false)
		# Anti-Slip Yellow Safety Strip on leading edge
		_add_box(st_root, Vector3(1.70, 0.052, 0.045), Vector3(-1.00, sy + 0.001, sz - 0.115), hazard_mat, false)

	# Flight 1 Diagonal Structural Steel Stringers (Underneath left & right of flight 1)
	var str_len = sqrt(mid_h * mid_h + run_z * run_z) + 0.4
	_add_box(st_root, Vector3(0.08, 0.25, str_len), Vector3(-1.84, mid_h * 0.5 - 0.25, 0.0), support_mat, false, Vector3(-atan2(mid_h, run_z), 0, 0))
	_add_box(st_root, Vector3(0.08, 0.25, str_len), Vector3(-0.16, mid_h * 0.5 - 0.25, 0.0), support_mat, false, Vector3(-atan2(mid_h, run_z), 0, 0))

	# Flight 2 Steps: Right side (x = +1.00), ascending from North (z = -slope_z, y = 5.7) to South (z = +slope_z, y = 11.4)
	for i in range(num_flight_steps):
		var sy = mid_h + (float(i) + 0.5) * d_step_y
		var sz = -slope_z + (float(i) + 0.5) * d_step_z

		# Step Tread
		_add_box(st_root, Vector3(1.70, 0.05, 0.28), Vector3(1.00, sy, sz), step_mat, false)
		# Anti-Slip Yellow Safety Strip on leading edge
		_add_box(st_root, Vector3(1.70, 0.052, 0.045), Vector3(1.00, sy + 0.001, sz + 0.115), hazard_mat, false)

	# Flight 2 Diagonal Structural Steel Stringers (Underneath left & right of flight 2)
	_add_box(st_root, Vector3(0.08, 0.25, str_len), Vector3(0.16, mid_h + mid_h * 0.5 - 0.25, 0.0), support_mat, false, Vector3(atan2(mid_h, run_z), 0, 0))
	_add_box(st_root, Vector3(0.08, 0.25, str_len), Vector3(1.84, mid_h + mid_h * 0.5 - 0.25, 0.0), support_mat, false, Vector3(atan2(mid_h, run_z), 0, 0))

	# =========================================================================
	# 4. THICK SOLID METAL HANDRAILS ON BOTH SIDES (Silver Brushed Metal)
	# =========================================================================
	var rail_radius: float = 0.035 # Thick sturdy 70mm diameter handrail
	var post_radius: float = 0.028 # 56mm solid steel baluster post

	# --- FLIGHT 1 HANDRAILS (Left & Right of Flight 1) ---
	var f1_out_start = Vector3(-1.82, 0.98, slope_z)
	var f1_out_end = Vector3(-1.82, mid_h + 0.98, -slope_z)
	_add_cylinder_segment(st_root, f1_out_start, f1_out_end, rail_radius, rail_mat)
	_add_cylinder_segment(st_root, f1_out_start - Vector3(0, 0.45, 0), f1_out_end - Vector3(0, 0.45, 0), rail_radius * 0.7, rail_mat)

	var f1_in_start = Vector3(-0.16, 0.98, slope_z)
	var f1_in_end = Vector3(-0.16, mid_h + 0.98, -slope_z)
	_add_cylinder_segment(st_root, f1_in_start, f1_in_end, rail_radius, rail_mat)
	_add_cylinder_segment(st_root, f1_in_start - Vector3(0, 0.45, 0), f1_in_end - Vector3(0, 0.45, 0), rail_radius * 0.7, rail_mat)

	# Flight 1 Bottom Landing Horizontal Railing Extension
	_add_cylinder_segment(st_root, f1_out_start, Vector3(-1.82, 0.98, half_l - 0.1), rail_radius, rail_mat)
	_add_cylinder_segment(st_root, f1_in_start, Vector3(-0.16, 0.98, half_l - 0.1), rail_radius, rail_mat)

	# Flight 1 Sturdy Baluster Posts (5 evenly spaced + landing posts)
	for pi in range(5):
		var frac = float(pi) / 4.0
		var p_z = lerpf(slope_z, -slope_z, frac)
		var p_y = lerpf(0.0, mid_h, frac)
		_add_cylinder_segment(st_root, Vector3(-1.82, p_y + 0.05, p_z), Vector3(-1.82, p_y + 0.98, p_z), post_radius, rail_mat)
		_add_cylinder_segment(st_root, Vector3(-0.16, p_y + 0.05, p_z), Vector3(-0.16, p_y + 0.98, p_z), post_radius, rail_mat)
	_add_cylinder_segment(st_root, Vector3(-1.82, 0.05, half_l - 0.1), Vector3(-1.82, 0.98, half_l - 0.1), post_radius, rail_mat)
	_add_cylinder_segment(st_root, Vector3(-0.16, 0.05, half_l - 0.1), Vector3(-0.16, 0.98, half_l - 0.1), post_radius, rail_mat)

	# --- MID-LANDING GUARDRAIL (Along North Wall at z = -half_l + 0.10, y = 5.7 + 0.98 = 6.68m) ---
	var ml_north_z = -half_l + 0.10
	var ml_left = Vector3(-1.82, mid_h + 0.98, ml_north_z)
	var ml_right = Vector3(1.82, mid_h + 0.98, ml_north_z)
	_add_cylinder_segment(st_root, f1_out_end, ml_left, rail_radius, rail_mat)
	_add_cylinder_segment(st_root, ml_left, ml_right, rail_radius, rail_mat)
	_add_cylinder_segment(st_root, ml_left - Vector3(0, 0.45, 0), ml_right - Vector3(0, 0.45, 0), rail_radius * 0.7, rail_mat)
	for pi in range(4):
		var px = lerpf(-1.82, 1.82, float(pi) / 3.0)
		_add_cylinder_segment(st_root, Vector3(px, mid_h + 0.05, ml_north_z), Vector3(px, mid_h + 0.98, ml_north_z), post_radius, rail_mat)

	# --- FLIGHT 2 HANDRAILS (Left & Right of Flight 2) ---
	var f2_out_start = Vector3(1.82, mid_h + 0.98, -slope_z)
	var f2_out_end = Vector3(1.82, total_h + 0.98, slope_z)
	_add_cylinder_segment(st_root, ml_right, f2_out_start, rail_radius, rail_mat)
	_add_cylinder_segment(st_root, f2_out_start, f2_out_end, rail_radius, rail_mat)
	_add_cylinder_segment(st_root, f2_out_start - Vector3(0, 0.45, 0), f2_out_end - Vector3(0, 0.45, 0), rail_radius * 0.7, rail_mat)

	var f2_in_start = Vector3(0.16, mid_h + 0.98, -slope_z)
	var f2_in_end = Vector3(0.16, total_h + 0.98, slope_z)
	_add_cylinder_segment(st_root, f2_in_start, f2_in_end, rail_radius, rail_mat)
	_add_cylinder_segment(st_root, f2_in_start - Vector3(0, 0.45, 0), f2_in_end - Vector3(0, 0.45, 0), rail_radius * 0.7, rail_mat)

	# Flight 2 Upper Landing Horizontal Railing (Terminates cleanly before Floor 2 doorway)
	var f2_rail_end_z = slope_z + 0.25 # 2.65m, leaving > 1.1m wide unobstructed passage to Floor 2 door
	_add_cylinder_segment(st_root, f2_out_end, Vector3(1.82, total_h + 0.98, f2_rail_end_z), rail_radius, rail_mat)
	_add_cylinder_segment(st_root, f2_in_end, Vector3(0.16, total_h + 0.98, f2_rail_end_z), rail_radius, rail_mat)

	# Flight 2 Sturdy Baluster Posts (5 evenly spaced + clean landing termination posts)
	for pi in range(5):
		var frac = float(pi) / 4.0
		var p_z = lerpf(-slope_z, slope_z, frac)
		var p_y = lerpf(mid_h, total_h, frac)
		_add_cylinder_segment(st_root, Vector3(1.82, p_y + 0.05, p_z), Vector3(1.82, p_y + 0.98, p_z), post_radius, rail_mat)
		_add_cylinder_segment(st_root, Vector3(0.16, p_y + 0.05, p_z), Vector3(0.16, p_y + 0.98, p_z), post_radius, rail_mat)
	_add_cylinder_segment(st_root, Vector3(1.82, total_h + 0.05, f2_rail_end_z), Vector3(1.82, total_h + 0.98, f2_rail_end_z), post_radius, rail_mat)
	_add_cylinder_segment(st_root, Vector3(0.16, total_h + 0.05, f2_rail_end_z), Vector3(0.16, total_h + 0.98, f2_rail_end_z), post_radius, rail_mat)

	# =========================================================================
	# 5. SMOOTH CONVEX BOX COLLIDERS FOR 100% RELIABLE CHARACTER TRAVERSAL
	# =========================================================================
	var ramp_body = StaticBody3D.new()
	ramp_body.name = "StairWalkableRamps"

	var f_angle = atan2(mid_h, run_z) # 49.8°
	var f_len = sqrt(mid_h * mid_h + run_z * run_z)
	var cos_a = cos(f_angle)
	var ramp_thick = 0.20
	var y_offset = (ramp_thick * 0.5) / cos_a # 0.155m to align top surface flush

	# Helper to create an aligned collision shape on ramp_body
	var add_ramp_box = func(b_size: Vector3, b_pos: Vector3, b_rot: Vector3 = Vector3.ZERO):
		var cs = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = b_size
		cs.shape = box
		cs.position = b_pos
		if b_rot != Vector3.ZERO:
			cs.rotation = b_rot
		ramp_body.add_child(cs)

	# --- FLIGHT 1 ---
	# Gentle lead-in ramp at bottom of Flight 1 (z: 2.80 to 2.40, rise 0.0 -> 0.18m at 24° grade towards North)
	var lead_l = 0.40
	var lead_h = 0.18
	var lead_angle = atan2(lead_h, lead_l)
	var lead_hyp = sqrt(lead_l * lead_l + lead_h * lead_h)
	var lead_y_off = (0.10 * 0.5) / cos(lead_angle)
	add_ramp_box.call(
		Vector3(1.76, 0.10, lead_hyp),
		Vector3(-1.00, lead_h * 0.5 - lead_y_off, slope_z + lead_l * 0.5),
		Vector3(lead_angle, 0, 0)
	)

	# Main Flight 1 Incline (rises towards North -Z: +2.4 to -2.4, rise 0.0 -> 5.7m)
	add_ramp_box.call(
		Vector3(1.76, ramp_thick, f_len),
		Vector3(-1.00, mid_h * 0.5 - y_offset, 0.0),
		Vector3(f_angle, 0, 0)
	)

	# --- MID-LANDING ---
	# Flat Mid-Landing Platform (spanning full width x: -1.88 to +1.88, z: -2.4 to -3.75, y = 5.7m)
	add_ramp_box.call(
		Vector3(3.76, ramp_thick, landing_depth),
		Vector3(0.0, mid_h - ramp_thick * 0.5, -landing_mid_z)
	)

	# --- FLIGHT 2 ---
	# Gentle lead-in ramp from Mid-Landing into Flight 2 (z: -2.80 to -2.40, rise 5.70 -> 5.88m towards South)
	add_ramp_box.call(
		Vector3(1.76, 0.10, lead_hyp),
		Vector3(1.00, mid_h + lead_h * 0.5 - lead_y_off, -(slope_z + lead_l * 0.5)),
		Vector3(-lead_angle, 0, 0)
	)

	# Main Flight 2 Incline (rises towards South +Z: -2.4 to +2.4, rise 5.7 -> 11.4m)
	add_ramp_box.call(
		Vector3(1.76, ramp_thick, f_len),
		Vector3(1.00, mid_h + mid_h * 0.5 - y_offset, 0.0),
		Vector3(-f_angle, 0, 0)
	)

	# --- UPPER LANDING ---
	# Gentle lead-out ramp into Upper Landing (z: 2.40 to 2.80, rise 11.22 -> 11.40m towards South)
	add_ramp_box.call(
		Vector3(1.76, 0.10, lead_hyp),
		Vector3(1.00, total_h - lead_h * 0.5 - lead_y_off, slope_z + lead_l * 0.5),
		Vector3(lead_angle, 0, 0)
	)

	# Flat Upper Landing Platform (x: +0.12 to +1.88, z: 2.4 to 3.75, y = 11.4m)
	add_ramp_box.call(
		Vector3(1.76, ramp_thick, landing_depth),
		Vector3(1.00, total_h - ramp_thick * 0.5, landing_mid_z)
	)

	st_root.add_child(ramp_body)

	# =========================================================================
	# 6. SOFT REALISTIC LIGHTING (Flush Wall-Mounted Industrial Bulkhead Lights)
	# 100% mounted ON shaft walls — NEVER suspended in walking paths or empty air!
	# =========================================================================
	var bulkhead_mount_mat = StandardMaterial3D.new()
	bulkhead_mount_mat.albedo_color = Color(0.12, 0.13, 0.15)
	bulkhead_mount_mat.metallic = 0.90
	bulkhead_mount_mat.roughness = 0.25

	var bulkhead_glass_mat = StandardMaterial3D.new()
	bulkhead_glass_mat.albedo_color = Color(0.95, 0.98, 1.0)
	bulkhead_glass_mat.emission_enabled = true
	bulkhead_glass_mat.emission = Color(0.95, 0.98, 1.0)
	bulkhead_glass_mat.emission_energy_multiplier = 2.4

	var wall_light_configs = [
		# 1. Flight 1 / Bottom Landing: Mounted flush against West Wall (x = -1.94, facing East)
		{
			"wall_pos": Vector3(-1.92, 2.6, landing_mid_z),
			"light_pos": Vector3(-1.80, 2.6, landing_mid_z),
			"plate_size": Vector3(0.04, 0.28, 0.18),
			"glass_size": Vector3(0.08, 0.20, 0.12),
			"range": 7.5, "energy": 1.5
		},
		# 2. Mid Landing: Mounted flush against North Wall (z = -half_l + 0.08, facing South)
		{
			"wall_pos": Vector3(0.0, mid_h + 2.4, -half_l + 0.08),
			"light_pos": Vector3(0.0, mid_h + 2.4, -half_l + 0.20),
			"plate_size": Vector3(0.28, 0.18, 0.04),
			"glass_size": Vector3(0.20, 0.12, 0.08),
			"range": 8.5, "energy": 1.6
		},
		# 3. Flight 2 / Upper Landing: Mounted flush against East Wall (x = +1.92, facing West)
		{
			"wall_pos": Vector3(1.92, total_h + 2.5, landing_mid_z),
			"light_pos": Vector3(1.80, total_h + 2.5, landing_mid_z),
			"plate_size": Vector3(0.04, 0.28, 0.18),
			"glass_size": Vector3(0.08, 0.20, 0.12),
			"range": 7.5, "energy": 1.5
		}
	]

	for wlc in wall_light_configs:
		# Steel backplate against wall
		_add_box(st_root, wlc["plate_size"], wlc["wall_pos"], bulkhead_mount_mat, false)
		# Glowing glass diffuser fixture
		_add_box(st_root, wlc["glass_size"], wlc["wall_pos"] + (wlc["light_pos"] - wlc["wall_pos"]) * 0.5, bulkhead_glass_mat, false)
		# Omnilight cast into stairwell
		var l_inst = OmniLight3D.new()
		l_inst.position = wlc["light_pos"]
		l_inst.omni_range = wlc["range"]
		l_inst.omni_attenuation = 1.0
		l_inst.light_color = Color(0.94, 0.96, 1.0)
		l_inst.light_energy = wlc["energy"]
		st_root.add_child(l_inst)

# Helper function to place a 3D cylinder segment smoothly between two 3D points
func _add_cylinder_segment(parent: Node3D, p1: Vector3, p2: Vector3, radius: float, mat: Material) -> void:
	var delta = p2 - p1
	var length = delta.length()
	if length < 0.001:
		return
	var inst = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = length
	inst.mesh = cyl
	inst.material_override = mat

	var dir = delta.normalized()
	var mid = (p1 + p2) * 0.5
	var up = Vector3.UP
	if abs(dir.dot(up)) > 0.99:
		up = Vector3.FORWARD
	var right = dir.cross(up).normalized()
	up = right.cross(dir).normalized()
	inst.transform = Transform3D(Basis(right, dir, up), mid)
	parent.add_child(inst)

# CCTV Surveillance Camera Station on Floor 2 looking down at Floor 1
func _create_lab_cctv_surveillance_station(parent: Node3D, pos: Vector3, rot_y: float, cam_index: int) -> void:
	var root = Node3D.new()
	root.position = pos
	root.rotation.y = rot_y
	parent.add_child(root)

	var desk_mat = StandardMaterial3D.new()
	desk_mat.albedo_color = Color(0.2, 0.22, 0.26)
	desk_mat.metallic = 0.8
	desk_mat.roughness = 0.35
	_add_box(root, Vector3(1.6, 0.85, 0.7), Vector3(0, 0.425, 0), desk_mat, true)

	# Mounting bracket for downward-angled surveillance monitors
	var mount_mat = StandardMaterial3D.new()
	mount_mat.albedo_color = Color(0.12, 0.14, 0.16)
	mount_mat.metallic = 0.9
	_add_box(root, Vector3(0.08, 0.75, 0.08), Vector3(-0.45, 1.2, -0.05), mount_mat, false)
	_add_box(root, Vector3(0.08, 0.75, 0.08), Vector3(0.45, 1.2, -0.05), mount_mat, false)
	_add_box(root, Vector3(1.2, 0.06, 0.06), Vector3(0.0, 1.45, -0.05), mount_mat, false)

	# 2 Large Downward-Angled CCTV Surveillance Screens looking down at Floor 1
	var cam_names = [
		"CAM 01: BIO-TANK LOWER ATRIUM",
		"CAM 02: SPECIMEN CAGES SECTOR",
		"CAM 03: SECURITY CHECKPOINT GATES",
		"CAM 04: LOWER CORRIDOR ARCHIVE",
		"CAM 05: SECTOR ZERO ENTRANCE"
	]
	var cam_name = cam_names[cam_index % cam_names.size()]

	for m_i in range(2):
		var mon_x = -0.38 + float(m_i) * 0.76
		var mon_node = Node3D.new()
		mon_node.position = Vector3(mon_x, 1.45, -0.1)
		# Tilted forward-downward by 25 degrees so it faces down towards Floor 1!
		mon_node.rotation.x = deg_to_rad(25.0)
		root.add_child(mon_node)

		# Monitor casing
		var case_mat = StandardMaterial3D.new()
		case_mat.albedo_color = Color(0.1, 0.12, 0.15)
		_add_box(mon_node, Vector3(0.68, 0.48, 0.08), Vector3(0, 0, 0), case_mat, false)

		# Screen with glowing surveillance camera feed
		var scr_mat = StandardMaterial3D.new()
		var feed_color = Color(0.15, 0.85, 0.95) if m_i == 0 else Color(0.2, 0.95, 0.45)
		scr_mat.albedo_color = feed_color
		scr_mat.emission_enabled = true
		scr_mat.emission = feed_color
		scr_mat.emission_energy_multiplier = 2.4
		_add_box(mon_node, Vector3(0.62, 0.42, 0.02), Vector3(0, 0, 0.045), scr_mat, false)

		# 3D In-world Screen Label
		var scr_label = Label3D.new()
		scr_label.text = "%s\n● LIVE REC • FLOOR 1 FEED" % cam_name
		scr_label.font_size = 14
		scr_label.pixel_size = 0.002
		scr_label.modulate = Color(0.95, 1.0, 1.0)
		scr_label.position = Vector3(0.0, 0.0, 0.06)
		mon_node.add_child(scr_label)

	# CCTV Control Desk surface lights & keyboard
	var kbd_mat = StandardMaterial3D.new()
	kbd_mat.albedo_color = Color(0.15, 0.16, 0.18)
	_add_box(root, Vector3(0.65, 0.02, 0.22), Vector3(0.0, 0.86, 0.15), kbd_mat, false)

	var cctv_light = OmniLight3D.new()
	cctv_light.position = Vector3(0.0, 1.6, -0.2)
	cctv_light.light_color = Color(0.2, 0.85, 1.0)
	cctv_light.light_energy = 1.4
	cctv_light.omni_range = 3.8
	root.add_child(cctv_light)

	weapon_candidate_slots.append(root.to_global(Vector3(-0.55, 0.88, 0.12)))

# =========================================================================
# FLOOR 2 RESEARCH LAB DECORATIONS (Computers, Monitors, Documents, Racks)
# =========================================================================

func _create_lab_computer(parent: Node3D, pos: Vector3, rot_y: float) -> void:
	var root = Node3D.new()
	root.position = pos
	root.rotation.y = rot_y
	parent.add_child(root)

	var desk_mat = StandardMaterial3D.new()
	desk_mat.albedo_color = Color(0.22, 0.25, 0.28)
	desk_mat.metallic = 0.5
	desk_mat.roughness = 0.6
	_add_box(root, Vector3(1.4, 0.75, 0.8), Vector3(0, 0.375, 0), desk_mat, true)

	# CRT Monitor casing
	var crt_mat = StandardMaterial3D.new()
	crt_mat.albedo_color = Color(0.12, 0.13, 0.15)
	_add_box(root, Vector3(0.52, 0.44, 0.42), Vector3(0, 0.98, 0.05), crt_mat, false)

	# Glowing CRT Green Screen with research terminal data
	var screen_mat = StandardMaterial3D.new()
	screen_mat.albedo_color = Color(0.1, 0.95, 0.35)
	screen_mat.emission_enabled = true
	screen_mat.emission = Color(0.15, 0.92, 0.4)
	screen_mat.emission_energy_multiplier = 2.4
	_add_box(root, Vector3(0.44, 0.36, 0.02), Vector3(0, 0.98, -0.17), screen_mat, false)

	# Keyboard & PC tower
	_add_box(root, Vector3(0.42, 0.03, 0.16), Vector3(0, 0.77, -0.24), crt_mat, false)
	_add_box(root, Vector3(0.22, 0.45, 0.45), Vector3(0.55, 0.25, 0.0), crt_mat, false)

	# Subtle ambient terminal light
	var sc_light = OmniLight3D.new()
	sc_light.position = Vector3(0, 1.0, -0.3)
	sc_light.omni_range = 2.8
	sc_light.light_color = Color(0.2, 0.95, 0.4)
	sc_light.light_energy = 0.85
	root.add_child(sc_light)

	weapon_candidate_slots.append(root.to_global(Vector3(-0.35, 0.82, -0.1)))

# Spawns facility weapons:
# Night 1: 5 Tasers, 2 Shock Batons
# Night 2: 4 Tasers, 2 Shock Batons
# Night 3: 3 Tasers, 2 Shock Batons
# Night 4 & 5: 3 Tasers, 1 Shock Baton
func _spawn_facility_weapons(open_cells: Array[Vector3]) -> void:
	weapon_candidate_slots.shuffle()
	batons_spawned = 0
	tasers_spawned = 0

	var target_tasers: int = 5
	var target_batons: int = 2
	if active_day == 1:
		target_tasers = 5
		target_batons = 2
	elif active_day == 2:
		target_tasers = 4
		target_batons = 2
	elif active_day == 3:
		target_tasers = 3
		target_batons = 2
	elif active_day >= 4:
		target_tasers = 3
		target_batons = 1

	# Multiplayer scaling support
	if has_meta("mp_supplies_mult"):
		var sm: float = float(get_meta("mp_supplies_mult", 1.0))
		target_tasers = int(ceil(float(target_tasers) * sm))
		target_batons = int(ceil(float(target_batons) * sm))

	for slot_pos in weapon_candidate_slots:
		var can_baton = batons_spawned < target_batons
		var can_taser = tasers_spawned < target_tasers
		if not can_baton and not can_taser:
			break

		var w_type = "taser"
		if can_baton and can_taser:
			w_type = "baton" if (batons_spawned == 0 and randf() < 0.6) else "taser"
		elif can_baton:
			w_type = "baton"
		else:
			w_type = "taser"

		if w_type == "baton":
			batons_spawned += 1
		else:
			tasers_spawned += 1

		_create_weapon_pickup(slot_pos, w_type)

	# Fallback if slots are few: place in corridor open cells
	var cell_idx = 0
	while batons_spawned < target_batons and cell_idx < open_cells.size():
		_create_weapon_pickup(open_cells[cell_idx] + Vector3(0, 0.5, 0), "baton")
		batons_spawned += 1
		cell_idx += 1
	while tasers_spawned < target_tasers and cell_idx < open_cells.size():
		_create_weapon_pickup(open_cells[cell_idx] + Vector3(0, 0.5, 0), "taser")
		tasers_spawned += 1
		cell_idx += 1

func _create_weapon_pickup(world_pos: Vector3, spawn_type: String) -> void:
	var area = Area3D.new()
	area.set_script(InteractableScript)
	area.position = world_pos
	add_child(area)

	var col = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 1.35
	col.shape = shape
	area.add_child(col)

	var item_entry = {
		"type": "weapon",
		"pos": world_pos,
		"weapon_type": spawn_type,
		"active": true
	}
	active_interactables.append(item_entry)

	# High-tech charging pedestal disc
	var base_mesh = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.24
	cyl.bottom_radius = 0.28
	cyl.height = 0.06
	base_mesh.mesh = cyl
	var base_mat = StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.14, 0.16, 0.20)
	base_mat.metallic = 0.85
	base_mesh.material_override = base_mat
	area.add_child(base_mesh)

	if spawn_type == "baton":
		area.set("prompt_text", "[E] Take Shock Baton (100% Durability / Block & Parry)")
		var b_root = Node3D.new()
		b_root.position.y = 0.16
		b_root.rotation.x = PI * 0.45
		area.add_child(b_root)

		var grip = MeshInstance3D.new()
		var g_cyl = CylinderMesh.new()
		g_cyl.top_radius = 0.024
		g_cyl.bottom_radius = 0.024
		g_cyl.height = 0.18
		grip.mesh = g_cyl
		grip.position = Vector3(0, -0.16, 0)
		var g_mat = StandardMaterial3D.new()
		g_mat.albedo_color = Color(0.12, 0.12, 0.14)
		grip.material_override = g_mat
		b_root.add_child(grip)

		var shaft = MeshInstance3D.new()
		var s_cyl = CylinderMesh.new()
		s_cyl.top_radius = 0.018
		s_cyl.bottom_radius = 0.020
		s_cyl.height = 0.46
		shaft.mesh = s_cyl
		shaft.position = Vector3(0, 0.14, 0)
		var s_mat = StandardMaterial3D.new()
		s_mat.albedo_color = Color(0.35, 0.38, 0.42)
		s_mat.metallic = 0.90
		shaft.material_override = s_mat
		b_root.add_child(shaft)

		# Glowing shock ring with pulsing cyan light
		var ring = MeshInstance3D.new()
		var r_tor = TorusMesh.new()
		r_tor.inner_radius = 0.025
		r_tor.outer_radius = 0.045
		ring.mesh = r_tor
		ring.position = Vector3(0, 0.35, 0)
		ring.rotation.x = PI * 0.5
		var r_mat = StandardMaterial3D.new()
		r_mat.albedo_color = Color(0.15, 0.85, 1.0)
		r_mat.emission_enabled = true
		r_mat.emission = Color(0.15, 0.85, 1.0)
		r_mat.emission_energy_multiplier = 3.5
		ring.material_override = r_mat
		b_root.add_child(ring)

		var light = OmniLight3D.new()
		light.light_color = Color(0.15, 0.85, 1.0)
		light.light_energy = 2.4
		light.omni_range = 4.2
		light.position.y = 0.25
		area.add_child(light)

		area.connect("interacted", func(p):
			if not is_instance_valid(area) or area.is_queued_for_deletion():
				return
			if p and p.has_method("pickup_weapon"):
				p.pickup_weapon("baton", 100.0)
			item_entry["active"] = false
			area.queue_free()
		)
	else:
		area.set("prompt_text", "[E] Take Stun Gun (1 Shot / 11 Steps Stun)")
		var t_root = Node3D.new()
		t_root.position.y = 0.12
		area.add_child(t_root)

		var t_box = MeshInstance3D.new()
		var b_mesh = BoxMesh.new()
		b_mesh.size = Vector3(0.10, 0.14, 0.26)
		t_box.mesh = b_mesh
		var t_mat = StandardMaterial3D.new()
		t_mat.albedo_color = Color(0.95, 0.75, 0.10)
		t_mat.emission_enabled = true
		t_mat.emission = Color(0.4, 0.3, 0.05)
		t_box.material_override = t_mat
		t_root.add_child(t_box)

		# 2 Front copper shock prongs
		for pi in [-0.025, 0.025]:
			var prong = MeshInstance3D.new()
			var p_cyl = CylinderMesh.new()
			p_cyl.top_radius = 0.005
			p_cyl.bottom_radius = 0.005
			p_cyl.height = 0.05
			prong.mesh = p_cyl
			prong.rotation.x = PI * 0.5
			prong.position = Vector3(pi, 0.0, 0.14)
			var p_mat = StandardMaterial3D.new()
			p_mat.albedo_color = Color(0.9, 0.6, 0.2)
			p_mat.metallic = 0.95
			prong.material_override = p_mat
			t_root.add_child(prong)

		var light = OmniLight3D.new()
		light.light_color = Color(1.0, 0.80, 0.20)
		light.light_energy = 2.4
		light.omni_range = 4.2
		light.position.y = 0.25
		area.add_child(light)

		area.connect("interacted", func(p):
			if not is_instance_valid(area) or area.is_queued_for_deletion():
				return
			if p and p.has_method("pickup_weapon"):
				p.pickup_weapon("taser", 1.0)
			item_entry["active"] = false
			area.queue_free()
		)

func _create_lab_server_rack(parent: Node3D, pos: Vector3, rot_y: float) -> void:
	var root = Node3D.new()
	root.position = pos
	root.rotation.y = rot_y
	parent.add_child(root)

	var rack_mat = StandardMaterial3D.new()
	rack_mat.albedo_color = Color(0.12, 0.14, 0.16)
	rack_mat.metallic = 0.7
	rack_mat.roughness = 0.4
	_add_box(root, Vector3(0.95, 2.2, 0.75), Vector3(0, 1.1, 0), rack_mat, true)

	# Rows of blinking LED status bars
	for i in range(6):
		var led = MeshInstance3D.new()
		var b = BoxMesh.new()
		b.size = Vector3(0.7, 0.04, 0.02)
		led.mesh = b
		var led_mat = StandardMaterial3D.new()
		var col = Color(0.2, 0.9, 0.3) if i % 2 == 0 else Color(1.0, 0.55, 0.1)
		led_mat.albedo_color = col
		led_mat.emission_enabled = true
		led_mat.emission = col
		led_mat.emission_energy_multiplier = 2.0
		led.material_override = led_mat
		led.position = Vector3(0, 0.45 + float(i) * 0.28, -0.38)
		root.add_child(led)

func _create_lab_research_table(parent: Node3D, pos: Vector3, rot_y: float) -> void:
	var root = Node3D.new()
	root.position = pos
	root.rotation.y = rot_y
	parent.add_child(root)

	var table_mat = StandardMaterial3D.new()
	table_mat.albedo_color = Color(0.3, 0.32, 0.35)
	_add_box(root, Vector3(1.5, 0.75, 0.85), Vector3(0, 0.375, 0), table_mat, true)

	# Research documents / dossiers / paper stacks on table
	var paper_mat = StandardMaterial3D.new()
	paper_mat.albedo_color = Color(0.9, 0.88, 0.8)
	paper_mat.roughness = 0.9
	_add_box(root, Vector3(0.32, 0.02, 0.42), Vector3(-0.35, 0.76, 0.05), paper_mat, false)
	_add_box(root, Vector3(0.28, 0.04, 0.38), Vector3(0.25, 0.77, -0.1), paper_mat, false)

	# Confidential folder (Red)
	var folder_mat = StandardMaterial3D.new()
	folder_mat.albedo_color = Color(0.75, 0.15, 0.15)
	_add_box(root, Vector3(0.34, 0.015, 0.44), Vector3(-0.05, 0.76, 0.12), folder_mat, false)

	# Scientific specimen chemical flask with bioluminescent liquid
	var flask = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.05
	cyl.bottom_radius = 0.11
	cyl.height = 0.28
	flask.mesh = cyl
	var flask_mat = StandardMaterial3D.new()
	flask_mat.albedo_color = Color(0.2, 0.85, 1.0, 0.75)
	flask_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flask_mat.emission_enabled = true
	flask_mat.emission = Color(0.1, 0.8, 1.0)
	flask_mat.emission_energy_multiplier = 1.8
	flask.material_override = flask_mat
	flask.position = Vector3(0.48, 0.89, 0.15)
	root.add_child(flask)

func _create_lab_overhead_lamp(parent: Node3D, pos: Vector3) -> void:
	var lamp = MeshInstance3D.new()
	var b = BoxMesh.new()
	b.size = Vector3(1.2, 0.08, 0.25)
	lamp.mesh = b
	var l_mat = StandardMaterial3D.new()
	l_mat.albedo_color = Color(0.85, 0.95, 1.0)
	l_mat.emission_enabled = true
	l_mat.emission = Color(0.85, 0.95, 1.0)
	l_mat.emission_energy_multiplier = 2.2
	lamp.material_override = l_mat
	lamp.position = pos
	parent.add_child(lamp)

	var light = OmniLight3D.new()
	light.position = pos - Vector3(0, 0.2, 0)
	light.omni_range = 6.5
	light.omni_attenuation = 1.3
	light.light_color = Color(0.82, 0.94, 1.0)
	light.light_energy = 1.2
	parent.add_child(light)

# =========================================================================
# FLOOR 2 INTERACTIVE WORK SHIFT TASK STATIONS & SIGNBOARDS (NIGHT 3+)
# =========================================================================

func _on_internal_f2_usb_picked_up() -> void:
	f2_usb_carried = true
	if is_instance_valid(f2_vault_waypoint):
		f2_vault_waypoint.visible = true

func _on_internal_f2_usb_deposited() -> void:
	f2_usb_carried = false
	f2_usb_is_archived = true
	if is_instance_valid(f2_vault_waypoint):
		f2_vault_waypoint.visible = false

func _on_internal_f2_dossier_picked_up() -> void:
	f2_dossier_carried = true
	if is_instance_valid(f2_archive_waypoint):
		f2_archive_waypoint.visible = true

func _on_internal_f2_dossier_archived() -> void:
	f2_dossier_carried = false
	f2_dossier_is_archived = true
	if is_instance_valid(f2_archive_waypoint):
		f2_archive_waypoint.visible = false

func _on_internal_f2_coolant_picked_up() -> void:
	f2_coolant_carried = true
	if is_instance_valid(f2_server_waypoint):
		f2_server_waypoint.visible = true

func _on_internal_f2_coolant_injected() -> void:
	f2_coolant_carried = false
	f2_coolant_is_injected = true
	if is_instance_valid(f2_server_waypoint):
		f2_server_waypoint.visible = false

func _create_station_signboard(
	parent: Node3D,
	pos: Vector3,
	rot_y: float,
	section_code: String,
	station_title: String,
	action_hint: String,
	accent_color: Color,
	is_source: bool = false
) -> Node3D:
	var sign_node = Node3D.new()
	sign_node.position = pos
	sign_node.rotation.y = rot_y
	parent.add_child(sign_node)

	# 1. Backing industrial metal plate
	var plate_mat = StandardMaterial3D.new()
	plate_mat.albedo_color = Color(0.10, 0.12, 0.15)
	plate_mat.metallic = 0.88
	plate_mat.roughness = 0.32
	_add_box(sign_node, Vector3(1.4, 0.46, 0.04), Vector3(0, 0, 0), plate_mat, false)

	# 2. Glowing accent rim borders (top and bottom)
	var rim_mat = StandardMaterial3D.new()
	rim_mat.albedo_color = accent_color
	rim_mat.emission_enabled = true
	rim_mat.emission = accent_color
	rim_mat.emission_energy_multiplier = 2.6
	_add_box(sign_node, Vector3(1.42, 0.03, 0.05), Vector3(0, 0.23, 0), rim_mat, false)
	_add_box(sign_node, Vector3(1.42, 0.03, 0.05), Vector3(0, -0.23, 0), rim_mat, false)

	# 3. High-contrast typography on plate
	var s_label = Label3D.new()
	s_label.font = preload("res://fonts/ShareTechMono-Regular.ttf")
	s_label.text = "[%s]  //  %s\n%s" % [section_code, station_title, action_hint]
	s_label.font_size = 14
	s_label.pixel_size = 0.0016
	s_label.modulate = accent_color
	s_label.outline_modulate = Color(0, 0, 0)
	s_label.outline_size = 3
	s_label.position = Vector3(0, 0, 0.025)
	sign_node.add_child(s_label)

	# 4. Floating 3D Billboard Badge above the station (visible from 360° across corridors)
	var badge = Label3D.new()
	badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	badge.font = preload("res://fonts/ShareTechMono-Regular.ttf")
	var role_tag = "▼ [SOURCE]" if is_source else "▼ [DESTINATION]"
	badge.text = "%s [%s]\n%s" % [role_tag, section_code, station_title]
	badge.font_size = 15
	badge.pixel_size = 0.0020
	badge.modulate = accent_color
	badge.outline_modulate = Color(0, 0, 0)
	badge.outline_size = 3
	badge.position = Vector3(0, 0.65, 0)
	sign_node.add_child(badge)

	# 5. Local accent spotlight illuminating the station
	var s_light = OmniLight3D.new()
	s_light.position = Vector3(0, 0.1, 0.28)
	s_light.light_color = accent_color
	s_light.light_energy = 1.4
	s_light.omni_range = 3.2
	sign_node.add_child(s_light)

	return sign_node

func _create_3d_waypoint_beacon(parent: Node3D, pos: Vector3, label_text: String, color: Color) -> Node3D:
	var wp = Node3D.new()
	wp.position = pos
	wp.visible = false
	parent.add_child(wp)

	# 1. Vertical translucent light pillar (cylinder from deck to 2.8m)
	var pillar = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.16
	cyl.bottom_radius = 0.24
	cyl.height = 2.8
	pillar.mesh = cyl
	pillar.position = Vector3(0, -1.0, 0)
	var p_mat = StandardMaterial3D.new()
	p_mat.albedo_color = Color(color.r, color.g, color.b, 0.25)
	p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p_mat.emission_enabled = true
	p_mat.emission = color
	p_mat.emission_energy_multiplier = 2.0
	pillar.material_override = p_mat
	wp.add_child(pillar)

	# 2. Downward-pointing glowing 3D Chevron / Inverted Cone Marker
	var marker = MeshInstance3D.new()
	var cone = CylinderMesh.new()
	cone.top_radius = 0.32
	cone.bottom_radius = 0.02
	cone.height = 0.50
	marker.mesh = cone
	marker.position = Vector3(0, 0.45, 0)
	var m_mat = StandardMaterial3D.new()
	m_mat.albedo_color = color
	m_mat.emission_enabled = true
	m_mat.emission = color
	m_mat.emission_energy_multiplier = 3.5
	marker.material_override = m_mat
	wp.add_child(marker)

	# 3. Floating 3D Billboard Label (always faces the player from any angle!)
	var lbl = Label3D.new()
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.text = "▼ [DELIVERY DESTINATION] ▼\n" + label_text
	lbl.font = preload("res://fonts/ShareTechMono-Regular.ttf")
	lbl.font_size = 18
	lbl.pixel_size = 0.0024
	lbl.modulate = color
	lbl.outline_modulate = Color(0, 0, 0)
	lbl.outline_size = 4
	lbl.position = Vector3(0, 1.05, 0)
	wp.add_child(lbl)

	# 4. Beacon light
	var light = OmniLight3D.new()
	light.light_color = color
	light.light_energy = 2.4
	light.omni_range = 6.0
	wp.add_child(light)

	return wp

func _create_f2_rogue_terminal(parent: Node3D, pos: Vector3, rot_y: float, term_idx: int) -> void:
	var root = Node3D.new()
	root.position = pos
	root.rotation.y = rot_y
	parent.add_child(root)

	var desk_mat = StandardMaterial3D.new()
	desk_mat.albedo_color = Color(0.18, 0.20, 0.24)
	desk_mat.metallic = 0.6
	desk_mat.roughness = 0.4
	_add_box(root, Vector3(1.4, 0.8, 0.75), Vector3(0, 0.4, 0), desk_mat, true)

	var crt_mat = StandardMaterial3D.new()
	crt_mat.albedo_color = Color(0.12, 0.13, 0.16)
	_add_box(root, Vector3(0.55, 0.46, 0.40), Vector3(0, 1.03, 0.04), crt_mat, false)

	var scr_mat = StandardMaterial3D.new()
	scr_mat.albedo_color = Color(1.0, 0.35, 0.15)
	scr_mat.emission_enabled = true
	scr_mat.emission = Color(1.0, 0.30, 0.12)
	scr_mat.emission_energy_multiplier = 2.4
	var screen_box = _add_box(root, Vector3(0.48, 0.38, 0.02), Vector3(0, 1.03, -0.17), scr_mat, false)

	var scr_label = Label3D.new()
	scr_label.text = "ROGUE TRANSMISSION // 8400m\nTRANSMITTING TELEMETRY #%d\n[E] OVERRIDE BROADCAST" % term_idx
	scr_label.font = preload("res://fonts/ShareTechMono-Regular.ttf")
	scr_label.font_size = 14
	scr_label.pixel_size = 0.0016
	scr_label.modulate = Color(1.0, 0.9, 0.85)
	scr_label.outline_modulate = Color(0, 0, 0)
	scr_label.outline_size = 2
	scr_label.position = Vector3(0, 0, -0.015)
	scr_label.rotation.y = PI
	screen_box.add_child(scr_label)

	# High-visibility Section Signboard
	_create_station_signboard(
		root,
		Vector3(0, 1.55, -0.32),
		PI,
		"SECTION D-%d" % term_idx,
		"TELEMETRY TERMINAL 0%d" % term_idx,
		"[E] OVERRIDE ROGUE BROADCAST",
		Color(0.95, 0.85, 0.2),
		true
	)

	var area = Area3D.new()
	area.set_script(InteractableScript)
	area.set("prompt_text", "[E] Override Rogue Broadcast #%d" % term_idx)
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(1.8, 2.0, 1.8)
	col.shape = shape
	col.position = Vector3(0, 0.9, -0.2)
	area.add_child(col)

	area.connect("interacted", func(_p):
		if area.is_active:
			area.is_active = false
			f2_rogue_terminals_shut += 1
			scr_mat.albedo_color = Color(0.15, 0.45, 0.25)
			scr_mat.emission = Color(0.15, 0.45, 0.25)
			scr_mat.emission_energy_multiplier = 0.8
			scr_label.text = "TRANSMISSION PURGED // OK\nHOST TELEMETRY: SEVERED\n[STANDBY // SECURED]"
			scr_label.modulate = Color(0.3, 0.95, 0.4)
			area.set("prompt_text", "[SECURED] Broadcast Terminated")
			SoundEffects.play(SoundEffects.snd_click, 2.0, 1.2)
			f2_terminal_shutdown.emit(f2_rogue_terminals_shut, f2_rogue_terminals_total)
	)
	root.add_child(area)

func _create_f2_usb_workstation(parent: Node3D, pos: Vector3, rot_y: float, current_day: int) -> void:
	var root = Node3D.new()
	root.position = pos
	root.rotation.y = rot_y
	parent.add_child(root)

	var desk_mat = StandardMaterial3D.new()
	desk_mat.albedo_color = Color(0.20, 0.22, 0.26)
	desk_mat.metallic = 0.7
	desk_mat.roughness = 0.35
	_add_box(root, Vector3(1.4, 0.8, 0.75), Vector3(0, 0.4, 0), desk_mat, true)

	var crt_mat = StandardMaterial3D.new()
	crt_mat.albedo_color = Color(0.12, 0.13, 0.16)
	_add_box(root, Vector3(0.55, 0.46, 0.40), Vector3(0, 1.03, 0.04), crt_mat, false)

	var scr_mat = StandardMaterial3D.new()
	scr_mat.albedo_color = Color(0.12, 0.85, 0.95)
	scr_mat.emission_enabled = true
	scr_mat.emission = Color(0.12, 0.85, 0.95)
	scr_mat.emission_energy_multiplier = 2.2
	var screen_box = _add_box(root, Vector3(0.48, 0.38, 0.02), Vector3(0, 1.03, -0.17), scr_mat, false)

	var scr_label = Label3D.new()
	scr_label.text = "PROJECT TETHER TELEMETRY\nENCRYPTED USB: INSERTED\n[E] EXTRACT TO VAULT"
	scr_label.font = preload("res://fonts/ShareTechMono-Regular.ttf")
	scr_label.font_size = 14
	scr_label.pixel_size = 0.0016
	scr_label.modulate = Color(0.9, 1.0, 1.0)
	scr_label.outline_modulate = Color(0, 0, 0)
	scr_label.outline_size = 2
	scr_label.position = Vector3(0, 0, -0.015)
	scr_label.rotation.y = PI
	screen_box.add_child(scr_label)

	# High-visibility Section Signboard
	_create_station_signboard(
		root,
		Vector3(0, 1.55, -0.32),
		PI,
		"SECTION A-2",
		"RESEARCH WORKSTATION",
		"EXTRACT USB -> DELIVER TO [SECTION A-1]",
		Color(0.15, 0.85, 1.0),
		true
	)

	# Physical glowing Encrypted USB drive plugged into workstation
	var usb_node = Node3D.new()
	usb_node.position = Vector3(0.42, 0.82, -0.12)
	root.add_child(usb_node)

	var usb_mat = StandardMaterial3D.new()
	usb_mat.albedo_color = Color(0.15, 0.85, 1.0)
	usb_mat.emission_enabled = true
	usb_mat.emission = Color(0.15, 0.85, 1.0)
	usb_mat.emission_energy_multiplier = 3.2
	_add_box(usb_node, Vector3(0.08, 0.03, 0.18), Vector3(0, 0, 0), usb_mat, false)

	var usb_light = OmniLight3D.new()
	usb_light.light_color = Color(0.2, 0.85, 1.0)
	usb_light.light_energy = 1.5
	usb_light.omni_range = 2.0
	usb_node.add_child(usb_light)

	var area = Area3D.new()
	area.set_script(InteractableScript)
	area.set("prompt_text", "[E] Extract Encrypted USB -> Deliver to [SECTION A-1 VAULT]")
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(1.8, 2.0, 1.8)
	col.shape = shape
	col.position = Vector3(0, 0.9, -0.2)
	area.add_child(col)

	area.connect("interacted", func(_p):
		if not f2_usb_carried and not f2_usb_is_archived:
			f2_usb_carried = true
			usb_node.visible = false
			scr_label.text = "USB EXTRACTED // IN TRANSIT\nDELIVER TO [SECTION A-1 VAULT]\n[TRANSPORT IN PROGRESS]"
			scr_label.modulate = Color(0.95, 0.85, 0.2)
			area.set("prompt_text", "[EXTRACTED] Deliver to [SECTION A-1 VAULT]")
			SoundEffects.play(SoundEffects.snd_pickup, 2.0, 1.2)
			if f2_vault_waypoint:
				f2_vault_waypoint.visible = true
			f2_usb_picked_up.emit()
			note_inspected.emit("f2_usb_n" + str(clampi(current_day, 3, 5)))
	)
	root.add_child(area)

func _create_f2_usb_vault(parent: Node3D, pos: Vector3, rot_y: float) -> void:
	var root = Node3D.new()
	root.position = pos
	root.rotation.y = rot_y
	parent.add_child(root)

	var vault_mat = StandardMaterial3D.new()
	vault_mat.albedo_color = Color(0.14, 0.16, 0.20)
	vault_mat.metallic = 0.92
	vault_mat.roughness = 0.25
	_add_box(root, Vector3(1.1, 1.9, 0.65), Vector3(0, 0.95, 0), vault_mat, true)

	var door_mat = StandardMaterial3D.new()
	door_mat.albedo_color = Color(0.22, 0.25, 0.30)
	door_mat.metallic = 0.85
	_add_box(root, Vector3(0.95, 1.6, 0.08), Vector3(0, 0.95, -0.32), door_mat, false)

	# Biometric Status Display
	var p_mat = StandardMaterial3D.new()
	p_mat.albedo_color = Color(0.1, 0.12, 0.16)
	var panel = _add_box(root, Vector3(0.65, 0.35, 0.02), Vector3(0, 1.45, -0.37), p_mat, false)

	var v_label = Label3D.new()
	v_label.text = "SECURE DATA VAULT 04\nSTATUS: EMPTY // UNSEALED\n[E] DEPOSIT RESEARCH USB"
	v_label.font = preload("res://fonts/ShareTechMono-Regular.ttf")
	v_label.font_size = 14
	v_label.pixel_size = 0.0016
	v_label.modulate = Color(1.0, 0.75, 0.2)
	v_label.outline_modulate = Color(0, 0, 0)
	v_label.outline_size = 2
	v_label.position = Vector3(0, 0, -0.015)
	v_label.rotation.y = PI
	panel.add_child(v_label)

	# High-visibility Section Signboard
	_create_station_signboard(
		root,
		Vector3(0, 2.15, -0.36),
		PI,
		"SECTION A-1",
		"SECURE DATA VAULT",
		"DEPOSIT EXTRACTED USB HERE",
		Color(0.2, 0.95, 0.5),
		false
	)

	var area = Area3D.new()
	area.set_script(InteractableScript)
	area.set("prompt_text", "[E] Deposit USB at [SECTION A-1 VAULT]")
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(1.8, 2.0, 1.8)
	col.shape = shape
	col.position = Vector3(0, 0.95, -0.4)
	area.add_child(col)

	area.connect("interacted", func(_p):
		if f2_usb_carried:
			f2_usb_carried = false
			f2_usb_is_archived = true
			if f2_vault_waypoint:
				f2_vault_waypoint.visible = false
			v_label.text = "VAULT SEALED // 0x8F STORED\nTELEMETRY LOCKED IN VAULT\n[ACCESS RESTRICTED // OK]"
			v_label.modulate = Color(0.25, 0.95, 0.4)
			area.set("prompt_text", "[ARCHIVED] USB Data Stored in Vault")
			SoundEffects.play(SoundEffects.snd_gate, 1.5, 1.3)
			f2_usb_deposited.emit()
		elif f2_usb_is_archived:
			area.set("prompt_text", "[ARCHIVED] USB Data Stored in Vault")
		else:
			SoundEffects.play(SoundEffects.snd_click, -2.0, 0.8)
	)
	root.add_child(area)

func _create_f2_dossier_desk(parent: Node3D, pos: Vector3, rot_y: float, current_day: int) -> void:
	var root = Node3D.new()
	root.position = pos
	root.rotation.y = rot_y
	parent.add_child(root)

	var desk_mat = StandardMaterial3D.new()
	desk_mat.albedo_color = Color(0.24, 0.26, 0.30)
	desk_mat.metallic = 0.65
	desk_mat.roughness = 0.4
	_add_box(root, Vector3(1.5, 0.8, 0.85), Vector3(0, 0.4, 0), desk_mat, true)

	# Blue research schematics on desk
	var blue_mat = StandardMaterial3D.new()
	blue_mat.albedo_color = Color(0.15, 0.35, 0.65)
	_add_box(root, Vector3(0.55, 0.015, 0.42), Vector3(-0.35, 0.81, 0.05), blue_mat, false)

	# High-visibility Section Signboard
	_create_station_signboard(
		root,
		Vector3(0, 1.55, -0.35),
		0.0,
		"SECTION B-2",
		"RESEARCH RECORDS DESK",
		"RETRIEVE DOSSIER -> FILE IN [SECTION B-1]",
		Color(1.0, 0.75, 0.2),
		true
	)

	# Classified Red Dossier Folder
	var dossier_node = Node3D.new()
	dossier_node.position = Vector3(0.28, 0.82, -0.05)
	root.add_child(dossier_node)

	var dossier_mat = StandardMaterial3D.new()
	dossier_mat.albedo_color = Color(0.85, 0.15, 0.18)
	dossier_mat.roughness = 0.5
	_add_box(dossier_node, Vector3(0.38, 0.04, 0.30), Vector3(0, 0, 0), dossier_mat, false)

	var d_label = Label3D.new()
	d_label.text = "CLASSIFIED DOSSIER // DR. VANCE\nRESEARCH SCHEMATIC // EYES ONLY\n[E] RETRIEVE FILE"
	d_label.font = preload("res://fonts/ShareTechMono-Regular.ttf")
	d_label.font_size = 14
	d_label.pixel_size = 0.0016
	d_label.modulate = Color(1.0, 0.85, 0.2)
	d_label.outline_modulate = Color(0, 0, 0)
	d_label.outline_size = 2
	d_label.position = Vector3(0.0, 1.25, 0.0)
	root.add_child(d_label)

	var area = Area3D.new()
	area.set_script(InteractableScript)
	area.set("prompt_text", "[E] Retrieve Dossier -> File in [SECTION B-1 ARCHIVE]")
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(1.8, 2.0, 1.8)
	col.shape = shape
	col.position = Vector3(0, 0.9, 0)
	area.add_child(col)

	area.connect("interacted", func(_p):
		if not f2_dossier_carried and not f2_dossier_is_archived:
			f2_dossier_carried = true
			dossier_node.visible = false
			d_label.text = "DOSSIER RETRIEVED // IN TRANSIT\nFILE IN [SECTION B-1 ARCHIVE]"
			d_label.modulate = Color(0.95, 0.85, 0.2)
			area.set("prompt_text", "[RETRIEVED] File in [SECTION B-1 ARCHIVE]")
			SoundEffects.play(SoundEffects.snd_pickup, 2.0, 1.2)
			if f2_archive_waypoint:
				f2_archive_waypoint.visible = true
			f2_dossier_picked_up.emit()
			note_inspected.emit("f2_dossier_n" + str(clampi(current_day, 3, 5)))
	)
	root.add_child(area)

func _create_f2_archive_station(parent: Node3D, pos: Vector3, rot_y: float) -> void:
	var root = Node3D.new()
	root.position = pos
	root.rotation.y = rot_y
	parent.add_child(root)

	var shelf_mat = StandardMaterial3D.new()
	shelf_mat.albedo_color = Color(0.18, 0.20, 0.24)
	shelf_mat.metallic = 0.82
	shelf_mat.roughness = 0.35
	_add_box(root, Vector3(1.3, 2.2, 0.55), Vector3(0, 1.1, 0), shelf_mat, true)

	# 3 Archival Document Shelves
	for si in range(3):
		_add_box(root, Vector3(1.15, 0.04, 0.45), Vector3(0, 0.55 + float(si) * 0.55, 0.02), shelf_mat, false)

	# High-visibility Section Signboard
	_create_station_signboard(
		root,
		Vector3(0, 2.45, -0.32),
		PI,
		"SECTION B-1",
		"CENTRAL ARCHIVE STATION",
		"FILE CLASSIFIED DOSSIER HERE",
		Color(0.25, 0.95, 0.4),
		false
	)

	var arch_dossier = Node3D.new()
	arch_dossier.position = Vector3(0.0, 1.15, 0.02)
	arch_dossier.visible = false
	root.add_child(arch_dossier)

	var dossier_mat = StandardMaterial3D.new()
	dossier_mat.albedo_color = Color(0.85, 0.15, 0.18)
	_add_box(arch_dossier, Vector3(0.38, 0.04, 0.30), Vector3(0, 0, 0), dossier_mat, false)

	var a_label = Label3D.new()
	a_label.text = "CENTRAL ARCHIVE // SECTION 09\nCLASSIFIED INTAKE\n[E] FILE DOSSIER"
	a_label.font = preload("res://fonts/ShareTechMono-Regular.ttf")
	a_label.font_size = 14
	a_label.pixel_size = 0.0016
	a_label.modulate = Color(1.0, 0.85, 0.2)
	a_label.outline_modulate = Color(0, 0, 0)
	a_label.outline_size = 2
	a_label.position = Vector3(0, 1.85, -0.30)
	a_label.rotation.y = PI
	root.add_child(a_label)

	var area = Area3D.new()
	area.set_script(InteractableScript)
	area.set("prompt_text", "[E] File Dossier at [SECTION B-1 ARCHIVE]")
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(1.8, 2.0, 1.8)
	col.shape = shape
	col.position = Vector3(0, 1.0, -0.3)
	area.add_child(col)

	area.connect("interacted", func(_p):
		if f2_dossier_carried:
			f2_dossier_carried = false
			f2_dossier_is_archived = true
			if f2_archive_waypoint:
				f2_archive_waypoint.visible = false
			arch_dossier.visible = true
			a_label.text = "SECTION 09 ARCHIVE // CATALOGUED\nDOSSIER PERMANENTLY SECURED\n[ARCHIVE COMPLETE]"
			a_label.modulate = Color(0.25, 0.95, 0.4)
			area.set("prompt_text", "[FILED] Dossier Secured in Archive")
			SoundEffects.play(SoundEffects.snd_click, 2.5, 1.1)
			f2_dossier_archived.emit()
		elif f2_dossier_is_archived:
			area.set("prompt_text", "[FILED] Dossier Secured in Archive")
		else:
			SoundEffects.play(SoundEffects.snd_click, -2.0, 0.8)
	)
	root.add_child(area)

func _create_f2_coolant_station(parent: Node3D, pos: Vector3, rot_y: float) -> void:
	var root = Node3D.new()
	root.position = pos
	root.rotation.y = rot_y
	parent.add_child(root)

	var frame_mat = StandardMaterial3D.new()
	frame_mat.albedo_color = Color(0.18, 0.22, 0.28)
	frame_mat.metallic = 0.88
	frame_mat.roughness = 0.25
	_add_box(root, Vector3(0.9, 1.9, 0.7), Vector3(0, 0.95, 0), frame_mat, true)

	# High-visibility Section Signboard
	_create_station_signboard(
		root,
		Vector3(0, 2.15, -0.38),
		PI,
		"SECTION C-2",
		"CRYO COOLANT DISPENSER",
		"TAKE COOLANT -> INJECT AT [SECTION C-1]",
		Color(0.3, 0.95, 1.0),
		true
	)

	# Cryogenic Nitrogen Canister
	var can_node = Node3D.new()
	can_node.position = Vector3(0, 0.85, -0.15)
	root.add_child(can_node)

	var can_mesh = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.14
	cyl.bottom_radius = 0.16
	cyl.height = 0.55
	can_mesh.mesh = cyl
	var can_mat = StandardMaterial3D.new()
	can_mat.albedo_color = Color(0.2, 0.85, 1.0)
	can_mat.emission_enabled = true
	can_mat.emission = Color(0.15, 0.85, 1.0)
	can_mat.emission_energy_multiplier = 2.8
	can_mesh.material_override = can_mat
	can_node.add_child(can_mesh)

	var can_light = OmniLight3D.new()
	can_light.light_color = Color(0.2, 0.9, 1.0)
	can_light.light_energy = 1.8
	can_light.omni_range = 3.5
	can_node.add_child(can_light)

	var c_label = Label3D.new()
	c_label.text = "CRYOGENIC LN2 DISPENSER\nNITROGEN CANISTER: 100%\n[E] TAKE COOLANT"
	c_label.font = preload("res://fonts/ShareTechMono-Regular.ttf")
	c_label.font_size = 14
	c_label.pixel_size = 0.0016
	c_label.modulate = Color(0.85, 1.0, 1.0)
	c_label.outline_modulate = Color(0, 0, 0)
	c_label.outline_size = 2
	c_label.position = Vector3(0, 1.6, -0.38)
	c_label.rotation.y = PI
	root.add_child(c_label)

	var area = Area3D.new()
	area.set_script(InteractableScript)
	area.set("prompt_text", "[E] Take Coolant -> Inject at [SECTION C-1 SERVER]")
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(1.8, 2.0, 1.8)
	col.shape = shape
	col.position = Vector3(0, 0.9, -0.3)
	area.add_child(col)

	area.connect("interacted", func(_p):
		if not f2_coolant_carried and not f2_coolant_is_injected:
			f2_coolant_carried = true
			can_node.visible = false
			c_label.text = "DISPENSER EMPTY // CANISTER OUT\nINJECT INTO [SECTION C-1 SERVER]"
			c_label.modulate = Color(0.95, 0.85, 0.2)
			area.set("prompt_text", "[CARRIED] Inject into [SECTION C-1 SERVER]")
			SoundEffects.play(SoundEffects.snd_pickup, 2.0, 1.3)
			if f2_server_waypoint:
				f2_server_waypoint.visible = true
			f2_coolant_picked_up.emit()
	)
	root.add_child(area)

func _create_f2_overheated_server(parent: Node3D, pos: Vector3, rot_y: float) -> void:
	var root = Node3D.new()
	root.position = pos
	root.rotation.y = rot_y
	parent.add_child(root)

	var server_mat = StandardMaterial3D.new()
	server_mat.albedo_color = Color(0.12, 0.14, 0.16)
	server_mat.metallic = 0.85
	server_mat.roughness = 0.35
	_add_box(root, Vector3(1.1, 2.3, 0.8), Vector3(0, 1.15, 0), server_mat, true)

	# High-visibility Section Signboard
	_create_station_signboard(
		root,
		Vector3(0, 2.55, -0.42),
		PI,
		"SECTION C-1",
		"MAINFRAME SERVER CORE",
		"CRITICAL 98°C: INJECT COOLANT",
		Color(1.0, 0.25, 0.25),
		false
	)

	# Blinking Overheat Alarm Bars
	var red_mat = StandardMaterial3D.new()
	red_mat.albedo_color = Color(1.0, 0.15, 0.15)
	red_mat.emission_enabled = true
	red_mat.emission = Color(1.0, 0.15, 0.15)
	red_mat.emission_energy_multiplier = 3.5

	for i in range(5):
		var bar = MeshInstance3D.new()
		var bb = BoxMesh.new()
		bb.size = Vector3(0.8, 0.04, 0.02)
		bar.mesh = bb
		bar.material_override = red_mat
		bar.position = Vector3(0, 0.5 + float(i) * 0.32, -0.41)
		root.add_child(bar)

	var s_label = Label3D.new()
	s_label.text = "CORE TEMP: 98°C // DANGER CRITICAL\nSERVER MELTDOWN IMMINENT\n[E] INJECT LIQUID NITROGEN"
	s_label.font = preload("res://fonts/ShareTechMono-Regular.ttf")
	s_label.font_size = 14
	s_label.pixel_size = 0.0016
	s_label.modulate = Color(1.0, 0.25, 0.25)
	s_label.outline_modulate = Color(0, 0, 0)
	s_label.outline_size = 2
	s_label.position = Vector3(0, 1.95, -0.42)
	s_label.rotation.y = PI
	root.add_child(s_label)

	var area = Area3D.new()
	area.set_script(InteractableScript)
	area.set("prompt_text", "[E] Inject Nitrogen Coolant into [SECTION C-1]")
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(1.8, 2.0, 1.8)
	col.shape = shape
	col.position = Vector3(0, 1.1, -0.4)
	area.add_child(col)

	area.connect("interacted", func(_p):
		if f2_coolant_carried:
			f2_coolant_carried = false
			f2_coolant_is_injected = true
			if f2_server_waypoint:
				f2_server_waypoint.visible = false
			red_mat.albedo_color = Color(0.2, 0.9, 1.0)
			red_mat.emission = Color(0.2, 0.9, 1.0)
			red_mat.emission_energy_multiplier = 2.0
			s_label.text = "CORE TEMP: 18°C // STABILIZED\nTHERMAL EQUILIBRIUM RESTORED\n[SYSTEM OPTIMAL // OK]"
			s_label.modulate = Color(0.25, 0.95, 0.4)
			area.set("prompt_text", "[COOLED] Server Stabilized (18°C)")
			SoundEffects.play(SoundEffects.snd_gate, 1.8, 1.5)
			f2_coolant_injected.emit()
		elif f2_coolant_is_injected:
			area.set("prompt_text", "[COOLED] Server Stabilized (18°C)")
		else:
			SoundEffects.play(SoundEffects.snd_click, -2.0, 0.8)
	)
	root.add_child(area)

func _add_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, has_collision: bool, rot: Vector3 = Vector3.ZERO) -> Node3D:
	if has_collision:
		var body = StaticBody3D.new()
		body.position = pos
		if rot != Vector3.ZERO:
			body.rotation = rot
		var col = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = size
		col.shape = shape
		body.add_child(col)

		var inst = MeshInstance3D.new()
		var b = BoxMesh.new()
		b.size = size
		inst.mesh = b
		if mat:
			inst.material_override = mat
		body.add_child(inst)

		parent.add_child(body)
		return body
	else:
		var inst = MeshInstance3D.new()
		inst.position = pos
		if rot != Vector3.ZERO:
			inst.rotation = rot
		var b = BoxMesh.new()
		b.size = size
		inst.mesh = b
		if mat:
			inst.material_override = mat
		parent.add_child(inst)
		return inst

# Security Gate Trap (PERPENDICULAR to corridor)
func _create_security_gate(pos: Vector3, r: int, c: int, grid: Array) -> void:
	var gate_root = Node3D.new()
	gate_root.position = pos

	var S = grid.size()
	var open_cell = func(rr: int, cc: int) -> bool:
		return rr >= 0 and rr < S and cc >= 0 and cc < S and grid[rr][cc] != 1

	var along_z = open_cell.call(r - 1, c) and open_cell.call(r + 1, c)
	if not along_z:
		gate_root.rotation.y = PI / 2.0

	var metal_mat = StandardMaterial3D.new()
	metal_mat.albedo_color = Color(0.3, 0.35, 0.4)
	metal_mat.metallic = 0.85
	metal_mat.roughness = 0.35

	var W = U - 0.15
	_add_box(gate_root, Vector3(0.28, 3.8, 0.42), Vector3(-(W/2.0 - 0.14), 1.9, 0), metal_mat, true)
	_add_box(gate_root, Vector3(0.28, 3.8, 0.42), Vector3((W/2.0 - 0.14), 1.9, 0), metal_mat, true)
	_add_box(gate_root, Vector3(W, 0.55, 0.5), Vector3(0, 3.52, 0), metal_mat, false)

	var bars_node = Node3D.new()
	bars_node.name = "Bars"
	bars_node.position.y = 3.3

	for i in range(11):
		var b_x = -W/2.0 + 0.35 + float(i) * ((W - 0.7) / 10.0)
		var bar = MeshInstance3D.new()
		var b_box = BoxMesh.new()
		b_box.size = Vector3(0.06, 3.2, 0.06)
		bar.mesh = b_box
		bar.position = Vector3(b_x, 1.6, 0)
		bar.material_override = metal_mat
		bars_node.add_child(bar)

	gate_root.add_child(bars_node)

	var gate_body = StaticBody3D.new()
	gate_body.position.y = 1.9
	gate_body.collision_layer = 1 | 4
	gate_body.collision_mask = 0
	var gate_col = CollisionShape3D.new()
	var g_shape = BoxShape3D.new()
	g_shape.size = Vector3(W + 0.4, 4.4, 0.8)
	gate_col.shape = g_shape
	gate_col.disabled = true
	gate_body.add_child(gate_col)
	gate_root.add_child(gate_body)

	var lamp = MeshInstance3D.new()
	var l_box = BoxMesh.new()
	l_box.size = Vector3(0.18, 0.14, 0.08)
	lamp.mesh = l_box
	lamp.position = Vector3(W/2.0 - 0.45, 1.5, 0.25)
	var lamp_mat = StandardMaterial3D.new()
	lamp_mat.albedo_color = Color(0.15, 0.9, 0.3)
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color(0.15, 0.9, 0.3)
	lamp_mat.emission_energy_multiplier = 1.6
	lamp.material_override = lamp_mat
	gate_root.add_child(lamp)

	var area = Area3D.new()
	area.set_script(InteractableScript)
	area.set("prompt_text", "[E] Slam Security Gate (30-45s Containment Lock)")
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(2.5, 2.5, 2.5)
	col.shape = shape
	col.position = Vector3(0, 1.5, 0)
	area.add_child(col)

	var gate_data = {
		"root": gate_root,
		"bars": bars_node,
		"body_col": gate_col,
		"lamp": lamp,
		"lamp_mat": lamp_mat,
		"area": area,
		"is_closed": false,
		"timer": 0.0,
		"cooldown": 0.0
	}
	active_gates.append(gate_data)
	active_interactables.append({"type": "gate", "pos": pos, "gate_data": gate_data})

	area.connect("interacted", func(_p):
		if gate_data.is_closed:
			SoundEffects.play(SoundEffects.snd_click, -2.0, 0.75)
			return
		if gate_data.get("cooldown", 0.0) > 0.0:
			SoundEffects.play(SoundEffects.snd_click, -2.0, 0.75)
			return
		_toggle_gate_state(gate_data, true)
	)
	gate_root.add_child(area)
	add_child(gate_root)

func _toggle_gate_state(g: Dictionary, close_it: bool) -> void:
	g.is_closed = close_it
	var area: Area3D = g.get("area")
	if close_it:
		g.timer = randf_range(30.0, 45.0)
		g.bars.position.y = 0.0
		g.body_col.set_deferred("disabled", false)
		g.lamp_mat.albedo_color = Color(0.95, 0.1, 0.1)
		g.lamp_mat.emission = Color(0.95, 0.1, 0.1)
		if is_instance_valid(area):
			area.set("prompt_text", "[GATE LOCKED — AUTO-REOPEN IN %ds]" % int(ceil(g.timer)))
		SoundEffects.play(SoundEffects.snd_stone, 2.0)
		SoundEffects.play(SoundEffects.snd_click, 1.0)
		gate_toggled.emit(true)
	else:
		g.timer = 0.0
		g.cooldown = 3.0
		g.bars.position.y = 3.3
		g.body_col.set_deferred("disabled", true)
		g.lamp_mat.albedo_color = Color(0.15, 0.9, 0.3)
		g.lamp_mat.emission = Color(0.15, 0.9, 0.3)
		if is_instance_valid(area):
			area.set("prompt_text", "[E] Slam Security Gate (30-45s Containment Lock)")
		SoundEffects.play(SoundEffects.snd_stone, 0.0)
		gate_toggled.emit(false)

func _process(delta: float) -> void:
	for g in active_gates:
		if not (g is Dictionary):
			continue
		if g.get("is_closed", false):
			g["timer"] = float(g.get("timer", 0.0)) - delta
			var area: Area3D = g.get("area")
			if is_instance_valid(area):
				area.set("prompt_text", "[GATE LOCKED — AUTO-REOPEN IN %ds]" % int(ceil(max(0.0, g["timer"]))))
			if g["timer"] <= 0.0:
				_toggle_gate_state(g, false)
		elif float(g.get("cooldown", 0.0)) > 0.0:
			g["cooldown"] = max(0.0, float(g.get("cooldown", 0.0)) - delta)

func _create_biotank(pos: Vector3, has_monster: bool, r: int = -1, c: int = -1, grid: Array = []) -> Vector3:
	var tank = Node3D.new()
	tank.name = "BioTank" if not has_monster else "MainBioTank"

	var rot_y = 0.0
	var offset = Vector3.ZERO
	if r >= 0 and c >= 0 and not grid.is_empty():
		var S = grid.size()
		# Check 4 directions for adjacent solid wall (1) to snap flush against wall
		var dirs = [
			{"dr": -1, "dc": 0, "off": Vector3(0, 0, -1.05), "rot": PI},        # Wall North (-Z)
			{"dr": 1, "dc": 0, "off": Vector3(0, 0, 1.05), "rot": 0.0},         # Wall South (+Z)
			{"dr": 0, "dc": -1, "off": Vector3(-1.05, 0, 0), "rot": -PI * 0.5}, # Wall West (-X)
			{"dr": 0, "dc": 1, "off": Vector3(1.05, 0, 0), "rot": PI * 0.5}     # Wall East (+X)
		]
		for d in dirs:
			var nr = r + d["dr"]
			var nc = c + d["dc"]
			if nr >= 0 and nr < S and nc >= 0 and nc < S and grid[nr][nc] == 1:
				offset = d["off"]
				rot_y = d["rot"]
				break

	tank.position = pos + offset
	tank.rotation.y = rot_y
	if has_monster:
		biotank_node = tank

	var niche_back = MeshInstance3D.new()
	var nb_box = BoxMesh.new()
	nb_box.size = Vector3(3.2, 3.8, 0.3)
	niche_back.mesh = nb_box
	niche_back.position = Vector3(0, 1.9, 0.95)
	var niche_mat = StandardMaterial3D.new()
	niche_mat.albedo_color = Color(0.16, 0.18, 0.22)
	niche_mat.roughness = 0.85
	niche_back.material_override = niche_mat
	tank.add_child(niche_back)

	for sx in [-1, 1]:
		var side = MeshInstance3D.new()
		var s_box = BoxMesh.new()
		s_box.size = Vector3(0.3, 3.8, 1.6)
		side.mesh = s_box
		side.position = Vector3(sx * 1.55, 1.9, 0.2)
		side.material_override = niche_mat
		tank.add_child(side)

	var b_mat = StandardMaterial3D.new()
	b_mat.albedo_color = Color(0.18, 0.20, 0.24)
	b_mat.metallic = 0.88
	b_mat.roughness = 0.3

	var tank_radius: float = 1.25 if has_monster else 0.85
	var base = MeshInstance3D.new()
	var b_cyl = CylinderMesh.new()
	b_cyl.top_radius = tank_radius
	b_cyl.bottom_radius = tank_radius + 0.1
	b_cyl.height = 0.3
	base.mesh = b_cyl
	base.position = Vector3(0, 0.15, 0.3)
	base.material_override = b_mat
	tank.add_child(base)

	var cap = MeshInstance3D.new()
	cap.mesh = b_cyl
	cap.position = Vector3(0, 3.15, 0.3)
	cap.material_override = b_mat
	tank.add_child(cap)

	var g_mat = StandardMaterial3D.new()
	g_mat.albedo_color = Color(0.15, 0.95, 0.45, 0.30)
	g_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	g_mat.roughness = 0.04

	var glass = MeshInstance3D.new()
	var g_cyl = CylinderMesh.new()
	g_cyl.top_radius = tank_radius
	g_cyl.bottom_radius = tank_radius
	g_cyl.height = 2.8 if has_monster else 2.5
	glass.mesh = g_cyl
	glass.position = Vector3(0, 1.65 if has_monster else 1.55, 0.3)
	glass.material_override = g_mat
	tank.add_child(glass)

	var f_mat = StandardMaterial3D.new()
	f_mat.albedo_color = Color(0.1, 0.95, 0.3, 0.4)
	f_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	f_mat.emission_enabled = true
	f_mat.emission = Color(0.1, 0.95, 0.3)
	f_mat.emission_energy_multiplier = 1.3

	var fluid = MeshInstance3D.new()
	var f_cyl = CylinderMesh.new()
	f_cyl.top_radius = tank_radius - 0.12
	f_cyl.bottom_radius = tank_radius - 0.12
	f_cyl.height = 2.5 if has_monster else 2.1
	fluid.mesh = f_cyl
	fluid.position = Vector3(0, 1.55 if has_monster else 1.45, 0.3)
	fluid.material_override = f_mat
	tank.add_child(fluid)

	var light = OmniLight3D.new()
	light.position = Vector3(0, 1.7, 0.3)
	light.light_color = Color(0.1, 0.98, 0.35)
	light.light_energy = 2.6
	light.omni_range = 7.0
	tank.add_child(light)

	if has_monster:
		# Add 8 Heavy Structural Reinforced Steel Perimeter Containment Bars around the main BioTank
		var bar_mat = StandardMaterial3D.new()
		bar_mat.albedo_color = Color(0.14, 0.16, 0.20)
		bar_mat.metallic = 0.92
		bar_mat.roughness = 0.22

		var hazard_stripe_mat = StandardMaterial3D.new()
		hazard_stripe_mat.albedo_color = Color(0.96, 0.82, 0.12)
		hazard_stripe_mat.metallic = 0.2

		for bi in range(8):
			var ang = float(bi) / 8.0 * TAU
			var bx = cos(ang) * (tank_radius + 0.08)
			var bz = 0.3 + sin(ang) * (tank_radius + 0.08)
			var bar = MeshInstance3D.new()
			var bc = CylinderMesh.new()
			bc.top_radius = 0.045
			bc.bottom_radius = 0.045
			bc.height = 3.2
			bar.mesh = bc
			bar.position = Vector3(bx, 1.65, bz)
			bar.material_override = bar_mat
			tank.add_child(bar)

			# Hazard band around center of bar
			var h_band = MeshInstance3D.new()
			var hbc = CylinderMesh.new()
			hbc.top_radius = 0.047
			hbc.bottom_radius = 0.047
			hbc.height = 0.25
			h_band.mesh = hbc
			h_band.position = Vector3(bx, 1.65, bz)
			h_band.material_override = hazard_stripe_mat
			tank.add_child(h_band)

		# Prominent High-Security Warning Placard
		var placard = MeshInstance3D.new()
		var p_box = BoxMesh.new()
		p_box.size = Vector3(1.3, 0.5, 0.05)
		placard.mesh = p_box
		placard.position = Vector3(0, 3.35, 0.3 - tank_radius - 0.06)
		var p_mat = StandardMaterial3D.new()
		p_mat.albedo_color = Color(0.08, 0.10, 0.14)
		placard.material_override = p_mat

		var p_label = Label3D.new()
		p_label.text = "BIO-CONTAINMENT UNIT 00\nSPECIMEN ZERO // THE TENANT\nCONTAINMENT: 100% SECURED • MAX CLEARANCE"
		p_label.font = preload("res://fonts/ShareTechMono-Regular.ttf")
		p_label.font_size = 15
		p_label.pixel_size = 0.002
		p_label.modulate = Color(0.95, 0.25, 0.25)
		p_label.outline_modulate = Color(0, 0, 0)
		p_label.outline_size = 3
		p_label.position = Vector3(0, 0, -0.03)
		p_label.rotation.y = PI
		placard.add_child(p_label)
		tank.add_child(placard)
	else:
		var creature = _create_suspended_specimen_mesh()
		creature.position = Vector3(0, 1.35, 0.3)
		creature.scale = Vector3(0.5, 0.5, 0.5)
		tank.add_child(creature)

	add_child(tank)
	return tank.to_global(Vector3(0, 1.35, 0.3))

func _create_suspended_specimen_mesh() -> Node3D:
	var root = Node3D.new()
	root.name = "SuspendedSpecimen"

	var skin_mat = StandardMaterial3D.new()
	skin_mat.albedo_color = Color(0.55, 0.5, 0.48)
	skin_mat.roughness = 0.7

	var bone_mat = StandardMaterial3D.new()
	bone_mat.albedo_color = Color(0.85, 0.8, 0.7)

	var eye_mat = StandardMaterial3D.new()
	eye_mat.albedo_color = Color(1.0, 0.05, 0.1)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(1.0, 0.05, 0.1)
	eye_mat.emission_energy_multiplier = 4.0

	var torso = MeshInstance3D.new()
	var t_box = BoxMesh.new()
	t_box.size = Vector3(0.45, 0.8, 0.5)
	torso.mesh = t_box
	torso.material_override = skin_mat
	root.add_child(torso)

	for i in range(6):
		var rib = MeshInstance3D.new()
		var torus = TorusMesh.new()
		torus.inner_radius = 0.28
		torus.outer_radius = 0.34
		rib.mesh = torus
		rib.rotation.x = PI / 2.0
		rib.position.y = -0.3 + float(i) * 0.12
		rib.material_override = bone_mat
		root.add_child(rib)

	var head = MeshInstance3D.new()
	var h_box = BoxMesh.new()
	h_box.size = Vector3(0.35, 0.4, 0.5)
	head.mesh = h_box
	head.position = Vector3(0, 0.55, 0.1)
	head.material_override = skin_mat
	root.add_child(head)

	var eye_coords = [
		Vector3(-0.08, 0.62, 0.36),
		Vector3(0.08, 0.62, 0.36),
		Vector3(-0.14, 0.52, 0.33),
		Vector3(0.14, 0.52, 0.33),
		Vector3(0.0, 0.70, 0.32),
		Vector3(-0.06, 0.44, 0.37),
		Vector3(0.06, 0.44, 0.37)
	]
	for ec in eye_coords:
		var eye = MeshInstance3D.new()
		var sph = SphereMesh.new()
		sph.radius = 0.03
		sph.height = 0.06
		eye.mesh = sph
		eye.position = ec
		eye.material_override = eye_mat
		root.add_child(eye)

	var eye_glow = OmniLight3D.new()
	eye_glow.position = Vector3(0, 0.55, 0.45)
	eye_glow.light_color = Color(1.0, 0.05, 0.1)
	eye_glow.light_energy = 2.0
	eye_glow.omni_range = 3.5
	root.add_child(eye_glow)

	return root

func shatter_biotank() -> void:
	if biotank_node and is_instance_valid(biotank_node):
		SoundEffects.play(SoundEffects.snd_shatter, 2.0)
		biotank_node.queue_free()
		biotank_node = null
	disable_statue_fences()

func create_statue_electric_fence(pos: Vector3) -> Node3D:
	var fence_root = Node3D.new()
	fence_root.name = "StatueElectricFence"
	fence_root.position = pos
	add_child(fence_root)
	statue_fences.append(fence_root)

	var p_mat = StandardMaterial3D.new()
	p_mat.albedo_color = Color(0.2, 0.22, 0.26)
	p_mat.metallic = 0.85
	p_mat.roughness = 0.35

	var laser_mat = StandardMaterial3D.new()
	laser_mat.albedo_color = Color(0.2, 0.85, 1.0)
	laser_mat.emission_enabled = true
	laser_mat.emission = Color(0.2, 0.85, 1.0)
	laser_mat.emission_energy_multiplier = 3.5

	# 4 Corner Insulator Pylons: compact wall-hugging pen (1.3m x 1.1m)
	var corners = [
		Vector3(-0.65, 0, -0.55),
		Vector3(0.65, 0, -0.55),
		Vector3(0.65, 0, 0.55),
		Vector3(-0.65, 0, 0.55)
	]
	for c_pos in corners:
		var post = MeshInstance3D.new()
		var p_cyl = CylinderMesh.new()
		p_cyl.top_radius = 0.05
		p_cyl.bottom_radius = 0.07
		p_cyl.height = 2.4
		post.mesh = p_cyl
		post.position = Vector3(c_pos.x, 1.2, c_pos.z)
		post.material_override = p_mat
		fence_root.add_child(post)

	# 3 Tiers of Glowing High-Voltage Laser Cables between posts
	for tier in range(3):
		var y_tier = 0.5 + float(tier) * 0.75
		for side in range(4):
			var p1 = corners[side]
			var p2 = corners[(side + 1) % 4]
			var mid_pt = Vector3((p1.x + p2.x) * 0.5, y_tier, (p1.z + p2.z) * 0.5)
			var cable = MeshInstance3D.new()
			var b = BoxMesh.new()
			if side % 2 == 0:
				b.size = Vector3(1.3, 0.03, 0.03)
			else:
				b.size = Vector3(0.03, 0.03, 1.1)
			cable.mesh = b
			cable.position = mid_pt
			cable.material_override = laser_mat
			fence_root.add_child(cable)

	# Warning Placard
	var placard = MeshInstance3D.new()
	var pb = BoxMesh.new()
	pb.size = Vector3(0.70, 0.32, 0.04)
	placard.mesh = pb
	placard.position = Vector3(0.0, 1.7, 0.57)
	var pl_mat = StandardMaterial3D.new()
	pl_mat.albedo_color = Color(0.12, 0.15, 0.22)
	placard.material_override = pl_mat
	fence_root.add_child(placard)

	var p_label = Label3D.new()
	p_label.text = "HIGH VOLTAGE GRID\nSPECIMEN: OBSERVER\nCONTAINMENT ACTIVE\nDO NOT BREACH"
	p_label.font = preload("res://fonts/ShareTechMono-Regular.ttf")
	p_label.font_size = 16
	p_label.pixel_size = 0.002
	p_label.modulate = Color(0.2, 0.85, 1.0)
	p_label.outline_modulate = Color(0, 0, 0)
	p_label.outline_size = 3
	p_label.position = Vector3(0, 0, 0.025)
	placard.add_child(p_label)

	# Electric Hum Light
	var e_light = OmniLight3D.new()
	e_light.position = Vector3(0, 1.5, 0)
	e_light.light_color = Color(0.2, 0.85, 1.0)
	e_light.light_energy = 1.6
	e_light.omni_range = 3.5
	fence_root.add_child(e_light)

	# StaticBody collider to keep player out and statue enclosed
	var fence_body = StaticBody3D.new()
	for side in range(4):
		var p1 = corners[side]
		var p2 = corners[(side + 1) % 4]
		var col = CollisionShape3D.new()
		var c_box = BoxShape3D.new()
		if side % 2 == 0:
			c_box.size = Vector3(1.3, 2.4, 0.12)
		else:
			c_box.size = Vector3(0.12, 2.4, 1.1)
		col.shape = c_box
		col.position = Vector3((p1.x + p2.x) * 0.5, 1.2, (p1.z + p2.z) * 0.5)
		fence_body.add_child(col)
	fence_root.add_child(fence_body)

	return fence_root

func disable_statue_fences() -> void:
	for fence in statue_fences:
		if is_instance_valid(fence):
			var tw = fence.create_tween()
			tw.tween_property(fence, "scale", Vector3(1.0, 0.01, 1.0), 0.6).set_trans(Tween.TRANS_QUAD)
			tw.tween_callback(func():
				if is_instance_valid(fence):
					fence.queue_free()
			)
	statue_fences.clear()

func _create_terminal(pos: Vector3, r: int, c: int, grid: Array) -> void:
	var S = grid.size()
	var term_root = Node3D.new()

	var neighbors = [
		{ "dr": -1, "dc":  0, "rot": 0.0,            "ox": 0.0,      "oz": -U * 0.42 },
		{ "dr":  1, "dc":  0, "rot": PI,             "ox": 0.0,      "oz":  U * 0.42 },
		{ "dr":  0, "dc": -1, "rot": PI / 2.0,       "ox": -U * 0.42, "oz": 0.0 },
		{ "dr":  0, "dc":  1, "rot": -PI / 2.0,      "ox":  U * 0.42, "oz": 0.0 }
	]
	var rot_y = 0.0
	var off_x = 0.0
	var off_z = -U * 0.42
	for n in neighbors:
		var nr = r + n.dr
		var nc = c + n.dc
		if nr < 0 or nr >= S or nc < 0 or nc >= S or grid[nr][nc] == 1:
			rot_y = n.rot
			off_x = n.ox
			off_z = n.oz
			break

	term_root.position = pos + Vector3(off_x, 0, off_z)
	term_root.rotation.y = rot_y

	var body = StaticBody3D.new()
	body.position.y = 1.0
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(1.1, 1.8, 0.6)
	col.shape = shape
	body.add_child(col)

	var housing = MeshInstance3D.new()
	var h_box = BoxMesh.new()
	h_box.size = Vector3(1.0, 1.6, 0.5)
	housing.mesh = h_box
	var h_mat = StandardMaterial3D.new()
	h_mat.albedo_color = Color(0.18, 0.22, 0.26)
	h_mat.metallic = 0.7
	housing.material_override = h_mat
	body.add_child(housing)

	var screen = MeshInstance3D.new()
	var s_box = BoxMesh.new()
	s_box.size = Vector3(0.7, 0.45, 0.04)
	screen.mesh = s_box
	screen.position = Vector3(0, 0.35, 0.26)
	var scr_mat = StandardMaterial3D.new()
	scr_mat.albedo_color = Color(0.1, 0.9, 0.35)
	scr_mat.emission_enabled = true
	scr_mat.emission = Color(0.1, 0.9, 0.35)
	scr_mat.emission_energy_multiplier = 1.8
	screen.material_override = scr_mat
	body.add_child(screen)

	var scr_label = Label3D.new()
	scr_label.text = "AETHELGARD SYS_DIAG\nSUB-LEVEL TELEMETRY OK\n[E] VERIFY TERMINAL"
	scr_label.font = preload("res://fonts/ShareTechMono-Regular.ttf")
	scr_label.font_size = 14
	scr_label.pixel_size = 0.0017
	scr_label.modulate = Color(0.9, 1.0, 0.92)
	scr_label.outline_modulate = Color(0, 0, 0)
	scr_label.outline_size = 2
	scr_label.position = Vector3(0, 0, 0.025)
	screen.add_child(scr_label)

	term_root.add_child(body)

	var area = Area3D.new()
	area.set_script(InteractableScript)
	area.set("prompt_text", "[E] Check In Security Terminal")
	var a_col = CollisionShape3D.new()
	var a_shape = BoxShape3D.new()
	a_shape.size = Vector3(2.0, 2.0, 2.0)
	a_col.shape = a_shape
	a_col.position.y = 1.2
	area.add_child(a_col)

	var term_item = {"type": "terminal", "pos": pos, "active": true}
	active_interactables.append(term_item)

	area.connect("interacted", func(_p):
		if area.is_active:
			area.is_active = false
			term_item.active = false
			scr_mat.albedo_color = Color(0.15, 0.45, 0.30)
			scr_mat.emission = Color(0.15, 0.45, 0.30)
			scr_mat.emission_energy_multiplier = 0.8
			scr_label.text = "VERIFIED // SAVED\nSHIFT LOG RECORDED\n[STANDBY // SECURED]"
			scr_label.modulate = Color(0.3, 0.95, 0.45)
			area.set("prompt_text", "[VERIFIED] Shift Check-In Recorded")
			SoundEffects.play(SoundEffects.snd_click, 2.0)
			terminal_checked.emit()
	)
	term_root.add_child(area)

	add_child(term_root)

	# External Security Weapon Console beside security terminal
	var rack_mat = StandardMaterial3D.new()
	rack_mat.albedo_color = Color(0.2, 0.22, 0.25)
	_add_box(term_root, Vector3(0.55, 0.85, 0.45), Vector3(0.95, 0.425, 0.0), rack_mat, true)
	weapon_candidate_slots.append(term_root.to_global(Vector3(0.95, 0.88, 0.0)))

func _create_lore_note(pos: Vector3, note_id: String) -> void:
	var area = Area3D.new()
	area.set_script(InteractableScript)
	area.set("prompt_text", "[E] Read Incident Note")
	area.position = pos + Vector3(0, 0.05, 0)

	var note = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.38, 0.015, 0.45)
	note.mesh = box
	var n_mat = StandardMaterial3D.new()
	n_mat.albedo_color = Color(0.95, 0.92, 0.78)
	note.material_override = n_mat
	area.add_child(note)

	var light = OmniLight3D.new()
	light.position.y = 0.3
	light.light_color = Color(1.0, 0.95, 0.6)
	light.light_energy = 0.8
	light.omni_range = 2.5
	area.add_child(light)

	var col = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 1.2
	col.shape = shape
	area.add_child(col)

	area.connect("interacted", func(_p):
		SoundEffects.play(SoundEffects.snd_click, -2.0)
		note_inspected.emit(note_id)
	)
	add_child(area)

func _create_map_fragment(pos: Vector3) -> void:
	var area = Area3D.new()
	area.set_script(InteractableScript)
	area.set("prompt_text", "[E] Collect Data Relic (+$30)")
	area.position = pos + Vector3(0, 0.5, 0)

	var cube = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.32, 0.32, 0.32)
	cube.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.6, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.6, 1.0)
	mat.emission_energy_multiplier = 2.0
	cube.material_override = mat
	area.add_child(cube)

	var light = OmniLight3D.new()
	light.position.y = 0.4
	light.light_color = Color(0.2, 0.6, 1.0)
	light.light_energy = 1.8
	light.omni_range = 3.5
	area.add_child(light)

	var col = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 1.2
	col.shape = shape
	area.add_child(col)

	area.connect("interacted", func(_p):
		area.queue_free()
		SoundEffects.play(SoundEffects.snd_pickup, 2.0, 1.2)
		relic_collected.emit(30)
	)
	add_child(area)

func _create_artifact(pos: Vector3) -> void:
	var area = Area3D.new()
	area.set_script(InteractableScript)
	area.set("prompt_text", "[E] Collect Ancient Relic (+$50)")
	area.position = pos + Vector3(0, 0.4, 0)

	var gem = MeshInstance3D.new()
	var prism = BoxMesh.new()
	prism.size = Vector3(0.25, 0.45, 0.25)
	gem.mesh = prism
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.1, 0.7)
	mat.emission_enabled = true
	mat.emission = Color(0.8, 0.1, 0.7)
	mat.emission_energy_multiplier = 2.5
	gem.material_override = mat
	area.add_child(gem)

	var light = OmniLight3D.new()
	light.position.y = 0.4
	light.light_color = Color(0.8, 0.1, 0.7)
	light.light_energy = 2.2
	light.omni_range = 4.0
	area.add_child(light)

	var col = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 1.2
	col.shape = shape
	area.add_child(col)

	area.connect("interacted", func(_p):
		area.queue_free()
		SoundEffects.play(SoundEffects.snd_pickup, 4.0, 1.5)
		relic_collected.emit(50)
	)
	add_child(area)

func _build_ceiling_pipes(grid: Array) -> void:
	var S = grid.size()
	var r_c = S / 2
	var c_c = S / 2
	var pipe_mat = StandardMaterial3D.new()
	pipe_mat.albedo_color = Color(0.28, 0.32, 0.36)
	pipe_mat.metallic = 0.8
	pipe_mat.roughness = 0.4

	for r in range(1, S - 1):
		for c in range(1, S - 1):
			if active_day >= 3 and abs(r - r_c) <= 2 and abs(c - c_c) <= 2:
				continue
			elif abs(r - r_c) <= 1 and abs(c - c_c) <= 1:
				continue
			if grid[r][c] != 1 and (r * 31 + c * 17) % 7 == 2:
				var pipe = MeshInstance3D.new()
				var cyl = CylinderMesh.new()
				cyl.top_radius = 0.08
				cyl.bottom_radius = 0.08
				cyl.height = U
				pipe.mesh = cyl
				pipe.position = Vector3(float(c) * U, H - 0.25, float(r) * U)
				if (r + c) % 2 == 0:
					pipe.rotation.z = PI / 2.0
				else:
					pipe.rotation.x = PI / 2.0
				pipe.material_override = pipe_mat
				add_child(pipe)

func _create_spill(pos: Vector3, is_blood: bool) -> void:
	var area = Area3D.new()
	area.set_script(InteractableScript)
	area.set("prompt_text", "[LMB / E] Clean Blood Stain (+$15)" if is_blood else "[LMB / E] Mop Toxic Spill")
	area.position = pos
	area.add_to_group("spills")
	var puddle = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.85
	cyl.bottom_radius = 0.85
	cyl.height = 0.02
	puddle.mesh = cyl
	puddle.position.y = 0.015
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if is_blood:
		mat.albedo_color = Color(0.65, 0.05, 0.08, 0.9)
		mat.roughness = 0.2
	else:
		mat.albedo_color = Color(0.1, 0.9, 0.25, 0.85)
		mat.emission_enabled = true
		mat.emission = Color(0.1, 0.9, 0.25)
		mat.emission_energy_multiplier = 0.8
	puddle.material_override = mat
	area.add_child(puddle)
	var col = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.radius = 1.1
	shape.height = 0.6
	col.shape = shape
	col.position.y = 0.3
	area.add_child(col)
	var spill_item = {"type": "spill", "pos": pos, "active": true, "is_blood": is_blood}
	active_interactables.append(spill_item)
	var _do_clean = func():
		if not area.is_inside_tree():
			return
		if area.get_meta("_cleaned", false):
			return
		area.set_meta("_cleaned", true)
		spill_item.active = false
		mat.emission_energy_multiplier = 0.0
		spill_cleaned.emit(is_blood)
		var t = area.create_tween()
		t.tween_method(func(a): mat.albedo_color.a = a, mat.albedo_color.a, 0.0, 0.55)
		t.tween_callback(area.queue_free)
	area.set_meta("_cleaned", false)
	area.connect("interacted", func(_p): _do_clean.call())
	area.set_meta("begin_fade_fn", _do_clean)
	add_child(area)

func _create_keycard(pos: Vector3) -> void:
	var area = Area3D.new()
	area.set_script(InteractableScript)
	area.set("prompt_text", "[E] Grab Security Keycard")
	area.position = pos + Vector3(0, 0.5, 0)

	var card = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.25, 0.02, 0.38)
	card.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.18, 0.98)
	mat.metallic = 0.85
	mat.roughness = 0.25
	mat.emission_enabled = true
	mat.emission = Color(0.85, 0.18, 0.98)
	mat.emission_energy_multiplier = 2.4
	card.material_override = mat
	area.add_child(card)

	var light = OmniLight3D.new()
	light.position.y = 0.3
	light.light_color = Color(0.88, 0.22, 1.0)
	light.light_energy = 1.6
	light.omni_range = 3.2
	area.add_child(light)

	var col = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 1.0
	col.shape = shape
	area.add_child(col)

	var kc_item = {"type": "keycard", "pos": pos, "active": false, "collected": false}
	active_interactables.append(kc_item)

	area.connect("interacted", func(_p):
		if not area.visible or kc_item.get("collected", false):
			return
		kc_item["collected"] = true
		kc_item["active"] = false
		area.queue_free()
		keycard_collected.emit()
		SoundEffects.play(SoundEffects.snd_pickup)
	)
	add_child(area)
	# Keycards are hidden and non-interactable during Work Shift; only revealed when Chase starts!
	area.visible = false
	area.collision_layer = 0
	area.monitoring = false
	area.monitorable = false
	area.set("is_active", false)
	keycard_entries.append({"area": area, "item": kc_item})

func set_keycards_visible(show_cards: bool) -> void:
	for entry in keycard_entries:
		var kc_item: Dictionary = entry["item"]
		if kc_item.get("collected", false):
			kc_item["active"] = false
			continue
		kc_item["active"] = show_cards
		var area: Area3D = entry.get("area")
		if is_instance_valid(area):
			area.visible = show_cards
			area.collision_layer = 4 if show_cards else 0
			area.monitoring = show_cards
			area.monitorable = show_cards
			area.set("is_active", show_cards)

func _create_exit(c: int, r: int, grid: Array) -> void:
	var S = grid.size()
	var group = Node3D.new()
	var x = float(c) * U
	var z = float(r) * U
	active_interactables.append({"type": "exit", "pos": Vector3(x, 0.0, z)})

	var neighbors = [
		{ "dr":  1, "dc":  0, "rot": PI,        "ox": 0.0,      "oz":  U * 0.42 },
		{ "dr": -1, "dc":  0, "rot": 0.0,       "ox": 0.0,      "oz": -U * 0.42 },
		{ "dr":  0, "dc":  1, "rot": PI / 2.0,  "ox":  U * 0.42, "oz": 0.0 },
		{ "dr":  0, "dc": -1, "rot": -PI / 2.0, "ox": -U * 0.42, "oz": 0.0 }
	]
	var rot_y = PI
	var off_x = 0.0
	var off_z = U * 0.42
	for n in neighbors:
		var nr = r + n.dr
		var nc = c + n.dc
		if nr < 0 or nr >= S or nc < 0 or nc >= S or grid[nr][nc] == 1:
			rot_y = n.rot
			off_x = n.ox
			off_z = n.oz
			break

	group.position = Vector3(x + off_x, 0.0, z + off_z)
	group.rotation.y = rot_y

	var frame_mat = StandardMaterial3D.new()
	frame_mat.albedo_color = Color(0.2, 0.25, 0.3)
	frame_mat.metallic = 0.8
	frame_mat.roughness = 0.3

	var door_mat = StandardMaterial3D.new()
	door_mat.albedo_color = Color(0.35, 0.4, 0.45)
	door_mat.metallic = 0.75
	door_mat.roughness = 0.4

	_add_box(group, Vector3(U * 0.98, 3.85, 0.7), Vector3(0, 1.9, -0.5), frame_mat, true)
	_add_box(group, Vector3(0.55, 3.85, 0.55), Vector3(-1.75, 1.9, -0.1), frame_mat, true)
	_add_box(group, Vector3(0.55, 3.85, 0.55), Vector3(1.75, 1.9, -0.1), frame_mat, true)
	_add_box(group, Vector3(4.0, 0.4, 0.55), Vector3(0, 3.65, -0.05), frame_mat, false)
	_add_box(group, Vector3(2.9, 3.2, 0.22), Vector3(0, 1.6, 0.08), door_mat, true)

	var exit_sign = MeshInstance3D.new()
	var s_box = BoxMesh.new()
	s_box.size = Vector3(1.1, 0.25, 0.06)
	exit_sign.mesh = s_box
	exit_sign.position = Vector3(0, 3.15, 0.24)
	var sign_mat = StandardMaterial3D.new()
	sign_mat.albedo_color = Color(0.1, 0.9, 0.35)
	sign_mat.emission_enabled = true
	sign_mat.emission = Color(0.1, 0.9, 0.35)
	sign_mat.emission_energy_multiplier = 2.0
	exit_sign.material_override = sign_mat
	group.add_child(exit_sign)

	var area = Area3D.new()
	area.set_script(InteractableScript)
	area.set("prompt_text", "[E] ESCAPE FACILITY")
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(2.5, 3.0, 1.8)
	col.shape = shape
	col.position = Vector3(0, 1.5, 0.6)
	area.add_child(col)
	area.connect("interacted", func(_p):
		exit_reached.emit()
	)
	group.add_child(area)
	add_child(group)

func _create_fluorescent_light(pos: Vector3) -> void:
	var fixture = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(1.4, 0.08, 0.35)
	fixture.mesh = box
	fixture.position = pos + Vector3(0, H - 0.05, 0)
	var f_mat = StandardMaterial3D.new()
	f_mat.albedo_color = Color(0.95, 0.98, 1.0)
	f_mat.emission_enabled = true
	f_mat.emission = Color(0.95, 0.98, 1.0)
	f_mat.emission_energy_multiplier = 2.0
	fixture.material_override = f_mat
	add_child(fixture)

	var light = OmniLight3D.new()
	light.position = pos + Vector3(0, H - 0.35, 0)
	light.light_color = Color(0.92, 0.96, 1.0)
	light.light_energy = 1.4
	light.omni_range = 9.0
	add_child(light)
	emergency_lights.append(light)

func set_emergency_lighting(enabled: bool) -> void:
	for light in emergency_lights:
		if is_instance_valid(light):
			if enabled:
				light.light_color = Color(0.95, 0.08, 0.12)
				light.light_energy = 1.6
			else:
				light.light_color = Color(0.92, 0.96, 1.0)
				light.light_energy = 1.4

func get_interactable_list() -> Array:
	var res = []
	for item in active_interactables:
		if item.type == "spill":
			if item.active:
				res.append({"type": "spill", "pos": item.pos})
		elif item.type == "terminal":
			res.append({"type": "terminal", "pos": item.pos, "active": item.active})
		elif item.type == "gate":
			res.append({"type": "gate", "pos": item.pos, "closed": item.gate_data.is_closed})
		elif item.type == "keycard":
			if item.active:
				res.append({"type": "keycard", "pos": item.pos})
		elif item.type == "weapon":
			if item.get("active", true):
				res.append({"type": "weapon", "pos": item.pos, "weapon_type": item.weapon_type})
		elif item.type == "exit":
			res.append({"type": "exit", "pos": item.pos})
	return res

func get_exit_position() -> Vector3:
	for item in active_interactables:
		if item.type == "exit":
			return item.pos
	return Vector3.ZERO

# Builds the Night 5 Secret Sanctuary Corridor (Master Spec Section 11):
# - Long dimly-lit empty corridor extending north from (r=0, c=13).
# - Stepping inside pauses the chase step counter and stops small monsters from pursuing.
# - Contains 3 interactive Sanctuary Pedestals at the far end revealing the truth of Project Tether.
func _build_night5_secret_corridor(door_pos: Vector3, wall_mat: Material, floor_mat: Material, ceil_mat: Material) -> void:
	var sec_root = Node3D.new()
	sec_root.name = "Night5SecretCorridor"
	sec_root.position = door_pos
	add_child(sec_root)

	var dark_mat = StandardMaterial3D.new()
	dark_mat.albedo_color = Color(0.05, 0.06, 0.09)
	dark_mat.roughness = 0.85

	var gold_mat = StandardMaterial3D.new()
	gold_mat.albedo_color = Color(0.75, 0.58, 0.18)
	gold_mat.metallic = 0.85
	gold_mat.roughness = 0.25

	# Corridor length = 28m extending toward -Z (from z = 2.0 down to z = -26.0)
	var corr_len: float = 28.0
	var corr_center_z: float = -12.0

	# Solid Floor, Ceiling, Left Wall, Right Wall, and Far End Wall
	_add_box(sec_root, Vector3(U * 1.6, 0.25, corr_len), Vector3(0, -0.125, corr_center_z), floor_mat, true)
	_add_box(sec_root, Vector3(U * 1.6, 0.25, corr_len), Vector3(0, H + 0.125, corr_center_z), ceil_mat, true)
	_add_box(sec_root, Vector3(0.35, H, corr_len), Vector3(-U * 0.72, H * 0.5, corr_center_z), wall_mat, true)
	_add_box(sec_root, Vector3(0.35, H, corr_len), Vector3(U * 0.72, H * 0.5, corr_center_z), wall_mat, true)
	_add_box(sec_root, Vector3(U * 1.6, H, 0.4), Vector3(0, H * 0.5, -25.8), wall_mat, true)

	# Doorway arch header at the entrance
	var arch_label = Label3D.new()
	arch_label.text = "OMEGA SANCTUARY — RESTRICTED ARCHIVE"
	arch_label.font = preload("res://fonts/ShareTechMono-Regular.ttf")
	arch_label.font_size = 20
	arch_label.pixel_size = 0.0025
	arch_label.modulate = Color(0.95, 0.75, 0.25)
	arch_label.position = Vector3(0, 3.1, 1.8)
	sec_root.add_child(arch_label)

	# Dim eerie corridor lights along the long empty passage
	for i in range(4):
		var d_light = OmniLight3D.new()
		d_light.position = Vector3(0, H - 0.4, -3.0 - float(i) * 6.5)
		d_light.light_color = Color(0.35, 0.55, 0.85) if i < 3 else Color(0.95, 0.75, 0.25)
		d_light.light_energy = 0.55 if i < 3 else 1.25
		d_light.omni_range = 7.5
		sec_root.add_child(d_light)

	# Sanctuary Safe-Zone Trigger Volume (pauses chase step counter & small monster pursuit while inside)
	var zone_area = Area3D.new()
	zone_area.name = "SecretSafeZone"
	zone_area.collision_layer = 0
	zone_area.collision_mask = 2 # Player layer
	var zone_col = CollisionShape3D.new()
	var zone_box = BoxShape3D.new()
	zone_box.size = Vector3(U * 1.4, H, corr_len - 1.5)
	zone_col.shape = zone_box
	zone_col.position = Vector3(0, H * 0.5, corr_center_z)
	zone_area.add_child(zone_col)

	zone_area.body_entered.connect(func(b):
		if b and "in_secret_corridor" in b:
			b.in_secret_corridor = true
			secret_corridor_state_changed.emit(true)
	)
	zone_area.body_exited.connect(func(b):
		if b and "in_secret_corridor" in b:
			b.in_secret_corridor = false
			secret_corridor_state_changed.emit(false)
	)
	sec_root.add_child(zone_area)

	# 3 Interactive Pedestals at the far end of the corridor (z = -23.5)
	var ped_titles = [
		"PEDESTAL I: THE DEBT LEDGER",
		"PEDESTAL II: HOST ZERO",
		"PEDESTAL III: THE OMEGA SEAL"
	]
	for idx in range(3):
		var px: float = (float(idx) - 1.0) * 1.65
		var pz: float = -23.5
		var ped_node = Node3D.new()
		ped_node.position = Vector3(px, 0.0, pz)
		sec_root.add_child(ped_node)

		# Pedestal column & top altar slab
		_add_box(ped_node, Vector3(0.65, 1.05, 0.65), Vector3(0, 0.525, 0), dark_mat, true)
		_add_box(ped_node, Vector3(0.78, 0.12, 0.78), Vector3(0, 1.10, 0), gold_mat, false)

		var orb = MeshInstance3D.new()
		var o_sph = SphereMesh.new()
		o_sph.radius = 0.16
		o_sph.height = 0.32
		orb.mesh = o_sph
		orb.position = Vector3(0, 1.38, 0)
		var orb_mat = StandardMaterial3D.new()
		orb_mat.albedo_color = Color(0.95, 0.25, 0.35)
		orb_mat.emission_enabled = true
		orb_mat.emission = Color(0.95, 0.20, 0.30)
		orb_mat.emission_energy_multiplier = 2.2
		orb.material_override = orb_mat
		ped_node.add_child(orb)

		var p_area = Area3D.new()
		p_area.set_script(InteractableScript)
		p_area.set("prompt_text", "[E] Inspect %s" % ped_titles[idx])
		p_area.position = Vector3(0, 1.1, 0)
		var p_col = CollisionShape3D.new()
		var p_shp = SphereShape3D.new()
		p_shp.radius = 1.35
		p_col.shape = p_shp
		p_area.add_child(p_col)

		var ped_id: int = idx + 1
		p_area.connect("interacted", func(_p):
			if not p_area.get_meta("_activated", false):
				p_area.set_meta("_activated", true)
				pedestals_activated_count += 1
				orb_mat.albedo_color = Color(0.2, 0.95, 0.55)
				orb_mat.emission = Color(0.2, 0.95, 0.55)
				p_area.set("prompt_text", "[SEALED] %s" % ped_titles[idx])
				SoundEffects.play(SoundEffects.snd_pickup, 3.0, 1.25)
				pedestal_activated.emit(ped_id, pedestals_activated_count)
		)
		ped_node.add_child(p_area)
