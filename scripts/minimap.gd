extends Control

var player: Node3D = null
var maze_grid: Array = []
var explored_tiles: Dictionary = {}
var interactable_data: Array = []
var chase_phase: bool = false

var floor1_grid: Array = []
var floor2_grid: Array = []
var explored_f1: Dictionary = {}
var explored_f2: Dictionary = {}
var current_floor_num: int = 1
var f2_delivery_markers: Array[Dictionary] = []

func set_f2_delivery_markers(markers: Array[Dictionary]) -> void:
	f2_delivery_markers = markers
	queue_redraw()

func init_map(grid: Array, p: Node3D) -> void:
	floor1_grid = grid
	player = p
	explored_f1.clear()
	explored_f2.clear()
	current_floor_num = 1
	maze_grid = floor1_grid
	explored_tiles = explored_f1
	queue_redraw()

func set_floor2_grid(f2_grid: Array) -> void:
	floor2_grid = f2_grid

func reveal_bonus_area() -> void:
	if maze_grid.size() == 0:
		return
	for r in range(maze_grid.size()):
		for c in range(maze_grid.size()):
			if randf() < 0.25:
				explored_tiles[Vector2i(r, c)] = true
	queue_redraw()

func reveal_entire_map() -> void:
	if maze_grid.size() == 0:
		return
	for r in range(maze_grid.size()):
		for c in range(maze_grid.size()):
			explored_tiles[Vector2i(r, c)] = true
	queue_redraw()

func set_interactables(data: Array, is_chase: bool) -> void:
	interactable_data = data
	chase_phase = is_chase
	queue_redraw()

func _process(_delta: float) -> void:
	if player:
		# Check player's floor and switch minimap grid accordingly
		var p_floor = int(player.get("current_floor")) if "current_floor" in player else 1
		if p_floor != current_floor_num:
			current_floor_num = p_floor
			if current_floor_num == 2 and not floor2_grid.is_empty():
				maze_grid = floor2_grid
				explored_tiles = explored_f2
			else:
				maze_grid = floor1_grid
				explored_tiles = explored_f1
			queue_redraw()

		if maze_grid.size() > 0:
			var px = int(round(player.global_position.x / GameData.UNIT))
			var pz = int(round(player.global_position.z / GameData.UNIT))
			for dr in range(-2, 3):
				for dc in range(-2, 3):
					var r = pz + dr
					var c = px + dc
					if r >= 0 and r < maze_grid.size() and c >= 0 and c < maze_grid.size():
						explored_tiles[Vector2i(r, c)] = true
			queue_redraw()

func _draw() -> void:
	if maze_grid.size() == 0 or player == null:
		return

	var size_px = min(size.x, size.y)
	var cell_size = size_px / float(maze_grid.size())

	# Background
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.06, 0.08, 0.85))

	# Grid tiles
	for r in range(maze_grid.size()):
		for c in range(maze_grid.size()):
			var coord = Vector2i(r, c)
			if not explored_tiles.has(coord):
				continue

			var rect = Rect2(Vector2(c * cell_size, r * cell_size), Vector2(cell_size, cell_size))
			if maze_grid[r][c] == 1:
				draw_rect(rect, Color(0.2, 0.28, 0.35, 0.9))
			else:
				var floor_col = Color(0.12, 0.24, 0.28, 0.7) if current_floor_num == 2 else Color(0.08, 0.12, 0.16, 0.6)
				draw_rect(rect, floor_col)

	# Live interactables & Weapons
	for item in interactable_data:
		var item_y = item.pos.y if "pos" in item else 0.0
		var on_this_floor = (current_floor_num == 2 and item_y >= 6.0) or (current_floor_num == 1 and item_y < 6.0)
		if not on_this_floor:
			continue

		var ix = (item.pos.x / GameData.UNIT) * cell_size
		var iz = (item.pos.z / GameData.UNIT) * cell_size
		var itype = item.type
		match itype:
			"spill":
				draw_rect(Rect2(Vector2(ix + cell_size * 0.15, iz + cell_size * 0.15), Vector2(cell_size * 0.7, cell_size * 0.7)), Color(0.52, 0.8, 0.09, 0.95))
			"terminal":
				var col = Color(0.06, 0.65, 0.91, 0.95) if item.get("active", true) else Color(0.12, 0.32, 0.42, 0.6)
				draw_rect(Rect2(Vector2(ix + cell_size * 0.1, iz + cell_size * 0.1), Vector2(cell_size * 0.8, cell_size * 0.8)), col)
			"gate":
				var col = Color(0.94, 0.27, 0.27, 0.95) if item.get("closed", false) else Color(0.96, 0.62, 0.07, 0.95)
				draw_rect(Rect2(Vector2(ix + cell_size * 0.1, iz + cell_size * 0.25), Vector2(cell_size * 0.8, cell_size * 0.5)), col)
			"keycard":
				var kc_rect = Rect2(Vector2(ix + cell_size * 0.12, iz + cell_size * 0.12), Vector2(cell_size * 0.76, cell_size * 0.76))
				# Distinctive Purple / Violet Security Keycard (Easy to differentiate from yellow gates / blue terminals)
				draw_rect(kc_rect, Color(0.85, 0.20, 0.98, 0.98))
				draw_rect(Rect2(Vector2(ix + cell_size * 0.04, iz + cell_size * 0.04), Vector2(cell_size * 0.92, cell_size * 0.92)), Color(0.72, 0.12, 0.92, 0.5), false, 1.5)
			"exit":
				draw_rect(Rect2(Vector2(ix + cell_size * 0.1, iz + cell_size * 0.1), Vector2(cell_size * 0.8, cell_size * 0.8)), Color(0.06, 0.72, 0.51, 0.95))

	# F2 Active Delivery Objective Highlights
	if current_floor_num == 2 and not f2_delivery_markers.is_empty():
		for dm in f2_delivery_markers:
			var d_pos: Vector3 = dm.get("pos", Vector3.ZERO)
			var dx = (d_pos.x / GameData.UNIT) * cell_size
			var dz = (d_pos.z / GameData.UNIT) * cell_size
			var d_col: Color = dm.get("color", Color(1.0, 0.9, 0.2))
			var d_lbl: String = dm.get("label", "!")
			draw_circle(Vector2(dx, dz), cell_size * 0.65, Color(d_col.r, d_col.g, d_col.b, 0.35))
			draw_circle(Vector2(dx, dz), cell_size * 0.35, d_col)
			var m_font = ThemeDB.fallback_font
			if m_font:
				draw_string(m_font, Vector2(dx - 12, dz - 6), d_lbl, HORIZONTAL_ALIGNMENT_CENTER, -1, 9, Color.WHITE)

	# Floor indicator in top-left of minimap
	var floor_txt = "2F [LAB]" if current_floor_num == 2 else "1F [FACILITY]"
	var font = ThemeDB.fallback_font
	if font:
		draw_string(font, Vector2(6, 16), floor_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.3, 0.9, 1.0) if current_floor_num == 2 else Color(0.85, 0.85, 0.85))

	# Player position and heading arrow
	var px = (player.global_position.x / GameData.UNIT) * cell_size
	var pz = (player.global_position.z / GameData.UNIT) * cell_size
	draw_circle(Vector2(px, pz), cell_size * 0.45, Color(0.13, 0.83, 0.93))

	var forward = -player.global_transform.basis.z
	var arrow_end = Vector2(px + forward.x * cell_size * 0.9, pz + forward.z * cell_size * 0.9)
	draw_line(Vector2(px, pz), arrow_end, Color(1.0, 1.0, 0.2), 2.0)
