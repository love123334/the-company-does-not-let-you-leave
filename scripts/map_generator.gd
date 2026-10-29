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

var biotank_node: Node3D = null
var emergency_lights: Array[OmniLight3D] = []
var active_gates: Array[Dictionary] = []
var active_interactables: Array = []
var keycard_entries: Array[Dictionary] = []
var cage_slots: Array[Dictionary] = []
var pedestals_activated_count: int = 0

func _load_tex(p: String) -> Texture2D:
	if ResourceLoader.exists(p):
		return load(p)
	return null

func build_map(grid: Array, player: Node3D, current_day: int) -> Dictionary:
	for c in get_children():
		c.queue_free()
	emergency_lights.clear()
	active_gates.clear()
	active_interactables.clear()
	keycard_entries.clear()
	cage_slots.clear()
	pedestals_activated_count = 0

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
	if ceil_tex:
		ceil_mat.albedo_texture = ceil_tex
		ceil_mat.uv1_scale = Vector3(float(S) / 2.0, float(S) / 2.0, 1)
	else:
		ceil_mat.albedo_color = Color(0.1, 0.11, 0.13)

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
	var ceil_inst = MeshInstance3D.new()
	var ceil_mesh = PlaneMesh.new()
	ceil_mesh.size = Vector2(float(S) * U, float(S) * U)
	ceil_inst.mesh = ceil_mesh
	ceil_inst.rotation.x = PI
	ceil_inst.position = Vector3((float(S) * U) / 2.0 - U / 2.0, H, (float(S) * U) / 2.0 - U / 2.0)
	ceil_inst.material_override = ceil_mat
	add_child(ceil_inst)

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
					_create_fluorescent_light(pos)

				match type:
					GameData.TileType.KEYCARD: # 2
						_create_keycard(pos)
					GameData.TileType.TRAP: # 3: Security Gate Trap
						_create_security_gate(pos, r, c, grid)
					GameData.TileType.EXIT: # 4
						_create_exit(c, r, grid)
					GameData.TileType.BIOTANK: # 5
						var is_main = (r == 1 and c == 6) or (r == 7 and c == 2)
						_create_biotank(pos, is_main)
						if is_main:
							results["hunter_pos"] = pos
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

	# Build Mezzanine Floor 2 walkways & stairs on Night 2+
	if current_day >= 2:
		_build_mezzanine_level(grid, wall_mat, floor_mat)

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

	var day_meta = GameData.DAY_META[clampi(current_day - 1, 0, GameData.DAY_META.size() - 1)]
	var st_count = min(int(day_meta.get("statues", 0)), open_cells.size())
	for i in range(st_count):
		results["statue_positions"].append(open_cells[i])

	return results

func _plan_niches(g: Array) -> Dictionary:
	var m = {}
	var S = g.size()
	var d4 = [Vector2i(-1,0), Vector2i(1,0), Vector2i(0,-1), Vector2i(0,1)]
	var kinds = ["cage", "locker", "booth", "locker", "cage", "gurney", "locker", "cage", "desk"]
	var count = 0
	for r in range(1, S - 1):
		for c in range(1, S - 1):
			if g[r][c] != 1 or (r + c) < 6 or ((r * 5 + c * 3 + r * c) % 5 != 0):
				continue
			var open_neighbors = []
			for d in d4:
				if g[r + d.x][c + d.y] == 0:
					open_neighbors.append(d)
			if open_neighbors.size() == 0:
				continue
			var chosen = open_neighbors[(r + c) % open_neighbors.size()]
			var kind = kinds[count % kinds.size()]
			count += 1
			m[Vector2i(r, c)] = { "r": r, "c": c, "a": chosen.x, "b": chosen.y, "kind": kind }
	return m

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

		"booth":
			_add_box(group, Vector3(2.1, 0.15, 1.9), Vector3(0, 0.08, 0.6), metal_mat, true)
			_add_box(group, Vector3(2.1, 0.15, 1.9), Vector3(0, 2.55, 0.6), metal_mat, false)
			var glass = _add_box(group, Vector3(2.0, 2.3, 1.8), Vector3(0, 1.35, 0.6), null, false)
			var g_mat = StandardMaterial3D.new()
			g_mat.albedo_color = Color(0.15, 0.8, 0.4, 0.25)
			g_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			g_mat.roughness = 0.08
			glass.material_override = g_mat

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

			# Cage floor base & ceiling plate
			_add_box(cage_root, Vector3(1.7, 0.1, 1.7), Vector3(0, 0.05, 0), metal_mat, false)
			_add_box(cage_root, Vector3(1.7, 0.1, 1.7), Vector3(0, 1.95, 0), metal_mat, false)

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

func _build_mezzanine_level(grid: Array, wall_mat: Material, floor_mat: Material) -> void:
	var S = grid.size()
	var mezz_root = Node3D.new()
	mezz_root.name = "MezzanineLevel"
	add_child(mezz_root)

	var metal_mat = StandardMaterial3D.new()
	metal_mat.albedo_color = Color(0.24, 0.27, 0.32)
	metal_mat.metallic = 0.8
	metal_mat.roughness = 0.4

	# Upper walkway ring along central corridors (rows/cols 5..9) at y = H (3.8m)
	var walkway_cells: Array[Vector2i] = []
	for r in range(3, S - 3):
		for c in range(3, S - 3):
			if grid[r][c] == 0 and (r == 5 or r == S - 6 or c == 5 or c == S - 6):
				walkway_cells.append(Vector2i(r, c))
				var wx = float(c) * U
				var wz = float(r) * U
				# Mezzanine grating deck at y = 3.85
				_add_box(mezz_root, Vector3(U, 0.16, U), Vector3(wx, 3.85, wz), floor_mat, true)
				# Mezzanine ceiling at y = 7.5
				_add_box(mezz_root, Vector3(U, 0.2, U), Vector3(wx, 7.5, wz), wall_mat, true)
				# Side safety railings/walls at y = 5.6
				for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
					var nr = r + d.x
					var nc = c + d.y
					if grid[nr][nc] == 1 or not (nr == 5 or nr == S - 6 or nc == 5 or nc == S - 6):
						var rx = wx + float(d.y) * (U * 0.48)
						var rz = wz + float(d.x) * (U * 0.48)
						var rsize = Vector3(U, 3.6, 0.18) if d.x != 0 else Vector3(0.18, 3.6, U)
						_add_box(mezz_root, rsize, Vector3(rx, 5.65, rz), metal_mat, true)

	if walkway_cells.size() >= 2:
		var stair_cells = [walkway_cells[0], walkway_cells[walkway_cells.size() / 2]]
		for sc in stair_cells:
			var sx = float(sc.y) * U
			var sz = float(sc.x) * U
			_create_stairwell(mezz_root, Vector3(sx, 0.0, sz), metal_mat)

func _create_stairwell(parent: Node3D, pos: Vector3, mat: Material) -> void:
	var st_root = Node3D.new()
	st_root.position = pos
	parent.add_child(st_root)

	# Visual stair steps leading up
	for i in range(6):
		var step = MeshInstance3D.new()
		var b = BoxMesh.new()
		b.size = Vector3(1.1, 0.12, 0.35)
		step.mesh = b
		step.material_override = mat
		step.position = Vector3(-U * 0.32, 0.35 + i * 0.55, -1.0 + i * 0.35)
		st_root.add_child(step)

	# Floor 1 -> Floor 2 Interactable
	var area_up = Area3D.new()
	area_up.set_script(InteractableScript)
	area_up.set("prompt_text", "[E] Ascend Stairs to Mezzanine (2F)")
	area_up.position = Vector3(0, 1.0, 0)
	var col_up = CollisionShape3D.new()
	var shp_up = SphereShape3D.new()
	shp_up.radius = 1.4
	col_up.shape = shp_up
	area_up.add_child(col_up)
	area_up.connect("interacted", func(p):
		p.global_position = pos + Vector3(0, 4.15, 0)
		if "current_floor" in p:
			p.current_floor = 2
		SoundEffects.play_heavy_step()
	)
	st_root.add_child(area_up)

	# Floor 2 -> Floor 1 Interactable
	var area_dn = Area3D.new()
	area_dn.set_script(InteractableScript)
	area_dn.set("prompt_text", "[E] Descend Stairs to Main Floor (1F)")
	area_dn.position = Vector3(0, 4.9, 0)
	var col_dn = CollisionShape3D.new()
	var shp_dn = SphereShape3D.new()
	shp_dn.radius = 1.4
	col_dn.shape = shp_dn
	area_dn.add_child(col_dn)
	area_dn.connect("interacted", func(p):
		p.global_position = pos + Vector3(0, 0.25, 0)
		if "current_floor" in p:
			p.current_floor = 1
		SoundEffects.play_heavy_step()
	)
	st_root.add_child(area_dn)

func _add_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, has_collision: bool) -> Node3D:
	if has_collision:
		var body = StaticBody3D.new()
		body.position = pos
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
		var b = BoxMesh.new()
		b.size = size
		inst.mesh = b
		inst.position = pos
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
	gate_body.position.y = 1.6
	var gate_col = CollisionShape3D.new()
	var g_shape = BoxShape3D.new()
	g_shape.size = Vector3(W - 0.4, 3.2, 0.3)
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
		g.body_col.disabled = false
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
		g.body_col.disabled = true
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

func _create_biotank(pos: Vector3, has_monster: bool) -> void:
	var tank = Node3D.new()
	tank.name = "BioTank"
	tank.position = pos
	if has_monster:
		biotank_node = tank

	var niche_back = MeshInstance3D.new()
	var nb_box = BoxMesh.new()
	nb_box.size = Vector3(2.4, 3.8, 0.22)
	niche_back.mesh = nb_box
	niche_back.position = Vector3(0, 1.9, 0.75)
	var niche_mat = StandardMaterial3D.new()
	niche_mat.albedo_color = Color(0.18, 0.2, 0.22)
	niche_mat.roughness = 0.85
	niche_back.material_override = niche_mat
	tank.add_child(niche_back)

	for sx in [-1, 1]:
		var side = MeshInstance3D.new()
		var s_box = BoxMesh.new()
		s_box.size = Vector3(0.22, 3.8, 1.1)
		side.mesh = s_box
		side.position = Vector3(sx * 1.11, 1.9, 0.2)
		side.material_override = niche_mat
		tank.add_child(side)

	var body = StaticBody3D.new()
	var col = CollisionShape3D.new()
	var cshape = BoxShape3D.new()
	cshape.size = Vector3(2.4, 3.8, 0.5)
	col.shape = cshape
	col.position = Vector3(0, 1.9, 0.5)
	body.add_child(col)
	tank.add_child(body)

	var b_mat = StandardMaterial3D.new()
	b_mat.albedo_color = Color(0.2, 0.22, 0.25)
	b_mat.metallic = 0.85
	b_mat.roughness = 0.3

	var base = MeshInstance3D.new()
	var b_cyl = CylinderMesh.new()
	b_cyl.top_radius = 0.85
	b_cyl.bottom_radius = 0.95
	b_cyl.height = 0.3
	base.mesh = b_cyl
	base.position = Vector3(0, 0.15, 0.3)
	base.material_override = b_mat
	tank.add_child(base)

	var cap = MeshInstance3D.new()
	cap.mesh = b_cyl
	cap.position = Vector3(0, 2.85, 0.3)
	cap.material_override = b_mat
	tank.add_child(cap)

	var g_mat = StandardMaterial3D.new()
	g_mat.albedo_color = Color(0.2, 0.9, 0.5, 0.22)
	g_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	g_mat.roughness = 0.05

	var glass = MeshInstance3D.new()
	var g_cyl = CylinderMesh.new()
	g_cyl.top_radius = 0.8
	g_cyl.bottom_radius = 0.8
	g_cyl.height = 2.5
	glass.mesh = g_cyl
	glass.position = Vector3(0, 1.55, 0.3)
	glass.material_override = g_mat
	tank.add_child(glass)

	var f_mat = StandardMaterial3D.new()
	f_mat.albedo_color = Color(0.1, 0.95, 0.3, 0.35)
	f_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	f_mat.emission_enabled = true
	f_mat.emission = Color(0.1, 0.95, 0.3)
	f_mat.emission_energy_multiplier = 1.2

	var fluid = MeshInstance3D.new()
	var f_cyl = CylinderMesh.new()
	f_cyl.top_radius = 0.65
	f_cyl.bottom_radius = 0.65
	f_cyl.height = 2.1
	fluid.mesh = f_cyl
	fluid.position = Vector3(0, 1.45, 0.3)
	fluid.material_override = f_mat
	tank.add_child(fluid)

	var light = OmniLight3D.new()
	light.position = Vector3(0, 1.6, 0.3)
	light.light_color = Color(0.1, 0.95, 0.3)
	light.light_energy = 2.2
	light.omni_range = 6.0
	tank.add_child(light)

	if not has_monster:
		var creature = _create_suspended_specimen_mesh()
		creature.position = Vector3(0, 1.35, 0.3)
		creature.scale = Vector3(0.5, 0.5, 0.5)
		tank.add_child(creature)

	add_child(tank)

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
	scr_mat.emission_energy_multiplier = 1.4
	screen.material_override = scr_mat
	body.add_child(screen)
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
			scr_mat.albedo_color = Color(0.2, 0.8, 1.0)
			scr_mat.emission = Color(0.2, 0.8, 1.0)
			area.set("prompt_text", "[VERIFIED] Shift Check-In Recorded")
			SoundEffects.play(SoundEffects.snd_click, 2.0)
			terminal_checked.emit()
	)
	term_root.add_child(area)
	add_child(term_root)

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
	var pipe_mat = StandardMaterial3D.new()
	pipe_mat.albedo_color = Color(0.28, 0.32, 0.36)
	pipe_mat.metallic = 0.8
	pipe_mat.roughness = 0.4

	for r in range(1, S - 1):
		for c in range(1, S - 1):
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
	mat.albedo_color = Color(0.9, 0.8, 0.1)
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.8, 0.1)
	mat.emission_energy_multiplier = 1.0
	card.material_override = mat
	area.add_child(card)

	var light = OmniLight3D.new()
	light.position.y = 0.3
	light.light_color = Color(0.9, 0.8, 0.1)
	light.light_energy = 1.2
	light.omni_range = 2.5
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
