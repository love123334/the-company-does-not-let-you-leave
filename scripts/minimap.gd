extends Control

var player: Node3D = null
var maze_grid: Array = []
var explored_tiles: Dictionary = {}
var interactable_data: Array = []
var chase_phase: bool = false

func init_map(grid: Array, p: Node3D) -> void:
	maze_grid = grid
	player = p
	explored_tiles.clear()
	queue_redraw()

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
	if player and maze_grid.size() > 0:
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
				draw_rect(rect, Color(0.08, 0.12, 0.16, 0.6))

	# Live interactables
	for item in interactable_data:
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
				if chase_phase:
					draw_rect(Rect2(Vector2(ix + cell_size * 0.15, iz + cell_size * 0.15), Vector2(cell_size * 0.7, cell_size * 0.7)), Color(0.0, 0.9, 0.95, 0.95))
			"exit":
				draw_rect(Rect2(Vector2(ix + cell_size * 0.1, iz + cell_size * 0.1), Vector2(cell_size * 0.8, cell_size * 0.8)), Color(0.06, 0.72, 0.51, 0.95))

	# Player position and heading arrow
	var px = (player.global_position.x / GameData.UNIT) * cell_size
	var pz = (player.global_position.z / GameData.UNIT) * cell_size
	draw_circle(Vector2(px, pz), cell_size * 0.45, Color(0.13, 0.83, 0.93))

	var forward = -player.global_transform.basis.z
	var arrow_end = Vector2(px + forward.x * cell_size * 0.9, pz + forward.z * cell_size * 0.9)
	draw_line(Vector2(px, pz), arrow_end, Color(1.0, 1.0, 0.2), 2.0)
