extends Node3D

enum Phase { WORK, CHASE }

const HunterScript = preload("res://scripts/hunter.gd")
const StatueScript = preload("res://scripts/statue.gd")
const CrawlerScript = preload("res://scripts/crawler.gd")
const CultistScript = preload("res://scripts/cultist.gd")
const CloakScript = preload("res://scripts/cloak.gd")
const HangerScript = preload("res://scripts/hanger.gd")
const RemotePlayerScript = preload("res://scripts/remote_player.gd")
const LightEaterScript = preload("res://scripts/light_eater.gd")
const PlayerCorpseScript = preload("res://scripts/player_corpse.gd")

var current_day: int = 1
var selected_map_index: int = -1
var current_phase: Phase = Phase.WORK
var remote_players: Dictionary = {} # peer_id -> RemotePlayer node
var mp_net_sync_timer: float = 0.0
var player_still_timer: float = 0.0
var is_spectating: bool = false
var spectate_target_idx: int = 0
var spawned_corpses: Array = []

var NetworkManager: Node:
	get:
		return get_node_or_null("/root/NetworkManager")

var spills_cleaned: int = 0
var spills_total: int = 3
var blood_cleaned: int = 0
var blood_total: int = 3
var terminals_checked: int = 0
var terminals_total: int = 2
var relics_collected: int = 0
var total_relics_career: int = 0
var wages: int = 0

var keycards_collected: int = 0
var keycards_total: int = 3
var chase_distance: int = 200
var max_chase_distance: int = 200

var crawler_bites: int = 0

# Floor 2 Event Shift Tasks (Night 3+)
var f2_terminals_done: int = 0
var f2_terminals_needed: int = 0
var f2_has_usb: bool = false
var f2_usb_done: bool = false
var f2_has_dossier: bool = false
var f2_dossier_done: bool = false
var f2_has_coolant: bool = false
var f2_coolant_done: bool = false
var mop_integrity: float = 100.0
var bait_count: int = 3
var active_bait_node: Node3D = null
var active_bait_timer: float = 0.0
var override_cooldown: float = 0.0
var heartbeat_timer: float = 0.0
var quit_attempts: int = 0
var pedestals_sealed: int = 0
var _exit_block_cooldown: float = 0.0

@onready var map_gen: Node3D = $MapGenerator
@onready var player: CharacterBody3D = $Player
@onready var hud: CanvasLayer = $HUD
@onready var entities: Node3D = $Entities

var hunter: CharacterBody3D = null
var statues: Array[CharacterBody3D] = []
var crawlers: Array[CharacterBody3D] = []
var cultists: Array[CharacterBody3D] = []
var cloaks: Array[CharacterBody3D] = []
var hangers: Array[CharacterBody3D] = []
var light_eater: CharacterBody3D = null
var f2_walkways_cached: Array = []
var open_spawn_cells: Array[Vector3] = []
var maze_grid: Array = []
var is_game_over: bool = false

var dev_god_mode: bool = false
var dev_freeze_entity: bool = false
var dev_noclip: bool = false
var dev_show_steps_hud: bool = false
var dev_panel_visible: bool = false
var _dev_ever_opened: bool = false

func _ready() -> void:
	hud.start_game_clicked.connect(_on_start_shift)
	hud.pause_resumed.connect(_resume_from_pause)
	hud.quit_to_menu.connect(_handle_quit_attempt)
	hud.game_over_to_menu.connect(_quit_to_menu)
	hud.quit_modal_dismissed.connect(_on_quit_modal_dismissed)
	hud.retry_clicked.connect(_on_retry_night)
	hud.victory_finish_clicked.connect(_quit_to_menu)
	hud.override_completed.connect(_on_override_completed)

	# Connect Multiplayer signals from HUD
	hud.mp_host_room_requested.connect(_on_mp_host_room)
	hud.mp_join_room_requested.connect(_on_mp_join_room)
	hud.mp_join_code_requested.connect(_on_mp_join_code)
	hud.mp_quick_join_requested.connect(_on_mp_quick_join)
	hud.mp_start_shift_requested.connect(_on_mp_start_shift)
	hud.mp_leave_room_requested.connect(_on_mp_leave_room)
	hud.mp_toggle_ready_requested.connect(_on_mp_toggle_ready)

	# Connect NetworkManager signals
	if NetworkManager:
		NetworkManager.room_code_ready.connect(func(code): hud.update_lobby_room_code(code))
		NetworkManager.room_list_updated.connect(func(rooms): hud.update_room_browser(rooms))
		NetworkManager.client_connected_to_host.connect(_on_client_connected_to_host)
		NetworkManager.connection_failed.connect(_on_mp_connection_failed)
		NetworkManager.server_disconnected_signal.connect(_on_mp_server_disconnected)
		NetworkManager.lobby_updated.connect(func(players): hud.update_mp_lobby(players, NetworkManager.is_host))
		NetworkManager.game_started_signal.connect(_on_mp_game_started)
		NetworkManager.remote_player_state_updated.connect(_on_remote_player_state_updated)
		NetworkManager.remote_player_action_received.connect(_on_remote_player_action_received)
		NetworkManager.remote_spill_cleaned.connect(_on_remote_spill_cleaned)
		NetworkManager.remote_terminal_checked.connect(_on_remote_terminal_checked)
		NetworkManager.remote_keycard_collected.connect(_on_remote_keycard_collected)
		NetworkManager.remote_chase_triggered.connect(_on_remote_chase_triggered)
		NetworkManager.leaderboard_summary_displayed.connect(_on_leaderboard_summary_displayed)
		NetworkManager.chat_message_received.connect(func(sender, msg, is_sys):
			hud.add_chat_message(sender, msg, is_sys)
		)
		NetworkManager.player_died_signal.connect(_on_remote_player_died)
		NetworkManager.all_players_eliminated_signal.connect(_on_all_players_eliminated)
		NetworkManager.round_restarted_signal.connect(_on_mp_round_restarted)
		NetworkManager.return_to_lobby_signal.connect(_on_return_to_lobby)

	map_gen.spill_cleaned.connect(_on_spill_cleaned)
	map_gen.terminal_checked.connect(_on_terminal_checked)
	map_gen.relic_collected.connect(_on_relic_collected)
	map_gen.keycard_collected.connect(_on_keycard_collected)
	map_gen.exit_reached.connect(_on_exit_reached)
	map_gen.note_inspected.connect(_on_note_inspected)
	map_gen.gate_toggled.connect(func(_closed): _refresh_minimap())
	map_gen.secret_corridor_state_changed.connect(_on_secret_corridor_state_changed)
	map_gen.pedestal_activated.connect(_on_pedestal_activated)

	# Connect Floor 2 Lab event signals (Night 3+)
	map_gen.f2_terminal_shutdown.connect(func(done, _total):
		f2_terminals_done = done
		wages += 25
		_update_hud_objectives()
		_check_work_complete()
	)
	map_gen.f2_usb_picked_up.connect(func():
		f2_has_usb = true
		hud.show_toast("📦 [USB ACQUIRED] Deliver to [SECTION A-1 VAULT] in Central Hub (West)!", Color(0.2, 0.9, 1.0), 5.0)
		_update_hud_objectives()
	)
	map_gen.f2_usb_deposited.connect(func():
		f2_has_usb = false
		f2_usb_done = true
		wages += 35
		hud.show_toast("✔ [SECTION A-1] Encrypted USB Archived into Vault! (+$35)", Color(0.25, 0.95, 0.4))
		_update_hud_objectives()
		_check_work_complete()
	)
	map_gen.f2_dossier_picked_up.connect(func():
		f2_has_dossier = true
		hud.show_toast("📁 [DOSSIER ACQUIRED] File in [SECTION B-1 ARCHIVE] in Central Hub (East)!", Color(1.0, 0.85, 0.2), 5.0)
		_update_hud_objectives()
	)
	map_gen.f2_dossier_archived.connect(func():
		f2_has_dossier = false
		f2_dossier_done = true
		wages += 35
		hud.show_toast("✔ [SECTION B-1] Classified Dossier Filed into Archive! (+$35)", Color(0.25, 0.95, 0.4))
		_update_hud_objectives()
		_check_work_complete()
	)
	map_gen.f2_coolant_picked_up.connect(func():
		f2_has_coolant = true
		hud.show_toast("❄ [COOLANT ACQUIRED] Inject into [SECTION C-1 SERVER] in Central Hub (NE)!", Color(0.3, 0.95, 1.0), 5.0)
		_update_hud_objectives()
	)
	map_gen.f2_coolant_injected.connect(func():
		f2_has_coolant = false
		f2_coolant_done = true
		wages += 35
		hud.show_toast("✔ [SECTION C-1] Server Cooled to 18°C! (+$35)", Color(0.25, 0.95, 0.4))
		_update_hud_objectives()
		_check_work_complete()
	)

	player.step_taken.connect(_on_player_step_taken)
	player.locker_state_changed.connect(_on_player_locker_state_changed)
	player.mop_strike_requested.connect(_on_player_mop_strike)
	player.weapon_attack_requested.connect(_on_player_weapon_attack)
	player.bait_toss_requested.connect(_on_player_bait_toss)
	player.override_requested.connect(_on_player_override_requested)
	player.bite_sequence_finished.connect(_on_player_bite_sequence_finished)

	# Connect dev panel signals
	hud.dev_god_toggled.connect(_on_dev_god_toggled)
	hud.dev_freeze_toggled.connect(_on_dev_freeze_toggled)
	hud.dev_noclip_toggled.connect(_on_dev_noclip_toggled)
	hud.dev_steps_hud_toggled.connect(_on_dev_steps_hud_toggled)
	hud.dev_force_chase.connect(_on_dev_force_chase)
	hud.dev_complete_objectives.connect(_on_dev_complete_objectives)
	hud.dev_give_keycards.connect(_on_dev_give_keycards)
	hud.dev_tp_exit.connect(_on_dev_tp_exit)
	hud.dev_skip_day.connect(_on_dev_skip_day)
	hud.dev_jump_day.connect(_on_dev_jump_day)
	hud.dev_spawn_crawler.connect(_on_dev_spawn_crawler)
	hud.dev_spawn_cultist.connect(_on_dev_spawn_cultist)
	if hud.has_signal("dev_spawn_cloak"):
		hud.dev_spawn_cloak.connect(_on_dev_spawn_cloak)
	if hud.has_signal("dev_spawn_hanger"):
		hud.dev_spawn_hanger.connect(_on_dev_spawn_hanger)
	hud.dev_repair_mop.connect(_on_dev_repair_mop)
	hud.dev_unlock_map.connect(_on_dev_unlock_map)
	hud.dev_panel_closed.connect(_hide_dev_panel)
	hud.dev_test_cutscene.connect(_on_dev_test_cutscene)

	_setup_initial_world()
	hud.game_hud.visible = false

func _setup_initial_world() -> void:
	current_day = 1
	total_relics_career = 0
	wages = 0
	_setup_world_for_day(current_day)

func _setup_world_for_day(day_num: int) -> void:
	current_day = clampi(day_num, 1, GameData.TOTAL_DAYS)
	current_phase = Phase.WORK

	var day_meta = GameData.DAY_META[current_day - 1]
	var map_pool_count = GameData.get_map_count_for_day(current_day)
	if selected_map_index < 0:
		selected_map_index = randi() % map_pool_count
	else:
		selected_map_index = clampi(selected_map_index, 0, map_pool_count - 1)

	maze_grid = GameData.get_random_maze_for_day(current_day, selected_map_index).duplicate(true)

	var t_mult: float = NetworkManager.mp_task_mult if NetworkManager.is_multiplayer_active else 1.0
	var s_mult: float = NetworkManager.mp_supplies_mult if NetworkManager.is_multiplayer_active else 1.0
	map_gen.set_meta("mp_supplies_mult", s_mult)

	spills_cleaned = 0
	spills_total = int(ceil(3.0 * t_mult))
	blood_cleaned = 0
	blood_total = int(ceil(3.0 * t_mult))
	terminals_checked = 0
	terminals_total = int(ceil(2.0 * t_mult))
	relics_collected = 0
	keycards_collected = 0
	keycards_total = 3

	max_chase_distance = int(day_meta.get("dist", 200))
	chase_distance = max_chase_distance
	crawler_bites = 0
	mop_integrity = 100.0
	bait_count = 3
	override_cooldown = 0.0
	quit_attempts = 0
	pedestals_sealed = 0
	if "in_secret_corridor" in player:
		player.in_secret_corridor = false

	if is_instance_valid(active_bait_node):
		active_bait_node.queue_free()
	active_bait_node = null

	if player.has_method("reset_special_sequences"):
		player.reset_special_sequences()
	if player.has_method("reset_weapons"):
		player.reset_weapons()
	if player.is_hiding:
		player.exit_locker()
	hud.set_locker_overlay(false)
	map_gen.set_emergency_lighting(false)

	statues.clear()
	crawlers.clear()
	cultists.clear()
	cloaks.clear()
	hangers.clear()
	hunter = null
	light_eater = null
	for child in entities.get_children():
		child.queue_free()

	# Reset Floor 2 Task tracking states
	f2_terminals_done = 0
	f2_terminals_needed = 2
	f2_has_usb = false
	f2_usb_done = false
	f2_has_dossier = false
	f2_dossier_done = false
	f2_has_coolant = false
	f2_coolant_done = false

	var spawn_info = map_gen.build_map(maze_grid, player, current_day)
	if map_gen.has_method("set_keycards_visible"):
		map_gen.set_keycards_visible(false)
	if "god_mode" in player:
		player.god_mode = dev_god_mode
	if player.has_method("set_noclip"):
		player.set_noclip(dev_noclip)
	player.reset_step_tracker()
	hud.minimap.init_map(maze_grid, player)
	if spawn_info.has("floor2_grid"):
		hud.minimap.set_floor2_grid(spawn_info["floor2_grid"])
	open_spawn_cells.assign(spawn_info.get("open_positions", []))

	# 1. Spawn Dormant Hunter inside main BioTank
	hunter = _create_hunter(spawn_info["hunter_pos"])

	# 2. Spawn Stone Statues / Observers inside Electric Fence Containment (Night 2+)
	for s_pos in spawn_info["statue_positions"]:
		var st = _create_statue(s_pos)
		statues.append(st)
		if map_gen.has_method("create_statue_electric_fence"):
			map_gen.create_statue_electric_fence(s_pos)

	# 3. Spawn Crawlers & Cultists inside Observation Cages (100% caged during work shift)
	var cage_slots: Array = spawn_info.get("cage_slots", [])
	var slot_idx: int = 0

	var num_crawlers: int = int(day_meta.get("crawlers", 4))
	for i in range(num_crawlers):
		var slot: Dictionary
		if slot_idx < cage_slots.size():
			slot = cage_slots[slot_idx]
			slot_idx += 1
		elif not open_spawn_cells.is_empty():
			var pos = open_spawn_cells[i % open_spawn_cells.size()]
			slot = map_gen.create_holding_cage(pos, randf() * TAU)
		if not slot.is_empty():
			var cr = _create_crawler(slot["caged_pos"])
			cr.setup_caged(slot["caged_pos"], slot["release_pos"], slot["bars_node"], slot["rot"])
			crawlers.append(cr)

	var num_cultists: int = int(day_meta.get("cultists", 0))
	for i in range(num_cultists):
		var slot: Dictionary
		if slot_idx < cage_slots.size():
			slot = cage_slots[slot_idx]
			slot_idx += 1
		elif not open_spawn_cells.is_empty():
			var pos = open_spawn_cells[(i + 3) % open_spawn_cells.size()]
			slot = map_gen.create_holding_cage(pos, randf() * TAU)
		if not slot.is_empty():
			if is_instance_valid(slot.get("label")):
				slot["label"].text = "SPECIMEN FILE: HERETIC\nSUB-RING CULTIST\nACTIVE CHANT • LETHAL\nCLEARANCE: OMEGA"
			var cu = _create_cultist(slot["caged_pos"])
			cu.setup_caged(slot["caged_pos"], slot["release_pos"], slot["bars_node"], slot["rot"])
			cultists.append(cu)

	# 4. Spawn Floating Cloak Shrouds (Night 4+ / Màn 4+)
	var num_cloaks: int = int(day_meta.get("cloaks", 0))
	if num_cloaks > 0 and not open_spawn_cells.is_empty():
		var step_idx: int = max(1, open_spawn_cells.size() / (num_cloaks + 1))
		for i in range(num_cloaks):
			var c_pos = open_spawn_cells[((i + 1) * step_idx) % open_spawn_cells.size()]
			var clk = _create_cloak(c_pos)
			clk.activate()
			cloaks.append(clk)

	# 5. Cache Floor 2 Walkways (Monsters do NOT appear on Floor 2 during cleaning/work shift)
	# Lurkers and Cultists will be spawned only when Chase Phase begins!
	f2_walkways_cached = spawn_info.get("floor2_walkways", [])

	_update_hud_objectives()
	hud.update_mop_integrity(mop_integrity, 100.0)
	hud.update_chase_distance(chase_distance, max_chase_distance, _get_hunter_steps_away(), keycards_collected, keycards_total)

func _on_start_shift() -> void:
	_setup_initial_world()
	SoundEffects.start_cutscene_music()
	hud.play_cutscene("intro", func():
		_start_work_shift()
	)

func _on_retry_night() -> void:
	if NetworkManager and NetworkManager.is_multiplayer_active:
		if NetworkManager.is_host:
			NetworkManager.host_restart_round()
		else:
			hud.show_toast("Chỉ Chủ Phòng (Host) mới có quyền bấm Chơi Lại!", Color(1.0, 0.4, 0.4))
		return
	is_game_over = false
	quit_attempts = 0
	_clean_up_session_entities()
	_freeze_all_monsters(false)
	hud.game_over_screen.visible = false
	_setup_world_for_day(current_day)
	_start_work_shift()

func _start_work_shift() -> void:
	is_game_over = false
	quit_attempts = 0
	SoundEffects.stop_siren()
	SoundEffects.stop_music()
	SoundEffects.start_ambient_music()
	hud.set_phase_presentation("work", current_day)
	_update_hud_objectives()
	hud.update_stamina(player.stamina, player.max_stamina)
	hud.update_mop_integrity(mop_integrity, 100.0)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_refresh_minimap()
	var day_meta = GameData.DAY_META[current_day - 1]
	hud.show_toast("SHIFT STARTED: %s" % day_meta.get("title", "NIGHT %d" % current_day), day_meta.get("color", Color.WHITE))

func _process(delta: float) -> void:
	if not hud.game_hud.visible:
		return

	hud.update_stamina(player.stamina, player.max_stamina)

	if NetworkManager.is_multiplayer_active and is_instance_valid(player):
		mp_net_sync_timer += delta
		if mp_net_sync_timer >= 0.05:
			mp_net_sync_timer = 0.0
			var moving = player.velocity.length_squared() > 0.05 or (player.get("last_frame_move_dist") != null and float(player.get("last_frame_move_dist")) > 0.001)
			var sprint = Input.is_action_pressed("sprint")
			var flash = player.flashlight.visible if is_instance_valid(player.flashlight) else true
			var w_type = player.get("current_weapon_idx") if "current_weapon_idx" in player else 0
			var guard = player.get("is_defending") if "is_defending" in player else false
			var cam_rot_x = player.camera.rotation.x if is_instance_valid(player.camera) else 0.0
			var in_lock = (player.get("is_hiding") == true)
			NetworkManager.update_local_player_state(player.global_position, moving, in_lock)
			NetworkManager.sync_player_transform(player.global_position, player.rotation.y, cam_rot_x, moving, sprint, flash, w_type, guard, in_lock)

	if is_spectating:
		_process_spectator_camera(delta)

	# Anti-Camping Penalty Check (25s standing completely still in MP during Chase Phase only)
	# During Work Shift (dọn dẹp), standing still is completely permitted and will NEVER trigger penalties.
	if current_phase == Phase.CHASE and is_instance_valid(player) and not player.is_hiding and not is_game_over and not is_spectating:
		var is_busy = (player.get("is_scrubbing") == true) or (player.get("is_defending") == true) or (player.velocity.length_squared() >= 0.05)
		if not is_busy and NetworkManager.is_multiplayer_active:
			player_still_timer += delta
			if player_still_timer >= 25.0:
				player_still_timer = 0.0
				_trigger_camping_penalty(player.global_position)
		else:
			player_still_timer = 0.0
	else:
		player_still_timer = 0.0

	if override_cooldown > 0.0:
		override_cooldown = max(0.0, override_cooldown - delta)
	if _exit_block_cooldown > 0.0:
		_exit_block_cooldown = max(0.0, _exit_block_cooldown - delta)

	if active_bait_node and is_instance_valid(active_bait_node):
		active_bait_timer -= delta
		if active_bait_timer <= 0.0:
			active_bait_node.queue_free()
			active_bait_node = null
			for cr in crawlers:
				if is_instance_valid(cr):
					cr.clear_bait()
			for cu in cultists:
				if is_instance_valid(cu):
					cu.clear_bait()

	if current_phase == Phase.CHASE:
		var h_steps = _get_hunter_steps_away()
		hud.update_chase_distance(chase_distance, max_chase_distance, h_steps, keycards_collected, keycards_total)
		if dev_panel_visible:
			_update_hud_objectives()

		# Heartbeat audio & subtle camera shake when Hunter is close (matching HTML dangerSteps())
		var danger = min(chase_distance, h_steps)
		if danger < 32:
			heartbeat_timer -= delta
			if heartbeat_timer <= 0.0:
				heartbeat_timer = clampf(float(danger) / 34.0, 0.28, 0.85)
				SoundEffects.play_heartbeat()

func _get_hunter_steps_away() -> int:
	if not is_instance_valid(hunter):
		return 50
	if hunter.has_method("get_bfs_steps_to_player"):
		return hunter.get_bfs_steps_to_player()
	var d = player.global_position.distance_to(hunter.global_position)
	return max(1, int(round(d / GameData.STEP_THRESH)))

func _on_player_step_taken() -> void:
	if current_phase != Phase.CHASE:
		return
	if dev_freeze_entity:
		return
	if player and (player.get("in_secret_corridor") == true):
		return
	_modify_chase_steps(-1)

func _modify_chase_steps(delta_steps: int) -> void:
	chase_distance = clampi(chase_distance + delta_steps, 0, max_chase_distance + 60)
	hud.update_chase_distance(chase_distance, max_chase_distance, _get_hunter_steps_away(), keycards_collected, keycards_total)
	_update_hud_objectives()

	if chase_distance <= GameData.FINAL_TRIGGER_STEPS and is_instance_valid(hunter) and not hunter.final_mode:
		hunter.enter_final_mode()
		# Only reveal Final Mode step countdown message if Dev Mode is active!
		if dev_panel_visible or hud.dev_mode_enabled:
			hud.show_toast("⚠ [DEV] 30 STEPS LEFT — HUNTER ENTERED FINAL INVINCIBLE MODE!", Color(1.0, 0.2, 0.2))

	if chase_distance <= 0 and not dev_god_mode and not dev_freeze_entity:
		if is_instance_valid(hunter):
			if hunter.has_method("enter_overtime_rage") and not hunter.get("overtime_rage"):
				hunter.enter_overtime_rage()
				hud.show_toast("200 STEPS EXPIRED — SUBJECT ZERO IS UNSTOPPABLE!", Color(1.0, 0.15, 0.15))
			var dist_2d = Vector2(player.global_position.x - hunter.global_position.x, player.global_position.z - hunter.global_position.z).length()
			if dist_2d <= 2.4 and hunter.has_method("start_kill"):
				hunter.start_kill("claw", "THE ENTITY CLOSED THE GAP — YOU WERE HARVESTED.")
		else:
			game_over("THE ENTITY CLOSED THE GAP — YOU WERE HARVESTED.")

func _on_player_locker_state_changed(hiding: bool, locker_node: Node3D) -> void:
	hud.set_locker_overlay(hiding)
	if hiding:
		hud.show_toast("HIDING IN LOCKER — [E] TO LEAVE", Color(0.4, 0.9, 1.0))
		if is_instance_valid(hunter) and hunter.has_method("on_player_entered_locker"):
			hunter.on_player_entered_locker(locker_node)
	else:
		if is_instance_valid(hunter) and hunter.has_method("on_player_exited_locker"):
			hunter.on_player_exited_locker()

# Mop combat ported from HTML animateMopSwing (lines 3193-3214)
func _on_player_mop_strike() -> void:
	if player.is_hiding or player.in_bite_sequence or player.in_death_sequence:
		return
	# Check if striking a nearby Cloak (allowed in both WORK and CHASE phases!)
	var best_cloak: Node3D = null
	var best_cloak_dist: float = 3.3
	for clk in cloaks:
		if is_instance_valid(clk) and (clk.get("active") == true):
			var d_clk = Vector2(player.global_position.x - clk.global_position.x, player.global_position.z - clk.global_position.z).length()
			if d_clk < best_cloak_dist:
				best_cloak_dist = d_clk
				best_cloak = clk

	if current_phase != Phase.CHASE and best_cloak == null:
		return
	if mop_integrity <= 1.0:
		hud.show_toast("The mop is broken. No more strikes.", Color(1.0, 0.3, 0.3))
		SoundEffects.play(SoundEffects.snd_click, -2.0)
		return

	var cost: float = 0.0
	var hit_type: String = "miss"

	# 0. Check if player struck a Cloak shroud!
	if best_cloak != null and best_cloak.has_method("hit_by_mop"):
		if best_cloak.hit_by_mop():
			cost += 20.0
			hit_type = "cultist"

	# 1. Find closest live Crawler or Cultist within 3.2m
	var best_ent: Node3D = null
	var best_dist: float = 3.2
	var best_is_crawler: bool = false

	for cr in crawlers:
		if is_instance_valid(cr) and cr.active and not cr.is_dead:
			var d = Vector2(player.global_position.x - cr.global_position.x, player.global_position.z - cr.global_position.z).length()
			if d < best_dist:
				best_dist = d
				best_ent = cr
				best_is_crawler = true

	for cu in cultists:
		if is_instance_valid(cu) and cu.active and not cu.is_dead:
			var d = Vector2(player.global_position.x - cu.global_position.x, player.global_position.z - cu.global_position.z).length()
			if d < best_dist:
				best_dist = d
				best_ent = cu
				best_is_crawler = false

	if best_ent != null:
		if best_is_crawler:
			if best_ent.hit_by_mop():
				cost += 10.0
				hit_type = "crawler"
				hud.show_toast("Lesser specimen crushed! (-10% durability)", Color(0.75, 0.95, 0.4))
		else:
			if best_ent.hit_by_mop():
				cost += 33.0
				hit_type = "cultist"
				hud.show_toast("Cultist staggered (3.5s) — MOVE! (-33% durability)", Color(0.98, 0.65, 0.65))

	# 2. Check main Hunter within 4.4m (matching HTML canHitMain <= 4.4)
	if is_instance_valid(hunter) and hunter.active:
		var dh = Vector2(player.global_position.x - hunter.global_position.x, player.global_position.z - hunter.global_position.z).length()
		if dh <= 4.4:
			var res: String = hunter.hit_by_mop()
			cost += 33.0
			hit_type = "hunter"
			if res == "stunned":
				hud.show_toast("THE MOP CRACKS ACROSS ITS JAW — IT STAGGERS! (4.5s)", Color(0.25, 0.95, 0.65))
			elif res == "ambush":
				hud.show_toast("IT COLLAPSED… WAIT. WHY ARE ITS EYES STILL MOVING?", Color(0.98, 0.75, 0.15))
			else:
				hud.show_toast("THE MOP SPLINTERS — NOTHING CAN STOP IT NOW!", Color(1.0, 0.25, 0.25))

	player.trigger_mop_swing_animation(hit_type)

	if hit_type == "miss":
		hud.show_toast("The mop cuts through empty air.", Color(0.98, 0.75, 0.15))
		return

	mop_integrity = max(0.0, mop_integrity - cost)
	if mop_integrity <= 1.0:
		mop_integrity = 0.0
		hud.show_toast("CRACK! The mop handle breaks.", Color(1.0, 0.25, 0.25))
	hud.update_mop_integrity(mop_integrity, 100.0)

# --- WEAPON ATTACKS (SHOCK BATON & STUN GUN) ---
func _on_player_weapon_attack(weapon_type: int) -> void:
	if player.is_hiding or player.in_bite_sequence or player.in_death_sequence:
		return

	if weapon_type == player.WeaponType.BATON:
		_handle_baton_attack()
	elif weapon_type == player.WeaponType.TASER:
		_handle_taser_attack()

func _handle_baton_attack() -> void:
	if not player.has_baton or player.baton_durability <= 0.0:
		hud.show_toast("NO SHOCK BATON EQUIPPED", Color(0.8, 0.4, 0.4))
		return

	var hit_type: String = "miss"
	var cost: float = 0.0

	# Reach for Shock Baton:
	# Cloak: 3.2m
	var best_cloak: Node3D = null
	var best_cloak_dist: float = 3.2
	for clk in cloaks:
		if is_instance_valid(clk) and (clk.get("active") == true):
			var d_clk = Vector2(player.global_position.x - clk.global_position.x, player.global_position.z - clk.global_position.z).length()
			if d_clk < best_cloak_dist and abs(player.global_position.y - clk.global_position.y) < 2.5:
				best_cloak_dist = d_clk
				best_cloak = clk

	if best_cloak != null and best_cloak.has_method("hit_by_mop"):
		if best_cloak.hit_by_mop():
			cost = 10.0
			hit_type = "cultist"
			hud.show_toast("⚡ BATON CRACKLES AGAINST CLOAK! (-10% durability)", Color(0.85, 0.65, 1.0))

	# Small monsters (Crawler 3.4m, Cultist 3.4m)
	var best_ent: Node3D = null
	var best_dist: float = 3.4
	var best_is_crawler: bool = false

	for cr in crawlers:
		if is_instance_valid(cr) and cr.active and not cr.is_dead:
			var d = Vector2(player.global_position.x - cr.global_position.x, player.global_position.z - cr.global_position.z).length()
			if d < best_dist and abs(player.global_position.y - cr.global_position.y) < 2.5:
				best_dist = d
				best_ent = cr
				best_is_crawler = true

	for cu in cultists:
		if is_instance_valid(cu) and cu.active and not cu.is_dead:
			var d = Vector2(player.global_position.x - cu.global_position.x, player.global_position.z - cu.global_position.z).length()
			if d < best_dist and abs(player.global_position.y - cu.global_position.y) < 2.5:
				best_dist = d
				best_ent = cu
				best_is_crawler = false

	if best_ent != null:
		if best_is_crawler:
			if best_ent.hit_by_mop():
				cost = 3.0 # "đập quái nhỏ chỉ mất 3% đồ bền"
				hit_type = "crawler"
				hud.show_toast("⚡ CRUSHED! Crawler pulverized by Shock Baton! (-3% durability: %d%%)" % int(max(0.0, player.baton_durability - cost)), Color(0.75, 0.95, 0.4))
		else:
			if best_ent.hit_by_mop():
				cost = 10.0 # "quái chính hoặc same tier thì chỉ mất 10%"
				hit_type = "cultist"
				hud.show_toast("⚡ STAGGERED! Cultist shocked with Baton! (-10% durability: %d%%)" % int(max(0.0, player.baton_durability - cost)), Color(0.98, 0.65, 0.65))

	# Hangers within 3.2m
	for h in hangers:
		if is_instance_valid(h) and (h.get("active") == true) and h.get("state") != "STUNNED":
			var dh_flat = Vector2(player.global_position.x - h.global_position.x, player.global_position.z - h.global_position.z).length()
			if dh_flat <= 3.2 and abs(player.global_position.y - h.global_position.y) < 3.0:
				if h.has_method("stun"):
					h.stun(3.0)
					cost = 10.0
					hit_type = "cultist"
					hud.show_toast("⚡ Hanger struck with Shock Baton! (-10% durability: %d%%)" % int(max(0.0, player.baton_durability - cost)), Color(0.8, 0.8, 1.0))
					break

	# Hunter within 3.8m
	if is_instance_valid(hunter) and hunter.active:
		var dh = Vector2(player.global_position.x - hunter.global_position.x, player.global_position.z - hunter.global_position.z).length()
		if dh <= 3.8 and abs(player.global_position.y - hunter.global_position.y) < 2.8:
			var res = hunter.hit_by_mop()
			cost = 10.0 # "quái chính hoặc same tier thì chỉ mất 10%"
			hit_type = "hunter"
			if res == "stunned":
				hud.show_toast("⚡ SHOCK BATON CRACKS ACROSS ITS JAW! (-10% durability: %d%%)" % int(max(0.0, player.baton_durability - cost)), Color(0.25, 0.95, 0.65))
			elif res == "ambush":
				hud.show_toast("⚡ IT COLLAPSED… AMBUSH POSTURE (-10% durability: %d%%)" % int(max(0.0, player.baton_durability - cost)), Color(0.98, 0.75, 0.15))
			else:
				hud.show_toast("THE ENTITY ENRAGED — IMMUNE! (-10% durability: %d%%)" % int(max(0.0, player.baton_durability - cost)), Color(1.0, 0.25, 0.25))

	player.trigger_baton_swing_animation(hit_type)

	if hit_type == "miss":
		hud.show_toast("The baton swings through empty air.", Color(0.98, 0.75, 0.15))
		return

	player.consume_baton_durability(cost)

func _handle_taser_attack() -> void:
	if not player.has_taser or player.taser_ammo <= 0:
		hud.show_toast("NO STUN GUN AMMO", Color(0.8, 0.4, 0.4))
		return

	var max_range: float = 11.0 * GameData.STEP_THRESH # 11 steps = 19.8m
	var cam: Camera3D = player.camera
	var cam_pos = cam.global_position
	var fwd = -cam.global_transform.basis.z.normalized()

	# Find closest monster in front of camera within 19.8m
	var best_target: Node3D = null
	var best_dist: float = max_range
	var best_type: String = ""

	# Check Statues
	for s in statues:
		if is_instance_valid(s) and (s.get("active") == true):
			var to_m = s.global_position + Vector3(0, 1.2, 0) - cam_pos
			var dist = to_m.length()
			if dist <= best_dist and dist > 0.1:
				if fwd.dot(to_m.normalized()) > 0.65:
					best_dist = dist
					best_target = s
					best_type = "statue"

	# Check Hunter
	if is_instance_valid(hunter) and hunter.active:
		var to_m = hunter.global_position + Vector3(0, 1.6, 0) - cam_pos
		var dist = to_m.length()
		if dist <= best_dist and dist > 0.1:
			if fwd.dot(to_m.normalized()) > 0.65:
				best_dist = dist
				best_target = hunter
				best_type = "hunter"

	# Check Cloaks
	for clk in cloaks:
		if is_instance_valid(clk) and (clk.get("active") == true):
			var to_m = clk.global_position + Vector3(0, 1.2, 0) - cam_pos
			var dist = to_m.length()
			if dist <= best_dist and dist > 0.1:
				if fwd.dot(to_m.normalized()) > 0.65:
					best_dist = dist
					best_target = clk
					best_type = "cloak"

	# Check Hangers
	for h in hangers:
		if is_instance_valid(h) and (h.get("active") == true):
			var to_m = h.global_position + Vector3(0, 1.2, 0) - cam_pos
			var dist = to_m.length()
			if dist <= best_dist and dist > 0.1:
				if fwd.dot(to_m.normalized()) > 0.65:
					best_dist = dist
					best_target = h
					best_type = "hanger"

	# Check Cultists
	for cu in cultists:
		if is_instance_valid(cu) and cu.active and not cu.is_dead:
			var to_m = cu.global_position + Vector3(0, 1.2, 0) - cam_pos
			var dist = to_m.length()
			if dist <= best_dist and dist > 0.1:
				if fwd.dot(to_m.normalized()) > 0.65:
					best_dist = dist
					best_target = cu
					best_type = "cultist"

	# Check Crawlers
	for cr in crawlers:
		if is_instance_valid(cr) and cr.active and not cr.is_dead:
			var to_m = cr.global_position + Vector3(0, 0.4, 0) - cam_pos
			var dist = to_m.length()
			if dist <= best_dist and dist > 0.1:
				if fwd.dot(to_m.normalized()) > 0.65:
					best_dist = dist
					best_target = cr
					best_type = "crawler"

	# Check Light Eater (Floor 2)
	if is_instance_valid(light_eater) and (light_eater.get("active") == true):
		var to_m = light_eater.global_position + Vector3(0, 1.0, 0) - cam_pos
		var dist = to_m.length()
		if dist <= best_dist and dist > 0.1:
			if fwd.dot(to_m.normalized()) > 0.65:
				best_dist = dist
				best_target = light_eater
				best_type = "light_eater"

	var end_pos = cam_pos + fwd * max_range
	if best_target != null:
		end_pos = best_target.global_position + Vector3(0, 1.2 if best_type != "crawler" else 0.4, 0)

	# Sound & Visuals
	SoundEffects.play(SoundEffects.snd_taser, 3.5)
	player.trigger_taser_fire_animation()
	_spawn_taser_lightning(cam_pos + fwd * 0.4 - cam.global_transform.basis.y * 0.15, end_pos)

	if best_target != null:
		if best_type == "statue":
			# Statues are IMMUNE!
			SoundEffects.play(SoundEffects.snd_stone, 2.0)
			hud.show_toast("⚡ THE OBSERVER'S STONE CARAPACE DEFLECTS THE CURRENT — IMMUNE!", Color(0.9, 0.9, 0.4))
		elif best_type == "hunter":
			# Hunter: 7s stun!
			if best_target.has_method("stun"):
				best_target.stun(7.0)
			hud.show_toast("⚡ 50,000V DISCHARGED INTO SUBJECT ZERO! STUNNED (7.0s)!", Color(0.2, 0.9, 1.0))
		elif best_type == "cloak":
			# Cloak: 7s stun!
			if best_target.has_method("stun"):
				best_target.stun(7.0)
			hud.show_toast("⚡ HIGH VOLTAGE ARCS THROUGH THE CLOAK! STUNNED (7.0s)!", Color(0.2, 0.9, 1.0))
		elif best_type == "hanger":
			# Hanger: 10s stun!
			if best_target.has_method("stun"):
				best_target.stun(10.0)
			hud.show_toast("⚡ HANGER ELECTROCUTED! STUNNED (10.0s)!", Color(0.2, 0.9, 1.0))
		elif best_type == "cultist":
			# Cultist: 10s stun!
			if best_target.has_method("stun"):
				best_target.stun(10.0)
			hud.show_toast("⚡ CULTIST CONVULSING UNDER HIGH VOLTAGE! STUNNED (10.0s)!", Color(0.2, 0.9, 1.0))
		elif best_type == "crawler":
			# Crawler: 10s stun!
			if best_target.has_method("stun"):
				best_target.stun(10.0)
			hud.show_toast("⚡ CRAWLER ELECTROCUTED! STUNNED (10.0s)!", Color(0.2, 0.9, 1.0))
		elif best_type == "light_eater":
			if best_target.has_method("trigger_taser_supercharge"):
				best_target.trigger_taser_supercharge(fwd)
			hud.show_toast("⚡ LIGHT EATER SUPERCHARGED! ARC CHARGE CLEARING THE CORRIDOR (5.0s STUN)!", Color(0.2, 1.0, 0.8), 5.0)
	else:
		hud.show_toast("Taser dart discharged into empty space.", Color(0.8, 0.8, 0.8))

	# Taser single use: consumed & dropped from inventory!
	player.consume_taser()

func _spawn_taser_lightning(from_pos: Vector3, to_pos: Vector3) -> void:
	var arc_root = Node3D.new()
	entities.add_child(arc_root)

	var arc_mat = StandardMaterial3D.new()
	arc_mat.albedo_color = Color(0.5, 0.95, 1.0)
	arc_mat.emission_enabled = true
	arc_mat.emission = Color(0.4, 0.92, 1.0)
	arc_mat.emission_energy_multiplier = 4.5

	var flash_start = OmniLight3D.new()
	flash_start.position = from_pos
	flash_start.light_color = Color(0.3, 0.85, 1.0)
	flash_start.light_energy = 3.5
	flash_start.omni_range = 3.5
	arc_root.add_child(flash_start)

	var flash_end = OmniLight3D.new()
	flash_end.position = to_pos
	flash_end.light_color = Color(0.3, 0.85, 1.0)
	flash_end.light_energy = 4.5
	flash_end.omni_range = 5.0
	arc_root.add_child(flash_end)

	var num_branches = 3
	var segs_per_branch = 8
	var segment_meshes: Array[MeshInstance3D] = []

	for b in range(num_branches):
		var prev_p = from_pos
		for s in range(1, segs_per_branch + 1):
			var frac = float(s) / float(segs_per_branch)
			var base_p = from_pos.lerp(to_pos, frac)
			var jitter = Vector3(randf_range(-0.16, 0.16), randf_range(-0.16, 0.16), randf_range(-0.16, 0.16)) if s < segs_per_branch else Vector3.ZERO
			var cur_p = base_p + jitter

			var seg = MeshInstance3D.new()
			var cyl = CylinderMesh.new()
			cyl.top_radius = 0.008
			cyl.bottom_radius = 0.008
			var diff = cur_p - prev_p
			var dist = diff.length()
			cyl.height = dist
			seg.mesh = cyl
			seg.material_override = arc_mat

			arc_root.add_child(seg)
			seg.global_position = prev_p + diff * 0.5
			if dist > 0.001 and seg.is_inside_tree():
				var up = Vector3.UP if abs(diff.normalized().y) < 0.9 else Vector3.RIGHT
				seg.look_at(cur_p, up)
				seg.rotate_object_local(Vector3.RIGHT, PI * 0.5)

			segment_meshes.append(seg)
			prev_p = cur_p

	var tw = create_tween()
	tw.tween_method(func(t: float):
		if not is_instance_valid(arc_root): return
		var fade = max(0.0, 1.0 - t * 4.5)
		flash_start.light_energy = 3.5 * fade
		flash_end.light_energy = 4.5 * fade
		for m in segment_meshes:
			if is_instance_valid(m):
				m.scale = Vector3.ONE * max(0.1, fade)
	, 0.0, 0.22, 0.22)
	tw.tween_callback(arc_root.queue_free)

func _on_player_bait_toss() -> void:
	if bait_count <= 0:
		hud.show_toast("NO CHEMICAL BAIT LEFT!", Color(1.0, 0.35, 0.35))
		return
	bait_count -= 1
	_update_hud_objectives()

	if is_instance_valid(active_bait_node):
		active_bait_node.queue_free()

	var forward = -player.global_transform.basis.z
	var drop_pos = player.global_position + forward * 2.2
	drop_pos.y = 0.1

	active_bait_node = Node3D.new()
	active_bait_node.position = drop_pos
	var mesh = MeshInstance3D.new()
	var sph = SphereMesh.new()
	sph.radius = 0.22
	sph.height = 0.44
	mesh.mesh = sph
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 1.0, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 1.0, 0.4)
	mat.emission_energy_multiplier = 3.0
	mesh.material_override = mat
	active_bait_node.add_child(mesh)

	var light = OmniLight3D.new()
	light.light_color = Color(0.2, 1.0, 0.4)
	light.light_energy = 2.0
	light.omni_range = 5.0
	light.position.y = 0.3
	active_bait_node.add_child(light)
	entities.add_child(active_bait_node)

	active_bait_timer = 12.0
	for cr in crawlers:
		if is_instance_valid(cr):
			cr.set_bait(drop_pos)
	for cu in cultists:
		if is_instance_valid(cu):
			cu.set_bait(drop_pos)

	SoundEffects.play(SoundEffects.snd_pickup, -2.0, 0.85)
	hud.show_toast("TOSSED CHEMICAL BAIT [B] — LURING SPECIMENS (%d LEFT)" % bait_count, Color(0.3, 1.0, 0.5))

func _on_player_override_requested() -> void:
	if current_phase != Phase.CHASE:
		hud.show_toast("CONTAINMENT OVERRIDE [R] ONLY AVAILABLE DURING BREACH!", Color(0.9, 0.7, 0.2))
		return
	if override_cooldown > 0.0:
		hud.show_toast("OVERRIDE RECHARGING (%.1fs)..." % override_cooldown, Color(1.0, 0.5, 0.3))
		return
	hud.start_override_minigame()

func _on_override_completed(success: bool) -> void:
	override_cooldown = 14.0
	if success:
		_modify_chase_steps(20)
		SoundEffects.play(SoundEffects.snd_pickup, 2.0, 1.3)
		hud.show_toast("OVERRIDE SUCCESS — THE ENTITY FALLS BACK!", Color(0.25, 1.0, 0.5))
	else:
		_modify_chase_steps(-25)
		hud.flash_damage()
		SoundEffects.play(SoundEffects.snd_click, 2.0, 0.6)
		hud.show_toast("OVERRIDE FAILED — THE ENTITY IS CLOSING IN!", Color(1.0, 0.25, 0.25))

func _on_spill_cleaned(is_blood: bool = false) -> void:
	if is_blood:
		blood_cleaned += 1
		wages += 15
		hud.show_toast("Blood cleaned +$15  (wages: $%d)" % wages, Color(0.53, 0.94, 0.67))
	else:
		spills_cleaned += 1
		wages += 15
		hud.show_toast("TOXIC SPILL MOPPED (%d / %d)" % [spills_cleaned, spills_total], Color(0.4, 1.0, 0.4))
	if NetworkManager.is_multiplayer_active:
		NetworkManager.clean_spill(player.global_position, NetworkManager.get_local_peer_id(), is_blood)
	_update_hud_objectives()
	_check_work_complete()
	_refresh_minimap()

func _on_terminal_checked() -> void:
	terminals_checked += 1
	wages += 25
	hud.show_toast("SCIENCE TERMINAL VERIFIED (%d / %d)" % [terminals_checked, terminals_total], Color(0.3, 0.85, 1.0))
	if NetworkManager.is_multiplayer_active:
		NetworkManager.verify_terminal(player.global_position, NetworkManager.get_local_peer_id())
	_update_hud_objectives()
	_check_work_complete()
	_refresh_minimap()

func _on_relic_collected(val: int) -> void:
	relics_collected += 1
	total_relics_career += 1
	wages += val
	hud.minimap.reveal_bonus_area()
	var whispers = GameData.RELIC_WHISPERS
	var w_text = whispers[(total_relics_career - 1) % whispers.size()]
	hud.show_toast(w_text, Color(0.85, 0.5, 1.0))
	_update_hud_objectives()

func _on_note_inspected(note_id: String) -> void:
	var note_data = GameData.LORE_NOTES.get(note_id, {})
	if note_data.is_empty():
		note_data = GameData.LORE_NOTES.get("note_intake", {})
	hud.show_note_popup(note_data.get("title", "INCIDENT NOTE"), note_data.get("tag", "FACILITY ARCHIVE"), note_data.get("body", "Record corrupted."))

func _update_hud_objectives() -> void:
	var f2_info: Dictionary = {}
	if current_day >= 3:
		f2_info = {
			"terms_done": f2_terminals_done,
			"terms_needed": f2_terminals_needed,
			"has_usb": f2_has_usb,
			"usb_done": f2_usb_done,
			"has_dossier": f2_has_dossier,
			"dossier_done": f2_dossier_done,
			"has_coolant": f2_has_coolant,
			"coolant_done": f2_coolant_done
		}
	hud.update_work_objectives(
		spills_cleaned,
		spills_total,
		terminals_checked,
		terminals_total,
		total_relics_career,
		wages,
		blood_cleaned,
		keycards_collected,
		keycards_total,
		crawler_bites,
		bait_count,
		f2_info
	)

	if current_day >= 3 and is_instance_valid(map_gen) and is_instance_valid(hud) and is_instance_valid(hud.minimap):
		var markers: Array[Dictionary] = []
		var s_pos = map_gen.get("f2_station_positions")
		if s_pos is Dictionary:
			if f2_has_usb and not f2_usb_done:
				markers.append({"pos": s_pos.get("vault", Vector3.ZERO), "label": "SEC A-1", "color": Color(0.2, 0.95, 0.5)})
			if f2_has_dossier and not f2_dossier_done:
				markers.append({"pos": s_pos.get("archive", Vector3.ZERO), "label": "SEC B-1", "color": Color(1.0, 0.75, 0.2)})
			if f2_has_coolant and not f2_coolant_done:
				markers.append({"pos": s_pos.get("server", Vector3.ZERO), "label": "SEC C-1", "color": Color(0.3, 0.95, 1.0)})
		hud.minimap.set_f2_delivery_markers(markers)

func _check_work_complete() -> void:
	var f1_done = spills_cleaned >= spills_total and terminals_checked >= terminals_total and blood_cleaned >= blood_total
	var f2_done = true
	if current_day >= 3:
		f2_done = (f2_terminals_done >= f2_terminals_needed) and f2_usb_done and f2_dossier_done and f2_coolant_done
	if f1_done and f2_done:
		if current_phase == Phase.WORK:
			if NetworkManager.is_multiplayer_active:
				NetworkManager.notify_chase_trigger()
			_trigger_chase_phase()

func _on_secret_corridor_state_changed(inside: bool) -> void:
	if inside:
		hud.show_toast("ENTERED OMEGA SANCTUARY — PURSUIT & STEP COUNTER PAUSED", Color(0.35, 0.95, 0.75))
	else:
		hud.show_toast("LEFT OMEGA SANCTUARY — CONTAINMENT BREACH ACTIVE", Color(1.0, 0.45, 0.35))

func _on_pedestal_activated(ped_id: int, total_activated: int) -> void:
	pedestals_sealed = total_activated
	var ped_msgs = [
		"PEDESTAL I SEALED: Every janitor's debt was fabricated to bind a host.",
		"PEDESTAL II SEALED: Subject Zero was Founder Aldric Aethelgard.",
		"PEDESTAL III SEALED: All 3 Sanctuary Seals aligned — The True Ending is unlocked!"
	]
	var msg = ped_msgs[clampi(ped_id - 1, 0, ped_msgs.size() - 1)]
	hud.show_toast(msg, Color(0.25, 1.0, 0.65))
	if total_activated >= 3 and total_relics_career < 15:
		total_relics_career = 15
		_update_hud_objectives()

func _trigger_chase_phase() -> void:
	if current_phase == Phase.CHASE:
		return
	current_phase = Phase.CHASE
	if map_gen.has_method("set_keycards_visible"):
		map_gen.set_keycards_visible(keycards_collected < keycards_total)
	SoundEffects.stop_music()
	_refresh_minimap()

	hud.play_cutscene("chaseBegin", func():
		map_gen.shatter_biotank()
		if map_gen.has_method("set_keycards_visible"):
			map_gen.set_keycards_visible(keycards_collected < keycards_total)
		SoundEffects.start_siren()
		SoundEffects.start_chase_music()
		map_gen.set_emergency_lighting(true)
		hud.set_phase_presentation("chase", current_day)
		player.reset_step_tracker()

		if is_instance_valid(hunter):
			_teleport_hunter_furthest_from_player()
			hunter.activate()
		for statue in statues:
			if is_instance_valid(statue):
				statue.activate()
		for cr in crawlers:
			if is_instance_valid(cr):
				cr.activate()
		for cu in cultists:
			if is_instance_valid(cu):
				cu.activate()

		# Floor 2 monsters spawn and emerge during Chase Phase only
		_spawn_floor2_monsters()

		hud.show_toast("⚠ CONTAINMENT BREACH! CAGES UNLOCKED — COLLECT 3 KEYCARDS!", Color(1.0, 0.25, 0.25))
		_update_hud_objectives()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if dev_panel_visible else Input.MOUSE_MODE_CAPTURED
		_refresh_minimap()
	)

func _teleport_hunter_furthest_from_player() -> void:
	if not is_instance_valid(hunter):
		return
	var furthest_pos := Vector3.ZERO
	var max_dist_sq := -1.0
	var p_pos := player.global_position if is_instance_valid(player) else Vector3(4.0, 0.0, 4.0)
	var U := GameData.UNIT

	var grid: Array = maze_grid
	if grid.is_empty() and current_day >= 1 and current_day <= GameData.ALL_MAZES.size():
		grid = GameData.ALL_MAZES[current_day - 1]

	if not grid.is_empty():
		var S = grid.size()
		for r in range(1, S - 1):
			for c in range(1, S - 1):
				if grid[r][c] == 0:
					var cell_world = Vector3(float(c) * U, 0.0, float(r) * U)
					var d2 = Vector2(cell_world.x - p_pos.x, cell_world.z - p_pos.z).length_squared()
					if d2 > max_dist_sq:
						max_dist_sq = d2
						furthest_pos = cell_world
	elif not open_spawn_cells.is_empty():
		for pos in open_spawn_cells:
			var d2 = Vector2(pos.x - p_pos.x, pos.z - p_pos.z).length_squared()
			if d2 > max_dist_sq:
				max_dist_sq = d2
				furthest_pos = pos

	if furthest_pos != Vector3.ZERO:
		hunter.global_position = Vector3(furthest_pos.x, 0.0, furthest_pos.z)
		hunter.velocity = Vector3.ZERO
		var to_p = p_pos - hunter.global_position
		to_p.y = 0.0
		if to_p.length_squared() > 0.01:
			hunter.rotation.y = atan2(-to_p.x, -to_p.z)

func _on_keycard_collected() -> void:
	keycards_collected += 1
	if NetworkManager.is_multiplayer_active:
		NetworkManager.collect_keycard(keycards_collected - 1, NetworkManager.get_local_peer_id())
	_update_hud_objectives()
	hud.update_chase_distance(chase_distance, max_chase_distance, _get_hunter_steps_away(), keycards_collected, keycards_total)
	hud.show_toast("SECURITY KEYCARD ACQUIRED (%d / %d)" % [keycards_collected, keycards_total], Color(1.0, 0.9, 0.2))
	_refresh_minimap()

func _on_exit_reached() -> void:
	if hud.cutscene_player.visible:
		return
	if current_phase == Phase.WORK:
		if current_day >= 3:
			hud.show_toast("COMPLETE 1F & 2F LAB TASKS BEFORE EVACUATING!", Color(1.0, 0.75, 0.2))
		else:
			hud.show_toast("COMPLETE SHIFT QUOTA (3 SPILLS, 3 BLOOD STAINS & 2 TERMINALS) BEFORE LEAVING!", Color(1.0, 0.75, 0.2))
		SoundEffects.play(SoundEffects.snd_click, 2.0)
		return

	if keycards_collected < keycards_total:
		if _exit_block_cooldown > 0.0:
			hud.show_toast("EXIT LOCKED: %d / %d Keycards Collected!" % [keycards_collected, keycards_total], Color(1.0, 0.8, 0.1))
			SoundEffects.play(SoundEffects.snd_click, 2.0)
			return
		_exit_block_cooldown = 4.5
		if player and "interact_cooldown" in player:
			player.interact_cooldown = 0.8
		hud.dist_warning.text = "EXIT LOCKED: %d / %d Keycards Collected!" % [keycards_collected, keycards_total]
		hud.dist_warning.modulate = Color(1.0, 0.8, 0.1)
		SoundEffects.play(SoundEffects.snd_click, 2.0)
		hud.play_cutscene("entityBlocksDoor", func():
			_exit_block_cooldown = 3.5
			if player and "interact_cooldown" in player:
				player.interact_cooldown = 0.8
			# Drive player back 1.8m from the exit door so they aren't pressed against the trigger
			if player:
				var back_dir = player.global_transform.basis.z
				back_dir.y = 0.0
				if back_dir.length_squared() > 0.01:
					player.velocity = back_dir.normalized() * 12.0
					player.move_and_slide()
					player.velocity = Vector3.ZERO
					player.reset_step_tracker()
			hud.flash_damage()
			_modify_chase_steps(-30)
			hud.show_toast("THE ENTITY DROVE YOU BACK! — FIND ALL %d KEYCARDS!" % keycards_total, Color(1.0, 0.25, 0.25))
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if dev_panel_visible else Input.MOUSE_MODE_CAPTURED
		)
		return

	# Shift survived! Award $100 nightly shift pay
	wages += 100
	SoundEffects.stop_siren()
	SoundEffects.stop_music()
	SoundEffects.play(SoundEffects.snd_pickup, 4.0)

	if NetworkManager.is_multiplayer_active:
		var pid = NetworkManager.get_local_peer_id()
		if NetworkManager.connected_players.has(pid):
			NetworkManager.connected_players[pid]["wages"] = wages
		if NetworkManager.is_host:
			NetworkManager.broadcast_night_leaderboard(current_day == GameData.TOTAL_DAYS)
		return

	if current_day < GameData.TOTAL_DAYS:
		var interlude_id = "interlude%d" % (current_day - 1)
		hud.play_cutscene("nextDay", func():
			hud.play_cutscene(interlude_id, func():
				current_day += 1
				_setup_world_for_day(current_day)
				hud.show_shift_gate(current_day, func():
					_start_work_shift()
				)
			)
		)
	else:
		var is_true_ending = (total_relics_career >= 15) or (pedestals_sealed >= 3)
		var ending_cutscene = "endingEarth" if is_true_ending else "endingFired"
		wages += 2500 if is_true_ending else 1000000000
		hud.play_cutscene(ending_cutscene, func():
			hud.game_hud.visible = false
			var title_str = "THE KEEPER OF THE SEAL" if is_true_ending else "FAKE VICTORY — GLOBAL BROADCAST"
			var summary_str = ""
			if is_true_ending:
				summary_str = "ALL 5 NIGHTS SURVIVED\nTotal Career Wages: $%d\nRelics / Sanctuary Seals: %d / 15 (3/3 Pedestals)\nEnding: TRUE ENDING (THE SEAL HOLDS — EARTH IS SAVED)" % [
					wages,
					total_relics_career
				]
			else:
				summary_str = "ALL 5 NIGHTS SURVIVED\nContract Bonus Credited: $1,000,000,000 ($1 BILLION) [VOIDED BY ENTITY]\nRelics Recovered: %d / 15\nEnding: FAKE ENDING — THE ENTITY BROADCAST THROUGH EVERY SCREEN ON EARTH" % [
					total_relics_career
				]
			hud.show_victory_summary(title_str, summary_str, is_true_ending)
		)

func _on_crawler_bitten_player(crawler_node: Node3D) -> void:
	if player.is_hiding or player.in_bite_sequence or player.in_death_sequence:
		return
	if not dev_god_mode:
		crawler_bites += 1
	hud.flash_damage()
	hud.show_toast("IT LATCHED ONTO YOU!", Color(1.0, 0.25, 0.25))
	var is_fatal = (crawler_bites >= GameData.CRAWLER_BITE_MAX) and not dev_god_mode
	player.start_crawler_bite_sequence(crawler_node, crawler_bites, is_fatal)
	_update_hud_objectives()

func _on_player_bite_sequence_finished(_bite_count: int, fatal: bool) -> void:
	_update_hud_objectives()
	if fatal and not dev_god_mode:
		game_over("FOUR BITES — THE VENOM FINISHED WHAT THE DARK BEGAN.")

func game_over(reason: String) -> void:
	if dev_god_mode:
		return
	if NetworkManager and NetworkManager.is_multiplayer_active:
		_enter_spectator_mode(reason)
		return
	is_game_over = true
	if player:
		if player.has_method("mark_dead"):
			player.mark_dead()
		elif player.has_method("reset_special_sequences"):
			player.reset_special_sequences()
	_freeze_all_monsters(true)
	SoundEffects.stop_siren()
	SoundEffects.stop_music()
	SoundEffects.play(SoundEffects.snd_screech, 4.0)
	hud.game_over_msg.text = "%s\n(Night %d  •  Wages: $%d)" % [reason, current_day, wages]
	hud.game_over_screen.visible = true
	hud.game_hud.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ENTER, KEY_KP_ENTER:
				if NetworkManager and NetworkManager.is_multiplayer_active and hud.game_hud.visible:
					if hud.is_chat_focused():
						hud.submit_current_chat()
					else:
						hud.open_chat_input()
					get_viewport().set_input_as_handled()
					return
			KEY_ESCAPE:
				if hud.is_chat_focused():
					hud.close_chat_input()
					get_viewport().set_input_as_handled()
					return
				if hud.quit_warning_modal and hud.quit_warning_modal.visible:
					hud.quit_warning_modal.visible = false
					_on_quit_modal_dismissed()
				elif hud.game_over_screen and hud.game_over_screen.visible:
					_quit_to_menu()
				elif hud.note_popup.visible:
					hud.hide_note_popup()
				elif dev_panel_visible:
					_hide_dev_panel()
				elif hud.game_hud.visible and not hud.cutscene_player.visible and not is_game_over:
					_attempt_pause()
			KEY_A, KEY_LEFT:
				if is_spectating:
					_cycle_spectator_target(-1)
					get_viewport().set_input_as_handled()
			KEY_D, KEY_RIGHT:
				if is_spectating:
					_cycle_spectator_target(1)
					get_viewport().set_input_as_handled()
			KEY_F9:
				get_viewport().set_input_as_handled()
				_toggle_dev_panel()
	elif event is InputEventMouseButton and event.pressed:
		if is_spectating:
			_cycle_spectator_target(1 if event.button_index == MOUSE_BUTTON_LEFT else -1)
			get_viewport().set_input_as_handled()

# Meta-Horror Pause System ported from HTML attemptPause() (lines 4376-4402)
func _attempt_pause() -> void:
	if get_tree().paused:
		_resume_from_pause()
		return
	if current_phase == Phase.WORK:
		get_tree().paused = true
		hud.set_pause_warning_text("Shift paused. Resume when you are ready.")
		hud.pause_menu.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return

	if player and (player.in_death_sequence or player.in_bite_sequence):
		return

	var d: int = 999 if (player and player.is_hiding) else min(chase_distance, _get_hunter_steps_away())
	if d < 6 and not dev_god_mode:
		SoundEffects.play_hunter_screech()
		if is_instance_valid(hunter) and hunter.has_method("start_kill"):
			hunter.start_kill("claw", "FATAL: You paused while the Entity was < 6 steps away. Instant harvest.")
		else:
			game_over("FATAL: You paused while the Entity was < 6 steps away. Instant harvest.")
	elif d <= 12 and not dev_god_mode:
		SoundEffects.play_hunter_screech()
		hud.flash_damage()
		_modify_chase_steps(-10)
		hud.show_toast("Entity sensed your hesitation! (-10 steps)", Color(1.0, 0.25, 0.25))
	else:
		get_tree().paused = true
		hud.set_pause_warning_text("Safe pause — Entity is beyond 12 steps.")
		hud.pause_menu.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _resume_from_pause() -> void:
	get_tree().paused = false
	hud.pause_menu.visible = false
	if hud.quit_warning_modal:
		hud.quit_warning_modal.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if dev_panel_visible else Input.MOUSE_MODE_CAPTURED

# Meta-Horror Quit Escalation ported from HTML handleQuitAttempt() & performEntityIntrusion() (lines 4318-4372)
func _handle_quit_attempt() -> void:
	if is_game_over or (hud.game_over_screen and hud.game_over_screen.visible) or (player and (player.get("is_dead") == true)) or current_phase != Phase.CHASE:
		_quit_to_menu()
		return

	quit_attempts += 1
	if quit_attempts == 1:
		SoundEffects.play(SoundEffects.snd_click, 3.0, 0.65)
		hud.show_quit_warning_modal(
			"YOU DON'T HAVE THE AUTHORITY TO LEAVE JUST YET.",
			"First notice: your performance is still in progress."
		)
		return

	var heading = "THE AUDIENCE HAS LOST ITS PATIENCE." if quit_attempts >= 3 else "YOUR RESIGNATION HAS BEEN DENIED."
	var body = "FINAL ORDER. The Entity will now conclude the performance." if quit_attempts >= 4 else "The Entity has noticed. Do not mistake this warning for a menu option."
	hud.show_quit_warning_modal(heading, body)
	_perform_entity_intrusion(quit_attempts)

func _perform_entity_intrusion(attempt: int) -> void:
	SoundEffects.play_hunter_screech()
	hud.flash_damage()
	hud.set_pause_warning_text("The Entity has noticed your repeated attempts to leave.")

	# Unpause SceneTree so the player sees Subject Zero intrude 2.0m right in front of them!
	get_tree().paused = false
	hud.pause_menu.visible = false

	var old_pos := Vector3.ZERO
	if is_instance_valid(hunter) and player:
		old_pos = hunter.global_position
		var fwd = -player.global_transform.basis.z
		fwd.y = 0.0
		if fwd.length_squared() < 0.01:
			fwd = Vector3.FORWARD
		else:
			fwd = fwd.normalized()
		hunter.global_position = player.global_position + fwd * 2.0
		hunter.global_position.y = player.global_position.y
		var to_p = player.global_position - hunter.global_position
		hunter.rotation.y = atan2(-to_p.x, -to_p.z)

	var death_chance: float = 1.0 if attempt >= 4 else (0.70 if attempt == 3 else 0.35)
	if randf() < death_chance and not dev_god_mode:
		get_tree().create_timer(0.85).timeout.connect(func():
			if current_phase == Phase.CHASE and hud.game_hud.visible:
				if hud.quit_warning_modal:
					hud.quit_warning_modal.visible = false
				if is_instance_valid(hunter) and hunter.has_method("start_kill"):
					hunter.start_kill("claw", "TERMINATION ORDER: The Entity crossed the boundary and ended your performance.")
				else:
					game_over("TERMINATION ORDER: The Entity crossed the boundary and ended your performance.")
		)
	else:
		var step_penalty: int = -30 if attempt >= 3 else -20
		_modify_chase_steps(step_penalty)
		hud.show_toast("THE ENTITY REJECTED YOUR RESIGNATION. (%d STEPS)" % step_penalty, Color(1.0, 0.25, 0.25))
		get_tree().create_timer(1.4).timeout.connect(func():
			if is_instance_valid(hunter) and old_pos != Vector3.ZERO and not (player and player.in_death_sequence):
				hunter.global_position = old_pos
		)

func _on_quit_modal_dismissed() -> void:
	if hud.game_hud.visible and current_phase == Phase.CHASE:
		get_tree().paused = false
		hud.pause_menu.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# F9 Dev Mode Panel: NEVER freezes get_tree().paused so gameplay and testing remain live!
func _toggle_dev_panel() -> void:
	dev_panel_visible = !dev_panel_visible
	if dev_panel_visible:
		if not _dev_ever_opened:
			_dev_ever_opened = true
			dev_show_steps_hud = true
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		hud.show_dev_panel(dev_god_mode, dev_freeze_entity, dev_noclip, dev_show_steps_hud)
		_update_hud_objectives()
		hud.update_chase_distance(chase_distance, max_chase_distance, _get_hunter_steps_away(), keycards_collected, keycards_total)
	else:
		_hide_dev_panel()

func _hide_dev_panel() -> void:
	dev_panel_visible = false
	hud.hide_dev_panel(dev_show_steps_hud)
	_update_hud_objectives()
	hud.update_chase_distance(chase_distance, max_chase_distance, _get_hunter_steps_away(), keycards_collected, keycards_total)
	var gate_vis = hud.shift_gate_panel and hud.shift_gate_panel.visible
	var qw_vis = hud.quit_warning_modal and hud.quit_warning_modal.visible
	if not hud.pause_menu.visible and not hud.main_menu.visible and not hud.cutscene_player.visible and not hud.note_popup.visible and not hud.game_over_screen.visible and not hud.victory_screen.visible and not gate_vis and not qw_vis:
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_dev_test_cutscene(cutscene_id: String) -> void:
	_hide_dev_panel()
	hud.play_cutscene(cutscene_id, func():
		if hud.game_hud.visible:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	)

func _on_dev_god_toggled(enabled: bool) -> void:
	dev_god_mode = enabled
	if player and "god_mode" in player:
		player.god_mode = enabled
		if enabled:
			player.stamina = player.max_stamina
			crawler_bites = 0
			_update_hud_objectives()
	hud.show_toast("DEV: GOD MODE %s" % ("ON (INVINCIBLE + ∞ STAMINA)" if enabled else "OFF"), Color(0.3, 1.0, 0.55) if enabled else Color(0.95, 0.65, 0.35))

func _on_dev_freeze_toggled(enabled: bool) -> void:
	dev_freeze_entity = enabled
	if is_instance_valid(hunter) and hunter.has_method("set_freeze"):
		hunter.set_freeze(enabled)
	for statue in statues:
		if is_instance_valid(statue) and statue.has_method("set_freeze"):
			statue.set_freeze(enabled)
	for cr in crawlers:
		if is_instance_valid(cr) and cr.has_method("set_freeze"):
			cr.set_freeze(enabled)
	for cu in cultists:
		if is_instance_valid(cu) and cu.has_method("set_freeze"):
			cu.set_freeze(enabled)
	for clk in cloaks:
		if is_instance_valid(clk) and clk.has_method("set_freeze"):
			clk.set_freeze(enabled)
	for hgr in hangers:
		if is_instance_valid(hgr) and "frozen_by_dev" in hgr:
			hgr.frozen_by_dev = enabled
	hud.show_toast("DEV: FREEZE ENTITIES %s" % ("ON" if enabled else "OFF"), Color(0.35, 0.9, 1.0) if enabled else Color(0.95, 0.65, 0.35))

func _on_dev_noclip_toggled(enabled: bool) -> void:
	dev_noclip = enabled
	if player and player.has_method("set_noclip"):
		player.set_noclip(enabled)
	hud.show_toast("DEV: NOCLIP %s" % ("ON (WALK THROUGH WALLS)" if enabled else "OFF"), Color(0.85, 0.55, 1.0) if enabled else Color(0.95, 0.65, 0.35))

func _on_dev_steps_hud_toggled(enabled: bool) -> void:
	dev_show_steps_hud = enabled
	hud.set_dev_mode_active(enabled)
	_update_hud_objectives()
	hud.update_chase_distance(chase_distance, max_chase_distance, _get_hunter_steps_away(), keycards_collected, keycards_total)
	hud.show_toast("DEV: STEP COUNTER HUD %s" % ("VISIBLE" if enabled else "HIDDEN"), Color(0.95, 0.85, 0.25))

func _on_dev_force_chase() -> void:
	_hide_dev_panel()
	if current_phase == Phase.WORK:
		spills_cleaned = spills_total
		blood_cleaned = max(blood_cleaned, blood_total)
		terminals_checked = terminals_total
		_trigger_chase_phase()
	else:
		chase_distance = max_chase_distance
		if map_gen.has_method("set_keycards_visible"):
			map_gen.set_keycards_visible(keycards_collected < keycards_total)
		_update_hud_objectives()
		hud.update_chase_distance(chase_distance, max_chase_distance, _get_hunter_steps_away(), keycards_collected, keycards_total)
		hud.show_toast("DEV: CHASE RESET TO %d STEPS" % max_chase_distance, Color(1.0, 0.5, 0.25))

func _on_dev_complete_objectives() -> void:
	if current_phase == Phase.WORK:
		_hide_dev_panel()
		spills_cleaned = spills_total
		blood_cleaned = max(blood_cleaned, blood_total)
		terminals_checked = terminals_total
		_update_hud_objectives()
		_refresh_minimap()
		_check_work_complete()
	else:
		_on_dev_give_keycards()

func _on_dev_give_keycards() -> void:
	keycards_collected = keycards_total
	if map_gen.has_method("set_keycards_visible"):
		map_gen.set_keycards_visible(false)
	_update_hud_objectives()
	hud.update_chase_distance(chase_distance, max_chase_distance, _get_hunter_steps_away(), keycards_collected, keycards_total)
	_refresh_minimap()
	hud.show_toast("DEV: ALL 3 KEYCARDS COLLECTED!", Color(1.0, 0.9, 0.2))

func _on_dev_tp_exit() -> void:
	_hide_dev_panel()
	var exit_pos = map_gen.get_exit_position()
	if exit_pos != Vector3.ZERO:
		player.global_position = exit_pos + Vector3(0, 0.5, 0)
		player.reset_step_tracker()

func _on_dev_skip_day() -> void:
	_hide_dev_panel()
	current_phase = Phase.CHASE
	keycards_collected = keycards_total
	_on_exit_reached()

func _on_dev_jump_day(day_num: int) -> void:
	_hide_dev_panel()
	_setup_world_for_day(day_num)
	_start_work_shift()

func _on_dev_spawn_crawler() -> void:
	_hide_dev_panel()
	var pos = player.global_position - player.global_transform.basis.z * 3.5
	pos.y = 0.05
	var cr = _create_crawler(pos)
	cr.activate()
	crawlers.append(cr)
	hud.show_toast("SPAWNED ACTIVE CRAWLER", Color(1.0, 0.7, 0.2))

func _on_dev_spawn_cultist() -> void:
	_hide_dev_panel()
	var pos = player.global_position - player.global_transform.basis.z * 3.8
	pos.y = 0.05
	var cu = _create_cultist(pos)
	cu.activate()
	cultists.append(cu)
	hud.show_toast("SPAWNED ACTIVE CULTIST", Color(1.0, 0.3, 0.3))

func _on_dev_spawn_cloak() -> void:
	_hide_dev_panel()
	var pos = player.global_position - player.global_transform.basis.z * 4.2
	pos.y = 0.05
	var clk = _create_cloak(pos)
	clk.activate()
	cloaks.append(clk)
	hud.show_toast("SPAWNED FLOATING CLOAK (NEUTRAL CAMOUFLAGE SHROUD)", Color(0.75, 0.55, 1.0))

func _on_dev_spawn_hanger() -> void:
	_hide_dev_panel()
	var ceil_y = 15.4 if player.global_position.y >= 6.0 else 3.8
	var pos = Vector3(player.global_position.x, ceil_y, player.global_position.z)
	var hgr = _create_hanger(pos)
	hangers.append(hgr)
	hud.show_toast("SPAWNED CEILING HANGER AT ELEVATION %.1fm" % ceil_y, Color(0.95, 0.4, 0.2))

func _on_dev_repair_mop() -> void:
	mop_integrity = 100.0
	bait_count = 3
	hud.update_mop_integrity(mop_integrity, 100.0)
	_update_hud_objectives()
	hud.show_toast("MOP REPAIRED & BAIT REFILLED!", Color(0.3, 1.0, 0.5))

func _on_dev_unlock_map() -> void:
	if hud.minimap and hud.minimap.has_method("reveal_entire_map"):
		hud.minimap.reveal_entire_map()
	hud.show_toast("FULL SECTOR MINIMAP REVEALED", Color(0.3, 0.9, 1.0))

func _refresh_minimap() -> void:
	var interactables = map_gen.get_interactable_list()
	hud.update_minimap_interactables(interactables, current_phase == Phase.CHASE)

func _quit_to_menu() -> void:
	is_game_over = false
	quit_attempts = 0
	get_tree().paused = false
	_freeze_all_monsters(false)
	if NetworkManager.is_multiplayer_active:
		_on_mp_leave_room()
	if player and player.has_method("reset_special_sequences"):
		player.reset_special_sequences()
	SoundEffects.stop_siren()
	SoundEffects.stop_music()
	hud.pause_menu.visible = false
	hud.game_over_screen.visible = false
	hud.victory_screen.visible = false
	hud.hide_mp_scoreboard()
	hud.hide_mp_lobby()
	hud.hide_multiplayer_menu()
	hud.game_hud.visible = false
	hud.main_menu.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for child in entities.get_children():
		child.queue_free()
	hunter = null
	light_eater = null
	statues.clear()
	crawlers.clear()
	cultists.clear()
	cloaks.clear()
	hangers.clear()

func _create_hunter(pos: Vector3) -> CharacterBody3D:
	var h = CharacterBody3D.new()
	h.set_script(HunterScript)
	h.player = player
	h.map_gen = map_gen
	h.maze_grid = maze_grid
	h.position = pos
	h.set_freeze(dev_freeze_entity)

	var col = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = 0.52
	shape.height = 2.2
	col.shape = shape
	col.position.y = 1.1
	h.add_child(col)

	h.player_caught.connect(func(reason: String = "HARVESTED BY SUBJECT ZERO — THE HUNTER CAUGHT YOU."):
		game_over(reason)
	)

	entities.add_child(h)
	return h

func _create_statue(pos: Vector3) -> CharacterBody3D:
	var s = CharacterBody3D.new()
	s.set_script(StatueScript)
	s.player = player
	s.position = pos
	s.set_freeze(dev_freeze_entity)

	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(0.75, 2.1, 0.75)
	col.shape = shape
	col.position.y = 1.05
	s.add_child(col)

	s.player_caught.connect(func(reason: String = "YOUR NECK SNAPPED IN THE DARK — YOU BLINKED NEAR AN OBSERVER."):
		game_over(reason)
	)

	entities.add_child(s)
	return s

func _create_crawler(pos: Vector3) -> CharacterBody3D:
	var cr = CharacterBody3D.new()
	cr.set_script(CrawlerScript)
	cr.player = player
	cr.position = pos
	cr.set_freeze(dev_freeze_entity)

	var col = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 0.38
	col.shape = shape
	col.position.y = 0.38
	cr.add_child(col)

	cr.player_bitten.connect(func(node):
		_on_crawler_bitten_player(node)
	)

	entities.add_child(cr)
	return cr

func _create_cultist(pos: Vector3) -> CharacterBody3D:
	var cu = CharacterBody3D.new()
	cu.set_script(CultistScript)
	cu.player = player
	cu.position = pos
	cu.set_freeze(dev_freeze_entity)

	var col = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = 0.42
	shape.height = 1.9
	col.shape = shape
	col.position.y = 0.95
	cu.add_child(col)

	cu.player_killed.connect(func(reason):
		game_over(reason)
	)

	entities.add_child(cu)
	return cu

func _create_cloak(pos: Vector3) -> CharacterBody3D:
	var clk = CharacterBody3D.new()
	clk.set_script(CloakScript)
	clk.player = player
	clk.maze_grid = maze_grid
	clk.position = pos
	clk.set_freeze(dev_freeze_entity)

	clk.player_killed.connect(func(reason):
		game_over(reason)
	)

	entities.add_child(clk)
	return clk

func _create_hanger(pos: Vector3) -> CharacterBody3D:
	var h = CharacterBody3D.new()
	h.set_script(HangerScript)
	h.position = pos
	h.ceiling_y = pos.y
	if "frozen_by_dev" in h:
		h.frozen_by_dev = dev_freeze_entity
	entities.add_child(h)
	return h

func _spawn_floor2_monsters() -> void:
	if f2_walkways_cached.is_empty() or current_day < 3:
		return

	# Hangers clinging to the 15.4m ceiling above Floor 2
	var num_f2_hangers = 2 if current_day >= 4 else 1
	var h_step = max(1, f2_walkways_cached.size() / (num_f2_hangers + 1))
	for i in range(num_f2_hangers):
		var w_pos: Vector3 = f2_walkways_cached[((i + 1) * h_step) % f2_walkways_cached.size()]
		var h_pos = Vector3(w_pos.x, 15.4, w_pos.z)
		var hgr = _create_hanger(h_pos)
		hangers.append(hgr)

	# Additional Cultists patrolling Floor 2 Observation Lab
	var num_f2_cultists = 2 if current_day >= 3 else 1
	var c_step = max(1, f2_walkways_cached.size() / (num_f2_cultists + 2))
	for i in range(num_f2_cultists):
		var w_pos: Vector3 = f2_walkways_cached[((i + 2) * c_step) % f2_walkways_cached.size()]
		var cu_pos = Vector3(w_pos.x, 11.45, w_pos.z)
		var cu = _create_cultist(cu_pos)
		cu.activate()
		cultists.append(cu)

	# Spawn Light Eater on Floor 2 (Night 3+)
	var le_idx = f2_walkways_cached.size() / 2
	var le_pos: Vector3 = f2_walkways_cached[le_idx] + Vector3(0.0, 0.5, 0.0)
	light_eater = _create_light_eater(le_pos)

func _create_light_eater(pos: Vector3) -> CharacterBody3D:
	var le = CharacterBody3D.new()
	le.set_script(LightEaterScript)
	le.position = pos
	le.player = player
	le.add_to_group("light_eaters")
	entities.add_child(le)
	le.activate()
	return le

func _trigger_camping_penalty(target_pos: Vector3) -> void:
	# Anti-Camping / Prolonged Inaction: Spawn corridor reinforcement monster at a fair distance (16m-26m)
	var spawn_pos = target_pos + Vector3(randf_range(-18.0, 18.0), 0.0, randf_range(-18.0, 18.0))
	if not open_spawn_cells.is_empty():
		var best_p = target_pos
		for p in open_spawn_cells:
			var d = p.distance_to(target_pos)
			if d >= 16.0 and d <= 26.0:
				best_p = p
				break
		spawn_pos = best_p

	var choice = randi() % 3
	if choice == 0:
		var cr = _create_crawler(spawn_pos)
		cr.activate()
		crawlers.append(cr)
		hud.show_toast("⚠ BẤT ĐỘNG QUÁ LÂU (>25s) — WALL-CRAWLER TIẾP VIỆN ĐANG SĂN LÙNG!", Color(1.0, 0.25, 0.25), 5.0)
	elif choice == 1:
		var st = _create_statue(spawn_pos)
		st.activate()
		statues.append(st)
		hud.show_toast("⚠ BẤT ĐỘNG QUÁ LÂU (>25s) — TƯỢNG ĐÁ OBSERVER ĐÃ THỨC TỈNH Ở HÀNH LANG!", Color(1.0, 0.25, 0.25), 5.0)
	else:
		var cu = _create_cultist(spawn_pos)
		cu.activate()
		cultists.append(cu)
		hud.show_toast("⚠ BẤT ĐỘNG QUÁ LÂU (>25s) — CULTIST ĐÃ ĐƯỢC ĐIỀU ĐỘNG ĐẾN!", Color(1.0, 0.25, 0.25), 5.0)

	SoundEffects.play_hunter_screech()
	hud.flash_damage()

func _freeze_all_monsters(enabled: bool) -> void:
	if is_instance_valid(hunter) and hunter.has_method("set_freeze"):
		hunter.set_freeze(enabled)
	for statue in statues:
		if is_instance_valid(statue) and statue.has_method("set_freeze"):
			statue.set_freeze(enabled)
	for cr in crawlers:
		if is_instance_valid(cr) and cr.has_method("set_freeze"):
			cr.set_freeze(enabled)
	for cu in cultists:
		if is_instance_valid(cu) and cu.has_method("set_freeze"):
			cu.set_freeze(enabled)
	for clk in cloaks:
		if is_instance_valid(clk) and clk.has_method("set_freeze"):
			clk.set_freeze(enabled)
	for h in hangers:
		if is_instance_valid(h):
			h.set("frozen_by_dev", enabled)
	if is_instance_valid(light_eater):
		light_eater.set_physics_process(not enabled)

# ==============================================================================
# --- MULTIPLAYER CO-OP SESSION HANDLERS ---
# ==============================================================================
func _on_mp_host_room(room_name: String, day_num: int, map_idx: int, task_mult: float, supplies_mult: float) -> void:
	var err = NetworkManager.create_room(room_name, 5)
	if err == OK:
		NetworkManager.mp_selected_day = day_num
		NetworkManager.mp_selected_map_idx = map_idx
		NetworkManager.mp_task_mult = task_mult
		NetworkManager.mp_supplies_mult = supplies_mult
		hud.show_mp_lobby(room_name, day_num, map_idx, task_mult, supplies_mult)
		hud.update_mp_lobby(NetworkManager.connected_players, true)
		var c = NetworkManager.get("room_code") if "room_code" in NetworkManager else NetworkManager.get("current_room_code")
		if c != null and str(c) != "":
			hud.update_lobby_room_code(str(c))
		hud.show_toast("✔ Đã tạo phòng thành công! Phòng đã được phát sóng lên Sảnh Tìm Phòng.", Color(0.2, 1.0, 0.6), 5.0)
	else:
		hud.show_toast("Tạo phòng thất bại: Lỗi %d" % err, Color(1.0, 0.3, 0.3))

func _on_mp_join_code(code_str: String) -> void:
	var clean = code_str.strip_edges().to_upper()
	if clean == "":
		hud.show_toast("Vui lòng nhập mã phòng!", Color(1.0, 0.35, 0.35))
		return

	hud.show_toast("⏳ Đang kết nối vào phòng %s..." % clean, Color(0.2, 0.95, 0.8), 4.0)
	if hud.mp_scan_status:
		hud.mp_scan_status.text = "⏳ Đang kết nối..."

	var err = NetworkManager.join_by_room_code(clean)
	if err != OK:
		hud.show_toast("Không thể kết nối vào phòng: Lỗi %d" % err, Color(1.0, 0.35, 0.35))
		if hud.mp_scan_status:
			hud.mp_scan_status.text = "❌ Không tìm thấy phòng hoặc phòng đã đóng."

func _on_mp_join_room(ip: String, port: int) -> void:
	hud.show_toast("⏳ Đang kết nối vào phòng... (Chờ chủ phòng phản hồi)", Color(0.2, 0.95, 0.8), 6.0)
	if hud.mp_scan_status:
		hud.mp_scan_status.text = "⏳ Đang kết nối..."
	var err = NetworkManager.join_room(ip, port)
	if err != OK:
		hud.show_toast("Không thể gửi yêu cầu kết nối: Lỗi %d" % err, Color(1.0, 0.3, 0.3))

func _on_client_connected_to_host(r_info: Dictionary) -> void:
	var r_name = str(r_info.get("name", "Shift-Room"))
	var day_num = int(r_info.get("day", 1))
	var map_idx = int(r_info.get("map", -1))
	var t_mult = float(r_info.get("task_mult", 1.0))
	var s_mult = float(r_info.get("supplies_mult", 1.0))
	hud.show_mp_lobby(r_name, day_num, map_idx, t_mult, s_mult)
	hud.update_mp_lobby(NetworkManager.connected_players, false)
	hud.update_lobby_room_code("ĐÃ THAM GIA PHÒNG THÀNH CÔNG")
	hud.show_toast("✔ Tham gia phòng thành công!", Color(0.2, 1.0, 0.5))

func _on_mp_connection_failed() -> void:
	hud.hide_mp_lobby()
	hud.show_multiplayer_menu()
	hud.show_toast("❌ Không thể kết nối! Phòng không tồn tại hoặc Host chưa mở.", Color(1.0, 0.35, 0.35), 4.5)
	if hud.mp_scan_status:
		hud.mp_scan_status.text = "❌ Kết nối thất bại. Host không phản hồi."

func _on_mp_server_disconnected() -> void:
	hud.hide_mp_lobby()
	hud.show_multiplayer_menu()
	hud.show_toast("⚠ Mất kết nối tới máy chủ (Host đã rời phòng)!", Color(1.0, 0.45, 0.2), 5.0)

func _on_mp_quick_join() -> void:
	NetworkManager.find_lan_rooms(1.5, func(found_rooms):
		if found_rooms.is_empty():
			hud.mp_scan_status.text = "Không tìm thấy phòng nào đang mở. Hãy đảm bảo chủ phòng đã tạo phòng."
			hud.show_toast("Không tìm thấy phòng nào đang mở trong mạng!", Color(1.0, 0.35, 0.35), 4.0)
		else:
			var target = found_rooms[0]
			hud.mp_scan_status.text = "Đã tìm thấy phòng '%s'! Đang kết nối..." % target.name
			_on_mp_join_room(target.ip, target.port)
	)

func _on_mp_start_shift() -> void:
	if not NetworkManager.is_host:
		return
	var day_num = NetworkManager.mp_selected_day
	var map_idx = NetworkManager.mp_selected_map_idx
	if map_idx < 0:
		map_idx = randi() % GameData.get_map_count_for_day(day_num)
	NetworkManager.host_start_game(day_num, map_idx, NetworkManager.mp_task_mult, NetworkManager.mp_supplies_mult)

func _on_mp_game_started(day_num: int, map_idx: int, _task_mult: float, _supplies_mult: float) -> void:
	hud.hide_mp_lobby()
	hud.hide_multiplayer_menu()
	hud.main_menu.visible = false
	selected_map_index = map_idx
	_setup_world_for_day(day_num)
	_spawn_remote_player_puppets()
	_start_work_shift()

func _spawn_remote_player_puppets() -> void:
	for p_node in remote_players.values():
		if is_instance_valid(p_node):
			p_node.queue_free()
	remote_players.clear()

	var my_id = NetworkManager.get_local_peer_id()
	for pid in NetworkManager.connected_players.keys():
		if pid == my_id:
			continue
		var p_info = NetworkManager.connected_players[pid]
		var r_node = CharacterBody3D.new()
		r_node.set_script(RemotePlayerScript)
		entities.add_child(r_node)
		var p_name = p_info.get("name", "Janitor #%d" % pid)
		var start_pos = player.global_position + Vector3(randf_range(-1.2, 1.2), 0.0, randf_range(-1.2, 1.2))
		r_node.setup_peer(pid, p_name, start_pos)
		remote_players[pid] = r_node

func _on_remote_player_state_updated(pid: int, state: Dictionary) -> void:
	var my_id = NetworkManager.get_local_peer_id()
	if pid == my_id:
		if remote_players.has(my_id):
			if is_instance_valid(remote_players[my_id]):
				remote_players[my_id].queue_free()
			remote_players.erase(my_id)
		return

	if not remote_players.has(pid):
		var p_info = NetworkManager.connected_players.get(pid, {})
		var p_name = p_info.get("name", "Janitor #%d" % pid)
		var r_node = CharacterBody3D.new()
		r_node.set_script(RemotePlayerScript)
		entities.add_child(r_node)
		r_node.setup_peer(pid, p_name, state.get("pos", player.global_position))
		remote_players[pid] = r_node
	var p_puppet = remote_players.get(pid)
	if is_instance_valid(p_puppet):
		p_puppet.update_state(state)

func _on_remote_player_action_received(pid: int, action: String, data: Dictionary) -> void:
	var p_puppet = remote_players.get(pid)
	if is_instance_valid(p_puppet) and p_puppet.has_method("play_action_animation"):
		p_puppet.play_action_animation(action, data)

func _on_remote_spill_cleaned(_spill_pos: Vector3, peer_id: int, is_blood: bool = false) -> void:
	if is_blood:
		blood_cleaned += 1
	else:
		spills_cleaned += 1
	var cleaner_name = "Another Janitor"
	if NetworkManager.connected_players.has(peer_id):
		cleaner_name = NetworkManager.connected_players[peer_id].get("name", "Janitor")
	if is_blood:
		hud.show_toast("✔ %s đã lau sạch một vết máu!" % cleaner_name, Color(0.85, 0.4, 0.5))
	else:
		hud.show_toast("✔ %s sanitized a chemical hazard!" % cleaner_name, Color(0.3, 0.9, 0.7))
	_update_hud_objectives()
	_check_work_complete()

func _on_remote_terminal_checked(_term_pos: Vector3, peer_id: int) -> void:
	terminals_checked += 1
	var cleaner_name = "Another Janitor"
	if NetworkManager.connected_players.has(peer_id):
		cleaner_name = NetworkManager.connected_players[peer_id].get("name", "Janitor")
	hud.show_toast("✔ %s verified a terminal diagnostic!" % cleaner_name, Color(0.2, 0.85, 1.0))
	_update_hud_objectives()
	_check_work_complete()

func _on_remote_keycard_collected(idx: int, peer_id: int) -> void:
	keycards_collected = clampi(keycards_collected + 1, 0, keycards_total)
	var collector_name = "Another Janitor"
	if NetworkManager.connected_players.has(peer_id):
		collector_name = NetworkManager.connected_players[peer_id].get("name", "Janitor")
	hud.show_toast("✔ %s secured Keycard #%d! (%d/%d)" % [collector_name, idx + 1, keycards_collected, keycards_total], Color(1.0, 0.85, 0.2))
	_update_hud_objectives()

func _on_remote_chase_triggered() -> void:
	if current_phase == Phase.WORK:
		hud.show_toast("⚠ BÁO ĐỘNG! MỘT NHÂN VIÊN ĐÃ HOÀN THÀNH CHỈ TIÊU — CẢ PHÒNG BƯỚC VÀO CHASE!", Color(1.0, 0.2, 0.2), 6.0)
		_trigger_chase_phase()

func _on_leaderboard_summary_displayed(stats: Array, is_final_night: bool) -> void:
	hud.show_mp_scoreboard(stats, is_final_night, NetworkManager.is_host)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_mp_leave_room() -> void:
	NetworkManager.leave_room()
	for p_node in remote_players.values():
		if is_instance_valid(p_node):
			p_node.queue_free()
	remote_players.clear()

func _on_mp_toggle_ready(ready_state: bool) -> void:
	NetworkManager.toggle_ready(ready_state)

# --- SPECTATOR & CORPSE SYSTEM ---
func _enter_spectator_mode(reason: String) -> void:
	is_spectating = true
	var d_pos = player.global_position if is_instance_valid(player) else Vector3.ZERO
	var d_rot = player.rotation.y if is_instance_valid(player) else 0.0
	var my_name = NetworkManager.local_player_name if NetworkManager else "Janitor"

	if player:
		if player.has_method("mark_dead"):
			player.mark_dead()
		player.set_physics_process(false)
		player.collision_layer = 0
		player.collision_mask = 0
		if is_instance_valid(player.flashlight):
			player.flashlight.visible = false
		if is_instance_valid(player.arms_root):
			player.arms_root.visible = false

	# Spawn fallen corpse locally
	_spawn_player_corpse(my_name, reason, d_pos, d_rot)

	# Broadcast death to all peers
	if NetworkManager:
		NetworkManager.notify_player_death(NetworkManager.get_local_peer_id(), d_pos, d_rot, reason)
		NetworkManager.send_chat_message("HỆ THỐNG", "✖ [%s] đã tử nạn: %s" % [my_name, reason], true)

	hud.show_toast("☠ BẠN ĐÃ TỬ NẠN! Đang chuyển sang quan sát đồng đội...", Color(1.0, 0.25, 0.25), 4.5)
	_update_spectator_target()

func _update_spectator_target() -> void:
	var targets = _get_living_spectate_targets()
	if targets.is_empty():
		hud.show_spectator_banner("🔴 TẤT CẢ ĐỒNG ĐỘI ĐÃ TỬ NẠN!")
	else:
		if spectate_target_idx >= targets.size():
			spectate_target_idx = 0
		var cur = targets[spectate_target_idx]
		hud.show_spectator_banner("🔴 ĐANG QUAN SÁT: %s\n[A] / [D] hoặc [Click Chuột] để chuyển người" % cur["name"])

func _get_living_spectate_targets() -> Array:
	var list: Array = []
	for pid in remote_players.keys():
		var r_node = remote_players[pid]
		if is_instance_valid(r_node) and r_node.get("is_dead") != true:
			list.append({"node": r_node, "name": r_node.player_name})
	return list

func _cycle_spectator_target(step: int) -> void:
	var targets = _get_living_spectate_targets()
	if targets.is_empty():
		return
	spectate_target_idx = (spectate_target_idx + step) % targets.size()
	if spectate_target_idx < 0:
		spectate_target_idx = targets.size() - 1
	var cur = targets[spectate_target_idx]
	hud.show_spectator_banner("🔴 ĐANG QUAN SÁT: %s\n[A] / [D] hoặc [Click Chuột] để chuyển người" % cur["name"])

func _process_spectator_camera(delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(player.camera):
		return
	var targets = _get_living_spectate_targets()
	if targets.is_empty():
		return
	if spectate_target_idx >= targets.size():
		spectate_target_idx = 0
	var target = targets[spectate_target_idx]["node"]
	if not is_instance_valid(target):
		return

	# Smooth 3rd person follow behind target's back
	var t_pos = target.global_position + Vector3(0, 1.45, 0)
	var cam_offset = -target.global_transform.basis.z * 2.4 + Vector3(0, 0.55, 0)
	var desired = t_pos + cam_offset
	player.camera.global_position = player.camera.global_position.lerp(desired, min(1.0, delta * 12.0))
	player.camera.look_at(t_pos, Vector3.UP)

func _spawn_player_corpse(p_name: String, reason: String, pos: Vector3, rot_y: float) -> void:
	var corpse = Node3D.new()
	corpse.set_script(PlayerCorpseScript)
	corpse.position = pos
	entities.add_child(corpse)
	corpse.setup_corpse(p_name, reason, rot_y)
	spawned_corpses.append(corpse)

func _on_remote_player_died(pid: int, pos: Vector3, rot_y: float, reason: String) -> void:
	var p_puppet = remote_players.get(pid)
	var p_name = "Đồng đội"
	if is_instance_valid(p_puppet):
		p_name = p_puppet.player_name
		if p_puppet.has_method("mark_peer_dead"):
			p_puppet.mark_peer_dead()
	_spawn_player_corpse(p_name, reason, pos, rot_y)
	hud.show_toast("✖ %s đã bị quái vật tiêu diệt!" % p_name, Color(1.0, 0.35, 0.35), 4.5)
	if is_spectating:
		_update_spectator_target()

func _on_all_players_eliminated() -> void:
	is_spectating = false
	is_game_over = true
	_freeze_all_monsters(true)
	hud.hide_spectator_banner()
	SoundEffects.stop_siren()
	SoundEffects.stop_music()
	SoundEffects.play(SoundEffects.snd_screech, 4.0)
	hud.show_toast("☠ TOÀN BỘ ĐỒNG ĐỘI ĐÃ TỬ NẠN!", Color(1.0, 0.2, 0.2), 6.0)
	hud.game_over_msg.text = "TẤT CẢ NHÂN VIÊN ĐỀU ĐÃ BỊ TIÊU DIỆT!\nĐang chuẩn bị đưa toàn đội trở về Sảnh Chờ (Lobby)..."
	hud.game_over_screen.visible = true
	hud.game_hud.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if NetworkManager and NetworkManager.is_host:
		get_tree().create_timer(4.5).timeout.connect(func():
			if NetworkManager:
				NetworkManager.host_return_to_lobby()
		)

func _on_mp_round_restarted(day: int, map_idx: int, _task_mult: float, _supplies_mult: float) -> void:
	is_game_over = false
	is_spectating = false
	quit_attempts = 0
	_clean_up_session_entities()
	_freeze_all_monsters(false)
	hud.game_over_screen.visible = false
	hud.hide_spectator_banner()

	current_day = day
	selected_map_index = map_idx
	_setup_world_for_day(day)
	_spawn_remote_player_puppets()
	_start_work_shift()
	hud.show_toast("🔄 BẮT ĐẦU LẠI CA TRỰC ĐỒNG BỘ CHO CẢ PHÒNG!", Color(0.2, 1.0, 0.6), 5.0)

func _on_return_to_lobby() -> void:
	is_game_over = false
	is_spectating = false
	_clean_up_session_entities()
	_freeze_all_monsters(false)
	hud.game_over_screen.visible = false
	hud.game_hud.visible = false
	hud.hide_spectator_banner()
	if NetworkManager:
		hud.show_mp_lobby(
			NetworkManager.current_room_name,
			NetworkManager.mp_selected_day,
			NetworkManager.mp_selected_map_idx,
			NetworkManager.mp_task_mult,
			NetworkManager.mp_supplies_mult
		)
		hud.update_mp_lobby(NetworkManager.connected_players, NetworkManager.is_host)
	hud.show_toast("Đã đưa toàn đội về sảnh chờ!", Color(0.2, 0.9, 1.0))

func _clean_up_session_entities() -> void:
	for c in spawned_corpses:
		if is_instance_valid(c):
			c.queue_free()
	spawned_corpses.clear()
