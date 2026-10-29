extends CharacterBody3D

# The Hunter (Subject Zero) — Full v7 Anatomical Horror Rig & Step-Linked AI
# Ported from HTML buildMonster, animateMonster, updateHunter, hitHunter, startKill & updateKill.
# Key Rules:
# - Dormant inside BioTank during Work Phase (scale 0.48), erupts in Chase Phase.
# - Step-Linked Movement: Advances ONLY when the player moves (budget = player_moved * HUNTER_MULT).
#   When the player stands still, the Hunter freezes its advance in place!
# - Mop Stun & Ambush: 1st/2nd mop hits stun it for 4.5s (slumped over, dimmed eyes);
#   3rd mop hit triggers AMBUSH (plays dead until player turns away, then lunges!).
# - Final Mode (<= 30 steps): Unstoppable, immune to mop stun, glowing rage eyes.
# - Kill Animation (1.3s): Screaming jaw, slashing claws, and impaling bone spike jumpscare!

signal player_caught(reason: String)

enum State { DORMANT, CHASE, ROAM, HIDE_SEEK, WINDUP, STUNNED, AMBUSH, KILL, HUNT_PREY, EXECUTE_PREY }

const _N4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var state: State = State.DORMANT
var player: CharacterBody3D = null
var map_gen: Node3D = null
var maze_grid: Array = []
var active: bool = false
var frozen_by_dev: bool = false
var final_mode: bool = false
var overtime_rage: bool = false

# Prey hunting & in-game execution state (Crawler / Cultist)
var prey_target: Node3D = null
var prey_type: String = ""
var execute_timer: float = 0.0
var execute_duration: float = 1.55
var _prey_scan_timer: float = 0.0
var _prey_toast_cooldown: float = 0.0

# Statue rerouting & Cloak repulsion state
var statue_blocked: bool = false
var _statue_reroute_toast_cd: float = 0.0
var cloak_repel_timer: float = 0.0

# Cached BFS distance field toward player (recomputed when player cell or gate state changes)
var _bfs_cache_key: String = ""
var _bfs_dist_field: PackedInt32Array = PackedInt32Array()
var _bfs_grid_size: int = 0

var base_speed: float = 5.6
var stun_timer: float = 0.0
var ambush_timer: float = 0.0
var windup_timer: float = 0.0
var devour_pause_timer: float = 0.0
var step_sound_accum: float = 0.0
var roam_timer: float = 0.0
var roam_dir: Vector3 = Vector3.FORWARD
var mop_hits_taken: int = 0

# Kill / Jumpscare sequence state
var kill_timer: float = 0.0
var kill_style: String = "claw"
var kill_reason: String = "HARVESTED BY SUBJECT ZERO — THE HUNTER CAUGHT YOU."
var kill_spike_triggered: bool = false

# Locker investigation state
var hide_seek_target: Vector3 = Vector3.ZERO
var hide_seek_locker: Node3D = null
var hide_seek_timer: float = 0.0
var saw_player_hide: bool = false

# Anatomical v7 Rig Nodes
var mesh_root: Node3D = null
var hips_node: Node3D = null
var spine_node: Node3D = null
var neck_node: Node3D = null
var head_node: Node3D = null
var jaw_node: Node3D = null
var arms_data: Array[Dictionary] = []
var legs_data: Array[Dictionary] = []
var spiders_data: Array[Dictionary] = []
var tendrils: Array[Node3D] = []
var eye_meshes: Array[MeshInstance3D] = []
var eye_mat: StandardMaterial3D = null
var kill_spike: Node3D = null
var eye_light: OmniLight3D = null
var anim_time: float = 0.0

func _ready() -> void:
	add_to_group("hunter")
	collision_layer = 4
	collision_mask = 1
	_build_hunter_mesh()
	scale = Vector3(0.48, 0.48, 0.48)

func activate() -> void:
	active = true
	state = State.CHASE
	mop_hits_taken = 0
	var tw = create_tween()
	tw.tween_property(self, "scale", Vector3.ONE, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	SoundEffects.play_hunter_screech()

func set_freeze(val: bool) -> void:
	frozen_by_dev = val

func enter_final_mode() -> void:
	if final_mode:
		return
	final_mode = true
	if state == State.STUNNED or state == State.AMBUSH or state == State.WINDUP or state == State.ROAM:
		state = State.CHASE
		stun_timer = 0.0
	base_speed = max(base_speed, 7.2)
	if eye_light:
		eye_light.light_energy = 4.5
		eye_light.omni_range = 14.0
	# Match HTML enterFinal: ensure Hunter is positioned at most (chase_distance * STEP_THRESH) along the BFS path
	if state != State.HIDE_SEEK and state != State.WINDUP and state != State.KILL:
		var target_units = float(GameData.FINAL_TRIGGER_STEPS) * GameData.STEP_THRESH + 2.5
		var cur_steps = get_bfs_steps_to_player()
		if cur_steps * GameData.STEP_THRESH > target_units + GameData.UNIT:
			place_at_bfs_distance(target_units, true)
	SoundEffects.play_hunter_screech()

func enter_overtime_rage() -> void:
	if not final_mode:
		enter_final_mode()
	if overtime_rage:
		return
	overtime_rage = true
	state = State.CHASE
	stun_timer = 0.0
	base_speed = max(base_speed, 9.5)
	if eye_light:
		eye_light.light_energy = 6.5
		eye_light.omni_range = 18.0
	# Teleport close along the shortest BFS corridor if far away so 0 steps means immediate harvest pressure
	if get_bfs_steps_to_player() > 6:
		place_at_bfs_distance(GameData.UNIT * 2.5, false)
	SoundEffects.play_hunter_screech()

func _get_closed_gate_cells(respect_gates: bool) -> Dictionary:
	var closed := {}
	if not respect_gates or map_gen == null or not is_instance_valid(map_gen):
		return closed
	var gates = map_gen.get("active_gates")
	if gates is Array:
		var U = GameData.UNIT
		for g in gates:
			if g is Dictionary and g.get("is_closed", false) and is_instance_valid(g.get("root")):
				var gp: Vector3 = g["root"].global_position
				var gr: int = int(round(gp.z / U))
				var gc: int = int(round(gp.x / U))
				closed[Vector2i(gr, gc)] = true
	return closed

func _is_inside_statue_fear_zone(wx: float, wz: float) -> bool:
	if final_mode or overtime_rage:
		return false
	for st in get_tree().get_nodes_in_group("statues"):
		if is_instance_valid(st) and st.get("active"):
			var d = Vector2(wx - st.global_position.x, wz - st.global_position.z).length()
			if d < GameData.STATUE_FEAR_RADIUS:
				return true
	return false

# Computes exact BFS distance table from player's grid cell (ported from HTML bfsField / playerField)
func _get_player_bfs_field(respect_gates: bool) -> PackedInt32Array:
	if maze_grid.is_empty() or player == null or not is_instance_valid(player):
		return PackedInt32Array()
	var S: int = maze_grid.size()
	_bfs_grid_size = S
	var U: float = GameData.UNIT
	var pr: int = clampi(int(round(player.global_position.z / U)), 0, S - 1)
	var pc: int = clampi(int(round(player.global_position.x / U)), 0, S - 1)

	var closed_gates: Dictionary = _get_closed_gate_cells(respect_gates)
	var gate_str := ""
	for k in closed_gates.keys():
		gate_str += "%d,%d;" % [k.x, k.y]
	var key := "%d,%d|%d|%s" % [pr, pc, S, gate_str]
	if key == _bfs_cache_key and _bfs_dist_field.size() == S * S:
		return _bfs_dist_field

	var d := PackedInt32Array()
	d.resize(S * S)
	d.fill(-1)

	var queue: Array[int] = [pr * S + pc]
	d[pr * S + pc] = 0
	var head: int = 0
	while head < queue.size():
		var cur: int = queue[head]
		head += 1
		var r: int = cur / S
		var c: int = cur % S
		for ofs in _N4:
			var nr: int = r + ofs.x
			var nc: int = c + ofs.y
			if nr < 0 or nc < 0 or nr >= S or nc >= S:
				continue
			if maze_grid[nr][nc] == 1:
				continue
			var idx: int = nr * S + nc
			if d[idx] >= 0:
				continue
			if closed_gates.has(Vector2i(nr, nc)):
				continue
			d[idx] = d[cur] + 1
			queue.append(idx)

	_bfs_cache_key = key
	_bfs_dist_field = d
	return d

# Computes a BFS distance field that marks Statue fear zones as obstacles so the Hunter can route via an alternate path
func _get_player_bfs_field_avoiding_statues(respect_gates: bool) -> PackedInt32Array:
	if maze_grid.is_empty() or player == null or not is_instance_valid(player):
		return PackedInt32Array()
	var S: int = maze_grid.size()
	_bfs_grid_size = S
	var U: float = GameData.UNIT
	var pr: int = clampi(int(round(player.global_position.z / U)), 0, S - 1)
	var pc: int = clampi(int(round(player.global_position.x / U)), 0, S - 1)
	var closed_gates: Dictionary = _get_closed_gate_cells(respect_gates)

	var d := PackedInt32Array()
	d.resize(S * S)
	d.fill(-1)

	var queue: Array[int] = [pr * S + pc]
	d[pr * S + pc] = 0
	var head: int = 0
	while head < queue.size():
		var cur: int = queue[head]
		head += 1
		var r: int = cur / S
		var c: int = cur % S
		for ofs in _N4:
			var nr: int = r + ofs.x
			var nc: int = c + ofs.y
			if nr < 0 or nc < 0 or nr >= S or nc >= S:
				continue
			if maze_grid[nr][nc] == 1:
				continue
			var idx: int = nr * S + nc
			if d[idx] >= 0:
				continue
			if closed_gates.has(Vector2i(nr, nc)):
				continue
			var wx: float = float(nc) * U
			var wz: float = float(nr) * U
			if _is_inside_statue_fear_zone(wx, wz):
				continue
			d[idx] = d[cur] + 1
			queue.append(idx)
	return d

# Returns the best neighboring cell (nr, nc, dr, dc) that strictly decreases BFS distance to player
func _bfs_next_cell(pos: Vector3, d: PackedInt32Array, S: int, ignore_statue_fear: bool = false) -> Array:
	if d.is_empty() or S <= 0:
		return []
	var U: float = GameData.UNIT
	var r: int = int(round(pos.z / U))
	var c: int = int(round(pos.x / U))
	if r < 0 or c < 0 or r >= S or c >= S:
		return []
	var cur: int = d[r * S + c]
	if cur <= 0:
		return []
	var best_cand: Array = []
	var best_world_dist: float = 1e9
	var skipped_by_statue: bool = false
	for ofs in _N4:
		var nr: int = r + ofs.x
		var nc: int = c + ofs.y
		if nr < 0 or nc < 0 or nr >= S or nc >= S:
			continue
		if d[nr * S + nc] == cur - 1:
			var wx: float = float(nc) * U
			var wz: float = float(nr) * U
			if not ignore_statue_fear and _is_inside_statue_fear_zone(wx, wz):
				skipped_by_statue = true
				continue
			var wd: float = Vector2( player.global_position.x - wx, player.global_position.z - wz ).length() if player else 0.0
			if wd < best_world_dist:
				best_world_dist = wd
				best_cand = [nr, nc, ofs.x, ofs.y]
	if best_cand.is_empty() and skipped_by_statue:
		statue_blocked = true
	return best_cand

func get_bfs_steps_to_player() -> int:
	if not player or not is_instance_valid(player):
		return 50
	var d := _get_player_bfs_field(not final_mode)
	var S: int = _bfs_grid_size
	if not d.is_empty() and S > 0:
		var U: float = GameData.UNIT
		var r: int = clampi(int(round(global_position.z / U)), 0, S - 1)
		var c: int = clampi(int(round(global_position.x / U)), 0, S - 1)
		var cells: int = d[r * S + c]
		if cells >= 0:
			var world_d = max(float(cells) * U, global_position.distance_to(player.global_position))
			return max(1, int(round(world_d / GameData.STEP_THRESH)))
	return max(1, int(round(global_position.distance_to(player.global_position) / GameData.STEP_THRESH)))

func place_at_bfs_distance(target_units: float, avoid_los: bool = true) -> bool:
	var d := _get_player_bfs_field(false)
	var S: int = _bfs_grid_size
	if d.is_empty() or S <= 0 or not player:
		return false
	var U: float = GameData.UNIT
	var best_cell := Vector2i(-1, -1)
	var best_score: float = 1e9
	for r in range(S):
		for c in range(S):
			var dist_cells: int = d[r * S + c]
			if dist_cells <= 0 or maze_grid[r][c] == 1:
				continue
			var score: float = abs(float(dist_cells) * U - target_units) + randf() * 1.2
			var wx: float = float(c) * U
			var wz: float = float(r) * U
			if avoid_los and _has_line_of_sight_to(Vector3(wx, 1.5, wz)):
				score += U * 3.0
			if score < best_score:
				best_score = score
				best_cell = Vector2i(r, c)
	if best_cell.x < 0:
		return false
	global_position = Vector3(float(best_cell.y) * U, 0.0, float(best_cell.x) * U)
	var to_p = player.global_position - global_position
	rotation.y = atan2(-to_p.x, -to_p.z)
	return true

# Exact port of HTML hAdvance(pos, F, budget, tx, tz, gates, stop):
# Advances the Hunter strictly along the BFS shortest path by `budget` meters!
func _advance_along_bfs_path(budget: float, stop_dist: float, delta: float) -> String:
	if not player or not is_instance_valid(player):
		return "lost"
	var respect_gates: bool = not final_mode and not overtime_rage
	var d := _get_player_bfs_field(false)
	var S: int = _bfs_grid_size
	if d.is_empty() or S <= 0:
		return "lost"

	var closed_gates: Dictionary = _get_closed_gate_cells(respect_gates)
	var U: float = GameData.UNIT
	var pos_x: float = global_position.x
	var pos_z: float = global_position.z
	var tx: float = player.global_position.x
	var tz: float = player.global_position.z
	var heading_dir := Vector2.ZERO
	var guard: int = 14
	var status: String = "moving"

	while budget > 0.001 and guard > 0:
		guard -= 1
		var c: int = int(round(pos_x / U))
		var r: int = int(round(pos_z / U))
		if r < 0 or c < 0 or r >= S or c >= S:
			status = "lost"
			break
		var cur: int = d[r * S + c]
		if cur < 0:
			status = "lost"
			break
		if cur == 0:
			var dx: float = tx - pos_x
			var dz: float = tz - pos_z
			var dd: float = sqrt(dx * dx + dz * dz)
			var allow: float = dd - stop_dist
			if allow <= 0.001:
				status = "near"
				break
			var mv: float = min(budget, allow)
			if dd > 0.0001:
				pos_x += (dx / dd) * mv
				pos_z += (dz / dd) * mv
				heading_dir = Vector2(dx / dd, dz / dd)
			status = "moving" if mv < allow - 0.001 else "near"
			break

		var nb: Array = _bfs_next_cell(Vector3(pos_x, 0.0, pos_z), d, S)
		if nb.is_empty():
			if statue_blocked and get_bfs_steps_to_player() > 30:
				# Player is > 30 steps away while Hunter is blocked by a Statue -> compute alternate route around Statue!
				var d_alt := _get_player_bfs_field_avoiding_statues(respect_gates)
				if not d_alt.is_empty():
					nb = _bfs_next_cell(Vector3(pos_x, 0.0, pos_z), d_alt, S, true)
					if not nb.is_empty():
						d = d_alt
				if nb.is_empty():
					# Fallback if no alternate loop exists: flank past once > 30 steps away
					nb = _bfs_next_cell(Vector3(pos_x, 0.0, pos_z), d, S, true)
				if not nb.is_empty() and _statue_reroute_toast_cd <= 0.0:
					_statue_reroute_toast_cd = 10.0
					SoundEffects.play(SoundEffects.snd_growl, 1.0, 0.78)
					var hud_node = get_tree().root.find_child("HUD", true, false)
					if hud_node and hud_node.has_method("show_toast"):
						hud_node.show_toast("⚠ Subject Zero is >30 steps behind—it's taking another route around the Statue!", Color(1.0, 0.55, 0.25))
			if nb.is_empty():
				status = "lost"
				break
		else:
			statue_blocked = false
		var nr: int = nb[0]
		var nc: int = nb[1]
		var dr: int = nb[2]
		var dc: int = nb[3]

		# Check if a closed security gate blocks the next cell
		if closed_gates.has(Vector2i(nr, nc)):
			var sx: float = float(nc) * U - float(dc) * 1.8
			var sz: float = float(nr) * U - float(dr) * 1.8
			var gd: float = Vector2(sx - pos_x, sz - pos_z).length()
			if gd > 0.05:
				var k: float = min(budget, gd) / gd
				pos_x += (sx - pos_x) * k
				pos_z += (sz - pos_z) * k
				heading_dir = Vector2(sx - pos_x, sz - pos_z).normalized()
			status = "blocked"
			break

		var gx: float = float(nc) * U
		var gz: float = float(nr) * U
		var dx: float = gx - pos_x
		var dz: float = gz - pos_z
		var dd: float = sqrt(dx * dx + dz * dz)
		if dd > 0.0001:
			heading_dir = Vector2(dx / dd, dz / dd)
		if dd <= budget:
			pos_x = gx
			pos_z = gz
			budget -= dd
		else:
			if dd > 0.0001:
				pos_x += (dx / dd) * budget
				pos_z += (dz / dd) * budget
			budget = 0.0

	var moved_vec := Vector3(pos_x - global_position.x, 0.0, pos_z - global_position.z)
	global_position.x = pos_x
	global_position.z = pos_z
	velocity = moved_vec / max(delta, 0.001)
	if heading_dir.length_squared() > 0.001:
		var target_yaw = atan2(-heading_dir.x, -heading_dir.y)
		rotation.y = lerp_angle(rotation.y, target_yaw, min(1.0, delta * 12.0))
	return status

# Returns: "stunned", "ambush", or "immune"
func hit_by_mop() -> String:
	if not active or state == State.DORMANT or state == State.KILL:
		return "immune"
	if final_mode:
		SoundEffects.play_hunter_screech()
		return "immune"

	mop_hits_taken += 1
	SoundEffects.play_hunter_screech()
	if mop_hits_taken >= 3:
		state = State.AMBUSH
		ambush_timer = 6.0
		return "ambush"
	else:
		state = State.STUNNED
		stun_timer = 4.5
		return "stunned"

func on_devoured_prey() -> void:
	devour_pause_timer = 0.9
	SoundEffects.play_Wet_Squish()

func on_repelled_by_cloak(cloak_pos: Vector3) -> void:
	if state == State.KILL or state == State.DORMANT or state == State.EXECUTE_PREY:
		return
	state = State.ROAM
	prey_target = null
	cloak_repel_timer = 3.2
	_pick_roam_dir_away_from(cloak_pos)

func start_prey_execution(target_node: Node3D, p_type: String) -> bool:
	if not active or state == State.DORMANT or state == State.KILL or state == State.EXECUTE_PREY or state == State.STUNNED:
		return false
	if not is_instance_valid(target_node) or bool(target_node.get("is_dead")) or bool(target_node.get("is_being_executed")):
		return false
	prey_target = target_node
	prey_type = p_type
	state = State.EXECUTE_PREY
	execute_timer = 0.0
	execute_duration = 1.45 if p_type == "crawler" else 1.65
	velocity = Vector3.ZERO
	var to_t = target_node.global_position - global_position
	if Vector2(to_t.x, to_t.z).length_squared() > 0.001:
		rotation.y = atan2(-to_t.x, -to_t.z)
	if target_node.has_method("start_execution_by_hunter"):
		target_node.start_execution_by_hunter(self)
	SoundEffects.play(SoundEffects.snd_growl, 3.0, 0.72)
	var hud_node = get_tree().root.find_child("HUD", true, false)
	if hud_node and hud_node.has_method("show_toast") and player and global_position.distance_to(player.global_position) < 22.0:
		var msg = "Subject Zero is crushing a Crawler—RUN WHILE IT'S DISTRACTED!" if p_type == "crawler" else "Subject Zero grabbed a Cultist by the throat—USE THIS CHANCE TO RUN!"
		hud_node.show_toast(msg, Color(0.35, 1.0, 0.65))
	return true

func _find_nearby_prey() -> void:
	if state != State.CHASE and state != State.ROAM:
		return
	if overtime_rage:
		return
	var best_node: Node3D = null
	var best_type: String = ""
	var best_dist: float = 11.2

	for cr in get_tree().get_nodes_in_group("crawlers"):
		if is_instance_valid(cr) and bool(cr.get("active")) and not bool(cr.get("is_dead")) and not bool(cr.get("latched")) and not bool(cr.get("is_being_executed")):
			if _is_inside_statue_fear_zone(cr.global_position.x, cr.global_position.z):
				continue
			var d = Vector2(cr.global_position.x - global_position.x, cr.global_position.z - global_position.z).length()
			if d < best_dist and (d < 6.5 or _has_line_of_sight_to(cr.global_position + Vector3(0, 0.6, 0))):
				best_dist = d
				best_node = cr
				best_type = "crawler"

	for cu in get_tree().get_nodes_in_group("cultists"):
		if is_instance_valid(cu) and bool(cu.get("active")) and not bool(cu.get("is_dead")) and not bool(cu.get("is_killing")) and not bool(cu.get("is_being_executed")):
			if _is_inside_statue_fear_zone(cu.global_position.x, cu.global_position.z):
				continue
			var d = Vector2(cu.global_position.x - global_position.x, cu.global_position.z - global_position.z).length()
			if d < best_dist and (d < 6.8 or _has_line_of_sight_to(cu.global_position + Vector3(0, 1.2, 0))):
				best_dist = d
				best_node = cu
				best_type = "cultist"

	if best_node != null:
		prey_target = best_node
		prey_type = best_type
		state = State.HUNT_PREY
		SoundEffects.play(SoundEffects.snd_growl, 2.0, 0.78)
		if _prey_toast_cooldown <= 0.0 and player and global_position.distance_to(player.global_position) < 20.0:
			_prey_toast_cooldown = 8.0
			var hud_node = get_tree().root.find_child("HUD", true, false)
			if hud_node and hud_node.has_method("show_toast"):
				hud_node.show_toast("Subject Zero spotted a %s—it's chasing it down instead of you!" % ("Crawler" if best_type == "crawler" else "Cultist"), Color(0.45, 0.95, 1.0))

func on_player_entered_locker(locker_node: Node3D) -> void:
	if not active or state == State.DORMANT or state == State.KILL:
		return
	hide_seek_locker = locker_node
	var corridor_pos: Vector3 = locker_node.global_position + locker_node.global_transform.basis.z * 2.8
	corridor_pos.y = global_position.y
	hide_seek_target = corridor_pos

	var dist = global_position.distance_to(locker_node.global_position)
	var has_los = _has_line_of_sight_to(locker_node.global_position + Vector3(0, 1.2, 0))

	if final_mode or (dist < 16.0 and has_los):
		saw_player_hide = (dist < 10.5 and has_los) or final_mode
		state = State.HIDE_SEEK
		hide_seek_timer = 3.8
	else:
		saw_player_hide = false
		state = State.ROAM
		_pick_roam_dir_away_from(locker_node.global_position)

func on_player_exited_locker() -> void:
	if not active or state == State.DORMANT or state == State.KILL:
		return
	if state == State.ROAM or state == State.HIDE_SEEK:
		state = State.CHASE

func _has_line_of_sight_to(target_pos: Vector3) -> bool:
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0, 1.6, 0),
		target_pos,
		1
	)
	var res = space_state.intersect_ray(query)
	return res.is_empty()

func _pick_roam_dir_away_from(pos: Vector3) -> void:
	var away = (global_position - pos)
	away.y = 0.0
	if away.length_squared() < 0.1:
		away = Vector3.FORWARD
	roam_dir = away.normalized().rotated(Vector3.UP, randf_range(-0.6, 0.6))
	roam_timer = randf_range(3.0, 5.5)

# Starts the 1.3s jumpscare execution matching HTML startKill & updateKill
func start_kill(style: String = "claw", reason: String = "HARVESTED BY SUBJECT ZERO — THE HUNTER CAUGHT YOU.") -> void:
	if state == State.KILL:
		return
	if player and player.get("god_mode"):
		return
	state = State.KILL
	kill_style = style
	kill_reason = reason
	kill_timer = 0.0
	kill_spike_triggered = false
	velocity = Vector3.ZERO

	if player and is_instance_valid(player):
		if player.get("is_hiding") and is_instance_valid(hide_seek_locker):
			# Pull player out of locker door to face Hunter
			var fwd_l = hide_seek_locker.global_transform.basis.z
			global_position = hide_seek_locker.global_position + fwd_l * 1.65
			global_position.y = 0.0
		else:
			# Place Hunter 1.65m in front of player along direction from player to Hunter
			var dir = global_position - player.global_position
			dir.y = 0.0
			if dir.length_squared() < 0.05:
				dir = -player.global_transform.basis.z
				dir.y = 0.0
			dir = dir.normalized()
			global_position = player.global_position + dir * 1.65
			global_position.y = player.global_position.y

		var to_p = player.global_position - global_position
		rotation.y = atan2(-to_p.x, -to_p.z)

		var hud_node = get_tree().root.find_child("HUD", true, false)
		if hud_node and hud_node.has_method("flash_damage"):
			hud_node.flash_damage()
		SoundEffects.play_hunter_screech()

		if player.has_method("start_death_sequence"):
			player.start_death_sequence(self, style, 1.3, func():
				player_caught.emit(kill_reason)
			)
		else:
			player_caught.emit(kill_reason)

# Full v7 anatomical horror rig ported from HTML buildMonster (lines 2292-2362)
func _build_hunter_mesh() -> void:
	mesh_root = Node3D.new()
	mesh_root.name = "HunterVisual"
	add_child(mesh_root)

	var skin_mat = StandardMaterial3D.new()
	skin_mat.albedo_color = Color(0.10, 0.05, 0.06)
	skin_mat.roughness = 0.42
	skin_mat.metallic = 0.08
	skin_mat.emission_enabled = true
	skin_mat.emission = Color(0.03, 0.0, 0.008)

	var wet_mat = StandardMaterial3D.new()
	wet_mat.albedo_color = Color(0.35, 0.03, 0.05)
	wet_mat.roughness = 0.16
	wet_mat.metallic = 0.15
	wet_mat.emission_enabled = true
	wet_mat.emission = Color(0.14, 0.008, 0.015)

	var bone_mat = StandardMaterial3D.new()
	bone_mat.albedo_color = Color(0.78, 0.72, 0.62)
	bone_mat.roughness = 0.50

	var dark_mat = StandardMaterial3D.new()
	dark_mat.albedo_color = Color(0.015, 0.004, 0.008)
	dark_mat.roughness = 0.95

	eye_mat = StandardMaterial3D.new()
	eye_mat.albedo_color = Color(1.0, 0.0, 0.09)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(1.0, 0.02, 0.06)
	eye_mat.emission_energy_multiplier = 4.2

	# Note: In Godot, -Z is forward, so we rotate the anatomical root by PI around Y
	# so all +Z features from the Three.js rig face -Z (forward toward the player)!
	var rig_align = Node3D.new()
	rig_align.rotation.y = PI
	mesh_root.add_child(rig_align)

	hips_node = Node3D.new()
	hips_node.position.y = 1.15
	rig_align.add_child(hips_node)

	var pelvis = MeshInstance3D.new()
	var pel_sph = SphereMesh.new()
	pel_sph.radius = 0.30
	pel_sph.height = 0.60
	pelvis.mesh = pel_sph
	pelvis.scale = Vector3(1.15, 0.7, 0.85)
	pelvis.material_override = skin_mat
	hips_node.add_child(pelvis)

	# --- SPINE & RIBCAGE ---
	spine_node = Node3D.new()
	spine_node.rotation.x = 0.62
	hips_node.add_child(spine_node)

	var gut = MeshInstance3D.new()
	var gut_cyl = CylinderMesh.new()
	gut_cyl.top_radius = 0.19
	gut_cyl.bottom_radius = 0.25
	gut_cyl.height = 0.55
	gut.mesh = gut_cyl
	gut.position.y = 0.26
	gut.material_override = skin_mat
	spine_node.add_child(gut)

	var chest = MeshInstance3D.new()
	var ch_sph = SphereMesh.new()
	ch_sph.radius = 0.44
	ch_sph.height = 0.88
	chest.mesh = ch_sph
	chest.scale = Vector3(1.15, 1.35, 0.82)
	chest.position = Vector3(0, 0.88, 0.04)
	chest.material_override = skin_mat
	spine_node.add_child(chest)

	# Hollow chest cavity
	var cav = MeshInstance3D.new()
	var cav_sph = SphereMesh.new()
	cav_sph.radius = 0.32
	cav_sph.height = 0.64
	cav.mesh = cav_sph
	cav.scale = Vector3(0.95, 1.2, 0.5)
	cav.position = Vector3(0, 0.86, 0.20)
	cav.material_override = dark_mat
	spine_node.add_child(cav)

	# 8 Curved Bone Ribs (Left & Right)
	for i in range(8):
		for s in [-1.0, 1.0]:
			var rib = MeshInstance3D.new()
			var r_tor = TorusMesh.new()
			var rad = 0.28 + sin((float(i) / 7.0) * PI) * 0.14
			r_tor.inner_radius = max(0.04, rad - 0.022)
			r_tor.outer_radius = rad + 0.022
			rib.mesh = r_tor
			rib.position = Vector3(s * 0.05, 0.48 + i * 0.095, 0.10)
			rib.rotation = Vector3(1.25, s * 0.25, 0.0)
			rib.material_override = bone_mat
			spine_node.add_child(rib)

	# 9 Dorsal Spine Spikes
	for i in range(9):
		var sp = MeshInstance3D.new()
		var sp_cone = CylinderMesh.new()
		sp_cone.top_radius = 0.0
		sp_cone.bottom_radius = 0.045
		sp_cone.height = 0.28 + (i % 2) * 0.10
		sp.mesh = sp_cone
		sp.position = Vector3(0, 0.22 + i * 0.13, -0.22 - sin(i * 0.3) * 0.08)
		sp.rotation.x = -1.15
		sp.material_override = bone_mat
		spine_node.add_child(sp)

	# 4 Open Glistening Flesh Wounds on Torso
	for i in range(4):
		var w = MeshInstance3D.new()
		var w_sph = SphereMesh.new()
		w_sph.radius = 0.11
		w_sph.height = 0.22
		w.mesh = w_sph
		var side_w = 1.0 if (i % 2 == 1) else -1.0
		w.position = Vector3(side_w * (0.18 + i * 0.03), 0.55 + i * 0.18, 0.24)
		w.scale = Vector3(1.2, 0.6, 0.5)
		w.material_override = wet_mat
		spine_node.add_child(w)

	# --- NECK, SKULL, JAW, 24 TEETH, 7 EYES, 5 HORNS & 8 TENDRILS ---
	neck_node = Node3D.new()
	neck_node.position = Vector3(0, 1.32, 0.18)
	neck_node.rotation.x = 0.52
	spine_node.add_child(neck_node)

	var neck_mesh = MeshInstance3D.new()
	var n_cyl = CylinderMesh.new()
	n_cyl.top_radius = 0.13
	n_cyl.bottom_radius = 0.17
	n_cyl.height = 0.45
	neck_mesh.mesh = n_cyl
	neck_mesh.position.y = 0.18
	neck_mesh.material_override = skin_mat
	neck_node.add_child(neck_mesh)

	head_node = Node3D.new()
	head_node.position = Vector3(0, 0.38, 0.12)
	head_node.rotation.x = -0.75
	neck_node.add_child(head_node)

	var skull = MeshInstance3D.new()
	var sk_sph = SphereMesh.new()
	sk_sph.radius = 0.29
	sk_sph.height = 0.58
	skull.mesh = sk_sph
	skull.scale = Vector3(0.88, 1.15, 1.35)
	skull.material_override = skin_mat
	head_node.add_child(skull)

	var gum = MeshInstance3D.new()
	var gum_sph = SphereMesh.new()
	gum_sph.radius = 0.20
	gum_sph.height = 0.40
	gum.mesh = gum_sph
	gum.position = Vector3(0, -0.06, 0.18)
	gum.material_override = wet_mat
	head_node.add_child(gum)

	jaw_node = Node3D.new()
	jaw_node.position = Vector3(0, -0.10, 0.05)
	jaw_node.rotation.x = 0.48
	head_node.add_child(jaw_node)

	var jaw_m = MeshInstance3D.new()
	var jm_box = BoxMesh.new()
	jm_box.size = Vector3(0.32, 0.13, 0.44)
	jaw_m.mesh = jm_box
	jaw_m.position = Vector3(0, -0.05, 0.16)
	jaw_m.material_override = skin_mat
	jaw_node.add_child(jaw_m)

	# 24 Jagged Bone Teeth (12 Upper + 12 Lower)
	for i in range(12):
		var a = -0.85 + (float(i) / 11.0) * 1.7
		var tx = sin(a) * 0.14
		var tz = 0.15 + cos(a) * 0.22
		var len_t = 0.08 + (1 if (i % 3 == 0) else 0) * 0.05

		var t_up = MeshInstance3D.new()
		var tu_cone = CylinderMesh.new()
		tu_cone.top_radius = 0.0
		tu_cone.bottom_radius = 0.017
		tu_cone.height = len_t
		t_up.mesh = tu_cone
		t_up.position = Vector3(tx, -0.11, tz)
		t_up.rotation.x = PI
		t_up.material_override = bone_mat
		head_node.add_child(t_up)

		var t_lo = MeshInstance3D.new()
		var tl_cone = CylinderMesh.new()
		tl_cone.top_radius = 0.0
		tl_cone.bottom_radius = 0.015
		tl_cone.height = len_t * 0.9
		t_lo.mesh = tl_cone
		t_lo.position = Vector3(tx, 0.02, tz - 0.04)
		t_lo.material_override = bone_mat
		jaw_node.add_child(t_lo)

	# 7 Asymmetric Glowing Red Eyes in Deep Pitch-Black Sockets
	var eye_layout = [
		[-0.12, 0.05, 0.34, 0.040],
		[0.12, 0.05, 0.34, 0.040],
		[-0.19, 0.14, 0.26, 0.026],
		[0.19, 0.14, 0.26, 0.026],
		[-0.07, 0.19, 0.30, 0.022],
		[0.08, 0.18, 0.31, 0.020],
		[0.0, 0.11, 0.36, 0.028]
	]
	for el in eye_layout:
		var ex: float = el[0]
		var ey: float = el[1]
		var ez: float = el[2]
		var er: float = el[3]

		var sock = MeshInstance3D.new()
		var s_sph = SphereMesh.new()
		s_sph.radius = er * 1.45
		s_sph.height = er * 2.9
		sock.mesh = s_sph
		sock.position = Vector3(ex, ey, ez - 0.015)
		sock.material_override = dark_mat
		head_node.add_child(sock)

		var eye = MeshInstance3D.new()
		var e_sph = SphereMesh.new()
		e_sph.radius = er
		e_sph.height = er * 2.0
		eye.mesh = e_sph
		eye.position = Vector3(ex, ey, ez)
		eye.material_override = eye_mat
		head_node.add_child(eye)
		eye_meshes.append(eye)

	# 5 Jagged Bone Crown Horns
	for i in range(5):
		var s = float(i) - 2.0
		var horn = MeshInstance3D.new()
		var h_cone = CylinderMesh.new()
		h_cone.top_radius = 0.0
		h_cone.bottom_radius = 0.045
		h_cone.height = 0.42 + (2.0 - abs(s)) * 0.12
		horn.mesh = h_cone
		horn.position = Vector3(s * 0.09, 0.26, -0.05 - abs(s) * 0.04)
		horn.rotation = Vector3(-0.55 - abs(s) * 0.15, 0.0, -s * 0.28)
		horn.material_override = bone_mat
		head_node.add_child(horn)

	# 8 Writhing Head Tendrils
	for i in range(8):
		var td = Node3D.new()
		td.position = Vector3((float(i) - 3.5) * 0.06, -0.05 + (i % 3) * 0.08, -0.22)
		var seg = MeshInstance3D.new()
		var sg_cyl = CylinderMesh.new()
		sg_cyl.top_radius = 0.008
		sg_cyl.bottom_radius = 0.025
		sg_cyl.height = 0.55 + (i % 3) * 0.18
		seg.mesh = sg_cyl
		seg.position.y = -0.28
		seg.material_override = wet_mat if (i % 2 == 1) else skin_mat
		td.add_child(seg)
		head_node.add_child(td)
		tendrils.append(td)

	# --- 2 LONG DRAGGING MULTI-JOINTED ARMS WITH 4 CLAWED FINGERS EACH ---
	for side in [-1.0, 1.0]:
		var sh = Node3D.new()
		sh.position = Vector3(side * 0.52, 1.12, 0.08)
		spine_node.add_child(sh)

		var sh_ball = MeshInstance3D.new()
		var sb_sph = SphereMesh.new()
		sb_sph.radius = 0.19
		sb_sph.height = 0.38
		sh_ball.mesh = sb_sph
		sh_ball.scale = Vector3(1.2, 0.9, 1.0)
		sh_ball.material_override = skin_mat
		sh.add_child(sh_ball)

		for k in range(2):
			var p_spike = MeshInstance3D.new()
			var ps_cone = CylinderMesh.new()
			ps_spike_setup(ps_cone, 0.04, 0.28 + k * 0.08)
			p_spike.mesh = ps_cone
			p_spike.position = Vector3(side * (0.08 + k * 0.07), 0.16, -0.04 * k)
			p_spike.rotation.z = -side * (0.55 + k * 0.25)
			p_spike.material_override = bone_mat
			sh.add_child(p_spike)

		var u_arm = MeshInstance3D.new()
		var ua_cyl = CylinderMesh.new()
		ua_cyl.top_radius = 0.095
		ua_cyl.bottom_radius = 0.13
		ua_cyl.height = 0.95
		u_arm.mesh = ua_cyl
		u_arm.position.y = -0.46
		u_arm.material_override = skin_mat
		sh.add_child(u_arm)

		var elb = Node3D.new()
		elb.position.y = -0.92
		elb.rotation.x = -0.55
		sh.add_child(elb)

		var e_spur = MeshInstance3D.new()
		var es_cone = CylinderMesh.new()
		ps_spike_setup(es_cone, 0.035, 0.26)
		e_spur.mesh = es_cone
		e_spur.position = Vector3(0, 0, -0.12)
		e_spur.rotation.x = -2.2
		e_spur.material_override = bone_mat
		elb.add_child(e_spur)

		var f_arm = MeshInstance3D.new()
		var fa_cyl = CylinderMesh.new()
		fa_cyl.top_radius = 0.065
		fa_cyl.bottom_radius = 0.095
		fa_cyl.height = 1.05
		f_arm.mesh = fa_cyl
		f_arm.position.y = -0.50
		f_arm.material_override = skin_mat
		elb.add_child(f_arm)

		var hand = Node3D.new()
		hand.position.y = -1.02
		elb.add_child(hand)

		for f in range(4):
			var fg = Node3D.new()
			fg.position = Vector3((float(f) - 1.5) * 0.048, 0, 0.02)
			fg.rotation = Vector3(0.35, 0.0, (float(f) - 1.5) * 0.12)

			var ph = MeshInstance3D.new()
			var ph_cyl = CylinderMesh.new()
			ph_cyl.top_radius = 0.012
			ph_cyl.bottom_radius = 0.018
			ph_cyl.height = 0.22
			ph.mesh = ph_cyl
			ph.position.y = -0.11
			ph.material_override = bone_mat
			fg.add_child(ph)

			var cl = MeshInstance3D.new()
			var cl_cone = CylinderMesh.new()
			ps_spike_setup(cl_cone, 0.022, 0.36)
			cl.mesh = cl_cone
			cl.position = Vector3(0, -0.34, 0.05)
			cl.rotation.x = PI + 0.38
			cl.material_override = bone_mat
			fg.add_child(cl)

			hand.add_child(fg)

		arms_data.append({"sh": sh, "elb": elb, "hand": hand, "s": side})

	# --- 4 DORSAL SPIDER LIMBS SPROUTING FROM BACK ---
	for row in range(2):
		for side in [-1.0, 1.0]:
			var b_hip = Node3D.new()
			b_hip.position = Vector3(side * 0.28, 0.78 + row * 0.30, -0.18)
			b_hip.rotation = Vector3(-0.3 + row * 0.2, 0.0, -side * (0.85 + row * 0.22))

			var b_seg1 = MeshInstance3D.new()
			var bs1_cyl = CylinderMesh.new()
			bs1_cyl.top_radius = 0.028
			bs1_cyl.bottom_radius = 0.045
			bs1_cyl.height = 0.78
			b_seg1.mesh = bs1_cyl
			b_seg1.position.y = 0.38
			b_seg1.material_override = skin_mat
			b_hip.add_child(b_seg1)

			var b_knee = Node3D.new()
			b_knee.position.y = 0.76
			b_knee.rotation.z = -side * 1.35
			b_hip.add_child(b_knee)

			var b_tip = MeshInstance3D.new()
			var bt_cone = CylinderMesh.new()
			ps_spike_setup(bt_cone, 0.032, 0.95)
			b_tip.mesh = bt_cone
			b_tip.position.y = 0.46
			b_tip.material_override = bone_mat
			b_knee.add_child(b_tip)

			spine_node.add_child(b_hip)
			spiders_data.append({"hip": b_hip, "shin": b_knee, "s": side, "row": row})

	# --- 2 DIGITIGRADE LEGS WITH 3-TOED BONE TALONS ---
	for side in [-1.0, 1.0]:
		var hip = Node3D.new()
		hip.position = Vector3(side * 0.27, 0.0, 0.0)
		hips_node.add_child(hip)

		var thigh = MeshInstance3D.new()
		var th_cyl = CylinderMesh.new()
		th_cyl.top_radius = 0.12
		th_cyl.bottom_radius = 0.165
		th_cyl.height = 0.65
		thigh.mesh = th_cyl
		thigh.position = Vector3(0, -0.28, 0.10)
		thigh.rotation.x = -0.50
		thigh.material_override = skin_mat
		hip.add_child(thigh)

		var knee = Node3D.new()
		knee.position = Vector3(0, -0.54, 0.24)
		hip.add_child(knee)

		var shin = MeshInstance3D.new()
		var sh_cyl = CylinderMesh.new()
		sh_cyl.top_radius = 0.07
		sh_cyl.bottom_radius = 0.105
		sh_cyl.height = 0.68
		shin.mesh = sh_cyl
		shin.position = Vector3(0, -0.28, -0.14)
		shin.rotation.x = 0.55
		shin.material_override = skin_mat
		knee.add_child(shin)

		for t in range(3):
			var talon = MeshInstance3D.new()
			var tl_cone = CylinderMesh.new()
			ps_spike_setup(tl_cone, 0.028, 0.26)
			talon.mesh = tl_cone
			talon.position = Vector3((float(t) - 1.0) * 0.075, -0.58, -0.15)
			talon.rotation.x = PI * 0.55
			talon.material_override = bone_mat
			knee.add_child(talon)

		legs_data.append({"hip": hip, "knee": knee, "s": side})

	# --- IMPALING KILL SPIKE (shoots into camera during start_kill) ---
	kill_spike = Node3D.new()
	kill_spike.visible = false
	kill_spike.position = Vector3(0, 1.52, -0.35)
	mesh_root.add_child(kill_spike)

	var ks_cone = MeshInstance3D.new()
	var ksc = CylinderMesh.new()
	ps_spike_setup(ksc, 0.09, 1.65)
	ks_cone.mesh = ksc
	ks_cone.rotation.x = -PI * 0.5
	ks_cone.position.z = -0.82
	ks_cone.material_override = bone_mat
	kill_spike.add_child(ks_cone)

	eye_light = OmniLight3D.new()
	eye_light.light_color = Color(1.0, 0.08, 0.04)
	eye_light.light_energy = 2.4
	eye_light.omni_range = 10.0
	eye_light.position = Vector3(0, 2.1, -0.55)
	mesh_root.add_child(eye_light)

func ps_spike_setup(cyl: CylinderMesh, bottom_r: float, h: float) -> void:
	cyl.top_radius = 0.0
	cyl.bottom_radius = bottom_r
	cyl.height = h

func _physics_process(delta: float) -> void:
	anim_time += delta
	_animate_mesh(anim_time)

	if _statue_reroute_toast_cd > 0.0:
		_statue_reroute_toast_cd = max(0.0, _statue_reroute_toast_cd - delta)
	if _prey_toast_cooldown > 0.0:
		_prey_toast_cooldown = max(0.0, _prey_toast_cooldown - delta)
	if cloak_repel_timer > 0.0:
		cloak_repel_timer = max(0.0, cloak_repel_timer - delta)

	if not active or state == State.DORMANT:
		return

	if state == State.KILL:
		_update_kill_sequence(delta)
		return

	if frozen_by_dev:
		velocity = Vector3.ZERO
		return

	if state == State.EXECUTE_PREY:
		execute_timer += delta
		velocity = Vector3.ZERO
		if is_instance_valid(prey_target):
			var to_prey = prey_target.global_position - global_position
			if Vector2(to_prey.x, to_prey.z).length_squared() > 0.001:
				rotation.y = lerp_angle(rotation.y, atan2(-to_prey.x, -to_prey.z), delta * 15.0)
		if execute_timer >= execute_duration:
			prey_target = null
			state = State.CHASE
			devour_pause_timer = 0.45
		return

	if devour_pause_timer > 0.0:
		devour_pause_timer -= delta
		velocity = Vector3.ZERO
		return

	if state == State.STUNNED:
		stun_timer -= delta
		velocity = Vector3.ZERO
		if stun_timer <= 0.0:
			state = State.ROAM if (player and (bool(player.get("is_hiding")) or bool(player.get("is_inside_cloak")))) else State.CHASE
		return

	if state == State.AMBUSH:
		ambush_timer -= delta
		velocity = Vector3.ZERO
		var player_turned_back := false
		if player and is_instance_valid(player) and player.get("camera"):
			var cam: Camera3D = player.get("camera")
			var cam_fwd = -cam.global_transform.basis.z
			var to_h = (global_position - cam.global_position).normalized()
			if cam_fwd.dot(to_h) < 0.12:
				player_turned_back = true
		if player_turned_back or ambush_timer <= 0.0:
			state = State.CHASE
			SoundEffects.play_hunter_screech()
			var hud_node = get_tree().root.find_child("HUD", true, false)
			if hud_node and hud_node.has_method("show_toast"):
				hud_node.show_toast("IT WAS PLAY-ACTING — BEHIND YOU!", Color(1.0, 0.2, 0.2))
		return

	if state == State.WINDUP:
		windup_timer -= delta
		velocity = Vector3.ZERO
		if player and is_instance_valid(player):
			var to_p = player.global_position - global_position
			rotation.y = lerp_angle(rotation.y, atan2(-to_p.x, -to_p.z), delta * 12.0)
			var dist_2d = Vector2(to_p.x, to_p.z).length()
			if windup_timer <= 0.0:
				if dist_2d <= 2.35 and not bool(player.get("is_hiding")) and not bool(player.get("is_inside_cloak")):
					start_kill("claw", "HARVESTED BY SUBJECT ZERO — YOU DID NOT BREAK LINE OF SIGHT.")
					return
				else:
					state = State.CHASE
		return

	# Pause pursuit while player is inside the Night 5 Secret Sanctuary Corridor
	if player and bool(player.get("in_secret_corridor")):
		velocity = Vector3.ZERO
		return

	# Scan for nearby Crawlers or Cultists to hunt & execute in real time (ignoring the player!)
	if (state == State.CHASE or state == State.ROAM) and cloak_repel_timer <= 0.0:
		_prey_scan_timer -= delta
		if _prey_scan_timer <= 0.0:
			_prey_scan_timer = 0.20
			_find_nearby_prey()

	if state == State.HUNT_PREY:
		if not is_instance_valid(prey_target) or bool(prey_target.get("is_dead")) or bool(prey_target.get("is_being_executed")):
			prey_target = null
			state = State.CHASE
		else:
			var to_prey = prey_target.global_position - global_position
			to_prey.y = 0.0
			var d_prey = to_prey.length()
			if d_prey > 16.5 or _is_inside_statue_fear_zone(prey_target.global_position.x, prey_target.global_position.z):
				prey_target = null
				state = State.CHASE
			elif d_prey <= 1.85:
				start_prey_execution(prey_target, prey_type)
				return
			else:
				# Real-time pursuit of prey monster (moves even when player stands still!)
				var hunt_dir = _steer_around_walls(to_prey.normalized())
				var hunt_spd = base_speed * 1.18
				var p_prev = global_position
				velocity.x = hunt_dir.x * hunt_spd
				velocity.z = hunt_dir.z * hunt_spd
				velocity.y = 0.0
				rotation.y = lerp_angle(rotation.y, atan2(-hunt_dir.x, -hunt_dir.z), delta * 11.0)
				move_and_slide()
				step_sound_accum += Vector2(global_position.x - p_prev.x, global_position.z - p_prev.z).length()
				if step_sound_accum >= 2.1:
					step_sound_accum = 0.0
					if player and global_position.distance_to(player.global_position) < 28.0:
						SoundEffects.play_heavy_step()
				return

	# Check if player is hiding in Locker or Cloak
	var player_hiding: bool = player != null and (bool(player.get("is_hiding")) or bool(player.get("is_inside_cloak")))
	if player_hiding and state == State.CHASE:
		state = State.ROAM
		_pick_roam_dir_away_from(global_position + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4)))
	elif not player_hiding and (state == State.ROAM or state == State.HIDE_SEEK) and cloak_repel_timer <= 0.0:
		state = State.CHASE

	# Check close-range catch / windup trigger even before checking step movement
	if state == State.CHASE and player and not player_hiding:
		var to_p = player.global_position - global_position
		var dist_2d = Vector2(to_p.x, to_p.z).length()
		var dy = abs(player.global_position.y - global_position.y)
		if dist_2d < 1.65 and dy < 2.3:
			if final_mode or overtime_rage:
				start_kill("claw", "HARVESTED BY SUBJECT ZERO — FINAL CONTAINMENT PROTOCOL.")
			else:
				state = State.WINDUP
				windup_timer = 0.42
				SoundEffects.play(SoundEffects.snd_growl, 2.0, 0.75)
			return

	# =========================================================================
	# SUPERHOT-STYLE STEP-LINKED MOVEMENT RULE (HTML updateHunter lines 2635-2641)
	# The Hunter ONLY advances when the player moves! When the player stands still,
	# the Hunter freezes its advance in place (except during HIDE_SEEK, HUNT_PREY, or Cloak repulsion).
	# =========================================================================
	var player_moved_dist: float = 0.0
	if player and is_instance_valid(player) and "last_frame_move_dist" in player:
		player_moved_dist = float(player.get("last_frame_move_dist"))

	if state != State.HIDE_SEEK and cloak_repel_timer <= 0.0 and player_moved_dist <= 0.0015 and not overtime_rage:
		velocity = Vector3.ZERO
		return

	var move_mult: float = GameData.HUNTER_MULT * (1.55 if overtime_rage else (1.20 if final_mode else 1.0))
	var budget: float = player_moved_dist * move_mult
	if cloak_repel_timer > 0.0 and budget < delta * 5.2:
		budget = max(budget, delta * 5.2)
	if overtime_rage and budget < delta * 6.5:
		# After 200 steps (0 steps left), Subject Zero enters Overtime Rage and closes any remaining gap relentlessly
		budget = max(budget, delta * 6.8)

	var prev_pos := global_position

	# Use exact BFS shortest path on the maze grid during CHASE!
	if state == State.CHASE and player and not maze_grid.is_empty():
		var adv_status := _advance_along_bfs_path(budget, 1.35, delta)
		if adv_status == "near":
			var dist_now = Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z).length()
			if dist_now <= 1.75 and abs(player.global_position.y - global_position.y) < 2.3:
				if final_mode or overtime_rage:
					start_kill("claw", "HARVESTED BY SUBJECT ZERO — THE ENTITY CLOSED THE GAP.")
					return
				else:
					state = State.WINDUP
					windup_timer = 0.42
					SoundEffects.play(SoundEffects.snd_growl, 2.0, 0.75)
					return
		var bfs_step = Vector2(global_position.x - prev_pos.x, global_position.z - prev_pos.z).length()
		step_sound_accum += bfs_step
		if step_sound_accum >= 2.1:
			step_sound_accum = 0.0
			if player and global_position.distance_to(player.global_position) < 28.0:
				SoundEffects.play_heavy_step()
		return

	var desired_dir := Vector3.ZERO
	var frame_speed: float = (budget / max(delta, 0.001))
	frame_speed = clampf(frame_speed, 0.0, base_speed * 2.2)

	# Repulsion from Stone Statues (STATUE_FEAR_RADIUS = 9.0m in HTML)
	var statue_repel := Vector3.ZERO
	if not final_mode:
		for st in get_tree().get_nodes_in_group("statues"):
			if st and st.get("active"):
				var diff = global_position - st.global_position
				diff.y = 0.0
				var d = diff.length()
				if d < GameData.STATUE_FEAR_RADIUS and d > 0.01:
					statue_repel += diff.normalized() * ((GameData.STATUE_FEAR_RADIUS - d) / GameData.STATUE_FEAR_RADIUS) * 2.2

	if state == State.HIDE_SEEK:
		frame_speed = base_speed * 0.95
		var to_target = hide_seek_target - global_position
		to_target.y = 0.0
		if to_target.length() > 1.2:
			desired_dir = to_target.normalized()
		else:
			hide_seek_timer -= delta
			rotation.y += sin(anim_time * 3.5) * delta * 2.2
			if hide_seek_timer <= 0.0:
				if saw_player_hide and player_hiding:
					start_kill("locker", "IT WATCHED YOU HIDE — THE LOCKER DOOR WAS TORN OFF ITS HINGES.")
					return
				else:
					state = State.ROAM
					if is_instance_valid(hide_seek_locker):
						_pick_roam_dir_away_from(hide_seek_locker.global_position)
					else:
						_pick_roam_dir_away_from(global_position)

	elif state == State.ROAM:
		roam_timer -= delta
		if roam_timer <= 0.0:
			var dirs = [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]
			roam_dir = dirs[randi() % dirs.size()].rotated(Vector3.UP, randf_range(-0.4, 0.4)).normalized()
			roam_timer = randf_range(2.5, 4.8)
		desired_dir = roam_dir
		frame_speed *= 0.85

	elif state == State.CHASE and player:
		var to_player = player.global_position - global_position
		to_player.y = 0.0
		if to_player.length_squared() > 0.001:
			desired_dir = to_player.normalized()

	if statue_repel.length_squared() > 0.01:
		desired_dir = (desired_dir + statue_repel).normalized()

	if desired_dir.length_squared() > 0.01 and frame_speed > 0.01:
		desired_dir = _steer_around_walls(desired_dir)
		velocity.x = desired_dir.x * frame_speed
		velocity.z = desired_dir.z * frame_speed
		var target_yaw = atan2(-desired_dir.x, -desired_dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, delta * 9.0)
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	velocity.y = 0.0
	move_and_slide()
	var actual_step = Vector2(global_position.x - prev_pos.x, global_position.z - prev_pos.z).length()

	if get_slide_collision_count() > 0 and state == State.ROAM:
		roam_dir = roam_dir.rotated(Vector3.UP, PI * 0.55)

	# Heavy footsteps audio linked to actual distance moved
	step_sound_accum += actual_step
	if step_sound_accum >= 2.1:
		step_sound_accum = 0.0
		if player and global_position.distance_to(player.global_position) < 28.0:
			SoundEffects.play_heavy_step()

func _update_kill_sequence(delta: float) -> void:
	kill_timer += delta
	var t = kill_timer
	if t > 0.35 and not kill_spike_triggered:
		kill_spike_triggered = true
		if kill_spike:
			kill_spike.visible = true
		SoundEffects.play_Wet_Squish()
		var hud_node = get_tree().root.find_child("HUD", true, false)
		if hud_node and hud_node.has_method("flash_damage"):
			hud_node.flash_damage()
	if kill_spike and kill_spike.visible:
		var prog = min(1.0, (t - 0.35) / 0.14)
		kill_spike.scale = Vector3(1.0, 1.0, 0.2 + prog * 1.45)

func _steer_around_walls(dir: Vector3) -> Vector3:
	var space_state = get_world_3d().direct_space_state
	var origin = global_position + Vector3(0, 1.0, 0)
	var q_front = PhysicsRayQueryParameters3D.create(origin, origin + dir * 2.1, 1)
	if space_state.intersect_ray(q_front).is_empty():
		return dir

	var best_dir := dir
	for angle_deg in [35.0, -35.0, 65.0, -65.0, 95.0, -95.0]:
		var cand = dir.rotated(Vector3.UP, deg_to_rad(angle_deg))
		var q = PhysicsRayQueryParameters3D.create(origin, origin + cand * 2.4, 1)
		if space_state.intersect_ray(q).is_empty():
			return cand
	return best_dir

# Procedural anatomical animation ported from HTML animateMonster(t) (lines 2368-2396)
func _animate_mesh(t: float) -> void:
	if not hips_node or not spine_node:
		return

	var is_moving := velocity.length_squared() > 0.15
	var chase_mode := active and state != State.DORMANT
	var stun_pose := (state == State.STUNNED or state == State.AMBUSH)
	var wind_pose := (state == State.WINDUP)
	var kill_pose := (state == State.KILL)
	var exec_pose := (state == State.EXECUTE_PREY)
	var w = (8.5 if is_moving else 3.2) if chase_mode else 1.8

	# Update eye glow color based on state
	if eye_mat:
		if stun_pose:
			eye_mat.albedo_color = Color(0.22, 0.0, 0.03)
			eye_mat.emission_energy_multiplier = 0.5
		elif final_mode or kill_pose or exec_pose:
			eye_mat.albedo_color = Color(1.0, 0.15, 0.05)
			eye_mat.emission_energy_multiplier = 5.5
		else:
			eye_mat.albedo_color = Color(1.0, 0.0, 0.09)
			eye_mat.emission_energy_multiplier = 4.0

	if exec_pose and prey_type == "crawler":
		var smash_p = clampf((execute_timer - 0.45) / 0.12, 0.0, 1.0)
		hips_node.position.y = lerpf(1.22, 0.65, smash_p)
		hips_node.rotation.z = 0.0
	else:
		hips_node.position.y = 0.72 if stun_pose else (1.12 + abs(sin(t * w)) * (0.14 if is_moving else 0.03))
		hips_node.rotation.z = sin(t * w) * (0.09 if is_moving else 0.02)

	if stun_pose:
		spine_node.rotation.x = 1.15 + sin(t * 2.0) * 0.05
		spine_node.rotation.z = sin(t * 1.5) * 0.12
		neck_node.rotation.x = 0.90
		head_node.rotation.x = -0.35
		head_node.rotation.y = sin(t * 7.0) * 0.18
		jaw_node.rotation.x = 0.15
	elif exec_pose:
		if prey_type == "crawler":
			# Raise high then slam torso down to crush Crawler at t = 0.52s
			var smash_p = clampf((execute_timer - 0.45) / 0.12, 0.0, 1.0)
			spine_node.rotation.x = lerpf(0.12, 1.28, smash_p)
			spine_node.rotation.z = 0.0
			neck_node.rotation.x = lerpf(0.20, 0.75, smash_p)
			head_node.rotation.x = lerpf(-0.45, -0.15, smash_p)
			jaw_node.rotation.x = 1.05
		else:
			# Hoisting Cultist by throat, then snapping neck at t = 0.82s
			var snap_p = clampf((execute_timer - 0.78) / 0.10, 0.0, 1.0)
			spine_node.rotation.x = 0.35 + snap_p * 0.18
			spine_node.rotation.z = -0.12 * snap_p
			neck_node.rotation.x = 0.38
			head_node.rotation.x = -0.42
			head_node.rotation.z = 0.28 * snap_p
			jaw_node.rotation.x = 0.95
	elif wind_pose:
		spine_node.rotation.x = 0.25
		neck_node.rotation.x = 0.30
		head_node.rotation.x = -0.35
		jaw_node.rotation.x = 0.95
	elif kill_pose:
		spine_node.rotation.x = 0.38
		neck_node.rotation.x = 0.35
		head_node.rotation.x = -0.45
		head_node.rotation.z = sin(t * 24.0) * 0.18
		jaw_node.rotation.x = 1.05
	else:
		spine_node.rotation.x = 0.62 + sin(t * 2.1) * 0.06 + (0.18 if is_moving else 0.0)
		spine_node.rotation.z = sin(t * w * 0.5) * 0.08
		neck_node.rotation.x = 0.52 + sin(t * 3.1) * 0.10
		neck_node.rotation.y = sin(t * 1.7) * 0.22 + (0.35 if sin(t * 11.3) > 0.92 else 0.0)
		head_node.rotation.x = -0.75 + sin(t * 2.7) * 0.08
		head_node.rotation.z = (0.38 if sin(t * 19.0) > 0.93 else sin(t * 1.3) * 0.10)
		jaw_node.rotation.x = 0.35 + abs(sin(t * (5.5 if chase_mode else 1.8))) * (0.55 if chase_mode else 0.22)

	for a in arms_data:
		var sh: Node3D = a["sh"]
		var elb: Node3D = a["elb"]
		var hand: Node3D = a["hand"]
		var s: float = a["s"]
		var ph = 0.0 if s > 0.0 else PI
		if stun_pose:
			sh.rotation.x = 0.6
			sh.rotation.z = s * 0.15
			elb.rotation.x = -0.2
		elif exec_pose:
			if prey_type == "crawler":
				# Two-handed overhead smash into floor
				var smash_p = clampf((execute_timer - 0.45) / 0.12, 0.0, 1.0)
				sh.rotation.x = lerpf(-2.25, 0.92, smash_p)
				sh.rotation.z = s * lerpf(0.55, 0.12, smash_p)
				elb.rotation.x = lerpf(-0.85, -0.18, smash_p)
			else:
				# Left arm (s < 0) lifts Cultist by throat; Right arm (s > 0) wrenches neck at t = 0.82s
				var lift_p = clampf(execute_timer / 0.55, 0.0, 1.0)
				var snap_p = clampf((execute_timer - 0.78) / 0.10, 0.0, 1.0)
				if s < 0.0:
					sh.rotation.x = lerpf(-0.65, -1.42, lift_p)
					sh.rotation.z = -0.15
					elb.rotation.x = -0.35
				else:
					sh.rotation.x = lerpf(-1.55, -0.82, snap_p)
					sh.rotation.z = lerpf(0.85, -0.58, snap_p)
					elb.rotation.x = lerpf(-0.95, -0.25, snap_p)
					hand.rotation.z = 1.25 * snap_p
		elif wind_pose:
			sh.rotation.x = -1.65
			sh.rotation.z = s * 0.70
			elb.rotation.x = -0.95
		elif kill_pose:
			var slash = min(1.0, max(0.0, (kill_timer - 0.18) * 4.5))
			sh.rotation.x = lerpf(-1.7, 0.85, slash)
			sh.rotation.z = s * lerpf(0.75, 0.15, slash)
			elb.rotation.x = lerpf(-0.95, -0.25, slash)
		else:
			sh.rotation.x = -0.35 + sin(t * w + ph) * (0.75 if is_moving else 0.18)
			sh.rotation.z = s * (0.28 + abs(cos(t * w * 0.5)) * 0.18)
			elb.rotation.x = -0.65 - abs(sin(t * w + ph)) * 0.55
			hand.rotation.x = sin(t * 6.0 + s) * 0.30

	for l in legs_data:
		var hip: Node3D = l["hip"]
		var knee: Node3D = l["knee"]
		var s: float = l["s"]
		var ph = PI if s > 0.0 else 0.0
		var sw = (sin(t * w + ph) * 0.65) if (is_moving and not stun_pose) else 0.0
		hip.rotation.x = sw
		knee.rotation.x = max(0.0, -sw * 0.9)

	for i in range(spiders_data.size()):
		var sp = spiders_data[i]
		var b_hip: Node3D = sp["hip"]
		var b_shin: Node3D = sp["shin"]
		var s: float = sp["s"]
		var row: int = sp["row"]
		b_hip.rotation.y = sin(t * 4.5 + i * 1.4) * 0.40
		b_hip.rotation.z = -s * (0.85 + row * 0.22 + sin(t * 5.2 + i) * 0.25)
		b_shin.rotation.z = -s * (1.35 + cos(t * 6.0 + i) * 0.30)

	for i in range(tendrils.size()):
		var td = tendrils[i]
		td.rotation.x = 0.3 + sin(t * 5.0 + i * 0.9) * 0.35
		td.rotation.z = cos(t * 4.2 + i * 1.3) * 0.28
