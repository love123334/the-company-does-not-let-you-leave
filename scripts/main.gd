extends Node3D

enum Phase { WORK, CHASE }

const HunterScript = preload("res://scripts/hunter.gd")
const StatueScript = preload("res://scripts/statue.gd")
const CrawlerScript = preload("res://scripts/crawler.gd")
const CultistScript = preload("res://scripts/cultist.gd")
const CloakScript = preload("res://scripts/cloak.gd")

var current_day: int = 1
var current_phase: Phase = Phase.WORK

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
var open_spawn_cells: Array[Vector3] = []

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
	hud.quit_modal_dismissed.connect(_on_quit_modal_dismissed)
	hud.retry_clicked.connect(_on_retry_night)
	hud.victory_finish_clicked.connect(_quit_to_menu)
	hud.override_completed.connect(_on_override_completed)

	map_gen.spill_cleaned.connect(_on_spill_cleaned)
	map_gen.terminal_checked.connect(_on_terminal_checked)
	map_gen.relic_collected.connect(_on_relic_collected)
	map_gen.keycard_collected.connect(_on_keycard_collected)
	map_gen.exit_reached.connect(_on_exit_reached)
	map_gen.note_inspected.connect(_on_note_inspected)
	map_gen.gate_toggled.connect(func(_closed): _refresh_minimap())
	map_gen.secret_corridor_state_changed.connect(_on_secret_corridor_state_changed)
	map_gen.pedestal_activated.connect(_on_pedestal_activated)

	player.step_taken.connect(_on_player_step_taken)
	player.locker_state_changed.connect(_on_player_locker_state_changed)
	player.mop_strike_requested.connect(_on_player_mop_strike)
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
	var maze_grid = GameData.ALL_MAZES[current_day - 1]

	spills_cleaned = 0
	spills_total = 3
	blood_cleaned = 0
	blood_total = 3
	terminals_checked = 0
	terminals_total = 2
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
	if player.is_hiding:
		player.exit_locker()
	hud.set_locker_overlay(false)
	map_gen.set_emergency_lighting(false)

	statues.clear()
	crawlers.clear()
	cultists.clear()
	cloaks.clear()
	hunter = null
	for child in entities.get_children():
		child.queue_free()

	var spawn_info = map_gen.build_map(maze_grid, player, current_day)
	if map_gen.has_method("set_keycards_visible"):
		map_gen.set_keycards_visible(false)
	if "god_mode" in player:
		player.god_mode = dev_god_mode
	if player.has_method("set_noclip"):
		player.set_noclip(dev_noclip)
	player.reset_step_tracker()
	hud.minimap.init_map(maze_grid, player)
	open_spawn_cells.assign(spawn_info.get("open_positions", []))

	# 1. Spawn Dormant Hunter inside main BioTank
	hunter = _create_hunter(spawn_info["hunter_pos"])

	# 2. Spawn Stone Statues / Observers (Night 2+)
	for s_pos in spawn_info["statue_positions"]:
		var st = _create_statue(s_pos)
		statues.append(st)

	# 3. Spawn Crawlers & Cultists inside Observation Cages (or open cells if more than cages)
	var cage_slots: Array = spawn_info.get("cage_slots", [])
	var slot_idx: int = 0

	var num_crawlers: int = int(day_meta.get("crawlers", 4))
	for i in range(num_crawlers):
		if slot_idx < cage_slots.size():
			var slot = cage_slots[slot_idx]
			slot_idx += 1
			var cr = _create_crawler(slot["caged_pos"])
			cr.setup_caged(slot["caged_pos"], slot["release_pos"], slot["bars_node"], slot["rot"])
			crawlers.append(cr)
		elif not open_spawn_cells.is_empty():
			var pos = open_spawn_cells[i % open_spawn_cells.size()]
			var cr = _create_crawler(pos)
			crawlers.append(cr)

	var num_cultists: int = int(day_meta.get("cultists", 0))
	for i in range(num_cultists):
		if slot_idx < cage_slots.size():
			var slot = cage_slots[slot_idx]
			slot_idx += 1
			if is_instance_valid(slot.get("label")):
				slot["label"].text = "SPECIMEN FILE: HERETIC\nSUB-RING CULTIST\nACTIVE CHANT • LETHAL\nCLEARANCE: OMEGA"
			var cu = _create_cultist(slot["caged_pos"])
			cu.setup_caged(slot["caged_pos"], slot["release_pos"], slot["bars_node"], slot["rot"])
			cultists.append(cu)
		elif not open_spawn_cells.is_empty():
			var pos = open_spawn_cells[(i + 3) % open_spawn_cells.size()]
			var cu = _create_cultist(pos)
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
	hud.game_over_screen.visible = false
	_setup_world_for_day(current_day)
	_start_work_shift()

func _start_work_shift() -> void:
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
	if player and bool(player.get("in_secret_corridor")):
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
		if is_instance_valid(clk) and bool(clk.get("active")):
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
	_update_hud_objectives()
	_check_work_complete()
	_refresh_minimap()

func _on_terminal_checked() -> void:
	terminals_checked += 1
	wages += 25
	hud.show_toast("SCIENCE TERMINAL VERIFIED (%d / %d)" % [terminals_checked, terminals_total], Color(0.3, 0.85, 1.0))
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
		bait_count
	)

func _check_work_complete() -> void:
	if spills_cleaned >= spills_total and terminals_checked >= terminals_total and blood_cleaned >= blood_total:
		if current_phase == Phase.WORK:
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

		hud.show_toast("⚠ CONTAINMENT BREACH! CAGES UNLOCKED — COLLECT 3 KEYCARDS!", Color(1.0, 0.25, 0.25))
		_update_hud_objectives()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if dev_panel_visible else Input.MOUSE_MODE_CAPTURED
		_refresh_minimap()
	)

func _on_keycard_collected() -> void:
	keycards_collected += 1
	_update_hud_objectives()
	hud.update_chase_distance(chase_distance, max_chase_distance, _get_hunter_steps_away(), keycards_collected, keycards_total)
	hud.show_toast("SECURITY KEYCARD ACQUIRED (%d / %d)" % [keycards_collected, keycards_total], Color(1.0, 0.9, 0.2))
	_refresh_minimap()

func _on_exit_reached() -> void:
	if hud.cutscene_player.visible:
		return
	if current_phase == Phase.WORK:
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
	if player and player.has_method("reset_special_sequences"):
		player.reset_special_sequences()
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
			KEY_ESCAPE:
				if hud.quit_warning_modal and hud.quit_warning_modal.visible:
					hud.quit_warning_modal.visible = false
					_on_quit_modal_dismissed()
				elif hud.note_popup.visible:
					hud.hide_note_popup()
				elif dev_panel_visible:
					_hide_dev_panel()
				elif hud.game_hud.visible and not hud.cutscene_player.visible:
					_attempt_pause()
			KEY_F9:
				get_viewport().set_input_as_handled()
				_toggle_dev_panel()

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
	if current_phase != Phase.CHASE:
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
	get_tree().paused = false
	if player and player.has_method("reset_special_sequences"):
		player.reset_special_sequences()
	SoundEffects.stop_siren()
	SoundEffects.stop_music()
	hud.pause_menu.visible = false
	hud.game_over_screen.visible = false
	hud.victory_screen.visible = false
	hud.game_hud.visible = false
	hud.main_menu.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for child in entities.get_children():
		child.queue_free()
	hunter = null
	statues.clear()
	crawlers.clear()
	cultists.clear()
	cloaks.clear()

func _create_hunter(pos: Vector3) -> CharacterBody3D:
	var h = CharacterBody3D.new()
	h.set_script(HunterScript)
	h.player = player
	h.map_gen = map_gen
	h.maze_grid = GameData.ALL_MAZES[clampi(current_day - 1, 0, GameData.ALL_MAZES.size() - 1)]
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
	clk.maze_grid = GameData.ALL_MAZES[clampi(current_day - 1, 0, GameData.ALL_MAZES.size() - 1)]
	clk.position = pos
	clk.set_freeze(dev_freeze_entity)

	clk.player_killed.connect(func(reason):
		game_over(reason)
	)

	entities.add_child(clk)
	return clk
