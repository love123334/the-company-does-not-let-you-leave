extends Node

signal lobby_updated(players: Dictionary)
signal player_joined_lobby(id: int, info: Dictionary)
signal player_left_lobby(id: int)
signal connection_failed()
signal server_disconnected_signal()
signal game_started_signal(day: int, map_idx: int, task_mult: float, supplies_mult: float)
signal remote_player_state_updated(id: int, state: Dictionary)
signal remote_player_action_received(id: int, action: String, data: Dictionary)
signal remote_spill_cleaned(spill_pos: Vector3, peer_id: int)
signal remote_terminal_checked(term_pos: Vector3, peer_id: int)
signal remote_keycard_collected(keycard_idx: int, peer_id: int)
signal remote_chase_triggered()
signal leaderboard_summary_displayed(stats: Array, is_final_night: bool)
signal room_code_ready(code: String)
signal upnp_status_updated(status: String)
signal ip_info_updated(ip_info: String)
signal client_connected_to_host(room_info: Dictionary)
signal chat_message_received(sender: String, message: String, is_system: bool)
signal player_died_signal(peer_id: int, pos: Vector3, rot_y: float, reason: String)
signal all_players_eliminated_signal()
signal round_restarted_signal(day: int, map_idx: int, task_mult: float, supplies_mult: float)
signal return_to_lobby_signal()
signal room_list_updated(rooms: Array)

const DEFAULT_PORT: int = 8910
const BROADCAST_PORT: int = 8911
const RELAY_PORT: int = 8912
const MAX_PLAYERS: int = 5
const CODE_ALPHABET = "23456789ABCDEFGHJKMNPQRSTUVWXYZ"

# ENet / LAN peer
var peer: ENetMultiplayerPeer = null
var is_host: bool = false
var is_multiplayer_active: bool = false
var local_player_name: String = "Janitor #1"
var current_room_name: String = "Facility Shift #101"
var target_host_address: String = ""
var _connect_timeout_timer: SceneTreeTimer = null

# WebSocket Relay Mode
var is_relay_mode: bool = false
var local_peer_id: int = 1
var relay_server_url: String = "ws://127.0.0.1:8912"
var _relay_ws: WebSocketPeer = null
var _browser_ws: WebSocketPeer = null
var _browser_poll_timer: float = 0.0
var _relay_process_pid: int = -1

# Room Code & Info
var current_room_code: String = ""
var room_code: String:
	get:
		return current_room_code
	set(v):
		current_room_code = v

var public_ip: String = ""
var is_upnp_active: bool = false
var upnp_status_text: String = ""
var _upnp_thread: Thread = null
var _http_ip_request: HTTPRequest = null

# All connected players: id -> { "id": int, "name": String, "wages": int, "tasks": int, "stuns": int, "kills": int, "deaths": int, "ready": bool }
var connected_players: Dictionary = {}
var alive_players: Dictionary = {} # peer_id -> bool

# Session game settings
var mp_task_mult: float = 1.0
var mp_supplies_mult: float = 1.0
var mp_selected_day: int = 1
var mp_selected_map_idx: int = -1

# LAN broadcast UDP & Real-time Room Browser
var _udp_server: UDPServer = null
var _udp_peer: PacketPeerUDP = null
var _broadcast_timer: float = 0.0
var _is_browsing: bool = false
var _browser_listener: PacketPeerUDP = null
var _discovered_rooms: Dictionary = {} # "key" -> room_dict

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_load_relay_config()

func _load_relay_config() -> void:
	# Check if custom relay URL is configured in relay_config.json
	var cfg_path = "res://relay_config.json"
	if FileAccess.file_exists(cfg_path):
		var f = FileAccess.open(cfg_path, FileAccess.READ)
		if f:
			var txt = f.get_as_text()
			f.close()
			var data = JSON.parse_string(txt)
			if data is Dictionary and data.has("relay_url"):
				relay_server_url = str(data["relay_url"]).strip_edges()

func get_local_peer_id() -> int:
	if is_relay_mode:
		return local_peer_id
	var uid = multiplayer.get_unique_id()
	return uid if uid != 0 else (1 if is_host else 2)

func cleaner_id_fallback(id: int) -> int:
	return id if id != 0 else get_local_peer_id()

func _process(delta: float) -> void:
	# 1. Process Active WebSocket Relay connection
	if _relay_ws:
		_relay_ws.poll()
		var state = _relay_ws.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			while _relay_ws.get_available_packet_count() > 0:
				var pkt = _relay_ws.get_packet().get_string_from_utf8()
				_handle_relay_packet(pkt)
		elif state == WebSocketPeer.STATE_CLOSED:
			var code = _relay_ws.get_close_code()
			var reason = _relay_ws.get_close_reason()
			_relay_ws = null
			if is_multiplayer_active:
				if not is_host:
					_on_server_disconnected()
				else:
					leave_room()

	# 2. Process Room Browser Queries
	if _is_browsing:
		_browser_poll_timer += delta
		# Poll WebSocket relay browser
		if _browser_ws:
			_browser_ws.poll()
			var b_state = _browser_ws.get_ready_state()
			if b_state == WebSocketPeer.STATE_OPEN:
				while _browser_ws.get_available_packet_count() > 0:
					var b_pkt = _browser_ws.get_packet().get_string_from_utf8()
					_handle_browser_packet(b_pkt)
			elif b_state == WebSocketPeer.STATE_CLOSED:
				_browser_ws = null

		# Periodic query refresh (every 1.5 seconds)
		if _browser_poll_timer >= 1.5:
			_browser_poll_timer = 0.0
			_query_relay_browser()

		# Poll LAN UDP broadcast listener
		if _browser_listener:
			var changed = false
			var now = Time.get_ticks_msec() / 1000.0
			while _browser_listener.get_available_packet_count() > 0:
				var pkt = _browser_listener.get_packet().get_string_from_utf8()
				var parts = pkt.split("|")
				if parts.size() >= 5 and parts[0] == "AGY_ROOM":
					var r_ip = _browser_listener.get_packet_ip()
					var r_port = int(parts[3])
					var r_code = parts[4]
					var r_host = parts[5] if parts.size() >= 6 else "Chủ phòng"
					var r_key = "lan_" + r_code
					_discovered_rooms[r_key] = {
						"name": parts[1],
						"players": parts[2],
						"port": r_port,
						"ip": r_ip,
						"code": r_code,
						"host": r_host,
						"last_seen": now
					}
					changed = true

			# Clean expired rooms (>4s without beacon)
			var expired_keys: Array = []
			for k in _discovered_rooms.keys():
				if now - _discovered_rooms[k].get("last_seen", 0) > 4.0:
					expired_keys.append(k)
			for k in expired_keys:
				_discovered_rooms.erase(k)
				changed = true

			if changed:
				room_list_updated.emit(_discovered_rooms.values())

	# 3. Host broadcasting UDP beacon (if ENet mode)
	if is_host and _udp_peer:
		_broadcast_timer += delta
		if _broadcast_timer >= 0.35:
			_broadcast_timer = 0.0
			var beacon = ("AGY_ROOM|" + current_room_name + "|" + str(connected_players.size()) + "|" + str(DEFAULT_PORT) + "|" + current_room_code + "|" + local_player_name).to_utf8_buffer()
			_udp_peer.set_dest_address("255.255.255.255", BROADCAST_PORT)
			_udp_peer.put_packet(beacon)

# ==============================================================================
# --- CREATE & JOIN ROOM METHODS ---
# ==============================================================================
func create_room(room_name: String, max_p: int = 5, port: int = DEFAULT_PORT) -> Error:
	stop_room_browser()
	leave_room()

	# Try WebSocket Relay Server first (Solution 1)
	var err = _start_relay_host(room_name, max_p)
	if err == OK:
		return OK

	# Fallback to ENet LAN host if relay server is offline
	print("[NetworkManager] Falling back to local ENet LAN server...")
	is_relay_mode = false
	peer = ENetMultiplayerPeer.new()
	var enet_err = peer.create_server(port, clampi(max_p, 2, MAX_PLAYERS))
	if enet_err != OK:
		return enet_err

	multiplayer.multiplayer_peer = peer
	is_host = true
	local_peer_id = 1
	is_multiplayer_active = true
	current_room_name = room_name

	connected_players.clear()
	connected_players[1] = {
		"id": 1,
		"name": local_player_name,
		"wages": 0,
		"tasks": 0,
		"stuns": 0,
		"kills": 0,
		"deaths": 0,
		"ready": true,
		"is_host": true
	}

	_udp_peer = PacketPeerUDP.new()
	_udp_peer.set_broadcast_enabled(true)

	var lan_ip = get_local_lan_ip()
	current_room_code = encode_room_code(lan_ip, port)
	room_code_ready.emit(current_room_code)
	lobby_updated.emit(connected_players)
	return OK

func _ensure_local_relay_server() -> void:
	# Try starting local relay server process if node is available and not already launched
	if _relay_process_pid <= 0:
		var script_path = ProjectSettings.globalize_path("res://server/relay_server.js")
		if FileAccess.file_exists(script_path):
			_relay_process_pid = OS.create_process("node", [script_path])
			print("[NetworkManager] Auto-started Relay Server process PID: ", _relay_process_pid)
			OS.delay_msec(150) # Allow server socket bind

func _start_relay_host(room_name: String, max_p: int) -> Error:
	_ensure_local_relay_server()

	_relay_ws = WebSocketPeer.new()
	var err = _relay_ws.connect_to_url(relay_server_url)
	if err != OK:
		_relay_ws = null
		return err

	is_relay_mode = true
	is_host = true
	local_peer_id = 1
	is_multiplayer_active = true
	current_room_name = room_name

	connected_players.clear()
	connected_players[1] = {
		"id": 1,
		"name": local_player_name,
		"wages": 0,
		"tasks": 0,
		"stuns": 0,
		"kills": 0,
		"deaths": 0,
		"ready": true,
		"is_host": true
	}

	# Wait briefly for open state and send create_room
	var start_t = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_t < 1200:
		_relay_ws.poll()
		if _relay_ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
			var req = JSON.stringify({
				"cmd": "create_room",
				"room_name": room_name,
				"player_name": local_player_name,
				"max_players": max_p,
				"day": mp_selected_day,
				"variant": mp_selected_map_idx
			})
			_relay_ws.send_text(req)
			return OK
		elif _relay_ws.get_ready_state() == WebSocketPeer.STATE_CLOSED:
			break
		OS.delay_msec(20)

	_relay_ws = null
	is_relay_mode = false
	return ERR_CANT_CONNECT

func join_by_room_code(code_str: String) -> Error:
	var clean_code = code_str.strip_edges().to_upper()
	if clean_code == "":
		return ERR_INVALID_PARAMETER

	# If it's a Relay room code (e.g. "AGY-..." or standard code)
	if clean_code.begins_with("AGY-") or (not "." in clean_code and clean_code.length() >= 6):
		return _join_relay_room(clean_code)

	# If it's an IP:Port or encoded IP code, parse and join via direct ENet
	var parsed = parse_room_input(clean_code)
	if not parsed.is_empty():
		return join_room(parsed.get("ip", "127.0.0.1"), parsed.get("port", DEFAULT_PORT))

	# Default try relay with the code
	return _join_relay_room(clean_code)

func _join_relay_room(code_str: String) -> Error:
	stop_room_browser()
	leave_room()

	_relay_ws = WebSocketPeer.new()
	var err = _relay_ws.connect_to_url(relay_server_url)
	if err != OK:
		_relay_ws = null
		return err

	is_relay_mode = true
	is_host = false
	is_multiplayer_active = true
	current_room_code = code_str

	# Wait briefly for connection and send join_room request
	var start_t = Time.get_ticks_msec()
	var sent = false
	while Time.get_ticks_msec() - start_t < 2500:
		_relay_ws.poll()
		if _relay_ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
			if not sent:
				var req = JSON.stringify({
					"cmd": "join_room",
					"room_code": code_str,
					"player_name": local_player_name
				})
				_relay_ws.send_text(req)
				sent = true
			if _relay_ws.get_available_packet_count() > 0:
				var pkt = _relay_ws.get_packet().get_string_from_utf8()
				_handle_relay_packet(pkt)
				if not connected_players.is_empty():
					return OK
		elif _relay_ws.get_ready_state() == WebSocketPeer.STATE_CLOSED:
			break
		OS.delay_msec(20)

	if connected_players.is_empty():
		leave_room()
		return ERR_CANT_CONNECT
	return OK

func join_room(ip: String = "127.0.0.1", port: int = DEFAULT_PORT) -> Error:
	stop_room_browser()
	leave_room()
	is_relay_mode = false
	peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(ip, port)
	if err != OK:
		return err

	multiplayer.multiplayer_peer = peer
	is_host = false
	is_multiplayer_active = true
	target_host_address = "%s:%d" % [ip, port]

	_connect_timeout_timer = get_tree().create_timer(6.0)
	_connect_timeout_timer.timeout.connect(func():
		if is_multiplayer_active and not is_host and connected_players.is_empty():
			_on_connection_failed()
	)
	return OK

func leave_room() -> void:
	stop_room_browser()

	# Close WebSocket relay if active
	if _relay_ws:
		if _relay_ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
			_relay_ws.send_text(JSON.stringify({"cmd": "leave_room"}))
		_relay_ws.close()
		_relay_ws = null

	# Close ENet peer
	if peer:
		peer.close()
		peer = null
		multiplayer.multiplayer_peer = null

	if _udp_peer:
		_udp_peer.close()
		_udp_peer = null
	if _udp_server:
		_udp_server.stop()
		_udp_server = null

	if _upnp_thread and _upnp_thread.is_alive():
		_upnp_thread.wait_to_finish()
	_upnp_thread = null

	is_host = false
	is_multiplayer_active = false
	is_relay_mode = false
	current_room_code = ""
	connected_players.clear()
	alive_players.clear()
	lobby_updated.emit(connected_players)

# ==============================================================================
# --- RELAY PACKET DISPATCHER ---
# ==============================================================================
func _handle_relay_packet(raw_str: String) -> void:
	var packet = JSON.parse_string(raw_str)
	if not (packet is Dictionary):
		return

	var type = str(packet.get("type", packet.get("cmd", "")))
	match type:
		"room_created":
			current_room_code = str(packet.get("room_code", ""))
			local_peer_id = int(packet.get("peer_id", 1))
			room_code_ready.emit(current_room_code)
			var p_arr = packet.get("players", [])
			connected_players.clear()
			for p in p_arr:
				connected_players[int(p["id"])] = p
			lobby_updated.emit(connected_players)

		"joined_room":
			current_room_code = str(packet.get("room_code", ""))
			local_peer_id = int(packet.get("peer_id", 2))
			current_room_name = str(packet.get("room_name", current_room_name))
			mp_selected_day = int(packet.get("day", mp_selected_day))
			mp_selected_map_idx = int(packet.get("variant", mp_selected_map_idx))
			var p_arr = packet.get("players", [])
			connected_players.clear()
			for p in p_arr:
				var pid = int(p["id"])
				connected_players[pid] = {
					"id": pid,
					"name": p.get("name", "Janitor"),
					"wages": 0,
					"tasks": 0,
					"stuns": 0,
					"kills": 0,
					"deaths": 0,
					"ready": bool(p.get("ready", pid == 1)),
					"is_host": bool(p.get("is_host", pid == 1))
				}
			var r_info = {
				"name": current_room_name,
				"day": mp_selected_day,
				"map": mp_selected_map_idx,
				"task_mult": mp_task_mult,
				"supplies_mult": mp_supplies_mult,
				"code": current_room_code
			}
			client_connected_to_host.emit(r_info)
			lobby_updated.emit(connected_players)

		"peer_joined":
			var pid = int(packet.get("peer_id", 0))
			var p_name = str(packet.get("player_name", "Janitor"))
			if pid != 0 and pid != local_peer_id:
				connected_players[pid] = {
					"id": pid,
					"name": p_name,
					"wages": 0,
					"tasks": 0,
					"stuns": 0,
					"kills": 0,
					"deaths": 0,
					"ready": false,
					"is_host": false
				}
				player_joined_lobby.emit(pid, connected_players[pid])
				lobby_updated.emit(connected_players)

		"peer_left":
			var pid = int(packet.get("peer_id", 0))
			if connected_players.has(pid):
				connected_players.erase(pid)
				player_left_lobby.emit(pid)
				lobby_updated.emit(connected_players)

		"host_left":
			leave_room()
			server_disconnected_signal.emit()

		"join_error":
			leave_room()
			connection_failed.emit()

		"relay":
			var from_id = int(packet.get("from", 0))
			var data = packet.get("data", {})
			if data is Dictionary:
				_handle_relayed_game_data(from_id, data)

func _handle_relayed_game_data(from_id: int, data: Dictionary) -> void:
	var action = str(data.get("action", data.get("type", "")))
	match action:
		"sync_tf":
			var pos_arr = data.get("pos", [0, 0, 0])
			var pos = Vector3(float(pos_arr[0]), float(pos_arr[1]), float(pos_arr[2]))
			var rot_y = float(data.get("rot", 0.0))
			var cam_x = float(data.get("cam", 0.0))
			var moving = bool(data.get("mov", false))
			var sprint = bool(data.get("spr", false))
			var flash = bool(data.get("fl", false))
			var weapon = int(data.get("w", 0))
			var guard = bool(data.get("g", false))
			var in_lock = bool(data.get("lock", false))

			if connected_players.has(from_id):
				connected_players[from_id]["pos"] = pos
				connected_players[from_id]["moving"] = moving
				connected_players[from_id]["in_locker"] = in_lock

			var state = {
				"pos": pos,
				"rot_y": rot_y,
				"cam_x": cam_x,
				"moving": moving,
				"sprint": sprint,
				"flash": flash,
				"weapon": weapon,
				"guard": guard,
				"in_locker": in_lock
			}
			remote_player_state_updated.emit(from_id, state)

		"chat":
			chat_message_received.emit(str(data.get("sender", "Janitor")), str(data.get("msg", "")), bool(data.get("sys", false)))

		"ready_state":
			var pid = int(data.get("id", from_id))
			var is_r = bool(data.get("ready", false))
			if connected_players.has(pid):
				connected_players[pid]["ready"] = is_r
				lobby_updated.emit(connected_players)

		"start_game":
			var day = int(data.get("day", 1))
			var map_idx = int(data.get("map", -1))
			var t_mult = float(data.get("task", 1.0))
			var s_mult = float(data.get("sup", 1.0))
			mp_selected_day = day
			mp_selected_map_idx = map_idx
			mp_task_mult = t_mult
			mp_supplies_mult = s_mult
			alive_players.clear()
			for pid in connected_players.keys():
				alive_players[pid] = true
			game_started_signal.emit(day, map_idx, t_mult, s_mult)

		"clean_spill":
			var p_arr = data.get("pos", [0, 0, 0])
			var s_pos = Vector3(float(p_arr[0]), float(p_arr[1]), float(p_arr[2]))
			var cleaner_id = int(data.get("id", from_id))
			if connected_players.has(cleaner_id):
				connected_players[cleaner_id]["tasks"] += 1
				connected_players[cleaner_id]["wages"] += 35
			remote_spill_cleaned.emit(s_pos, cleaner_id)

		"verify_terminal":
			var p_arr = data.get("pos", [0, 0, 0])
			var t_pos = Vector3(float(p_arr[0]), float(p_arr[1]), float(p_arr[2]))
			var checker_id = int(data.get("id", from_id))
			if connected_players.has(checker_id):
				connected_players[checker_id]["tasks"] += 1
				connected_players[checker_id]["wages"] += 50
			remote_terminal_checked.emit(t_pos, checker_id)

		"collect_keycard":
			var idx = int(data.get("idx", 0))
			var cid = int(data.get("id", from_id))
			if connected_players.has(cid):
				connected_players[cid]["wages"] += 25
			remote_keycard_collected.emit(idx, cid)

		"chase_trigger":
			remote_chase_triggered.emit()

		"player_died":
			var pid = int(data.get("id", from_id))
			var p_arr = data.get("pos", [0, 0, 0])
			var d_pos = Vector3(float(p_arr[0]), float(p_arr[1]), float(p_arr[2]))
			var d_rot = float(data.get("rot", 0.0))
			var reason = str(data.get("reason", "Tử nạn"))
			alive_players[pid] = false
			if connected_players.has(pid):
				connected_players[pid]["deaths"] = connected_players[pid].get("deaths", 0) + 1
			player_died_signal.emit(pid, d_pos, d_rot, reason)

			if is_host:
				var any_alive = false
				for p_id in connected_players.keys():
					if alive_players.get(p_id, true):
						any_alive = true
						break
				if not any_alive:
					send_all_players_eliminated()

		"all_eliminated":
			all_players_eliminated_signal.emit()

		"restart_round":
			var day = int(data.get("day", mp_selected_day))
			var map_idx = int(data.get("map", mp_selected_map_idx))
			var t_mult = float(data.get("task", mp_task_mult))
			var s_mult = float(data.get("sup", mp_supplies_mult))
			mp_selected_day = day
			mp_selected_map_idx = map_idx
			mp_task_mult = t_mult
			mp_supplies_mult = s_mult
			alive_players.clear()
			for pid in connected_players.keys():
				alive_players[pid] = true
			round_restarted_signal.emit(day, map_idx, t_mult, s_mult)

		"return_to_lobby":
			alive_players.clear()
			return_to_lobby_signal.emit()

		"show_leaderboard":
			var stats = data.get("stats", [])
			var is_final = bool(data.get("is_final", false))
			leaderboard_summary_displayed.emit(stats, is_final)

# Helper to send payload to relay server
func _send_relay(action_type: String, data_dict: Dictionary, target: String = "others") -> void:
	if not _relay_ws or _relay_ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	data_dict["action"] = action_type
	var msg = {
		"cmd": "relay",
		"target": target,
		"data": data_dict
	}
	_relay_ws.send_text(JSON.stringify(msg))

# ==============================================================================
# --- GAME EVENT NETWORK API (Works seamlessly across Relay & ENet) ---
# ==============================================================================
func sync_player_transform(pos: Vector3, rot_y: float, cam_x: float, moving: bool, sprint: bool, flash: bool, weapon: int, guard: bool, in_locker: bool) -> void:
	if is_relay_mode:
		_send_relay("sync_tf", {
			"pos": [snapped(pos.x, 0.01), snapped(pos.y, 0.01), snapped(pos.z, 0.01)],
			"rot": snapped(rot_y, 0.02),
			"cam": snapped(cam_x, 0.02),
			"mov": moving,
			"spr": sprint,
			"fl": flash,
			"w": weapon,
			"g": guard,
			"lock": in_locker
		}, "others")
	elif peer and multiplayer.multiplayer_peer:
		rpc("rpc_sync_transform", pos, rot_y, cam_x, moving, sprint, flash, weapon, guard, in_locker)

func send_chat_message(sender: String, message: String, is_system: bool = false) -> void:
	if is_relay_mode:
		_send_relay("chat", {"sender": sender, "msg": message, "sys": is_system}, "all")
	elif peer and multiplayer.multiplayer_peer:
		rpc("rpc_send_chat", sender, message, is_system)
	else:
		chat_message_received.emit(sender, message, is_system)

func clean_spill(pos: Vector3, cleaner_id: int) -> void:
	if is_relay_mode:
		_send_relay("clean_spill", {"pos": [pos.x, pos.y, pos.z], "id": cleaner_id}, "all")
	elif peer and multiplayer.multiplayer_peer:
		rpc("rpc_clean_spill", pos, cleaner_id)

func verify_terminal(pos: Vector3, checker_id: int) -> void:
	if is_relay_mode:
		_send_relay("verify_terminal", {"pos": [pos.x, pos.y, pos.z], "id": checker_id}, "all")
	elif peer and multiplayer.multiplayer_peer:
		rpc("rpc_verify_terminal", pos, checker_id)

func collect_keycard(idx: int, collector_id: int) -> void:
	if is_relay_mode:
		_send_relay("collect_keycard", {"idx": idx, "id": collector_id}, "all")
	elif peer and multiplayer.multiplayer_peer:
		rpc("rpc_collect_keycard", idx, collector_id)

func notify_chase_trigger() -> void:
	if is_relay_mode:
		_send_relay("chase_trigger", {}, "all")
	elif peer and multiplayer.multiplayer_peer:
		rpc("rpc_notify_chase_trigger")

func toggle_ready(is_ready: bool) -> void:
	var my_id = get_local_peer_id()
	if is_relay_mode:
		if connected_players.has(my_id):
			connected_players[my_id]["ready"] = is_ready
			lobby_updated.emit(connected_players)
		_send_relay("ready_state", {"id": my_id, "ready": is_ready}, "others")
	elif peer and multiplayer.multiplayer_peer:
		rpc("rpc_toggle_ready", is_ready)

func notify_player_death(pid: int, pos: Vector3, rot_y: float, reason: String) -> void:
	if is_relay_mode:
		_send_relay("player_died", {
			"id": pid,
			"pos": [pos.x, pos.y, pos.z],
			"rot": rot_y,
			"reason": reason
		}, "all")
	elif peer and multiplayer.multiplayer_peer:
		rpc("rpc_player_died", pid, pos, rot_y, reason)

func send_all_players_eliminated() -> void:
	if is_relay_mode:
		_send_relay("all_eliminated", {}, "all")
	elif peer and multiplayer.multiplayer_peer:
		rpc("rpc_all_players_eliminated")

func host_start_game(day: int, map_idx: int, task_mult: float, supplies_mult: float) -> void:
	if not is_host:
		return
	mp_selected_day = day
	mp_selected_map_idx = map_idx
	mp_task_mult = task_mult
	mp_supplies_mult = supplies_mult
	if is_relay_mode:
		_send_relay("start_game", {
			"day": day,
			"map": map_idx,
			"task": task_mult,
			"sup": supplies_mult
		}, "all")
	elif peer and multiplayer.multiplayer_peer:
		rpc("rpc_start_game", day, map_idx, task_mult, supplies_mult)

func host_restart_round() -> void:
	if not is_host:
		return
	if is_relay_mode:
		_send_relay("restart_round", {
			"day": mp_selected_day,
			"map": mp_selected_map_idx,
			"task": mp_task_mult,
			"sup": mp_supplies_mult
		}, "all")
	elif peer and multiplayer.multiplayer_peer:
		rpc("rpc_restart_round", mp_selected_day, mp_selected_map_idx, mp_task_mult, mp_supplies_mult)

func host_return_to_lobby() -> void:
	if not is_host:
		return
	if is_relay_mode:
		_send_relay("return_to_lobby", {}, "all")
	elif peer and multiplayer.multiplayer_peer:
		rpc("rpc_return_to_lobby")

func broadcast_night_leaderboard(is_final_night: bool) -> void:
	if not is_host:
		return
	var stats_array = get_ranked_leaderboard()
	if is_relay_mode:
		_send_relay("show_leaderboard", {"stats": stats_array, "is_final": is_final_night}, "all")
	elif peer and multiplayer.multiplayer_peer:
		rpc("rpc_show_leaderboard", stats_array, is_final_night)

# ==============================================================================
# --- ROOM BROWSER QUERIES ---
# ==============================================================================
func start_room_browser() -> void:
	if _is_browsing:
		return
	_discovered_rooms.clear()
	_is_browsing = true
	_browser_poll_timer = 2.0 # trigger immediate query

	# 1. Listen for local LAN broadcasts
	_browser_listener = PacketPeerUDP.new()
	if _browser_listener.bind(BROADCAST_PORT) != OK:
		_browser_listener = null

	# 2. Query WebSocket Relay Browser
	_query_relay_browser()

func stop_room_browser() -> void:
	_is_browsing = false
	if _browser_ws:
		_browser_ws.close()
		_browser_ws = null
	if _browser_listener:
		_browser_listener.close()
		_browser_listener = null
	_discovered_rooms.clear()
	room_list_updated.emit([])

func _query_relay_browser() -> void:
	if not _browser_ws or _browser_ws.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		_browser_ws = WebSocketPeer.new()
		var err = _browser_ws.connect_to_url(relay_server_url)
		if err != OK:
			_browser_ws = null
			return

	if _browser_ws and _browser_ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_browser_ws.send_text(JSON.stringify({"cmd": "list_rooms"}))

func _handle_browser_packet(pkt_str: String) -> void:
	var packet = JSON.parse_string(pkt_str)
	if not (packet is Dictionary):
		return
	if packet.get("type") == "room_list":
		var rooms_arr = packet.get("rooms", [])
		var changed = false
		for r in rooms_arr:
			var code = str(r.get("code", ""))
			if code != "":
				var r_key = "relay_" + code
				_discovered_rooms[r_key] = {
					"name": r.get("name", "Shift-Room"),
					"players": str(r.get("players", 1)),
					"code": code,
					"host": r.get("host_name", "Janitor"),
					"day": r.get("day", 1),
					"last_seen": Time.get_ticks_msec() / 1000.0,
					"is_relay": true
				}
				changed = true
		if changed:
			room_list_updated.emit(_discovered_rooms.values())

func find_lan_rooms(timeout: float = 0.5, on_found: Callable = Callable()) -> void:
	if not _is_browsing:
		start_room_browser()
	get_tree().create_timer(timeout).timeout.connect(func():
		if on_found.is_valid():
			on_found.call(_discovered_rooms.values())
	)

# ==============================================================================
# --- ENET / LAN RPCs (Maintained for full backward-compatibility) ---
# ==============================================================================
func _on_peer_connected(id: int) -> void:
	if is_host and not is_relay_mode:
		rpc_id(id, "rpc_request_player_info")

func _on_peer_disconnected(id: int) -> void:
	if connected_players.has(id):
		connected_players.erase(id)
		player_left_lobby.emit(id)
		if is_host and not is_relay_mode:
			rpc("rpc_sync_lobby", connected_players)
		lobby_updated.emit(connected_players)

func _on_connected_to_server() -> void:
	_connect_timeout_timer = null
	if not is_relay_mode:
		rpc_id(1, "rpc_register_player", local_player_name)

func _on_connection_failed() -> void:
	_connect_timeout_timer = null
	leave_room()
	connection_failed.emit()

func _on_server_disconnected() -> void:
	_connect_timeout_timer = null
	leave_room()
	server_disconnected_signal.emit()

@rpc("any_peer", "reliable")
func rpc_request_player_info() -> void:
	var sender_id = multiplayer.get_remote_sender_id()
	rpc_id(sender_id if sender_id != 0 else 1, "rpc_register_player", local_player_name)

@rpc("any_peer", "reliable")
func rpc_register_player(p_name: String) -> void:
	if not is_host:
		return
	var peer_id = multiplayer.get_remote_sender_id()
	connected_players[peer_id] = {
		"id": peer_id,
		"name": p_name if p_name.strip_edges() != "" else ("Janitor #" + str(peer_id)),
		"wages": 0,
		"tasks": 0,
		"stuns": 0,
		"kills": 0,
		"deaths": 0,
		"ready": false,
		"is_host": false
	}
	var r_info = {
		"name": current_room_name,
		"day": mp_selected_day,
		"map": mp_selected_map_idx,
		"task_mult": mp_task_mult,
		"supplies_mult": mp_supplies_mult,
		"code": current_room_code
	}
	rpc("rpc_sync_lobby", connected_players, r_info)
	lobby_updated.emit(connected_players)

@rpc("call_local", "reliable")
func rpc_sync_lobby(p_dict: Dictionary, r_info: Dictionary = {}) -> void:
	connected_players = p_dict
	if not r_info.is_empty():
		current_room_name = r_info.get("name", current_room_name)
		mp_selected_day = int(r_info.get("day", mp_selected_day))
		mp_selected_map_idx = int(r_info.get("map", mp_selected_map_idx))
		mp_task_mult = float(r_info.get("task_mult", mp_task_mult))
		mp_supplies_mult = float(r_info.get("supplies_mult", mp_supplies_mult))
		if not is_host:
			client_connected_to_host.emit(r_info)
	lobby_updated.emit(connected_players)

@rpc("any_peer", "call_local", "reliable")
func rpc_toggle_ready(is_ready: bool) -> void:
	var peer_id = multiplayer.get_remote_sender_id()
	if peer_id == 0: peer_id = get_local_peer_id()
	if connected_players.has(peer_id):
		connected_players[peer_id]["ready"] = is_ready
		if is_host and not is_relay_mode:
			rpc("rpc_sync_lobby", connected_players)
		lobby_updated.emit(connected_players)

@rpc("call_local", "reliable")
func rpc_start_game(day: int, map_idx: int, task_mult: float, supplies_mult: float) -> void:
	mp_selected_day = day
	mp_selected_map_idx = map_idx
	mp_task_mult = task_mult
	mp_supplies_mult = supplies_mult
	alive_players.clear()
	for pid in connected_players.keys():
		alive_players[pid] = true
	game_started_signal.emit(day, map_idx, task_mult, supplies_mult)

@rpc("any_peer", "unreliable_ordered")
func rpc_sync_transform(pos: Vector3, rot_y: float, cam_x: float, moving: bool, sprint: bool, flash: bool, weapon: int, guard: bool, in_locker: bool = false) -> void:
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0 or sender_id == multiplayer.get_unique_id():
		return
	if connected_players.has(sender_id):
		connected_players[sender_id]["pos"] = pos
		connected_players[sender_id]["moving"] = moving
		connected_players[sender_id]["in_locker"] = in_locker
	var state = {
		"pos": pos,
		"rot_y": rot_y,
		"cam_x": cam_x,
		"moving": moving,
		"sprint": sprint,
		"flash": flash,
		"weapon": weapon,
		"guard": guard,
		"in_locker": in_locker
	}
	remote_player_state_updated.emit(sender_id, state)

@rpc("any_peer", "call_local", "reliable")
func rpc_clean_spill(spill_pos: Vector3, cleaner_id: int) -> void:
	var cid = cleaner_id_fallback(cleaner_id)
	if connected_players.has(cid):
		connected_players[cid]["tasks"] += 1
		connected_players[cid]["wages"] += 35
	remote_spill_cleaned.emit(spill_pos, cleaner_id)

@rpc("any_peer", "call_local", "reliable")
func rpc_verify_terminal(term_pos: Vector3, checker_id: int) -> void:
	var cid = cleaner_id_fallback(checker_id)
	if connected_players.has(cid):
		connected_players[cid]["tasks"] += 1
		connected_players[cid]["wages"] += 50
	remote_terminal_checked.emit(term_pos, checker_id)

@rpc("any_peer", "call_local", "reliable")
func rpc_collect_keycard(idx: int, collector_id: int) -> void:
	var cid = cleaner_id_fallback(collector_id)
	if connected_players.has(cid):
		connected_players[cid]["wages"] += 25
	remote_keycard_collected.emit(idx, collector_id)

@rpc("call_local", "reliable")
func rpc_notify_chase_trigger() -> void:
	remote_chase_triggered.emit()

@rpc("any_peer", "call_local", "reliable")
func rpc_send_chat(sender: String, message: String, is_system: bool = false) -> void:
	chat_message_received.emit(sender, message, is_system)

@rpc("any_peer", "call_local", "reliable")
func rpc_player_died(pid: int, pos: Vector3, rot_y: float, reason: String) -> void:
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0: sender_id = pid
	alive_players[sender_id] = false
	if connected_players.has(sender_id):
		connected_players[sender_id]["deaths"] = connected_players[sender_id].get("deaths", 0) + 1
	player_died_signal.emit(sender_id, pos, rot_y, reason)

	if is_host:
		var any_alive = false
		for p_id in connected_players.keys():
			if alive_players.get(p_id, true):
				any_alive = true
				break
		if not any_alive:
			rpc("rpc_all_players_eliminated")

@rpc("call_local", "reliable")
func rpc_all_players_eliminated() -> void:
	all_players_eliminated_signal.emit()

@rpc("call_local", "reliable")
func rpc_restart_round(day: int, map_idx: int, task_mult: float, supplies_mult: float) -> void:
	mp_selected_day = day
	mp_selected_map_idx = map_idx
	mp_task_mult = task_mult
	mp_supplies_mult = supplies_mult
	alive_players.clear()
	for pid in connected_players.keys():
		alive_players[pid] = true
	round_restarted_signal.emit(day, map_idx, task_mult, supplies_mult)

@rpc("call_local", "reliable")
func rpc_return_to_lobby() -> void:
	alive_players.clear()
	return_to_lobby_signal.emit()

@rpc("call_local", "reliable")
func rpc_show_leaderboard(stats_array: Array, is_final_night: bool) -> void:
	leaderboard_summary_displayed.emit(stats_array, is_final_night)

# ==============================================================================
# --- UTILITIES & STATS ---
# ==============================================================================
func update_local_player_state(pos: Vector3, moving: bool, in_locker: bool) -> void:
	var my_id = get_local_peer_id()
	if connected_players.has(my_id):
		connected_players[my_id]["pos"] = pos
		connected_players[my_id]["moving"] = moving
		connected_players[my_id]["in_locker"] = in_locker

func get_still_player_ratio() -> float:
	if connected_players.is_empty():
		return 1.0
	var still_count: int = 0
	for pid in connected_players.keys():
		if not connected_players[pid].get("moving", false):
			still_count += 1
	return float(still_count) / float(connected_players.size())

func is_any_player_in_locker() -> bool:
	for pid in connected_players.keys():
		if connected_players[pid].get("in_locker", false):
			return true
	return false

func is_near_any_player(pos: Vector3, max_dist: float = 3.75) -> bool:
	for pid in connected_players.keys():
		var p_pos: Vector3 = connected_players[pid].get("pos", Vector3.ZERO)
		if p_pos != Vector3.ZERO:
			var d = Vector2(pos.x - p_pos.x, pos.z - p_pos.z).length()
			if d <= max_dist:
				return true
	return false

func should_monsters_freeze(monster_pos: Vector3) -> bool:
	if not is_multiplayer_active:
		return false
	if is_any_player_in_locker():
		return false
	if is_near_any_player(monster_pos, 3.75):
		return false
	return get_still_player_ratio() >= 0.51

func record_boss_stun(peer_id: int = 0) -> void:
	var pid = cleaner_id_fallback(peer_id)
	if connected_players.has(pid):
		connected_players[pid]["stuns"] += 1
		connected_players[pid]["wages"] += 40

func record_monster_kill(peer_id: int = 0) -> void:
	var pid = cleaner_id_fallback(peer_id)
	if connected_players.has(pid):
		connected_players[pid]["kills"] += 1
		connected_players[pid]["wages"] += 30

func record_player_down(peer_id: int = 0) -> void:
	var pid = cleaner_id_fallback(peer_id)
	if connected_players.has(pid):
		connected_players[pid]["deaths"] += 1

func get_ranked_leaderboard() -> Array:
	var list: Array = []
	for pid in connected_players.keys():
		list.append(connected_players[pid].duplicate(true))
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.get("wages", 0) != b.get("wages", 0):
			return a.get("wages", 0) > b.get("wages", 0)
		if a.get("stuns", 0) != b.get("stuns", 0):
			return a.get("stuns", 0) > b.get("stuns", 0)
		if a.get("kills", 0) != b.get("kills", 0):
			return a.get("kills", 0) > b.get("kills", 0)
		if a.get("deaths", 0) != b.get("deaths", 0):
			return a.get("deaths", 0) < b.get("deaths", 0)
		return a.get("tasks", 0) > b.get("tasks", 0)
	)
	return list

func get_local_lan_ip() -> String:
	for ip in IP.get_local_addresses():
		if ip.begins_with("192.168.") or ip.begins_with("10.") or (ip.begins_with("172.") and not ip.begins_with("172.17.")):
			return ip
	return "127.0.0.1"

func encode_room_code(ip_str: String, port: int) -> String:
	var parts = ip_str.split(".")
	if parts.size() != 4:
		return "AGY-LOCAL"
	var b0 = int(parts[0]) & 0xFF
	var b1 = int(parts[1]) & 0xFF
	var b2 = int(parts[2]) & 0xFF
	var b3 = int(parts[3]) & 0xFF
	var p_high = (port >> 8) & 0xFF
	var p_low = port & 0xFF
	var val: int = (b0 << 40) | (b1 << 32) | (b2 << 24) | (b3 << 16) | (p_high << 8) | p_low
	var chars = ""
	for i in range(10):
		var shift = (9 - i) * 5
		var idx = (val >> shift) & 0x1F
		chars += CODE_ALPHABET[idx]
	return "AGY-" + chars.substr(0, 4) + "-" + chars.substr(4, 4)

func parse_room_input(input_str: String) -> Dictionary:
	var s = input_str.strip_edges().to_upper()
	if s.contains(":"):
		var p = s.split(":")
		return {"ip": p[0], "port": int(p[1]), "is_domain": not p[0].is_valid_ip_address()}
	return {}
