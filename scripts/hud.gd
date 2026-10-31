extends CanvasLayer

# --- MAIN MENU ELEMENTS ---
@onready var main_menu: Control = $MainMenu
@onready var menu_bg_rect: ColorRect = $MainMenu/Background
@onready var menu_center_box: VBoxContainer = $MainMenu/CenterBox
@onready var menu_title_box: VBoxContainer = $MainMenu/CenterBox/TitleBox
@onready var menu_badge: Label = $MainMenu/CenterBox/TitleBox/Badge
@onready var menu_title: Label = $MainMenu/CenterBox/TitleBox/Title
@onready var menu_subtitle: Label = $MainMenu/CenterBox/TitleBox/Subtitle
@onready var menu_footer: Label = $MainMenu/FooterText
@onready var btn_start: Button = $MainMenu/CenterBox/ButtonBox/BtnStart
@onready var btn_options: Button = $MainMenu/CenterBox/ButtonBox/BtnOptions
@onready var btn_leaderboard: Button = $MainMenu/CenterBox/ButtonBox/BtnLeaderboard
@onready var btn_exit: Button = $MainMenu/CenterBox/ButtonBox/BtnExit

# --- OPTIONS SCREEN ---
@onready var options_screen: Control = $OptionsScreen
@onready var btn_options_back: Button = $OptionsScreen/VBox/BtnBack
@onready var sens_slider: HSlider = $OptionsScreen/VBox/SensRow/SensSlider
@onready var fov_slider: HSlider = $OptionsScreen/VBox/FovRow/FovSlider
@onready var sfx_slider: HSlider = $OptionsScreen/VBox/SfxRow/SfxSlider
@onready var music_slider: HSlider = $OptionsScreen/VBox/MusicRow/MusicSlider
@onready var flash_slider: HSlider = $OptionsScreen/VBox/FlashRow/FlashSlider

# --- LEADERBOARD SCREEN ---
@onready var leaderboard_screen: Control = $LeaderboardScreen
@onready var btn_lb_back: Button = $LeaderboardScreen/VBox/BtnBack

# --- PAUSE MENU ---
@onready var pause_menu: Control = $PauseMenu
@onready var btn_resume: Button = $PauseMenu/VBox/BtnResume
@onready var btn_pause_options: Button = $PauseMenu/VBox/BtnOptions
@onready var btn_quit: Button = $PauseMenu/VBox/BtnQuit

# --- IN-GAME HUD ---
@onready var game_hud: Control = $GameHud
@onready var facility_title: Label = $GameHud/TopLeftPanel/VBox/FacilityTitle
@onready var facility_dot: ColorRect = $GameHud/TopLeftPanel/VBox/TitleRow/Dot
@onready var objective_list: Label = $GameHud/TopLeftPanel/VBox/ObjectiveList
@onready var dist_warning: Label = $GameHud/TopLeftPanel/VBox/DistWarning

@onready var chase_hud_box: Control = $GameHud/TopRightBox
@onready var chase_title_label: Label = $GameHud/TopRightBox/VBox/Title
@onready var chase_distance_hud: Label = $GameHud/TopRightBox/VBox/DistanceValue
@onready var chase_bar: ProgressBar = $GameHud/TopRightBox/VBox/ChaseBar

@onready var reticle: Label = $GameHud/Reticle
@onready var interaction_label: Label = $GameHud/InteractionLabel

@onready var stamina_bar: ProgressBar = $GameHud/BottomLeft/StaminaBox/Bar
@onready var mop_bar: ProgressBar = $GameHud/BottomLeft/MopBox/Bar
@onready var flashlight_status: Label = $GameHud/BottomLeft/FlashlightBox/Status

@onready var horror_vignette: ColorRect = $HorrorVignette
@onready var crt_overlay: ColorRect = $CRTOverlay
@onready var minimap: Control = $GameHud/Minimap

# --- ANIMATIC CUTSCENE SYSTEM ---
@onready var cutscene_player: Control = $CutscenePlayer
@onready var cutscene_canvas: Control = $CutscenePlayer/CutsceneCanvas
@onready var cs_speaker: Label = $CutscenePlayer/BottomBar/BarLayout/VBox/Speaker
@onready var cs_text: RichTextLabel = $CutscenePlayer/BottomBar/BarLayout/VBox/Text
@onready var cs_counter: Label = $CutscenePlayer/BottomBar/BarLayout/HBoxBtn/SlideCounter
@onready var cs_next: Button = $CutscenePlayer/BottomBar/BarLayout/HBoxBtn/BtnRow/NextBtn
@onready var cs_skip: Button = $CutscenePlayer/BottomBar/BarLayout/HBoxBtn/BtnRow/SkipBtn

# --- NOTE POPUP ---
@onready var note_popup: Control = $NotePopup
@onready var note_tag: Label = $NotePopup/VBox/Header/Tag
@onready var note_close_btn: Button = $NotePopup/VBox/Header/CloseBtn
@onready var note_title: Label = $NotePopup/VBox/Title
@onready var note_body: RichTextLabel = $NotePopup/VBox/Body
var _note_just_opened: bool = false

# --- GAME OVER & VICTORY ---
@onready var game_over_screen: Control = $GameOverScreen
@onready var game_over_msg: Label = $GameOverScreen/VBox/DeathMessage
@onready var retry_btn: Button = $GameOverScreen/VBox/RetryBtn
@onready var victory_screen: Control = $VictoryScreen
@onready var victory_title: Label = $VictoryScreen/VBox/Title
@onready var victory_msg: Label = $VictoryScreen/VBox/Message
@onready var victory_exit_btn: Button = $VictoryScreen/VBox/ExitBtn

# --- DEV PANEL ---
@onready var dev_panel: Control = $DevPanel
@onready var dev_btn_close: Button = $DevPanel/VBox/Header/CloseBtn
@onready var dev_chk_god: CheckBox = $DevPanel/VBox/ChkGod
@onready var dev_chk_freeze: CheckBox = $DevPanel/VBox/ChkFreeze
@onready var dev_btn_chase: Button = $DevPanel/VBox/BtnForceChase
@onready var dev_btn_objectives: Button = $DevPanel/VBox/BtnCompleteObj
@onready var dev_btn_tp: Button = $DevPanel/VBox/BtnTpExit
@onready var dev_btn_skip: Button = $DevPanel/VBox/BtnSkipDay
var dev_chk_noclip: CheckBox = null
var dev_chk_steps: CheckBox = null

# --- DYNAMIC OVERLAYS & MENU CANVAS ---
var menu_canvas: Control = null
var menu_anim_time: float = 0.0
var menu_glitch_timer: float = 0.0
var menu_line1: Label = null
var menu_line2: Label = null
var menu_line3: Label = null

var hunter_prox_label: Label = null
var locker_overlay: Control = null
var cloak_overlay: Control = null
var cloak_overlay_mode: String = "none"
var cloak_overlay_ratio: float = 0.0
var damage_flash_rect: ColorRect = null
var toast_label: Label = null
var toast_timer: float = 0.0
var shift_gate_panel: PanelContainer = null
var shift_gate_title: Label = null
var shift_gate_sub: Label = null
var shift_gate_callback: Callable

# Dev Mode state (controls whether raw step countdown to Final Mode is visible)
var dev_mode_enabled: bool = false
var current_hud_phase: String = "work"
var _cached_dist: int = 210
var _cached_max_dist: int = 210
var _cached_hunter_steps: int = 40
var _cached_keycards: int = 0
var _cached_max_keycards: int = 3

# Containment Override [R] Minigame UI
var override_panel: PanelContainer = null
var override_canvas: Control = null
var override_active: bool = false
var override_cursor: float = 0.0
var override_dir: float = 1.0
var override_zone_min: float = 0.58
var override_zone_max: float = 0.78

# --- 2-SLOT WEAPON INVENTORY UI ---
var weapon_inv_container: VBoxContainer = null
var weapon_mop_label: Label = null
var weapon_taser_label: Label = null
var weapon_baton_label: Label = null
var weapon_guard_label: Label = null

# --- HANGER STRUGGLE QTE UI ---
var hanger_struggle_panel: PanelContainer = null
var hanger_struggle_bar: ProgressBar = null
var hanger_struggle_timer_label: Label = null
var hanger_struggle_prompt_label: Label = null

signal start_game_clicked()
signal pause_resumed()
signal quit_to_menu()
signal game_over_to_menu()
signal retry_clicked()
signal victory_finish_clicked()
signal override_completed(success: bool)

# Multiplayer signals
signal mp_host_room_requested(room_name: String, day: int, map_idx: int, task_mult: float, supplies_mult: float)
signal mp_join_room_requested(ip: String, port: int)
signal mp_join_code_requested(code_or_address: String)
signal mp_quick_join_requested()
signal mp_start_shift_requested()
signal mp_leave_room_requested()
signal mp_toggle_ready_requested(ready: bool)

signal dev_god_toggled(enabled: bool)
signal dev_freeze_toggled(enabled: bool)
signal dev_noclip_toggled(enabled: bool)
signal dev_steps_hud_toggled(enabled: bool)
signal dev_force_chase()
signal dev_complete_objectives()
signal dev_give_keycards()
signal dev_tp_exit()
signal dev_skip_day()
signal dev_jump_day(day_num: int)
signal dev_spawn_crawler()
signal dev_spawn_cultist()
signal dev_spawn_cloak()
signal dev_spawn_hanger()
signal dev_repair_mop()
signal dev_unlock_map()
signal dev_panel_closed()
signal dev_test_cutscene(cutscene_id: String)
signal quit_modal_dismissed()

var quit_warning_modal: PanelContainer = null
var quit_warning_title: Label = null
var quit_warning_body: Label = null
var pause_warning_label: Label = null

# --- MULTIPLAYER CO-OP UI SYSTEM ---
var btn_multiplayer: Button = null
var mp_panel: PanelContainer = null
var mp_callsign_input: LineEdit = null
var mp_room_input: LineEdit = null
var mp_day_select: OptionButton = null
var mp_map_select: OptionButton = null
var mp_task_select: OptionButton = null
var mp_supply_select: OptionButton = null
var mp_ip_input: LineEdit = null
var mp_port_input: LineEdit = null
var mp_code_input: LineEdit = null
var mp_scan_status: Label = null
var mp_btn_host_tab: Button = null
var mp_btn_join_tab: Button = null
var mp_host_box: VBoxContainer = null
var mp_join_box: VBoxContainer = null

var mp_lobby_panel: PanelContainer = null
var mp_lobby_title: Label = null
var mp_lobby_info: Label = null
var mp_lobby_code_label: Label = null
var mp_btn_copy_code: Button = null
var mp_lobby_player_list: VBoxContainer = null
var mp_btn_lobby_ready: Button = null
var mp_btn_lobby_start: Button = null
var mp_local_is_ready: bool = false

var mp_browser_scroll: ScrollContainer = null
var mp_browser_vbox: VBoxContainer = null
var mp_browser_empty_label: Label = null

var mp_scoreboard_panel: PanelContainer = null
var mp_scoreboard_title: Label = null
var mp_scoreboard_winner: Label = null
var mp_scoreboard_table: VBoxContainer = null
var mp_btn_scoreboard_next: Button = null
var mp_btn_scoreboard_menu: Button = null

var mp_chat_panel: PanelContainer = null
var mp_chat_scroll: ScrollContainer = null
var mp_chat_vbox: VBoxContainer = null
var mp_chat_input: LineEdit = null
var mp_btn_send_chat: Button = null
var mp_spectator_banner: PanelContainer = null
var mp_spectator_label: Label = null

var current_slides: Array = []
var slide_index: int = 0
var cutscene_callback: Callable
var cutscene_art_id: String = ""
var cs_slide_time: float = 0.0
var cs_input_delay: float = 0.0
var cs_fx_mode: String = "dust"

var full_text: String = ""
var type_idx: int = 0
var type_timer: float = 0.0

var font_mono: Font = preload("res://fonts/ShareTechMono-Regular.ttf")
var font_horror: Font = preload("res://fonts/Creepster-Regular.ttf")

const CS_FX_MAP = {
	"intro": "rain",
	"chaseBegin": "alarm",
	"entityBlocksDoor": "alarm",
	"endingFired": "rain",
	"endingEarth": "alarm"
}

func _ready() -> void:
	cutscene_player.mouse_filter = Control.MOUSE_FILTER_PASS
	if cutscene_canvas:
		cutscene_canvas.mouse_filter = Control.MOUSE_FILTER_PASS
		cutscene_canvas.draw.connect(_draw_cutscene_illustration)
		cutscene_canvas.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				cutscene_canvas.accept_event()
				get_viewport().set_input_as_handled()
				_on_cutscene_next_action()
		)

	_overhaul_main_menu()
	_build_dynamic_hud_elements()
	_build_multiplayer_ui()

	# Main menu connections
	btn_start.pressed.connect(func():
		main_menu.visible = false
		start_game_clicked.emit()
	)
	btn_options.pressed.connect(func():
		main_menu.visible = false
		options_screen.visible = true
	)
	btn_leaderboard.pressed.connect(func():
		main_menu.visible = false
		leaderboard_screen.visible = true
	)
	btn_exit.mouse_entered.connect(_on_exit_hover)
	btn_exit.pressed.connect(_on_exit_hover)

	btn_options_back.pressed.connect(func():
		options_screen.visible = false
		if game_hud.visible:
			pause_menu.visible = true
		else:
			main_menu.visible = true
	)
	btn_lb_back.pressed.connect(func():
		leaderboard_screen.visible = false
		main_menu.visible = true
	)

	sfx_slider.value_changed.connect(func(val): SoundEffects.set_sfx_volume(val))
	music_slider.value_changed.connect(func(val): SoundEffects.set_music_volume(val))

	cs_next.pressed.connect(func():
		get_viewport().set_input_as_handled()
		_on_cutscene_next_action()
	)
	cs_skip.pressed.connect(func():
		get_viewport().set_input_as_handled()
		_finish_cutscene()
	)

	if note_close_btn:
		note_close_btn.pressed.connect(func(): hide_note_popup())

	btn_resume.pressed.connect(func(): emit_signal("pause_resumed"))
	btn_pause_options.pressed.connect(func():
		pause_menu.visible = false
		options_screen.visible = true
	)
	btn_quit.pressed.connect(func(): emit_signal("quit_to_menu"))

	if retry_btn:
		retry_btn.pressed.connect(func(): retry_clicked.emit())
	if victory_exit_btn:
		victory_exit_btn.pressed.connect(func(): victory_finish_clicked.emit())

	if dev_panel:
		dev_panel.visible = false
		dev_btn_close.pressed.connect(func():
			hide_dev_panel()
			dev_panel_closed.emit()
		)
		dev_chk_god.toggled.connect(func(v): dev_god_toggled.emit(v))
		dev_chk_freeze.toggled.connect(func(v): dev_freeze_toggled.emit(v))
		dev_btn_chase.pressed.connect(func(): dev_force_chase.emit())
		dev_btn_objectives.pressed.connect(func(): dev_complete_objectives.emit())
		dev_btn_tp.pressed.connect(func(): dev_tp_exit.emit())
		dev_btn_skip.pressed.connect(func(): dev_skip_day.emit())

# Rebuilds the Main Menu to match the HTML original (#main-menu lines 97-132):
# - Animated procedural background canvas (corridor perspective, flickering lights, Subject Zero silhouette, spores, scanlines)
# - Flickering "AETHELGARD BIOTECH — SUB-LEVEL 4" header
# - Huge stacked 3-line Creepster horror title: THE COMPANY (white) / DOES NOT LET (blood red) / YOU LEAVE (white)
# - Italic subtitle: "Your shift has already begun."
# - Styled corporate horror buttons with glowing hover borders
func _overhaul_main_menu() -> void:
	if not main_menu:
		return
	if menu_bg_rect:
		menu_bg_rect.color = Color(0.01, 0.02, 0.05, 0.78)

	menu_canvas = Control.new()
	menu_canvas.name = "MenuAnimatedCanvas"
	menu_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_canvas.draw.connect(_draw_main_menu_bg)
	main_menu.add_child(menu_canvas)
	main_menu.move_child(menu_canvas, 1)

	if menu_center_box:
		menu_center_box.offset_left = -360.0
		menu_center_box.offset_right = 360.0
		menu_center_box.offset_top = -270.0
		menu_center_box.offset_bottom = 260.0
		menu_center_box.add_theme_constant_override("separation", 24)

	if menu_badge:
		menu_badge.text = "A E T H E L G A R D   B I O T E C H   —   S U B - L E V E L   4"
		menu_badge.add_theme_color_override("font_color", Color(0.58, 0.64, 0.72, 1.0))
		menu_badge.add_theme_font_size_override("font_size", 13)

	# Hide old single-line title and insert stacked 3-line horror title matching HTML
	if menu_title:
		menu_title.visible = false

	var stack_box = VBoxContainer.new()
	stack_box.name = "StackedTitleBox"
	stack_box.add_theme_constant_override("separation", -10)
	menu_title_box.add_child(stack_box)
	menu_title_box.move_child(stack_box, 1)

	menu_line1 = Label.new()
	menu_line1.text = "THE COMPANY"
	menu_line1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_line1.add_theme_font_override("font", font_horror)
	menu_line1.add_theme_font_size_override("font_size", 68)
	menu_line1.add_theme_color_override("font_color", Color(0.97, 0.98, 1.0, 1.0))
	menu_line1.add_theme_color_override("font_shadow_color", Color(0.94, 0.27, 0.27, 0.45))
	menu_line1.add_theme_constant_override("shadow_offset_x", 0)
	menu_line1.add_theme_constant_override("shadow_offset_y", 4)
	stack_box.add_child(menu_line1)

	menu_line2 = Label.new()
	menu_line2.text = "DOES NOT LET"
	menu_line2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_line2.add_theme_font_override("font", font_horror)
	menu_line2.add_theme_font_size_override("font_size", 72)
	menu_line2.add_theme_color_override("font_color", Color(0.88, 0.14, 0.16, 1.0))
	menu_line2.add_theme_color_override("font_shadow_color", Color(0.45, 0.0, 0.04, 0.9))
	menu_line2.add_theme_constant_override("shadow_offset_x", 0)
	menu_line2.add_theme_constant_override("shadow_offset_y", 5)
	stack_box.add_child(menu_line2)

	menu_line3 = Label.new()
	menu_line3.text = "YOU LEAVE"
	menu_line3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_line3.add_theme_font_override("font", font_horror)
	menu_line3.add_theme_font_size_override("font_size", 68)
	menu_line3.add_theme_color_override("font_color", Color(0.97, 0.98, 1.0, 1.0))
	menu_line3.add_theme_color_override("font_shadow_color", Color(0.94, 0.27, 0.27, 0.45))
	menu_line3.add_theme_constant_override("shadow_offset_x", 0)
	menu_line3.add_theme_constant_override("shadow_offset_y", 4)
	stack_box.add_child(menu_line3)

	if menu_subtitle:
		menu_subtitle.text = "Your shift has already begun."
		menu_subtitle.add_theme_color_override("font_color", Color(0.42, 0.48, 0.56, 1.0))
		menu_subtitle.add_theme_font_size_override("font_size", 14)

	if menu_footer:
		menu_footer.text = "v8 — CAGES / BLOOD +$15 / MOP DURABILITY / WALL-CRAWLERS / F9 DEBUG  |  LMB=Scrub/Strike  |  E=Interact  |  B=Bait  |  F=Flash"
		menu_footer.add_theme_color_override("font_color", Color(0.32, 0.38, 0.46, 0.9))

	# Style the 4 menu buttons to look sleek and atmospheric like the HTML .menu-btn
	_style_menu_button(btn_start, Color(0.88, 0.14, 0.16), Color(0.28, 0.04, 0.06))
	_style_menu_button(btn_options, Color(0.95, 0.65, 0.15), Color(0.16, 0.14, 0.08))
	_style_menu_button(btn_leaderboard, Color(0.18, 0.82, 0.92), Color(0.06, 0.16, 0.22))
	_style_menu_button(btn_exit, Color(0.85, 0.20, 0.22), Color(0.20, 0.05, 0.06))

func _style_menu_button(btn: Button, hover_border: Color, hover_bg: Color) -> void:
	if not btn:
		return
	btn.custom_minimum_size = Vector2(280, 46)
	var normal_sb = StyleBoxFlat.new()
	normal_sb.bg_color = Color(0.06, 0.09, 0.16, 0.92)
	normal_sb.border_width_left = 2
	normal_sb.border_width_top = 1
	normal_sb.border_width_right = 1
	normal_sb.border_width_bottom = 1
	normal_sb.border_color = Color(0.20, 0.26, 0.34, 0.9)
	normal_sb.corner_radius_top_left = 4
	normal_sb.corner_radius_top_right = 4
	normal_sb.corner_radius_bottom_left = 4
	normal_sb.corner_radius_bottom_right = 4

	var hover_sb = normal_sb.duplicate()
	hover_sb.bg_color = hover_bg
	hover_sb.border_width_left = 4
	hover_sb.border_color = hover_border

	btn.add_theme_stylebox_override("normal", normal_sb)
	btn.add_theme_stylebox_override("hover", hover_sb)
	btn.add_theme_stylebox_override("pressed", hover_sb)

func _draw_main_menu_bg() -> void:
	if not menu_canvas or not main_menu.visible:
		return
	var w = menu_canvas.size.x
	var h = menu_canvas.size.y
	var t = menu_anim_time

	# 1. Deep Sub-Level 4 corridor perspective lines
	var cx = w * 0.5 + sin(t * 0.45) * 18.0
	var cy = h * 0.48 + cos(t * 0.35) * 10.0
	var line_col = Color(0.10, 0.16, 0.26, 0.28)
	menu_canvas.draw_line(Vector2(cx, cy), Vector2(0, 0), line_col, 2.0)
	menu_canvas.draw_line(Vector2(cx, cy), Vector2(w, 0), line_col, 2.0)
	menu_canvas.draw_line(Vector2(cx, cy), Vector2(0, h), line_col, 2.0)
	menu_canvas.draw_line(Vector2(cx, cy), Vector2(w, h), line_col, 2.0)

	for i in range(1, 7):
		var p = fmod(float(i) / 6.0 + t * 0.04, 1.0)
		var rw = lerpf(80.0, w * 0.95, p * p)
		var rh = lerpf(60.0, h * 0.90, p * p)
		var alpha = (1.0 - p) * 0.18
		menu_canvas.draw_rect(Rect2(cx - rw * 0.5, cy - rh * 0.5, rw, rh), Color(0.14, 0.22, 0.35, alpha), false, 1.5)

	# 2. Emergency red siren pulse & flickering ceiling tube
	var red_pulse = 0.05 + 0.05 * sin(t * 2.4)
	menu_canvas.draw_circle(Vector2(cx, cy - 90.0), 280.0, Color(0.75, 0.05, 0.08, red_pulse))
	if fmod(t * 7.0, 11.0) > 0.35:
		menu_canvas.draw_rect(Rect2(cx - 55.0, cy - 165.0, 110.0, 4.0), Color(0.75, 0.88, 1.0, 0.22))

	# 3. Lurking Subject Zero Silhouette in the deep corridor
	var sil_bob = sin(t * 1.9) * 5.0
	var sil_col = Color(0.03, 0.01, 0.015, 0.72)
	menu_canvas.draw_circle(Vector2(cx, cy - 22.0 + sil_bob), 24.0, sil_col)
	menu_canvas.draw_rect(Rect2(cx - 28.0, cy - 5.0 + sil_bob, 56.0, 95.0), sil_col)
	# Dragging claws & dorsal spider limbs on silhouette
	menu_canvas.draw_line(Vector2(cx - 26.0, cy + 5.0 + sil_bob), Vector2(cx - 68.0, cy + 68.0 + sil_bob), sil_col, 6.0)
	menu_canvas.draw_line(Vector2(cx + 26.0, cy + 5.0 + sil_bob), Vector2(cx + 68.0, cy + 68.0 + sil_bob), sil_col, 6.0)
	menu_canvas.draw_line(Vector2(cx - 18.0, cy - 5.0 + sil_bob), Vector2(cx - 72.0, cy - 42.0 + sin(t * 3.2) * 8.0), sil_col, 3.0)
	menu_canvas.draw_line(Vector2(cx + 18.0, cy - 5.0 + sil_bob), Vector2(cx + 72.0, cy - 42.0 + cos(t * 3.2) * 8.0), sil_col, 3.0)

	# 7 Asymmetric Glowing Red Eyes in the dark
	var blink = 0.15 if fmod(t, 4.8) > 4.65 else 0.85
	var eyes = [
		Vector2(-9, -24), Vector2(9, -24),
		Vector2(-15, -19), Vector2(15, -19),
		Vector2(-5, -30), Vector2(6, -30), Vector2(0, -21)
	]
	for eo in eyes:
		menu_canvas.draw_circle(Vector2(cx, cy + sil_bob) + eo, 2.6, Color(1.0, 0.12, 0.12, blink))

	# 4. Floating Bio-Spores & Dust Particles
	for i in range(55):
		var px = fmod(float(i * 137) + t * (10.0 + float(i % 5) * 3.0), max(1.0, w))
		var py = fmod(float(i * 89) - t * (7.0 + float(i % 4) * 2.5) + h * 10.0, max(1.0, h))
		var sz = 1.5 + float(i % 3)
		var col = Color(0.95, 0.25, 0.25, 0.26) if (i % 6 == 0) else Color(0.65, 0.75, 0.88, 0.18)
		menu_canvas.draw_rect(Rect2(px, py, sz, sz), col)

	# 5. Periodic Horizontal Glitch Tear Bars
	if menu_glitch_timer > 0.0 or fmod(t * 13.0, 19.0) < 0.25:
		for g in range(3):
			var gy = fmod(float(g * 193) + t * 520.0, max(1.0, h))
			menu_canvas.draw_rect(Rect2(0, gy, w, 4.0 + float(g * 3)), Color(0.95, 0.15, 0.2, 0.14))

	# 6. Dark Perimeter Vignette Bars
	menu_canvas.draw_rect(Rect2(0, 0, w, 38), Color(0, 0, 0, 0.65))
	menu_canvas.draw_rect(Rect2(0, h - 42, w, 42), Color(0, 0, 0, 0.75))

func _build_dynamic_hud_elements() -> void:
	# 1. Extra proximity / keycard label inside TopRightBox (Dev-mode only raw step counter)
	# Moved to Top-Center with MOUSE_FILTER_IGNORE so it NEVER overlaps or blocks DevPanel on the right!
	if chase_hud_box:
		chase_hud_box.visible = false
		chase_hud_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
		chase_hud_box.offset_left = -145.0
		chase_hud_box.offset_top = 16.0
		chase_hud_box.offset_right = 145.0
		chase_hud_box.offset_bottom = 118.0
		chase_hud_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if chase_title_label:
			chase_title_label.text = "⚠ [DEV] ENTITY PROXIMITY"
			chase_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if chase_distance_hud:
			chase_distance_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if chase_bar:
			chase_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hunter_prox_label = Label.new()
		hunter_prox_label.add_theme_font_override("font", font_mono)
		hunter_prox_label.add_theme_font_size_override("font_size", 11)
		hunter_prox_label.add_theme_color_override("font_color", Color(0.95, 0.65, 0.55))
		hunter_prox_label.text = "Hunter: ~40 steps away"
		hunter_prox_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		$GameHud/TopRightBox/VBox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		$GameHud/TopRightBox/VBox.add_child(hunter_prox_label)

	# 2. Locker Slit Overlay (when hiding in locker)
	locker_overlay = Control.new()
	locker_overlay.name = "LockerOverlay"
	locker_overlay.visible = false
	locker_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	locker_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	locker_overlay.draw.connect(_draw_locker_overlay)
	game_hud.add_child(locker_overlay)
	game_hud.move_child(locker_overlay, 0)

	# 2b. Cloak Camouflage / Suffocation Blur / Strangulation Cloth Overlay
	cloak_overlay = Control.new()
	cloak_overlay.name = "CloakOverlay"
	cloak_overlay.visible = false
	cloak_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	cloak_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cloak_overlay.draw.connect(_draw_cloak_overlay)
	game_hud.add_child(cloak_overlay)
	game_hud.move_child(cloak_overlay, 1)

	# 3. Damage Flash Overlay
	damage_flash_rect = ColorRect.new()
	damage_flash_rect.name = "DamageFlash"
	damage_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	damage_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_flash_rect.color = Color(0.9, 0.05, 0.05, 0.0)
	add_child(damage_flash_rect)

	# 4. Floating Message Toast Banner
	toast_label = Label.new()
	toast_label.name = "ToastLabel"
	toast_label.visible = false
	toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_label.offset_left = -320.0
	toast_label.offset_top = 82.0
	toast_label.offset_right = 320.0
	toast_label.offset_bottom = 122.0
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_override("font", font_mono)
	toast_label.add_theme_font_size_override("font_size", 14)
	toast_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	toast_label.add_theme_constant_override("outline_size", 4)
	game_hud.add_child(toast_label)

	# 5. Containment Override [R] Minigame Bar
	override_panel = PanelContainer.new()
	override_panel.visible = false
	override_panel.set_anchors_preset(Control.PRESET_CENTER)
	override_panel.offset_left = -190.0
	override_panel.offset_top = 65.0
	override_panel.offset_right = 190.0
	override_panel.offset_bottom = 135.0
	override_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ov_vbox = VBoxContainer.new()
	override_panel.add_child(ov_vbox)
	var ov_lbl = Label.new()
	ov_lbl.text = "CONTAINMENT OVERRIDE — PRESS [R] OR [SPACE] IN GREEN ZONE"
	ov_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ov_lbl.add_theme_font_override("font", font_mono)
	ov_lbl.add_theme_font_size_override("font_size", 10)
	ov_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.25))
	ov_vbox.add_child(ov_lbl)
	override_canvas = Control.new()
	override_canvas.custom_minimum_size = Vector2(350, 26)
	override_canvas.draw.connect(_draw_override_bar)
	ov_vbox.add_child(override_canvas)
	game_hud.add_child(override_panel)

	# 5b. 2-Slot Weapon Inventory HUD Panel (Bottom Left)
	var bottom_left = game_hud.get_node_or_null("BottomLeft")
	if bottom_left:
		weapon_inv_container = VBoxContainer.new()
		weapon_inv_container.name = "WeaponInventory"
		weapon_inv_container.add_theme_constant_override("separation", 2)

		weapon_mop_label = Label.new()
		weapon_mop_label.add_theme_font_override("font", font_mono)
		weapon_mop_label.add_theme_font_size_override("font_size", 13)
		weapon_mop_label.add_theme_constant_override("outline_size", 2)
		weapon_mop_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		weapon_mop_label.text = "► [Q] MOP (EQUIPPED)"
		weapon_mop_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
		weapon_inv_container.add_child(weapon_mop_label)

		weapon_taser_label = Label.new()
		weapon_taser_label.add_theme_font_override("font", font_mono)
		weapon_taser_label.add_theme_font_size_override("font_size", 13)
		weapon_taser_label.add_theme_constant_override("outline_size", 2)
		weapon_taser_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		weapon_taser_label.text = "  [2] [EMPTY]"
		weapon_taser_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
		weapon_inv_container.add_child(weapon_taser_label)

		weapon_baton_label = Label.new()
		weapon_baton_label.add_theme_font_override("font", font_mono)
		weapon_baton_label.add_theme_font_size_override("font_size", 13)
		weapon_baton_label.add_theme_constant_override("outline_size", 2)
		weapon_baton_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		weapon_baton_label.text = "  [3] [EMPTY]"
		weapon_baton_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
		weapon_inv_container.add_child(weapon_baton_label)

		weapon_guard_label = Label.new()
		weapon_guard_label.add_theme_font_override("font", font_mono)
		weapon_guard_label.add_theme_font_size_override("font_size", 13)
		weapon_guard_label.add_theme_constant_override("outline_size", 2)
		weapon_guard_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		weapon_guard_label.visible = false
		weapon_inv_container.add_child(weapon_guard_label)

		bottom_left.add_child(weapon_inv_container)

	# 5c. Hanger Struggle QTE Bar Widget
	hanger_struggle_panel = PanelContainer.new()
	hanger_struggle_panel.name = "HangerStrugglePanel"
	hanger_struggle_panel.visible = false
	hanger_struggle_panel.set_anchors_preset(Control.PRESET_CENTER)
	hanger_struggle_panel.offset_left = -220.0
	hanger_struggle_panel.offset_top = -140.0
	hanger_struggle_panel.offset_right = 220.0
	hanger_struggle_panel.offset_bottom = -20.0
	hanger_struggle_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var hg_sb = StyleBoxFlat.new()
	hg_sb.bg_color = Color(0.12, 0.02, 0.04, 0.92)
	hg_sb.border_width_left = 3
	hg_sb.border_width_top = 3
	hg_sb.border_width_right = 3
	hg_sb.border_width_bottom = 3
	hg_sb.border_color = Color(0.95, 0.15, 0.25, 0.95)
	hg_sb.content_margin_left = 16
	hg_sb.content_margin_right = 16
	hg_sb.content_margin_top = 10
	hg_sb.content_margin_bottom = 10
	hanger_struggle_panel.add_theme_stylebox_override("panel", hg_sb)

	var hg_vbox = VBoxContainer.new()
	hg_vbox.add_theme_constant_override("separation", 6)
	hanger_struggle_panel.add_child(hg_vbox)

	var hg_title = Label.new()
	hg_title.text = "⚠ CAUGHT BY CEILING HANGER! ⚠"
	hg_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hg_title.add_theme_font_override("font", font_mono)
	hg_title.add_theme_font_size_override("font_size", 14)
	hg_title.add_theme_color_override("font_color", Color(1.0, 0.25, 0.3))
	hg_vbox.add_child(hg_title)

	hanger_struggle_prompt_label = Label.new()
	hanger_struggle_prompt_label.text = "[SPAM SPACE TO STRUGGLE & BREAK FREE]"
	hanger_struggle_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hanger_struggle_prompt_label.add_theme_font_override("font", font_mono)
	hanger_struggle_prompt_label.add_theme_font_size_override("font_size", 12)
	hanger_struggle_prompt_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	hg_vbox.add_child(hanger_struggle_prompt_label)

	hanger_struggle_bar = ProgressBar.new()
	hanger_struggle_bar.custom_minimum_size = Vector2(360, 20)
	hanger_struggle_bar.min_value = 0.0
	hanger_struggle_bar.max_value = 100.0
	hanger_struggle_bar.value = 0.0
	hanger_struggle_bar.show_percentage = true

	var hg_bg = StyleBoxFlat.new()
	hg_bg.bg_color = Color(0.2, 0.05, 0.05, 0.8)
	hanger_struggle_bar.add_theme_stylebox_override("background", hg_bg)

	var hg_fill = StyleBoxFlat.new()
	hg_fill.bg_color = Color(0.2, 0.95, 0.4, 0.95)
	hanger_struggle_bar.add_theme_stylebox_override("fill", hg_fill)
	hg_vbox.add_child(hanger_struggle_bar)

	hanger_struggle_timer_label = Label.new()
	hanger_struggle_timer_label.text = "STRANGULATION IMMINENT (5.0s)"
	hanger_struggle_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hanger_struggle_timer_label.add_theme_font_override("font", font_mono)
	hanger_struggle_timer_label.add_theme_font_size_override("font_size", 11)
	hanger_struggle_timer_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.6))
	hg_vbox.add_child(hanger_struggle_timer_label)

	game_hud.add_child(hanger_struggle_panel)

	# 6. Shift Start Gate Overlay (for Night 2..5 transitions)
	shift_gate_panel = PanelContainer.new()
	shift_gate_panel.visible = false
	shift_gate_panel.set_anchors_preset(Control.PRESET_CENTER)
	shift_gate_panel.offset_left = -240.0
	shift_gate_panel.offset_top = -130.0
	shift_gate_panel.offset_right = 240.0
	shift_gate_panel.offset_bottom = 130.0
	var sg_vbox = VBoxContainer.new()
	sg_vbox.add_theme_constant_override("separation", 12)
	shift_gate_panel.add_child(sg_vbox)

	shift_gate_title = Label.new()
	shift_gate_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shift_gate_title.add_theme_font_override("font", font_horror)
	shift_gate_title.add_theme_font_size_override("font_size", 32)
	sg_vbox.add_child(shift_gate_title)

	shift_gate_sub = Label.new()
	shift_gate_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shift_gate_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shift_gate_sub.add_theme_font_override("font", font_mono)
	shift_gate_sub.add_theme_font_size_override("font_size", 13)
	sg_vbox.add_child(shift_gate_sub)

	var sg_btn = Button.new()
	sg_btn.text = "CLOCK IN & BEGIN SHIFT ▶"
	sg_btn.custom_minimum_size = Vector2(0, 38)
	sg_btn.add_theme_font_override("font", font_mono)
	sg_btn.pressed.connect(func():
		shift_gate_panel.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if shift_gate_callback.is_valid():
			shift_gate_callback.call()
	)
	sg_vbox.add_child(sg_btn)
	add_child(shift_gate_panel)

	# 7. Main Menu button on GameOverScreen
	if game_over_screen:
		var go_menu_btn = Button.new()
		go_menu_btn.text = "MAIN MENU"
		go_menu_btn.add_theme_font_override("font", font_mono)
		go_menu_btn.pressed.connect(func():
			game_over_screen.visible = false
			game_over_to_menu.emit()
		)
		$GameOverScreen/VBox.add_child(go_menu_btn)

	# 8. Extra F9 Debug Panel buttons (Jump N1..N5, Noclip, Step HUD toggle, Spawn Crawler/Cultist, Repair Mop, Unlock Map, +3 Keycards)
	if dev_panel:
		dev_panel.z_index = 100
		dev_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		dev_panel.offset_left = -325.0
		dev_panel.offset_top = 18.0
		dev_panel.offset_right = -15.0
		dev_panel.offset_bottom = 545.0

		var dp_sb = StyleBoxFlat.new()
		dp_sb.bg_color = Color(0.04, 0.06, 0.09, 0.96)
		dp_sb.border_width_left = 2
		dp_sb.border_width_top = 2
		dp_sb.border_width_right = 2
		dp_sb.border_width_bottom = 2
		dp_sb.border_color = Color(0.96, 0.62, 0.07, 0.9)
		dp_sb.content_margin_left = 12
		dp_sb.content_margin_right = 12
		dp_sb.content_margin_top = 10
		dp_sb.content_margin_bottom = 10
		dev_panel.add_theme_stylebox_override("panel", dp_sb)

		var dv = $DevPanel/VBox
		dv.add_theme_constant_override("separation", 5)

		dev_chk_noclip = CheckBox.new()
		dev_chk_noclip.text = "Noclip (đi xuyên tường)"
		dev_chk_noclip.add_theme_font_override("font", font_mono)
		dev_chk_noclip.add_theme_font_size_override("font_size", 12)
		dev_chk_noclip.toggled.connect(func(v): dev_noclip_toggled.emit(v))
		dv.add_child(dev_chk_noclip)
		dv.move_child(dev_chk_noclip, 3)

		dev_chk_steps = CheckBox.new()
		dev_chk_steps.text = "Show Step Counter (hiện số bước)"
		dev_chk_steps.button_pressed = true
		dev_chk_steps.add_theme_font_override("font", font_mono)
		dev_chk_steps.add_theme_font_size_override("font_size", 12)
		dev_chk_steps.toggled.connect(func(v):
			set_dev_mode_active(v)
			dev_steps_hud_toggled.emit(v)
		)
		dv.add_child(dev_chk_steps)
		dv.move_child(dev_chk_steps, 4)

		if dev_btn_objectives:
			dev_btn_objectives.text = "Complete Work Objectives"

		var night_row = HBoxContainer.new()
		night_row.add_theme_constant_override("separation", 4)
		for d in range(1, 6):
			var nb = Button.new()
			nb.text = "N%d" % d
			nb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			nb.add_theme_font_override("font", font_mono)
			nb.add_theme_font_size_override("font_size", 11)
			var day_idx = d
			nb.pressed.connect(func(): dev_jump_day.emit(day_idx))
			night_row.add_child(nb)
		dv.add_child(night_row)

		var sp_row = HBoxContainer.new()
		sp_row.add_theme_constant_override("separation", 4)
		var btn_cr = Button.new()
		btn_cr.text = "+Crawler"
		btn_cr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_cr.add_theme_font_override("font", font_mono)
		btn_cr.add_theme_font_size_override("font_size", 11)
		btn_cr.pressed.connect(func(): dev_spawn_crawler.emit())
		sp_row.add_child(btn_cr)

		var btn_cu = Button.new()
		btn_cu.text = "+Cultist"
		btn_cu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_cu.add_theme_font_override("font", font_mono)
		btn_cu.add_theme_font_size_override("font_size", 11)
		btn_cu.pressed.connect(func(): dev_spawn_cultist.emit())
		sp_row.add_child(btn_cu)

		var btn_clk = Button.new()
		btn_clk.text = "+Cloak"
		btn_clk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_clk.add_theme_font_override("font", font_mono)
		btn_clk.add_theme_font_size_override("font_size", 11)
		btn_clk.pressed.connect(func(): dev_spawn_cloak.emit())
		sp_row.add_child(btn_clk)

		var btn_hgr = Button.new()
		btn_hgr.text = "+Hanger"
		btn_hgr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_hgr.add_theme_font_override("font", font_mono)
		btn_hgr.add_theme_font_size_override("font_size", 11)
		btn_hgr.pressed.connect(func(): dev_spawn_hanger.emit())
		sp_row.add_child(btn_hgr)
		dv.add_child(sp_row)

		var util_row = HBoxContainer.new()
		util_row.add_theme_constant_override("separation", 4)
		var btn_mop = Button.new()
		btn_mop.text = "Fix Mop"
		btn_mop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_mop.add_theme_font_override("font", font_mono)
		btn_mop.add_theme_font_size_override("font_size", 11)
		btn_mop.pressed.connect(func(): dev_repair_mop.emit())
		util_row.add_child(btn_mop)

		var btn_map = Button.new()
		btn_map.text = "Full Map"
		btn_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_map.add_theme_font_override("font", font_mono)
		btn_map.add_theme_font_size_override("font_size", 11)
		btn_map.pressed.connect(func(): dev_unlock_map.emit())
		util_row.add_child(btn_map)

		var btn_keys = Button.new()
		btn_keys.text = "+3 Keys"
		btn_keys.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_keys.add_theme_font_override("font", font_mono)
		btn_keys.add_theme_font_size_override("font_size", 11)
		btn_keys.pressed.connect(func(): dev_give_keycards.emit())
		util_row.add_child(btn_keys)
		dv.add_child(util_row)

		if dev_btn_skip:
			dev_btn_skip.text = "Complete Current Night ▶"

		# Cutscene Tester row in DevPanel (Master Spec Section 14)
		var cs_row = HBoxContainer.new()
		cs_row.add_theme_constant_override("separation", 4)
		var cs_tests = [
			{"label": "CS:Intro", "id": "intro"},
			{"label": "CS:Breach", "id": "chaseBegin"},
			{"label": "CS:$1B", "id": "endingFired"},
			{"label": "CS:True", "id": "endingEarth"}
		]
		for ct in cs_tests:
			var cb = Button.new()
			cb.text = ct["label"]
			cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cb.add_theme_font_override("font", font_mono)
			cb.add_theme_font_size_override("font_size", 10)
			var cid: String = ct["id"]
			cb.pressed.connect(func(): dev_test_cutscene.emit(cid))
			cs_row.add_child(cb)
		dv.add_child(cs_row)

		var btn_resume_dev = Button.new()
		btn_resume_dev.text = "▶ Đóng Menu & Chơi Tiếp (F9)"
		btn_resume_dev.add_theme_font_override("font", font_mono)
		btn_resume_dev.add_theme_font_size_override("font_size", 12)
		btn_resume_dev.add_theme_color_override("font_color", Color(0.25, 0.98, 0.55))
		btn_resume_dev.pressed.connect(func():
			hide_dev_panel()
			dev_panel_closed.emit()
		)
		dv.add_child(btn_resume_dev)

		# Prevent Space/Enter from accidentally pressing focused debug buttons during gameplay
		for node in dev_panel.find_children("*", "BaseButton", true, false):
			if node is Control:
				node.focus_mode = Control.FOCUS_NONE

	# 9. Pause Warning Status Label inside PauseMenu
	if pause_menu and pause_menu.has_node("VBox"):
		pause_warning_label = Label.new()
		pause_warning_label.text = "Shift paused. Resume when you are ready."
		pause_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pause_warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pause_warning_label.add_theme_font_override("font", font_mono)
		pause_warning_label.add_theme_font_size_override("font_size", 12)
		pause_warning_label.add_theme_color_override("font_color", Color(0.95, 0.65, 0.35))
		$PauseMenu/VBox.add_child(pause_warning_label)
		$PauseMenu/VBox.move_child(pause_warning_label, 1)

	# 10. Meta-Horror Quit Warning Modal (matching HTML #quit-warning-modal lines 4318-4372)
	quit_warning_modal = PanelContainer.new()
	quit_warning_modal.name = "QuitWarningModal"
	quit_warning_modal.visible = false
	quit_warning_modal.set_anchors_preset(Control.PRESET_CENTER)
	quit_warning_modal.offset_left = -260.0
	quit_warning_modal.offset_top = -130.0
	quit_warning_modal.offset_right = 260.0
	quit_warning_modal.offset_bottom = 130.0
	var qw_sb = StyleBoxFlat.new()
	qw_sb.bg_color = Color(0.08, 0.01, 0.02, 0.96)
	qw_sb.border_width_left = 2
	qw_sb.border_width_top = 2
	qw_sb.border_width_right = 2
	qw_sb.border_width_bottom = 2
	qw_sb.border_color = Color(0.95, 0.18, 0.20, 0.95)
	qw_sb.content_margin_left = 20
	qw_sb.content_margin_right = 20
	qw_sb.content_margin_top = 18
	qw_sb.content_margin_bottom = 18
	quit_warning_modal.add_theme_stylebox_override("panel", qw_sb)

	var qw_vbox = VBoxContainer.new()
	qw_vbox.add_theme_constant_override("separation", 14)
	quit_warning_modal.add_child(qw_vbox)

	quit_warning_title = Label.new()
	quit_warning_title.text = "YOU DON'T HAVE THE AUTHORITY TO LEAVE JUST YET."
	quit_warning_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quit_warning_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quit_warning_title.add_theme_font_override("font", font_horror)
	quit_warning_title.add_theme_font_size_override("font_size", 26)
	quit_warning_title.add_theme_color_override("font_color", Color(0.96, 0.22, 0.24))
	qw_vbox.add_child(quit_warning_title)

	quit_warning_body = Label.new()
	quit_warning_body.text = "First notice: your performance is still in progress."
	quit_warning_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quit_warning_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quit_warning_body.add_theme_font_override("font", font_mono)
	quit_warning_body.add_theme_font_size_override("font_size", 13)
	quit_warning_body.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
	qw_vbox.add_child(quit_warning_body)

	var qw_btn = Button.new()
	qw_btn.text = "RETURN TO SHIFT"
	qw_btn.custom_minimum_size = Vector2(0, 38)
	qw_btn.add_theme_font_override("font", font_mono)
	qw_btn.pressed.connect(func():
		quit_warning_modal.visible = false
		quit_modal_dismissed.emit()
	)
	qw_vbox.add_child(qw_btn)
	add_child(quit_warning_modal)

	# Keep DevPanel as the topmost child of HUD so nothing ever blocks its mouse clicks
	if dev_panel:
		move_child(dev_panel, get_child_count() - 1)

func show_quit_warning_modal(heading_str: String, body_str: String) -> void:
	if quit_warning_title:
		quit_warning_title.text = heading_str
	if quit_warning_body:
		quit_warning_body.text = body_str
	if quit_warning_modal:
		quit_warning_modal.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func set_pause_warning_text(msg: String) -> void:
	if pause_warning_label:
		pause_warning_label.text = msg

func set_dev_mode_active(enabled: bool) -> void:
	dev_mode_enabled = enabled
	if chase_hud_box:
		chase_hud_box.visible = dev_mode_enabled and (current_hud_phase == "chase")

func _draw_locker_overlay() -> void:
	if not locker_overlay or not locker_overlay.visible:
		return
	var w = locker_overlay.size.x
	var h = locker_overlay.size.y
	var border_col = Color(0.02, 0.03, 0.04, 0.94)
	locker_overlay.draw_rect(Rect2(0, 0, w * 0.16, h), border_col)
	locker_overlay.draw_rect(Rect2(w * 0.84, 0, w * 0.16, h), border_col)
	locker_overlay.draw_rect(Rect2(0, 0, w, h * 0.14), border_col)
	locker_overlay.draw_rect(Rect2(0, h * 0.86, w, h * 0.14), border_col)
	var slat_col = Color(0.04, 0.05, 0.07, 0.82)
	locker_overlay.draw_rect(Rect2(w * 0.16, h * 0.22, w * 0.68, 16), slat_col)
	locker_overlay.draw_rect(Rect2(w * 0.16, h * 0.76, w * 0.68, 16), slat_col)
	locker_overlay.draw_rect(Rect2(w * 0.5 - 4, h * 0.14, 8, h * 0.72), Color(0.03, 0.04, 0.05, 0.55))

func _draw_override_bar() -> void:
	if not override_canvas:
		return
	var w = override_canvas.size.x
	var h = override_canvas.size.y
	override_canvas.draw_rect(Rect2(0, 0, w, h), Color(0.08, 0.1, 0.14, 0.95))
	override_canvas.draw_rect(Rect2(override_zone_min * w, 2, (override_zone_max - override_zone_min) * w, h - 4), Color(0.15, 0.85, 0.35, 0.85))
	override_canvas.draw_rect(Rect2(override_cursor * w - 3, 0, 6, h), Color(1.0, 0.95, 0.3, 1.0))
	override_canvas.draw_rect(Rect2(0, 0, w, h), Color(0.4, 0.5, 0.6, 0.9), false, 2.0)

func set_locker_overlay(enabled: bool) -> void:
	if locker_overlay:
		locker_overlay.visible = enabled
		if enabled:
			locker_overlay.queue_redraw()

func set_cloak_overlay(mode: String, ratio: float) -> void:
	if not cloak_overlay:
		return
	cloak_overlay_mode = mode
	cloak_overlay_ratio = clampf(ratio, 0.0, 1.0)
	if mode == "none" or cloak_overlay_ratio <= 0.001:
		cloak_overlay.visible = false
	else:
		cloak_overlay.visible = true
		cloak_overlay.queue_redraw()

func _draw_cloak_overlay() -> void:
	if not cloak_overlay or not cloak_overlay.visible:
		return
	var w: float = cloak_overlay.size.x
	var h: float = cloak_overlay.size.y
	var r: float = cloak_overlay_ratio
	var t_sec: float = float(Time.get_ticks_msec()) * 0.001

	if cloak_overlay_mode == "suffocate":
		# 1. Draped ethereal white silk shroud borders around screen edges so player feels inside her shroud
		var fold_w: float = w * lerpf(0.08, 0.34, r)
		var fold_h: float = h * lerpf(0.07, 0.30, r)
		# Starts as soft translucent pearlescent silk, gradually darkening as oxygen depletes
		var cloth_col := Color(lerpf(0.88, 0.04, r), lerpf(0.88, 0.02, r), lerpf(0.95, 0.06, r), lerpf(0.52, 0.96, r))
		cloak_overlay.draw_rect(Rect2(0, 0, fold_w, h), cloth_col)
		cloak_overlay.draw_rect(Rect2(w - fold_w, 0, fold_w, h), cloth_col)
		cloak_overlay.draw_rect(Rect2(0, 0, w, fold_h), cloth_col)
		cloak_overlay.draw_rect(Rect2(0, h - fold_h * 0.85, w, fold_h * 0.85), cloth_col)

		# Soft inner blur feather bands (gradually narrowing & blurring vision as oxygen runs out)
		for i in range(1, 6):
			var fi: float = float(i)
			var inset_x: float = fold_w + fi * (w * 0.035)
			var inset_y: float = fold_h + fi * (h * 0.032)
			var band_a: float = clampf((r - 0.12) * 0.95 / fi, 0.0, 0.72)
			if band_a > 0.01 and w - inset_x * 2.0 > 10.0 and h - inset_y * 2.0 > 10.0:
				var b_col := Color(lerpf(0.82, 0.05, r), lerpf(0.80, 0.03, r), lerpf(0.90, 0.08, r), band_a)
				cloak_overlay.draw_rect(Rect2(inset_x - 28.0, inset_y - 22.0, 28.0, h - (inset_y - 22.0) * 2.0), b_col)
				cloak_overlay.draw_rect(Rect2(w - inset_x, inset_y - 22.0, 28.0, h - (inset_y - 22.0) * 2.0), b_col)
				cloak_overlay.draw_rect(Rect2(inset_x, inset_y - 22.0, w - inset_x * 2.0, 22.0), b_col)
				cloak_overlay.draw_rect(Rect2(inset_x, h - inset_y, w - inset_x * 2.0, 22.0), b_col)

		# 2. Progressive hypoxic vision blur / fogging ("tầm nhìn sẽ dần mờ" + pulsing with rapid breathing)
		var pulse_spd: float = lerpf(3.0, 14.0, r)
		var breath_pulse: float = (0.5 + 0.5 * sin(t_sec * pulse_spd)) * r * 0.18
		var haze_alpha: float = clampf(pow(r, 1.35) * 0.88 + breath_pulse, 0.0, 0.98)
		cloak_overlay.draw_rect(Rect2(0, 0, w, h), Color(0.04, 0.02, 0.07, haze_alpha))

	elif cloak_overlay_mode == "strangle":
		# Cloth coiling around the player's body and strangling their neck ("vải quấn quanh cơ thể xong xiết cổ chết")
		var num_bands: int = 7
		for b in range(num_bands):
			var fb: float = float(b) / float(num_bands - 1)
			var appear: float = clampf((r * 1.35) - fb * 0.45, 0.0, 1.0)
			if appear <= 0.01:
				continue
			var band_y: float = lerpf(h * 0.85, h * 0.12, fb) + sin(t_sec * 18.0 + float(b)) * 8.0 * (1.0 - r * 0.5)
			var band_thick: float = lerpf(36.0, 92.0, r) * appear
			var band_col := Color(0.04, 0.01, 0.03, 0.92 * appear)
			cloak_overlay.draw_rect(Rect2(0, band_y - band_thick * 0.5, w, band_thick), band_col)
			# Crimson inner thread highlight on tightening cloth coils
			var seam_col := Color(0.45, 0.03, 0.08, 0.55 * appear)
			cloak_overlay.draw_rect(Rect2(0, band_y - 2.0, w, 4.0), seam_col)

		# Tightening throat constriction blackout when neck is wrenched (r > 0.55)
		var choke_alpha: float = clampf((r - 0.25) * 1.15, 0.0, 0.96)
		cloak_overlay.draw_rect(Rect2(0, 0, w, h), Color(0.08, 0.01, 0.02, choke_alpha))

func show_toast(msg: String, col: Color = Color(0.95, 0.88, 0.35), dur: float = 3.2) -> void:
	if not toast_label:
		return
	toast_label.text = msg
	toast_label.modulate = col
	toast_label.visible = true
	toast_timer = dur

func flash_damage() -> void:
	if not damage_flash_rect:
		return
	damage_flash_rect.color = Color(0.9, 0.05, 0.05, 0.52)
	var tw = create_tween()
	tw.tween_property(damage_flash_rect, "color:a", 0.0, 0.45)

func start_override_minigame() -> void:
	if override_active:
		return
	override_active = true
	override_cursor = 0.0
	override_dir = 1.0
	override_zone_min = randf_range(0.42, 0.64)
	override_zone_max = override_zone_min + 0.18
	override_panel.visible = true

func show_shift_gate(day_num: int, on_begin: Callable) -> void:
	var meta = GameData.DAY_META[clampi(day_num - 1, 0, GameData.DAY_META.size() - 1)]
	shift_gate_title.text = meta.get("title", "NIGHT %d" % day_num)
	shift_gate_title.modulate = meta.get("color", Color(0.3, 0.9, 0.5))
	shift_gate_sub.text = "%s\n\n• Mop 3 Toxic Spills, 3 Blood Stains & 2 Science Terminals\n• Active Specimens: %d Crawlers, %d Observers, %d Cultists\n• Shift Authorised — Entering Facility…" % [
		meta.get("label", ""),
		int(meta.get("crawlers", 4)),
		int(meta.get("statues", 0)),
		int(meta.get("cultists", 0))
	]
	shift_gate_callback = on_begin
	shift_gate_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta: float) -> void:
	if _note_just_opened:
		_note_just_opened = false

	# Animate Main Menu continuously when visible
	if main_menu and main_menu.visible:
		menu_anim_time += delta
		if menu_glitch_timer > 0.0:
			menu_glitch_timer = max(0.0, menu_glitch_timer - delta)
		if menu_badge:
			var flick = 0.35 if fmod(menu_anim_time * 5.0, 9.0) > 8.75 else (0.75 + 0.25 * sin(menu_anim_time * 2.5))
			menu_badge.modulate.a = flick
		if menu_line2:
			var jx = randf_range(-4.0, 4.0) if (menu_glitch_timer > 0.0 or fmod(menu_anim_time * 9.0, 14.0) < 0.18) else 0.0
			menu_line2.position.x = jx
		if menu_canvas:
			menu_canvas.queue_redraw()

	if toast_timer > 0.0:
		toast_timer -= delta
		if toast_timer <= 0.0 and toast_label:
			toast_label.visible = false

	if override_active:
		override_cursor += override_dir * delta * 1.45
		if override_cursor >= 1.0:
			override_cursor = 1.0
			override_dir = -1.0
		elif override_cursor <= 0.0:
			override_cursor = 0.0
			override_dir = 1.0
		if override_canvas:
			override_canvas.queue_redraw()

	# Animate Cutscene Canvas every frame (matching HTML csLoop) + Typewriter + Slide Delay
	if cutscene_player.visible:
		cs_slide_time += delta
		if cs_input_delay > 0.0:
			cs_input_delay = max(0.0, cs_input_delay - delta)
		if cutscene_canvas:
			cutscene_canvas.queue_redraw()
		if type_idx < full_text.length() and cs_slide_time >= 0.12:
			type_timer += delta
			if type_timer >= 0.034:
				type_timer = 0.0
				type_idx += 1
				cs_text.text = full_text.substr(0, type_idx) + (" █" if type_idx < full_text.length() else "")
				if type_idx % 3 == 0:
					SoundEffects.play(SoundEffects.snd_click, -18.0, 1.4)

func _unhandled_input(event: InputEvent) -> void:
	if override_active:
		if event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_R or event.physical_keycode == KEY_SPACE):
			var success = override_cursor >= override_zone_min and override_cursor <= override_zone_max
			override_active = false
			override_panel.visible = false
			override_completed.emit(success)
			get_viewport().set_input_as_handled()
			return

	if note_popup.visible:
		if _note_just_opened:
			return
		if (event is InputEventKey and event.pressed and (event.physical_keycode == KEY_E or event.physical_keycode == KEY_ESCAPE or event.physical_keycode == KEY_SPACE or event.physical_keycode == KEY_ENTER)) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			hide_note_popup()
			get_viewport().set_input_as_handled()
			return

	if cutscene_player.visible:
		if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_SPACE or event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_E)):
			_on_cutscene_next_action()
			get_viewport().set_input_as_handled()
			return

func _on_cutscene_next_action() -> void:
	if not cutscene_player.visible:
		return
	# Slight delay on slide entry so clicks feel deliberate and never accidentally double-skip
	if cs_input_delay > 0.0:
		return
	if type_idx < full_text.length():
		type_idx = full_text.length()
		cs_text.text = full_text
		cs_input_delay = 0.18
	else:
		_advance_cutscene()

func _on_exit_hover() -> void:
	menu_glitch_timer = 1.6
	var ox = randf_range(-90.0, 90.0)
	var oy = randf_range(-40.0, 40.0)
	btn_exit.position += Vector2(ox, oy)
	menu_footer.text = "THE COMPANY DOES NOT LET YOU LEAVE."
	menu_footer.modulate = Color(0.95, 0.2, 0.2)
	SoundEffects.play(SoundEffects.snd_click, -2.0, 0.65)

func set_phase_presentation(phase: String, day_num: int = 1) -> void:
	current_hud_phase = phase
	game_hud.visible = true
	var meta = GameData.DAY_META[clampi(day_num - 1, 0, GameData.DAY_META.size() - 1)]
	var night_title = meta.get("title", "NIGHT %d" % day_num)
	if phase == "work":
		facility_title.text = "%s [WORK SHIFT]" % night_title
		facility_dot.color = Color(0.2, 0.85, 0.3)
		chase_hud_box.visible = false
		dist_warning.text = "STATUS: COMPLETE QUOTA TO UNLOCK ESCAPE"
		dist_warning.modulate = Color(0.3, 0.9, 0.4)
	elif phase == "chase":
		facility_title.text = "%s [CONTAINMENT BREACH]" % night_title
		facility_dot.color = Color(0.95, 0.15, 0.2)
		# Raw step counter box is ONLY shown in Dev Mode (matching HTML lines 4279-4280 & 4472-4475)
		chase_hud_box.visible = dev_mode_enabled
		dist_warning.text = "STATUS: CONTAINMENT BREACH — SURVIVE & RUN!"
		dist_warning.modulate = Color(1.0, 0.25, 0.25)

func update_work_objectives(
	spills: int,
	max_spills: int,
	terms: int,
	max_terms: int,
	relics: int,
	wages: int,
	blood_cleaned: int = 0,
	keycards: int = 0,
	max_keycards: int = 3,
	_bites: int = 0,
	bait_left: int = 3,
	f2_info: Dictionary = {}
) -> void:
	_cached_keycards = keycards
	_cached_max_keycards = max_keycards
	var lines: Array[String] = []
	if current_hud_phase == "work":
		if f2_info.is_empty():
			lines.append("• Mop spills: %d / %d" % [spills, max_spills])
			lines.append("• Check terminals: %d / %d" % [terms, max_terms])
			lines.append("• Clean blood stains: %d / 3 (+$15 each)" % blood_cleaned)
			lines.append("• Wages: $%d  |  Bait [B]: %d" % [wages, bait_left])
		else:
			lines.append("• 1F Mop spills: %d / %d" % [spills, max_spills])
			lines.append("• 1F Check terminals: %d / %d" % [terms, max_terms])
			lines.append("• 1F Clean blood: %d / 2 (+$15 each)" % blood_cleaned)
			lines.append("• 2F Shutdown rogue PCs: %d / %d [SEC D]" % [f2_info.get("terms_done", 0), f2_info.get("terms_needed", 2)])
			var usb_str = "ARCHIVED [SEC A-1]" if f2_info.get("usb_done", false) else ("DELIVER -> [SEC A-1 VAULT]" if f2_info.get("has_usb", false) else "TAKE [SEC A-2]")
			lines.append("• 2F Research USB: %s" % usb_str)
			var dos_str = "FILED [SEC B-1]" if f2_info.get("dossier_done", false) else ("FILE -> [SEC B-1 ARCHIVE]" if f2_info.get("has_dossier", false) else "TAKE [SEC B-2]")
			lines.append("• 2F Classified Dossier: %s" % dos_str)
			var cool_str = "COOLED [SEC C-1]" if f2_info.get("coolant_done", false) else ("INJECT -> [SEC C-1 SERVER]" if f2_info.get("has_coolant", false) else "TAKE [SEC C-2]")
			lines.append("• 2F Server Coolant: %s" % cool_str)
			lines.append("• Wages: $%d  |  Bait [B]: %d" % [wages, bait_left])
		if relics > 0:
			lines.append("• Relics: %d / 15" % relics)
	else:
		# CHASE PHASE: Exactly 2 objectives as requested
		# 1: collect key card
		# 2: RUN!
		var task1 = "• 1: collect key card (%d / %d)" % [keycards, max_keycards]
		if keycards >= max_keycards:
			task1 = "• 1: collect key card: SECURED (%d / %d) ✓" % [keycards, max_keycards]
		lines.append(task1)

		var task2 = "• 2: RUN!"
		if keycards >= max_keycards:
			task2 = "• 2: RUN TO THE EXIT GATE!"
		lines.append(task2)

		if keycards < max_keycards:
			dist_warning.text = "STATUS: COLLECT %d KEYCARD%s TO UNLOCK EXIT!" % [(max_keycards - keycards), ("S" if (max_keycards - keycards) > 1 else "")]
			dist_warning.modulate = Color(1.0, 0.45, 0.2)
		else:
			dist_warning.text = "STATUS: EXIT GATE UNLOCKED — EVACUATE NOW!"
			dist_warning.modulate = Color(0.25, 1.0, 0.45)

		if dev_mode_enabled:
			var final_tag = " (FINAL INVINCIBLE!)" if _cached_dist <= GameData.FINAL_TRIGGER_STEPS else " (Final at <=%d)" % GameData.FINAL_TRIGGER_STEPS
			lines.append("• [DEV] Steps: %d%s · Entity: ~%d away" % [_cached_dist, final_tag, _cached_hunter_steps])
	objective_list.text = "\n".join(lines)

func update_chase_distance(dist: int, max_dist: int = 210, hunter_steps_away: int = 40, keycards: int = 0, max_keycards: int = 3) -> void:
	_cached_dist = dist
	_cached_max_dist = max_dist
	_cached_hunter_steps = hunter_steps_away
	_cached_keycards = keycards
	_cached_max_keycards = max_keycards

	# Enforce HTML & user rule: raw step counter before Final Mode is hidden outside Dev Mode
	if chase_hud_box:
		chase_hud_box.visible = dev_mode_enabled and (current_hud_phase == "chase")

	chase_distance_hud.text = "%d STEPS" % dist
	if dist <= 50:
		chase_distance_hud.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
	else:
		chase_distance_hud.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	chase_bar.max_value = float(max(max_dist, 1))
	chase_bar.value = clampf(float(dist), 0.0, float(max_dist))
	if hunter_prox_label:
		var f_str = " [FINAL RAGE]" if dist <= GameData.FINAL_TRIGGER_STEPS else " [Final <=%d]" % GameData.FINAL_TRIGGER_STEPS
		hunter_prox_label.text = "Hunter: ~%d steps%s | Keys: %d/%d" % [hunter_steps_away, f_str, keycards, max_keycards]

func update_stamina(val: float, max_val: float) -> void:
	stamina_bar.value = (val / max_val) * 100.0

func update_mop_integrity(val: float, max_val: float = 100.0) -> void:
	if mop_bar:
		mop_bar.value = clampf((val / max_val) * 100.0, 0.0, 100.0)

func update_weapon_inventory(active_w: int, has_taser: bool, taser_ammo: int, has_baton: bool, baton_durability: float, is_guarding: bool, is_parrying: bool) -> void:
	if not weapon_inv_container or not is_instance_valid(weapon_mop_label):
		return

	# Slot MOP
	if active_w == 0:
		weapon_mop_label.text = "► [Q] MOP (EQUIPPED)"
		weapon_mop_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	else:
		weapon_mop_label.text = "  [Q] MOP"
		weapon_mop_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

	# Slot 1: TASER
	if has_taser:
		var txt = "► [2] STUN GUN (%d SHOT)" % taser_ammo if active_w == 1 else "  [2] STUN GUN (%d SHOT)" % taser_ammo
		weapon_taser_label.text = txt
		weapon_taser_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0) if active_w == 1 else Color(0.3, 0.7, 0.8))
	else:
		weapon_taser_label.text = "  [2] [EMPTY]"
		weapon_taser_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))

	# Slot 2: BATON
	if has_baton:
		var d_pct = int(round(baton_durability))
		var txt = "► [3] SHOCK BATON (%d%%)" % d_pct if active_w == 2 else "  [3] SHOCK BATON (%d%%)" % d_pct
		weapon_baton_label.text = txt
		weapon_baton_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4) if active_w == 2 else Color(0.4, 0.8, 0.4))
	else:
		weapon_baton_label.text = "  [3] [EMPTY]"
		weapon_baton_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))

	# Guard / Parry status indicator
	if is_guarding and active_w == 2:
		weapon_guard_label.visible = true
		if is_parrying:
			weapon_guard_label.text = "⚡ PARRY WINDOW ACTIVE (0.25s)!"
			weapon_guard_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.2))
		else:
			weapon_guard_label.text = "🛡 BLOCKING DEFENSE (RMB)"
			weapon_guard_label.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
	else:
		weapon_guard_label.visible = false

func set_interaction_prompt(prompt: String) -> void:
	if prompt != "":
		interaction_label.visible = true
		interaction_label.text = prompt
		reticle.modulate = Color(0.2, 1.0, 0.4)
	else:
		interaction_label.visible = false
		reticle.modulate = Color(1.0, 1.0, 1.0, 0.7)

func show_hanger_struggle(time_left: float, current_count: int, required_count: int) -> void:
	if hanger_struggle_panel:
		hanger_struggle_panel.visible = true
		var pct = (float(current_count) / float(max(1, required_count))) * 100.0
		if hanger_struggle_bar:
			hanger_struggle_bar.value = pct
		if hanger_struggle_timer_label:
			hanger_struggle_timer_label.text = "STRANGULATION IN: %.1fs  |  PROGRESS: %d / %d" % [time_left, current_count, required_count]
		var flash = (int(Time.get_ticks_msec() / 200) % 2) == 0
		if hanger_struggle_prompt_label:
			hanger_struggle_prompt_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.2) if flash else Color(1.0, 0.35, 0.35))

func hide_hanger_struggle() -> void:
	if hanger_struggle_panel:
		hanger_struggle_panel.visible = false

func show_note_popup(title: String, tag: String, body_content) -> void:
	note_title.text = title
	note_tag.text = tag
	if body_content is Array:
		note_body.text = "\n\n".join(body_content)
	else:
		note_body.text = str(body_content)
	note_popup.visible = true
	_note_just_opened = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func hide_note_popup() -> void:
	note_popup.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func update_minimap_interactables(interactables: Array, chase_phase: bool) -> void:
	if minimap and minimap.has_method("set_interactables"):
		minimap.set_interactables(interactables, chase_phase)

func show_dev_panel(god: bool, freeze: bool, noclip: bool = false, show_steps: bool = true) -> void:
	set_dev_mode_active(show_steps)
	if dev_panel:
		move_child(dev_panel, get_child_count() - 1)
		dev_panel.visible = true
		dev_chk_god.set_pressed_no_signal(god)
		dev_chk_freeze.set_pressed_no_signal(freeze)
		if dev_chk_noclip:
			dev_chk_noclip.set_pressed_no_signal(noclip)
		if dev_chk_steps:
			dev_chk_steps.set_pressed_no_signal(show_steps)

func hide_dev_panel(keep_dev_hud: bool = false) -> void:
	set_dev_mode_active(keep_dev_hud)
	if dev_panel:
		dev_panel.visible = false

func show_victory_summary(title_str: String, summary_str: String, is_true_ending: bool = false) -> void:
	if victory_title:
		victory_title.text = title_str
		victory_title.add_theme_color_override("font_color", Color(0.25, 0.95, 0.55) if is_true_ending else Color(0.95, 0.75, 0.25))
	if victory_msg:
		victory_msg.text = summary_str
	victory_screen.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func play_cutscene(cutscene_id: String, on_done: Callable) -> void:
	current_slides = GameData.CUTSCENES.get(cutscene_id, [])
	if current_slides.is_empty():
		on_done.call()
		return
	cutscene_art_id = cutscene_id
	cs_fx_mode = CS_FX_MAP.get(cutscene_id, "dust")
	slide_index = 0
	cutscene_callback = on_done
	cutscene_player.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_current_slide()

func _show_current_slide() -> void:
	if slide_index >= current_slides.size():
		_finish_cutscene()
		return
	var s = current_slides[slide_index]
	var spk = s.get("speaker", "NARRATOR")
	cs_speaker.text = spk if spk != "" else "NARRATOR"
	full_text = s.get("text", "")
	type_idx = 0
	type_timer = 0.0
	cs_slide_time = 0.0
	cs_input_delay = 0.28 # Slight delay on each slide transition matching HTML feel
	cs_text.text = ""
	cs_counter.text = "%d / %d" % [slide_index + 1, current_slides.size()]
	if slide_index >= current_slides.size() - 1:
		cs_next.text = "CONTINUE ▶"
	else:
		cs_next.text = "NEXT ▶"
	if cutscene_canvas:
		cutscene_canvas.queue_redraw()

func update_flashlight_status(is_on: bool) -> void:
	if not flashlight_status:
		return
	if is_on:
		flashlight_status.text = "ON"
		flashlight_status.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4, 1.0))
	else:
		flashlight_status.text = "OFF"
		flashlight_status.add_theme_color_override("font_color", Color(0.4, 0.45, 0.5, 1.0))

func _advance_cutscene() -> void:
	slide_index += 1
	_show_current_slide()

func _finish_cutscene() -> void:
	if not cutscene_player.visible:
		return
	cutscene_player.visible = false
	var cb = cutscene_callback
	cutscene_callback = Callable()
	get_viewport().set_input_as_handled()
	if cb.is_valid():
		cb.call()

# Animated Cutscene Renderer ported from HTML CUTSCENES + csLoop(now) (lines 3825-4179):
# Features continuous frame jitter/shake, slow creeping zoom, chromatic glitch slices,
# animated rain/dust/alarm siren pulse, light flicker, film grain, and 0.45s slide fade-in.
func _draw_cutscene_illustration() -> void:
	if not cutscene_canvas or not cutscene_player.visible:
		return
	var w = cutscene_canvas.size.x
	var h = cutscene_canvas.size.y
	var t = cs_slide_time

	var is_alarm = (cs_fx_mode == "alarm")
	var sh = 4.2 if is_alarm else (7.0 if t < 0.30 else 0.85)
	var zoom = 1.0 + 0.05 * min(t / 8.0, 1.0)
	var jx = (sin(t * 67.3) * cos(t * 41.7)) * sh
	var jy = (cos(t * 53.1) * sin(t * 79.9)) * sh

	cutscene_canvas.draw_rect(Rect2(Vector2.ZERO, cutscene_canvas.size), Color(0.01, 0.015, 0.03, 1.0))

	# Apply camera jitter + creeping zoom transform matching HTML csLoop
	var center = Vector2(w * 0.5, h * 0.5)
	cutscene_canvas.draw_set_transform(center + Vector2(jx, jy), 0.0, Vector2(zoom, zoom))
	_draw_slide_scene_content(w, h, t, - center)

	# Chromatic / ghost double-image glitch on slide entry (t < 0.38) or periodic glitch spikes
	var do_glitch = (t < 0.38) or (fmod(t * 11.0, 7.0) < 0.14)
	if do_glitch:
		cutscene_canvas.draw_set_transform(center + Vector2(jx + 7.0, jy), 0.0, Vector2(zoom, zoom))
		_draw_slide_scene_content(w, h, t, -center, 0.25)

	# Reset transform for screen-space FX (rain, dust, alarm pulse, glitch bars, letterbox, fade-in)
	cutscene_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if do_glitch:
		var gy = fmod(t * 640.0, max(1.0, h))
		cutscene_canvas.draw_rect(Rect2(0, gy, w, 4.0 + fmod(t * 97.0, 10.0)), Color(1.0, 1.0, 1.0, 0.09))

	if cs_fx_mode == "rain":
		var rain_col = Color(0.55, 0.71, 0.90, 0.28)
		for i in range(90):
			var rx = fmod(float(i * 97) + t * 42.0, max(1.0, w))
			var ry = fmod(float(i * 53) + t * 880.0, max(1.0, h))
			cutscene_canvas.draw_line(Vector2(rx, ry), Vector2(rx + 4.0, ry + 22.0), rain_col, 1.1)
	else:
		var dust_col = Color(0.78, 0.82, 0.90, 0.24)
		for i in range(45):
			var dx = fmod(float(i * 131) + t * 8.0 * float(1 + (i % 3)), max(1.0, w))
			var dy = fmod(float(i * 71) - t * 6.0 * float(1 + (i % 4)) + h * 20.0, max(1.0, h))
			var dsz = float(1 + (i % 2))
			cutscene_canvas.draw_rect(Rect2(dx, dy, dsz, dsz), dust_col)

	if is_alarm:
		var a_pulse = 0.07 + 0.07 * sin(t * 7.0)
		cutscene_canvas.draw_rect(Rect2(0, 0, w, h), Color(0.86, 0.08, 0.08, a_pulse))

	# Random 2% fluorescent light flicker
	if fmod(t * 43.0, 3.7) < 0.07:
		cutscene_canvas.draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.44))

	# Animated film grain speckles & CRT scanlines
	for g in range(36):
		var gx = fmod(float(g * 173) + t * 997.0, max(1.0, w))
		var gy = fmod(float(g * 211) + t * 743.0, max(1.0, h))
		cutscene_canvas.draw_rect(Rect2(gx, gy, 2.0, 2.0), Color(1, 1, 1, 0.05))

	# Smooth 0.45s fade-in on slide entry (matching HTML if (t < 0.5) fade-in)
	if t < 0.45:
		var fade_a = clampf(1.0 - (t / 0.45), 0.0, 1.0)
		cutscene_canvas.draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, fade_a))

func _draw_slide_scene_content(w: float, h: float, t: float, ofs: Vector2, alpha_mul: float = 1.0) -> void:
	var slide_art := ""
	if slide_index < current_slides.size():
		slide_art = str(current_slides[slide_index].get("art", ""))

	var cx = w * 0.5 + ofs.x
	var cy = h * 0.5 + ofs.y

	if slide_art == "room_rain_bulb" or slide_art == "window" or (cutscene_art_id == "intro" and slide_index == 0):
		# Slide 1: Cramped dusty boarding-house room (Room 4B) in heavy rain with a single swaying bare light bulb
		var floor_y = cy + 95.0
		# Back wall & dark floorboards
		cutscene_canvas.draw_rect(Rect2(ofs.x + 60, ofs.y + 40, w - 120, floor_y - (ofs.y + 40)), Color(0.05, 0.06, 0.09, alpha_mul))
		cutscene_canvas.draw_rect(Rect2(ofs.x + 60, floor_y, w - 120, h - (floor_y - ofs.y) - 40), Color(0.03, 0.035, 0.05, alpha_mul))
		cutscene_canvas.draw_line(Vector2(ofs.x + 60, floor_y), Vector2(ofs.x + w - 60, floor_y), Color(0.14, 0.16, 0.22, alpha_mul), 2.0)

		# Peeling wallpaper vertical cracks
		for w_i in range(6):
			var wx = cx - 260 + w_i * 105
			cutscene_canvas.draw_line(Vector2(wx, ofs.y + 50), Vector2(wx + sin(w_i) * 8.0, floor_y), Color(0.08, 0.09, 0.13, 0.55 * alpha_mul), 1.5)

		# Rain-streaked window on the left with lightning flashes
		var win_rect = Rect2(cx - 280, cy - 115, 155, 145)
		var flash = 0.28 if fmod(t, 4.1) < 0.14 else 0.04
		cutscene_canvas.draw_rect(win_rect, Color(0.05 + flash, 0.10 + flash, 0.19 + flash, 0.92 * alpha_mul))
		for r_i in range(18):
			var rx = win_rect.position.x + 8.0 + fmod(float(r_i * 19) + t * 25.0, win_rect.size.x - 16.0)
			var ry = win_rect.position.y + fmod(float(r_i * 29) + t * 220.0, win_rect.size.y - 18.0)
			cutscene_canvas.draw_line(Vector2(rx, ry), Vector2(rx - 3.0, ry + 15.0), Color(0.60, 0.78, 0.95, 0.45 * alpha_mul), 1.2)
		cutscene_canvas.draw_rect(win_rect, Color(0.16, 0.24, 0.34, alpha_mul), false, 4.0)
		cutscene_canvas.draw_line(Vector2(win_rect.position.x + 77.5, win_rect.position.y), Vector2(win_rect.position.x + 77.5, win_rect.end.y), Color(0.16, 0.24, 0.34, alpha_mul), 3.0)
		cutscene_canvas.draw_line(Vector2(win_rect.position.x, win_rect.position.y + 72.5), Vector2(win_rect.end.x, win_rect.position.y + 72.5), Color(0.16, 0.24, 0.34, alpha_mul), 3.0)

		# Single bare tungsten bulb hanging from ceiling cord & swaying gently
		var sway = sin(t * 2.1) * 18.0
		var cord_top = Vector2(cx + 10.0, ofs.y + 40.0)
		var bulb_pos = Vector2(cx + 10.0 + sway, cy - 118.0 + abs(sway) * 0.08)
		var flick = 0.25 if fmod(t * 17.0, 6.3) < 0.09 else (0.88 + 0.12 * sin(t * 19.0))

		# Warm light cone cast by the single bulb over the cluttered room
		var cone_pts = PackedVector2Array([
			bulb_pos,
			Vector2(cx - 230.0 + sway * 1.6, floor_y + 35.0),
			Vector2(cx + 260.0 + sway * 1.6, floor_y + 35.0)
		])
		var cone_col = Color(0.98, 0.84, 0.42, 0.11 * flick * alpha_mul)
		cutscene_canvas.draw_polygon(cone_pts, PackedColorArray([cone_col, Color(0.98, 0.82, 0.35, 0.01), Color(0.98, 0.82, 0.35, 0.01)]))
		cutscene_canvas.draw_line(cord_top, bulb_pos, Color(0.25, 0.25, 0.28, alpha_mul), 2.5)
		cutscene_canvas.draw_rect(Rect2(bulb_pos.x - 5, bulb_pos.y - 6, 10, 8), Color(0.35, 0.35, 0.38, alpha_mul))
		cutscene_canvas.draw_circle(bulb_pos + Vector2(0, 6), 24.0, Color(1.0, 0.85, 0.38, 0.24 * flick * alpha_mul))
		cutscene_canvas.draw_circle(bulb_pos + Vector2(0, 6), 8.5, Color(1.0, 0.94, 0.68, flick * alpha_mul))

		# Cluttered, dusty furniture: stacked crooked cardboard boxes, messy desk, unmade mattress, overturned cups
		# 1. Stacked cardboard boxes on left/center
		cutscene_canvas.draw_rect(Rect2(cx - 115, floor_y - 54, 68, 54), Color(0.36, 0.26, 0.15, 0.88 * alpha_mul))
		cutscene_canvas.draw_rect(Rect2(cx - 115, floor_y - 54, 68, 54), Color(0.22, 0.15, 0.08, alpha_mul), false, 2.0)
		cutscene_canvas.draw_rect(Rect2(cx - 102, floor_y - 96, 52, 42), Color(0.42, 0.31, 0.18, 0.88 * alpha_mul))
		cutscene_canvas.draw_rect(Rect2(cx - 42, floor_y - 38, 48, 38), Color(0.32, 0.23, 0.14, 0.85 * alpha_mul))
		# 2. Desk on right with lamp/papers/phone glow
		cutscene_canvas.draw_rect(Rect2(cx + 35, floor_y - 68, 135, 10), Color(0.28, 0.18, 0.11, alpha_mul))
		cutscene_canvas.draw_rect(Rect2(cx + 45, floor_y - 58, 10, 58), Color(0.20, 0.13, 0.08, alpha_mul))
		cutscene_canvas.draw_rect(Rect2(cx + 150, floor_y - 58, 10, 58), Color(0.20, 0.13, 0.08, alpha_mul))
		cutscene_canvas.draw_rect(Rect2(cx + 55, floor_y - 74, 34, 6), Color(0.92, 0.88, 0.78, 0.85 * alpha_mul)) # Eviction letter on desk
		cutscene_canvas.draw_circle(Vector2(cx + 125, floor_y - 72), 12.0, Color(0.95, 0.22, 0.25, (0.35 + 0.25 * abs(sin(t * 8.0))) * alpha_mul)) # Buzzing phone glow
		# 3. Unmade cot/mattress & scattered cans/cups on floor
		cutscene_canvas.draw_rect(Rect2(cx + 185, floor_y - 24, 110, 24), Color(0.22, 0.25, 0.32, 0.85 * alpha_mul))
		for cup_i in range(5):
			var cup_x = cx - 175 + cup_i * 72
			cutscene_canvas.draw_rect(Rect2(cup_x, floor_y + 6 + (cup_i % 2) * 8, 12, 15), Color(0.65, 0.22, 0.20, 0.75 * alpha_mul))
		# 4. Thick floating dust motes inside the bulb's light cone
		for d_i in range(28):
			var dx = cx - 180 + fmod(float(d_i * 43) + t * (6.0 + float(d_i % 4) * 2.0), 380.0)
			var dy = cy - 95 + fmod(float(d_i * 29) - t * 4.5 + 220.0, 195.0)
			cutscene_canvas.draw_circle(Vector2(dx, dy), 1.6, Color(0.98, 0.88, 0.58, 0.38 * flick * alpha_mul))
		cutscene_canvas.draw_string(font_mono, Vector2(cx - 180, ofs.y + 68), "ROOM 4B • 01:45 AM • RENT OVERDUE", HORIZONTAL_ALIGNMENT_CENTER, 360, 13, Color(0.68, 0.72, 0.78, 0.75 * alpha_mul))

	elif slide_art == "desk_notice_phone" or slide_art == "bills" or (cutscene_art_id == "intro" and slide_index == 1):
		# Slide 2: Close-up of cluttered desk with Landlord's FINAL EVICTION NOTICE letter + vibrating phone with missed calls & texts
		cutscene_canvas.draw_rect(Rect2(cx - 310, cy - 165, 620, 320), Color(0.14, 0.09, 0.06, 0.95 * alpha_mul))
		cutscene_canvas.draw_rect(Rect2(cx - 310, cy - 165, 620, 320), Color(0.28, 0.19, 0.12, alpha_mul), false, 3.0)

		# LEFT SIDE: Torn Envelope & Landlord's Red-Stamped FINAL EVICTION NOTICE Letter
		var env_rect = Rect2(cx - 285, cy - 145, 250, 95)
		cutscene_canvas.draw_rect(env_rect, Color(0.78, 0.70, 0.52, 0.85 * alpha_mul))
		cutscene_canvas.draw_string(font_mono, Vector2(cx - 275, cy - 120), "FROM: VANCE PROPERTY MGMT", HORIZONTAL_ALIGNMENT_LEFT, 230, 11, Color(0.25, 0.18, 0.10, alpha_mul))

		var letter_rect = Rect2(cx - 270, cy - 105, 275, 235)
		cutscene_canvas.draw_rect(letter_rect, Color(0.96, 0.93, 0.84, 0.96 * alpha_mul))
		cutscene_canvas.draw_rect(letter_rect, Color(0.65, 0.58, 0.45, alpha_mul), false, 2.0)
		var pulse_red = 0.75 + 0.25 * abs(sin(t * 5.0))
		cutscene_canvas.draw_rect(Rect2(cx - 255, cy - 90, 245, 32), Color(0.85, 0.12, 0.14, 0.18 * alpha_mul))
		cutscene_canvas.draw_string(font_mono, Vector2(cx - 250, cy - 68), "FINAL EVICTION NOTICE", HORIZONTAL_ALIGNMENT_CENTER, 235, 17, Color(0.86, 0.10, 0.12, pulse_red * alpha_mul))
		cutscene_canvas.draw_string(font_mono, Vector2(cx - 250, cy - 38), "TENANT: EMPLOYEE #8 (ROOM 4B)", HORIZONTAL_ALIGNMENT_LEFT, 240, 11, Color(0.18, 0.20, 0.24, alpha_mul))
		cutscene_canvas.draw_string(font_mono, Vector2(cx - 250, cy - 16), "RENT ARREARS: $840.00 (PAST DUE)", HORIZONTAL_ALIGNMENT_LEFT, 240, 12, Color(0.78, 0.12, 0.12, alpha_mul))
		cutscene_canvas.draw_string(font_mono, Vector2(cx - 250, cy + 8), "Notice is hereby given that unless", HORIZONTAL_ALIGNMENT_LEFT, 240, 11, Color(0.22, 0.24, 0.28, alpha_mul))
		cutscene_canvas.draw_string(font_mono, Vector2(cx - 250, cy + 24), "full payment is received by 06:00 AM,", HORIZONTAL_ALIGNMENT_LEFT, 240, 11, Color(0.22, 0.24, 0.28, alpha_mul))
		cutscene_canvas.draw_string(font_mono, Vector2(cx - 250, cy + 40), "locks will be changed immediately.", HORIZONTAL_ALIGNMENT_LEFT, 240, 11, Color(0.22, 0.24, 0.28, alpha_mul))
		cutscene_canvas.draw_string(font_mono, Vector2(cx - 250, cy + 70), "SIGNED: H. VANCE (LANDLORD)", HORIZONTAL_ALIGNMENT_LEFT, 240, 12, Color(0.12, 0.14, 0.18, alpha_mul))
		# Spare coins ($4.50) sitting on corner of desk
		cutscene_canvas.draw_circle(Vector2(cx - 220, cy + 108), 11.0, Color(0.75, 0.62, 0.22, alpha_mul))
		cutscene_canvas.draw_circle(Vector2(cx - 196, cy + 112), 9.0, Color(0.72, 0.74, 0.78, alpha_mul))
		cutscene_canvas.draw_string(font_mono, Vector2(cx - 178, cy + 116), "CASH LEFT: $4.50", HORIZONTAL_ALIGNMENT_LEFT, 140, 12, Color(0.95, 0.82, 0.32, alpha_mul))

		# RIGHT SIDE: Smartphone vibrating violently on the desk with Missed Calls & Landlord Texts
		var buzz = sin(t * 48.0) * 3.5 if fmod(t, 1.2) < 0.65 else 0.0
		var ph_rect = Rect2(cx + 55 + buzz, cy - 135, 215, 270)
		# Vibration wave arcs around phone
		if abs(buzz) > 0.1:
			cutscene_canvas.draw_arc(Vector2(cx + 162, cy), 155.0, -0.5, 0.5, 16, Color(0.95, 0.25, 0.25, 0.45 * alpha_mul), 2.0)
			cutscene_canvas.draw_arc(Vector2(cx + 162, cy), 155.0, PI - 0.5, PI + 0.5, 16, Color(0.95, 0.25, 0.25, 0.45 * alpha_mul), 2.0)
		cutscene_canvas.draw_rect(ph_rect, Color(0.05, 0.08, 0.14, 0.98 * alpha_mul))
		cutscene_canvas.draw_rect(ph_rect, Color(0.32, 0.38, 0.48, alpha_mul), false, 3.5)
		# Red missed-call alert banner
		cutscene_canvas.draw_rect(Rect2(ph_rect.position.x + 10, ph_rect.position.y + 14, 195, 44), Color(0.82, 0.12, 0.15, 0.32 * alpha_mul))
		cutscene_canvas.draw_string(font_mono, Vector2(ph_rect.position.x + 16, ph_rect.position.y + 32), "☎ LANDLORD (MR. VANCE)", HORIZONTAL_ALIGNMENT_LEFT, 185, 12, Color(1.0, 0.35, 0.35, alpha_mul))
		cutscene_canvas.draw_string(font_mono, Vector2(ph_rect.position.x + 16, ph_rect.position.y + 50), "14 MISSED CALLS • 3 NEW TEXTS", HORIZONTAL_ALIGNMENT_LEFT, 185, 11, Color(0.98, 0.78, 0.32, alpha_mul))

		# SMS Threat Bubbles on phone screen
		var sms_list = [
			{"time": "11:40 PM", "msg": "\"Where is my $840 rent??\""},
			{"time": "01:12 AM", "msg": "\"Stop ignoring my calls.\""},
			{"time": "01:44 AM", "msg": "\"Pay by dawn or you're out!\""}
		]
		for s_i in range(sms_list.size()):
			var by = ph_rect.position.y + 68 + s_i * 62
			cutscene_canvas.draw_rect(Rect2(ph_rect.position.x + 12, by, 191, 52), Color(0.11, 0.16, 0.25, 0.92 * alpha_mul))
			cutscene_canvas.draw_string(font_mono, Vector2(ph_rect.position.x + 18, by + 18), "SMS • " + sms_list[s_i]["time"], HORIZONTAL_ALIGNMENT_LEFT, 175, 10, Color(0.55, 0.68, 0.85, alpha_mul))
			cutscene_canvas.draw_string(font_mono, Vector2(ph_rect.position.x + 18, by + 38), sms_list[s_i]["msg"], HORIZONTAL_ALIGNMENT_LEFT, 180, 11, Color(0.95, 0.92, 0.88, alpha_mul))

	elif slide_art == "walk_rain_street":
		# Slide 3: Protagonist stepping out into the dark rain-drenched city street searching for night work
		var road_y = cy + 65.0
		# Night sky & dark apartment blocks lining the street
		cutscene_canvas.draw_rect(Rect2(ofs.x, ofs.y, w, road_y - ofs.y), Color(0.02, 0.03, 0.06, alpha_mul))
		var b_rects = [
			Rect2(ofs.x + 40, ofs.y + 30, 170, road_y - (ofs.y + 30)),
			Rect2(ofs.x + 220, ofs.y + 65, 145, road_y - (ofs.y + 65)),
			Rect2(ofs.x + w - 380, ofs.y + 50, 160, road_y - (ofs.y + 50)),
			Rect2(ofs.x + w - 210, ofs.y + 20, 180, road_y - (ofs.y + 20))
		]
		for br in b_rects:
			cutscene_canvas.draw_rect(br, Color(0.04, 0.06, 0.10, alpha_mul))
			cutscene_canvas.draw_rect(br, Color(0.09, 0.12, 0.18, alpha_mul), false, 1.5)

		# Wet asphalt road & shimmering puddle reflections
		cutscene_canvas.draw_rect(Rect2(ofs.x, road_y, w, h - (road_y - ofs.y)), Color(0.03, 0.04, 0.07, alpha_mul))
		cutscene_canvas.draw_line(Vector2(ofs.x, road_y), Vector2(ofs.x + w, road_y), Color(0.18, 0.22, 0.30, alpha_mul), 2.0)

		# Streetlamp on the right casting a misty cone toward a glowing yellow flyer on the brick corner
		var lamp_x = cx + 125.0
		cutscene_canvas.draw_line(Vector2(lamp_x, road_y + 10), Vector2(lamp_x, cy - 135), Color(0.22, 0.26, 0.32, alpha_mul), 5.0)
		cutscene_canvas.draw_line(Vector2(lamp_x, cy - 135), Vector2(lamp_x - 36, cy - 135), Color(0.22, 0.26, 0.32, alpha_mul), 4.0)
		var l_flick = 0.85 + 0.15 * sin(t * 23.0)
		var lamp_cone = PackedVector2Array([
			Vector2(lamp_x - 36, cy - 132),
			Vector2(lamp_x - 175, road_y + 35),
			Vector2(lamp_x + 95, road_y + 35)
		])
		var lc_col = Color(0.98, 0.86, 0.45, 0.14 * l_flick * alpha_mul)
		cutscene_canvas.draw_polygon(lamp_cone, PackedColorArray([lc_col, Color(0.98, 0.86, 0.45, 0.01), Color(0.98, 0.86, 0.45, 0.01)]))
		cutscene_canvas.draw_circle(Vector2(lamp_x - 36, cy - 132), 14.0, Color(1.0, 0.90, 0.52, 0.55 * l_flick * alpha_mul))
		# Small glowing yellow flyer visible ahead on the wall near the lamp
		cutscene_canvas.draw_rect(Rect2(lamp_x + 28, cy - 32, 22, 28), Color(0.98, 0.90, 0.35, 0.92 * alpha_mul))

		# Protagonist silhouette walking along the rain-slicked sidewalk toward the streetlamp
		var walk_x = cx - 95.0 + min(85.0, t * 18.0)
		var bob = abs(sin(t * 7.5)) * 4.0
		var leg_sw = sin(t * 7.5) * 9.0
		# Coat, head, and walking legs
		cutscene_canvas.draw_circle(Vector2(walk_x, road_y - 68 - bob), 10.0, Color(0.08, 0.10, 0.15, alpha_mul))
		cutscene_canvas.draw_rect(Rect2(walk_x - 12, road_y - 58 - bob, 24, 34), Color(0.07, 0.09, 0.14, alpha_mul))
		cutscene_canvas.draw_line(Vector2(walk_x - 4, road_y - 24 - bob), Vector2(walk_x - 4 - leg_sw, road_y + 6), Color(0.06, 0.08, 0.12, alpha_mul), 5.0)
		cutscene_canvas.draw_line(Vector2(walk_x + 4, road_y - 24 - bob), Vector2(walk_x + 4 + leg_sw, road_y + 6), Color(0.06, 0.08, 0.12, alpha_mul), 5.0)
		# Puddle ripples on the wet street
		for p_i in range(6):
			var px = cx - 220 + p_i * 88
			var pr = 8.0 + fmod(t * 22.0 + float(p_i * 7), 24.0)
			cutscene_canvas.draw_arc(Vector2(px, road_y + 28 + (p_i % 2) * 16), pr, 0, TAU, 20, Color(0.55, 0.72, 0.92, 0.22 * alpha_mul), 1.2)

	elif slide_art == "flyer_wall" or slide_art == "flyer" or (cutscene_art_id == "intro" and slide_index == 2):
		# Slide 4: Wet brick wall with the yellow "NIGHT JANITOR WANTED" flyer and tear-off phone number tabs (555-0199)
		for r in range(0, int(h), 40):
			var c_start = 0 if ((r / 40) % 2 == 0) else 20
			for c in range(c_start, int(w), 80):
				cutscene_canvas.draw_rect(Rect2(ofs.x + c, ofs.y + r, 75, 35), Color(0.10, 0.04, 0.03, alpha_mul))
		var flap = sin(t * 3.2) * 2.5
		var flyer_rect = Rect2(cx - 125 + flap, cy - 115, 250, 185)
		cutscene_canvas.draw_rect(flyer_rect, Color(0.99, 0.95, 0.78, 0.95 * alpha_mul))
		cutscene_canvas.draw_rect(flyer_rect, Color(0.55, 0.42, 0.18, alpha_mul), false, 2.0)
		cutscene_canvas.draw_string(font_mono, Vector2(cx - 115 + flap, cy - 82), "URGENT: NIGHT JANITOR WANTED", HORIZONTAL_ALIGNMENT_CENTER, 230, 14, Color(0.57, 0.20, 0.05, alpha_mul))
		cutscene_canvas.draw_string(font_mono, Vector2(cx - 115 + flap, cy - 46), "$100 / NIGHT (CASH WIRE)", HORIZONTAL_ALIGNMENT_CENTER, 230, 19, Color(0.02, 0.37, 0.27, alpha_mul))
		cutscene_canvas.draw_string(font_mono, Vector2(cx - 115 + flap, cy - 18), "AETHELGARD BIOTECH CORP.", HORIZONTAL_ALIGNMENT_CENTER, 230, 13, Color(0.18, 0.22, 0.28, alpha_mul))
		cutscene_canvas.draw_string(font_mono, Vector2(cx - 115 + flap, cy + 4), "Deep Storage • Sub-Level 4", HORIZONTAL_ALIGNMENT_CENTER, 230, 12, Color(0.22, 0.25, 0.32, alpha_mul))
		cutscene_canvas.draw_string(font_mono, Vector2(cx - 115 + flap, cy + 28), "• No Experience Needed • Start 02:00 AM", HORIZONTAL_ALIGNMENT_CENTER, 230, 11, Color(0.28, 0.30, 0.35, alpha_mul))
		cutscene_canvas.draw_string(font_mono, Vector2(cx - 115 + flap, cy + 52), "☎ CALL HR INTAKE: 555-0199", HORIZONTAL_ALIGNMENT_CENTER, 230, 14, Color(0.78, 0.10, 0.12, alpha_mul))

		# Perforated tear-off phone number tabs along the bottom of the flyer
		for tab_i in range(5):
			if tab_i == 2:
				continue # Already torn off
			var tx = cx - 121 + flap + tab_i * 50
			var ty = cy + 70
			var pull_y = min(18.0, t * 6.0) if tab_i == 3 else 0.0
			cutscene_canvas.draw_rect(Rect2(tx, ty + pull_y, 44, 42), Color(0.96, 0.91, 0.72, 0.94 * alpha_mul))
			cutscene_canvas.draw_rect(Rect2(tx, ty + pull_y, 44, 42), Color(0.55, 0.45, 0.25, alpha_mul), false, 1.0)
			cutscene_canvas.draw_string(font_mono, Vector2(tx + 2, ty + 24 + pull_y), "555-0199", HORIZONTAL_ALIGNMENT_CENTER, 40, 9, Color(0.15, 0.18, 0.22, alpha_mul))

	elif slide_art == "calling_phone":
		# Slide 5: Protagonist holding the torn "555-0199" tab in the rain and dialing Aethelgard HR on their phone
		cutscene_canvas.draw_rect(Rect2(ofs, Vector2(w, h)), Color(0.02, 0.03, 0.06, alpha_mul))

		# Left: Torn paper tab held in hand reading "AETHELGARD HR: 555-0199"
		var tab_rect = Rect2(cx - 260, cy - 35 + sin(t * 3.0) * 3.0, 175, 95)
		cutscene_canvas.draw_rect(tab_rect, Color(0.97, 0.92, 0.74, 0.94 * alpha_mul))
		cutscene_canvas.draw_rect(tab_rect, Color(0.55, 0.42, 0.20, alpha_mul), false, 2.0)
		cutscene_canvas.draw_string(font_mono, Vector2(tab_rect.position.x + 10, tab_rect.position.y + 32), "NIGHT JANITOR ($100)", HORIZONTAL_ALIGNMENT_CENTER, 155, 12, Color(0.20, 0.22, 0.26, alpha_mul))
		cutscene_canvas.draw_string(font_mono, Vector2(tab_rect.position.x + 10, tab_rect.position.y + 62), "CALL: 555-0199", HORIZONTAL_ALIGNMENT_CENTER, 155, 16, Color(0.78, 0.12, 0.12, alpha_mul))

		# Right: Smartphone active call screen with live audio waveform from Supervisor Harlow
		var ph_rect = Rect2(cx - 20, cy - 140, 235, 280)
		cutscene_canvas.draw_rect(ph_rect, Color(0.04, 0.08, 0.14, 0.98 * alpha_mul))
		cutscene_canvas.draw_rect(ph_rect, Color(0.22, 0.65, 0.52, alpha_mul), false, 3.0)
		cutscene_canvas.draw_string(font_mono, Vector2(ph_rect.position.x + 15, ph_rect.position.y + 36), "CALL CONNECTED • 00:0%d" % min(9, int(t) + 1), HORIZONTAL_ALIGNMENT_CENTER, 205, 12, Color(0.28, 0.92, 0.55, alpha_mul))
		cutscene_canvas.draw_string(font_mono, Vector2(ph_rect.position.x + 15, ph_rect.position.y + 66), "555-0199", HORIZONTAL_ALIGNMENT_CENTER, 205, 24, Color(0.95, 0.98, 1.0, alpha_mul))
		cutscene_canvas.draw_string(font_mono, Vector2(ph_rect.position.x + 15, ph_rect.position.y + 92), "AETHELGARD HR • SUB-LEVEL 4", HORIZONTAL_ALIGNMENT_CENTER, 205, 11, Color(0.62, 0.72, 0.84, alpha_mul))

		# Animated voice oscilloscope waveform
		var wave_y = ph_rect.position.y + 155.0
		for w_i in range(24):
			var wx = ph_rect.position.x + 24.0 + w_i * 8.0
			var amp = (8.0 + 26.0 * abs(sin(t * 14.0 + w_i * 0.65)))
			cutscene_canvas.draw_line(Vector2(wx, wave_y - amp), Vector2(wx, wave_y + amp), Color(0.94, 0.25, 0.28, 0.9 * alpha_mul), 3.0)
		cutscene_canvas.draw_string(font_mono, Vector2(ph_rect.position.x + 15, ph_rect.position.y + 225), "\"Come to Elevator #4. Now.\"", HORIZONTAL_ALIGNMENT_CENTER, 205, 12, Color(0.95, 0.42, 0.42, alpha_mul))

	elif slide_art == "elevator" or (cutscene_art_id == "intro" and slide_index == 3):
		var d_h = h - 100
		var shake_y = sin(t * 28.0) * 1.8
		cutscene_canvas.draw_rect(Rect2(cx - 130, ofs.y + 50 + shake_y, 120, d_h), Color(0.12, 0.16, 0.23, alpha_mul))
		cutscene_canvas.draw_rect(Rect2(cx + 10, ofs.y + 50 + shake_y, 120, d_h), Color(0.12, 0.16, 0.23, alpha_mul))
		cutscene_canvas.draw_rect(Rect2(cx - 10, ofs.y + 50 + shake_y, 20, d_h), Color(0.99, 0.98, 0.76, (0.22 + 0.12 * sin(t * 8.0)) * alpha_mul))
		cutscene_canvas.draw_string(font_mono, Vector2(cx - 80, cy + 15 + shake_y), "SUB-4", HORIZONTAL_ALIGNMENT_CENTER, 160, 40, Color(0.94, 0.27, 0.27, alpha_mul))
		cutscene_canvas.draw_string(font_mono, Vector2(cx - 110, ofs.y + h - 60), "AETHELGARD BIOTECH", HORIZONTAL_ALIGNMENT_CENTER, 220, 14, Color(0.39, 0.45, 0.55, 0.6 * alpha_mul))

	elif slide_art == "alarm" or (cutscene_art_id == "chaseBegin" and slide_index == 0):
		cutscene_canvas.draw_rect(Rect2(ofs, Vector2(w, h)), Color(0.11, 0.01, 0.01, alpha_mul))
		var pulse = 0.25 + 0.20 * abs(sin(t * 8.0))
		for i in range(6):
			var lx = ofs.x + float(i) * (w / 5.0)
			cutscene_canvas.draw_circle(Vector2(lx, ofs.y), 115.0, Color(0.94, 0.27, 0.27, pulse * alpha_mul))
		cutscene_canvas.draw_string(font_mono, Vector2(cx - 200, cy), "BREACH DETECTED", HORIZONTAL_ALIGNMENT_CENTER, 400, 36, Color(0.94, 0.27, 0.27, alpha_mul))
		cutscene_canvas.draw_string(font_mono, Vector2(cx - 200, cy + 45), "ENTITY RELEASED — SUB-LEVEL 4", HORIZONTAL_ALIGNMENT_CENTER, 400, 18, Color(0.94, 0.27, 0.27, 0.65 * alpha_mul))

	elif slide_art == "monster_eyes" or (cutscene_art_id == "chaseBegin" and slide_index == 1):
		cutscene_canvas.draw_rect(Rect2(ofs, Vector2(w, h)), Color(0.04, 0.0, 0.0, alpha_mul))
		var breath = sin(t * 3.5) * 6.0
		cutscene_canvas.draw_circle(Vector2(cx, cy + 30 + breath), 75.0, Color(0.11, 0.02, 0.02, 0.95 * alpha_mul))
		cutscene_canvas.draw_line(Vector2(cx - 60, cy + breath), Vector2(cx - 165, cy + 85 + sin(t * 5.0) * 10.0), Color(0.11, 0.02, 0.02, 0.9 * alpha_mul), 14.0)
		cutscene_canvas.draw_line(Vector2(cx + 60, cy + breath), Vector2(cx + 165, cy + 85 + cos(t * 5.0) * 10.0), Color(0.11, 0.02, 0.02, 0.9 * alpha_mul), 14.0)
		cutscene_canvas.draw_circle(Vector2(cx, cy - 50 + breath), 52.0, Color(0.94, 0.27, 0.27, 0.22 * alpha_mul))
		cutscene_canvas.draw_circle(Vector2(cx - 22, cy - 50 + breath), 10.0, Color(0.94, 0.27, 0.27, alpha_mul))
		cutscene_canvas.draw_circle(Vector2(cx + 22, cy - 50 + breath), 10.0, Color(0.94, 0.27, 0.27, alpha_mul))

	elif slide_art == "run" or (cutscene_art_id == "chaseBegin" and slide_index == 2):
		cutscene_canvas.draw_line(Vector2(cx, cy), Vector2(ofs.x, ofs.y + h), Color(0.12, 0.16, 0.23, alpha_mul), 3.0)
		cutscene_canvas.draw_line(Vector2(cx, cy), Vector2(ofs.x + w, ofs.y + h), Color(0.12, 0.16, 0.23, alpha_mul), 3.0)
		cutscene_canvas.draw_line(Vector2(cx, cy), Vector2(cx, ofs.y), Color(0.12, 0.16, 0.23, alpha_mul), 3.0)
		cutscene_canvas.draw_circle(Vector2(cx, cy), 220.0, Color(0.99, 0.97, 0.76, 0.10 * alpha_mul))
		var rx = sin(t * 35.0) * 4.0
		cutscene_canvas.draw_string(font_horror, Vector2(cx - 150 + rx, cy + 28), "RUN.", HORIZONTAL_ALIGNMENT_CENTER, 300, 84, Color(0.94, 0.27, 0.27, 0.95 * alpha_mul))

	elif slide_art == "blocked_door" or (cutscene_art_id == "entityBlocksDoor" and slide_index == 0):
		var d_box = Rect2(cx - 100, cy - 170, 200, 340)
		cutscene_canvas.draw_rect(d_box, Color(0.06, 0.72, 0.51, 0.06 * alpha_mul))
		cutscene_canvas.draw_rect(d_box, Color(0.06, 0.72, 0.51, alpha_mul), false, 6.0)
		cutscene_canvas.draw_line(Vector2(cx - 80, cy - 150), Vector2(cx + 80, cy + 150), Color(0.94, 0.27, 0.27, 0.85 * alpha_mul), 10.0)
		cutscene_canvas.draw_line(Vector2(cx + 80, cy - 150), Vector2(cx - 80, cy + 150), Color(0.94, 0.27, 0.27, 0.85 * alpha_mul), 10.0)
		cutscene_canvas.draw_string(font_mono, Vector2(cx - 150, cy - 190), "ACCESS DENIED", HORIZONTAL_ALIGNMENT_CENTER, 300, 24, Color(0.94, 0.27, 0.27, alpha_mul))
		cutscene_canvas.draw_string(font_mono, Vector2(cx - 150, cy + 195), "Required: 3 Security Keycards", HORIZONTAL_ALIGNMENT_CENTER, 300, 14, Color(0.58, 0.64, 0.72, alpha_mul))

	elif slide_art == "monster_close" or (cutscene_art_id == "entityBlocksDoor" and slide_index == 1):
		cutscene_canvas.draw_rect(Rect2(ofs, Vector2(w, h)), Color(0.03, 0.0, 0.01, alpha_mul))
		var b = sin(t * 4.2) * 5.0
		cutscene_canvas.draw_circle(Vector2(cx, cy - 60 + b), 65.0, Color(0.07, 0.01, 0.01, alpha_mul))
		cutscene_canvas.draw_rect(Rect2(cx - 80, cy - 15 + b, 160, 210), Color(0.07, 0.01, 0.01, alpha_mul))
		cutscene_canvas.draw_line(Vector2(cx - 70, cy + 25 + b), Vector2(cx - 220, cy + 120), Color(0.07, 0.01, 0.01, alpha_mul), 16.0)
		cutscene_canvas.draw_line(Vector2(cx + 70, cy + 25 + b), Vector2(cx + 220, cy + 120), Color(0.07, 0.01, 0.01, alpha_mul), 16.0)
		cutscene_canvas.draw_circle(Vector2(cx - 24, cy - 70 + b), 18.0, Color(0.94, 0.27, 0.27, 0.35 * alpha_mul))
		cutscene_canvas.draw_circle(Vector2(cx + 24, cy - 70 + b), 18.0, Color(0.94, 0.27, 0.27, 0.35 * alpha_mul))
		cutscene_canvas.draw_circle(Vector2(cx - 24, cy - 70 + b), 7.5, Color(0.94, 0.27, 0.27, alpha_mul))
		cutscene_canvas.draw_circle(Vector2(cx + 24, cy - 70 + b), 7.5, Color(0.94, 0.27, 0.27, alpha_mul))

	elif slide_art == "sunrise" or (cutscene_art_id == "nextDay" and slide_index == 0):
		cutscene_canvas.draw_rect(Rect2(ofs.x, ofs.y + h * 0.55, w, h * 0.45), Color(0.48, 0.17, 0.07, 0.45 * alpha_mul))
		cutscene_canvas.draw_circle(Vector2(cx, ofs.y + h), 160.0, Color(0.98, 0.57, 0.24, 0.35 * alpha_mul))
		var bh = [180, 130, 210, 90, 160, 200, 110, 170, 140, 200, 120, 180]
		for i in range(bh.size()):
			var b_w = w / 12.0
			cutscene_canvas.draw_rect(Rect2(ofs.x + float(i) * b_w, ofs.y + h - bh[i], b_w - 4, bh[i]), Color(0.01, 0.02, 0.09, alpha_mul))
		var slip_rect = Rect2(cx - 130, cy - 60, 260, 100)
		cutscene_canvas.draw_rect(slip_rect, Color(0.99, 0.95, 0.78, 0.12 * alpha_mul))
		cutscene_canvas.draw_string(font_mono, Vector2(cx - 120, cy - 20), "WIRE TRANSFER: $100.00", HORIZONTAL_ALIGNMENT_CENTER, 240, 18, Color(0.29, 0.87, 0.5, 0.95 * alpha_mul))
		cutscene_canvas.draw_string(font_mono, Vector2(cx - 120, cy + 12), "Your rent is paid. They call again.", HORIZONTAL_ALIGNMENT_CENTER, 240, 12, Color(0.6, 0.7, 0.8, 0.85 * alpha_mul))

	elif slide_art == "phone" or (cutscene_art_id == "nextDay" and slide_index == 1):
		var buzz = sin(t * 42.0) * 3.0 if fmod(t, 1.4) < 0.5 else 0.0
		var ph_rect = Rect2(cx - 80 + buzz, cy - 130, 160, 260)
		cutscene_canvas.draw_rect(ph_rect, Color(0.06, 0.09, 0.16, 0.95 * alpha_mul))
		cutscene_canvas.draw_rect(ph_rect, Color(0.2, 0.25, 0.33, alpha_mul), false, 3.0)
		cutscene_canvas.draw_rect(ph_rect, Color(0.94, 0.27, 0.27, (0.12 + 0.08 * sin(t * 6.0)) * alpha_mul))
		cutscene_canvas.draw_string(font_mono, Vector2(cx - 75 + buzz, cy - 90), "AETHELGARD HR", HORIZONTAL_ALIGNMENT_CENTER, 150, 12, Color(0.94, 0.27, 0.27, alpha_mul))
		cutscene_canvas.draw_string(font_mono, Vector2(cx - 75 + buzz, cy - 70), "MISSED ×4", HORIZONTAL_ALIGNMENT_CENTER, 150, 12, Color(0.94, 0.27, 0.27, alpha_mul))
		cutscene_canvas.draw_string(font_mono, Vector2(cx - 75 + buzz, cy - 38), "\"Shift begins at midnight.\"", HORIZONTAL_ALIGNMENT_CENTER, 150, 10, Color(0.45, 0.52, 0.62, alpha_mul))
		cutscene_canvas.draw_string(font_mono, Vector2(cx - 75 + buzz, cy - 18), "\"Your compliance is noted.\"", HORIZONTAL_ALIGNMENT_CENTER, 150, 10, Color(0.45, 0.52, 0.62, alpha_mul))
		cutscene_canvas.draw_string(font_mono, Vector2(cx - 75 + buzz, cy + 10), "\"You will return.\"", HORIZONTAL_ALIGNMENT_CENTER, 150, 10, Color(0.85, 0.35, 0.35, alpha_mul))

	elif slide_art == "stairs":
		# Nested stairwell rectangles matching HTML artStairs
		for i in range(9):
			var pulse_ofs = fmod(t * 1.4, 1.0) * 6.0
			var rx = cx - 150 + i * 14 + pulse_ofs * 0.5
			var ry = cy - 100 + i * 12 + pulse_ofs * 0.4
			var rw = 300 - i * 28
			var rh = 200 - i * 22
			cutscene_canvas.draw_rect(Rect2(rx, ry, rw, rh), Color(0.39, 0.59, 0.78, (0.52 - i * 0.05) * alpha_mul), false, 2.0)

	elif slide_art == "eyes":
		# Multiple glowing pairs of eyes in the dark matching HTML artEyes
		var pairs = [Vector2(-40, 0), Vector2(40, 0), Vector2(-95, -32), Vector2(95, -32)]
		var blink = 0.1 if fmod(t, 3.2) > 3.05 else 1.0
		for i in range(pairs.size()):
			var p = pairs[i] + Vector2(sin(t * 2.5 + i) * 3.0, cos(t * 2.0 + i) * 2.0)
			cutscene_canvas.draw_circle(Vector2(cx, cy) + p, 22.0, Color(0.94, 0.27, 0.27, 0.22 * blink * alpha_mul))
			cutscene_canvas.draw_rect(Rect2(cx + p.x - 8, cy + p.y - 3, 16, 6 if i >= 2 else 8), Color(0.94, 0.27, 0.27, blink * alpha_mul))

	elif slide_art == "rings":
		# Concentric pulsing ritual rings matching HTML artRings
		for i in range(1, 8):
			var rad = float(i) * 22.0 + sin(t * 3.0 - i * 0.5) * 4.0
			cutscene_canvas.draw_arc(Vector2(cx, cy), rad, 0, TAU, 48, Color(0.96, 0.25, 0.37, (0.72 - i * 0.08) * alpha_mul), 2.0)
		cutscene_canvas.draw_circle(Vector2(cx, cy), 8.0 + sin(t * 6.0) * 2.0, Color(0.96, 0.25, 0.37, alpha_mul))

	elif slide_art == "street":
		# Rainy night street with single lit red corporate window matching HTML artStreet
		cutscene_canvas.draw_rect(Rect2(ofs.x, ofs.y + h * 0.62, w, h * 0.38), Color(0.03, 0.04, 0.07, alpha_mul))
		cutscene_canvas.draw_rect(Rect2(ofs.x + w * 0.08, ofs.y + h * 0.12, w * 0.22, h * 0.50), Color(0.04, 0.07, 0.11, alpha_mul))
		cutscene_canvas.draw_rect(Rect2(ofs.x + w * 0.70, ofs.y + h * 0.20, w * 0.20, h * 0.42), Color(0.04, 0.07, 0.11, alpha_mul))
		cutscene_canvas.draw_circle(Vector2(ofs.x + w * 0.19 + 5, ofs.y + h * 0.25 + 7), 22.0, Color(0.94, 0.27, 0.27, 0.35 * alpha_mul))
		cutscene_canvas.draw_rect(Rect2(ofs.x + w * 0.19, ofs.y + h * 0.25, 12, 16), Color(0.94, 0.27, 0.27, alpha_mul))
		# Lone janitor silhouette on street
		cutscene_canvas.draw_rect(Rect2(cx - 6, ofs.y + h * 0.50, 12, h * 0.12), Color(0.01, 0.02, 0.03, alpha_mul))
		cutscene_canvas.draw_circle(Vector2(cx, ofs.y + h * 0.48), 7.0, Color(0.01, 0.02, 0.03, alpha_mul))

	elif slide_art == "earth":
		# Colossal Entity hand & eyes closing around Earth matching HTML artEarth
		cutscene_canvas.draw_circle(Vector2(cx, cy), 90.0, Color(0.08, 0.22, 0.55, alpha_mul))
		cutscene_canvas.draw_circle(Vector2(cx - 30, cy - 20), 24.0, Color(0.08, 0.50, 0.24, alpha_mul))
		cutscene_canvas.draw_circle(Vector2(cx + 20, cy + 10), 30.0, Color(0.08, 0.50, 0.24, alpha_mul))
		cutscene_canvas.draw_circle(Vector2(cx - 10, cy + 40), 16.0, Color(0.08, 0.50, 0.24, alpha_mul))
		for i in range(5):
			var a = PI * (1.05 + i * 0.22)
			var grip = min(1.0, t * 0.25)
			var p1 = Vector2(cx + cos(a) * 155.0, cy + sin(a) * 155.0 + 40.0)
			var p2 = Vector2(cx + cos(a) * lerpf(95.0, 68.0, grip), cy + sin(a) * lerpf(95.0, 68.0, grip))
			cutscene_canvas.draw_line(p1, p2, Color(0.02, 0.02, 0.02, alpha_mul), 18.0)
		cutscene_canvas.draw_rect(Rect2(cx - 60, ofs.y + h * 0.12, 16, 6), Color(0.94, 0.27, 0.27, alpha_mul))
		cutscene_canvas.draw_rect(Rect2(cx + 44, ofs.y + h * 0.12, 16, 6), Color(0.94, 0.27, 0.27, alpha_mul))

	else:
		# Default: Overdue Employee Ledger matching HTML artLedger
		for i in range(12):
			var emp_str = "EMP #%d   $%s   OVERDUE" % [8 + i * 31, "%.2f" % (4.5 * (i + 1))]
			var row_a = (0.65 if (int(t * 6.0) % 12 != i) else 0.95) * alpha_mul
			cutscene_canvas.draw_string(font_mono, Vector2(cx - 135, cy - 110 + i * 20), emp_str, HORIZONTAL_ALIGNMENT_LEFT, 280, 14, Color(0.94, 0.27, 0.27, row_a))

# ==============================================================================
# --- MULTIPLAYER CO-OP UI IMPLEMENTATION (UP TO 5 PLAYERS) ---
# ==============================================================================
func _build_multiplayer_ui() -> void:
	# 1. Multiplayer Button on Main Menu
	var button_box = $MainMenu/CenterBox/ButtonBox
	if button_box:
		btn_multiplayer = Button.new()
		btn_multiplayer.name = "BtnMultiplayer"
		btn_multiplayer.text = "CO-OP MULTIPLAYER (1-5 P)"
		btn_multiplayer.add_theme_font_override("font", font_mono)
		_style_menu_button(btn_multiplayer, Color(0.18, 0.88, 0.72), Color(0.04, 0.18, 0.15))
		button_box.add_child(btn_multiplayer)
		button_box.move_child(btn_multiplayer, 1)

		btn_multiplayer.pressed.connect(func():
			main_menu.visible = false
			show_multiplayer_menu()
		)

	# 2. Main Multiplayer Menu Panel (Host / Join Room)
	mp_panel = PanelContainer.new()
	mp_panel.name = "MultiplayerMenuPanel"
	mp_panel.visible = false
	mp_panel.set_anchors_preset(Control.PRESET_CENTER)
	mp_panel.custom_minimum_size = Vector2(580, 480)
	mp_panel.offset_left = -290.0
	mp_panel.offset_right = 290.0
	mp_panel.offset_top = -240.0
	mp_panel.offset_bottom = 240.0

	var panel_sb = StyleBoxFlat.new()
	panel_sb.bg_color = Color(0.02, 0.04, 0.08, 0.96)
	panel_sb.border_width_left = 2
	panel_sb.border_width_top = 2
	panel_sb.border_width_right = 2
	panel_sb.border_width_bottom = 2
	panel_sb.border_color = Color(0.18, 0.85, 0.75, 0.9)
	panel_sb.content_margin_left = 20
	panel_sb.content_margin_right = 20
	panel_sb.content_margin_top = 18
	panel_sb.content_margin_bottom = 18
	panel_sb.corner_radius_top_left = 6
	panel_sb.corner_radius_top_right = 6
	panel_sb.corner_radius_bottom_left = 6
	panel_sb.corner_radius_bottom_right = 6
	mp_panel.add_theme_stylebox_override("panel", panel_sb)
	add_child(mp_panel)

	var mp_vbox = VBoxContainer.new()
	mp_vbox.add_theme_constant_override("separation", 12)
	mp_panel.add_child(mp_vbox)

	var mp_title = Label.new()
	mp_title.text = "AETHELGARD BIOTECH — JANITOR CO-OP"
	mp_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mp_title.add_theme_font_override("font", font_mono)
	mp_title.add_theme_font_size_override("font_size", 20)
	mp_title.add_theme_color_override("font_color", Color(0.2, 0.9, 0.8))
	mp_vbox.add_child(mp_title)

	var mp_sub = Label.new()
	mp_sub.text = "Coordinate shifts, adjust supply quotas, and survive together across 28 sector maps."
	mp_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mp_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mp_sub.add_theme_font_override("font", font_mono)
	mp_sub.add_theme_font_size_override("font_size", 12)
	mp_sub.add_theme_color_override("font_color", Color(0.55, 0.65, 0.72))
	mp_vbox.add_child(mp_sub)

	# Callsign Input Row
	var callsign_row = HBoxContainer.new()
	var cs_lbl = Label.new()
	cs_lbl.text = "CALLSIGN:"
	cs_lbl.custom_minimum_size = Vector2(130, 0)
	cs_lbl.add_theme_font_override("font", font_mono)
	cs_lbl.add_theme_font_size_override("font_size", 13)
	cs_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	callsign_row.add_child(cs_lbl)

	mp_callsign_input = LineEdit.new()
	mp_callsign_input.text = "Janitor #%d" % (randi() % 900 + 100)
	mp_callsign_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mp_callsign_input.add_theme_font_override("font", font_mono)
	callsign_row.add_child(mp_callsign_input)
	mp_vbox.add_child(callsign_row)

	# Tab Selection: Host Room vs Join Room
	var tab_row = HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 10)
	mp_btn_host_tab = Button.new()
	mp_btn_host_tab.text = "★ HOST ROOM (CREATE)"
	mp_btn_host_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mp_btn_host_tab.add_theme_font_override("font", font_mono)

	mp_btn_join_tab = Button.new()
	mp_btn_join_tab.text = "CONNECT / JOIN"
	mp_btn_join_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mp_btn_join_tab.add_theme_font_override("font", font_mono)

	tab_row.add_child(mp_btn_host_tab)
	tab_row.add_child(mp_btn_join_tab)
	mp_vbox.add_child(tab_row)

	# --- HOST ROOM CONTAINER ---
	mp_host_box = VBoxContainer.new()
	mp_host_box.add_theme_constant_override("separation", 8)
	mp_vbox.add_child(mp_host_box)

	var room_row = HBoxContainer.new()
	var rr_lbl = Label.new()
	rr_lbl.text = "ROOM NAME:"
	rr_lbl.custom_minimum_size = Vector2(130, 0)
	rr_lbl.add_theme_font_override("font", font_mono)
	rr_lbl.add_theme_font_size_override("font_size", 12)
	room_row.add_child(rr_lbl)
	mp_room_input = LineEdit.new()
	mp_room_input.text = "Shift-Sector-4"
	mp_room_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mp_room_input.add_theme_font_override("font", font_mono)
	room_row.add_child(mp_room_input)
	mp_host_box.add_child(room_row)

	# Night Selection (Night 1 to 5)
	var day_row = HBoxContainer.new()
	var dr_lbl = Label.new()
	dr_lbl.text = "SHIFT NIGHT:"
	dr_lbl.custom_minimum_size = Vector2(130, 0)
	dr_lbl.add_theme_font_override("font", font_mono)
	dr_lbl.add_theme_font_size_override("font_size", 12)
	day_row.add_child(dr_lbl)
	mp_day_select = OptionButton.new()
	mp_day_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mp_day_select.add_theme_font_override("font", font_mono)
	mp_day_select.add_item("Night 1 (3 Map Pool)", 1)
	mp_day_select.add_item("Night 2 (5 Map Pool)", 2)
	mp_day_select.add_item("Night 3 (6 Map Pool)", 3)
	mp_day_select.add_item("Night 4 (7 Map Pool)", 4)
	mp_day_select.add_item("Night 5 (7 Map Pool)", 5)
	day_row.add_child(mp_day_select)
	mp_host_box.add_child(day_row)

	# Sector Map Variant Selection (28 Maps)
	var map_row = HBoxContainer.new()
	var mr_lbl = Label.new()
	mr_lbl.text = "SECTOR MAP:"
	mr_lbl.custom_minimum_size = Vector2(130, 0)
	mr_lbl.add_theme_font_override("font", font_mono)
	mr_lbl.add_theme_font_size_override("font_size", 12)
	map_row.add_child(mr_lbl)
	mp_map_select = OptionButton.new()
	mp_map_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mp_map_select.add_theme_font_override("font", font_mono)
	map_row.add_child(mp_map_select)
	mp_host_box.add_child(map_row)

	mp_day_select.item_selected.connect(func(idx):
		_update_mp_map_options_for_day(idx + 1)
	)
	_update_mp_map_options_for_day(1)

	# Task Scaling Multiplier
	var task_row = HBoxContainer.new()
	var tr_lbl = Label.new()
	tr_lbl.text = "TASK QUOTA:"
	tr_lbl.custom_minimum_size = Vector2(130, 0)
	tr_lbl.add_theme_font_override("font", font_mono)
	tr_lbl.add_theme_font_size_override("font_size", 12)
	task_row.add_child(tr_lbl)
	mp_task_select = OptionButton.new()
	mp_task_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mp_task_select.add_theme_font_override("font", font_mono)
	mp_task_select.add_item("Standard Quota (1.0x)", 0)
	mp_task_select.add_item("Co-op 2P Quota (1.5x)", 1)
	mp_task_select.add_item("Co-op 3-4P Quota (2.0x)", 2)
	mp_task_select.add_item("Full Squad 5P Quota (2.5x)", 3)
	mp_task_select.select(1)
	task_row.add_child(mp_task_select)
	mp_host_box.add_child(task_row)

	# Supplies Scaling Multiplier
	var sup_row = HBoxContainer.new()
	var sr_lbl = Label.new()
	sr_lbl.text = "FACILITY GEAR:"
	sr_lbl.custom_minimum_size = Vector2(130, 0)
	sr_lbl.add_theme_font_override("font", font_mono)
	sr_lbl.add_theme_font_size_override("font_size", 12)
	sup_row.add_child(sr_lbl)
	mp_supply_select = OptionButton.new()
	mp_supply_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mp_supply_select.add_theme_font_override("font", font_mono)
	mp_supply_select.add_item("Standard Supplies (1.0x)", 0)
	mp_supply_select.add_item("Expanded Crates (1.5x)", 1)
	mp_supply_select.add_item("Surplus Cache (2.0x)", 2)
	mp_supply_select.select(1)
	sup_row.add_child(mp_supply_select)
	mp_host_box.add_child(sup_row)

	var btn_create = Button.new()
	btn_create.text = "CREATE ROOM & HOST LOBBY"
	btn_create.custom_minimum_size = Vector2(0, 38)
	btn_create.add_theme_font_override("font", font_mono)
	btn_create.pressed.connect(_on_create_room_pressed)
	mp_host_box.add_child(btn_create)

	# --- JOIN ROOM CONTAINER (AUTO ROOM BROWSER & CODE) ---
	mp_join_box = VBoxContainer.new()
	mp_join_box.visible = false
	mp_join_box.add_theme_constant_override("separation", 10)
	mp_vbox.add_child(mp_join_box)

	# 1. Real-time Live Room Browser
	var browser_header = Label.new()
	browser_header.text = "📡 CÁC PHÒNG ĐANG MỞ (BẤM ĐỂ VÀO NGAY / 1-CLICK JOIN):"
	browser_header.add_theme_font_override("font", font_mono)
	browser_header.add_theme_font_size_override("font_size", 12)
	browser_header.add_theme_color_override("font_color", Color(0.2, 0.95, 0.75))
	mp_join_box.add_child(browser_header)

	mp_browser_scroll = ScrollContainer.new()
	mp_browser_scroll.custom_minimum_size = Vector2(0, 160)
	mp_browser_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mp_browser_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mp_join_box.add_child(mp_browser_scroll)

	mp_browser_vbox = VBoxContainer.new()
	mp_browser_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mp_browser_vbox.add_theme_constant_override("separation", 6)
	mp_browser_scroll.add_child(mp_browser_vbox)

	mp_browser_empty_label = Label.new()
	mp_browser_empty_label.text = "⏳ Đang tự động dò tìm phòng trong mạng...\n(Khi bạn bè tạo phòng, phòng sẽ xuất hiện ngay tại đây)"
	mp_browser_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mp_browser_empty_label.add_theme_font_override("font", font_mono)
	mp_browser_empty_label.add_theme_font_size_override("font_size", 11)
	mp_browser_empty_label.add_theme_color_override("font_color", Color(0.75, 0.8, 0.85))
	mp_browser_vbox.add_child(mp_browser_empty_label)

	# 2. Hoặc tham gia bằng Mã Phòng
	var sep = HSeparator.new()
	mp_join_box.add_child(sep)

	var code_header = Label.new()
	code_header.text = "HOẶC NHẬP MÃ PHÒNG (NẾU CÓ):"
	code_header.add_theme_font_override("font", font_mono)
	code_header.add_theme_font_size_override("font_size", 11)
	code_header.add_theme_color_override("font_color", Color(0.7, 0.85, 0.9))
	mp_join_box.add_child(code_header)

	var code_row = HBoxContainer.new()
	code_row.add_theme_constant_override("separation", 8)
	mp_code_input = LineEdit.new()
	mp_code_input.placeholder_text = "Nhập Mã Phòng (AGY-XXXXX-XXXXX)..."
	mp_code_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mp_code_input.custom_minimum_size = Vector2(0, 36)
	mp_code_input.add_theme_font_override("font", font_mono)
	code_row.add_child(mp_code_input)

	var btn_paste = Button.new()
	btn_paste.text = "📋 DÁN MÃ"
	btn_paste.custom_minimum_size = Vector2(95, 36)
	btn_paste.add_theme_font_override("font", font_mono)
	btn_paste.pressed.connect(func():
		var clip = DisplayServer.clipboard_get().strip_edges()
		if clip != "":
			mp_code_input.text = clip
			show_toast("Đã dán mã từ clipboard!", Color(0.25, 0.95, 0.55))
	)
	code_row.add_child(btn_paste)

	var btn_join_code = Button.new()
	btn_join_code.text = "🚀 VÀO BẰNG MÃ"
	btn_join_code.custom_minimum_size = Vector2(125, 36)
	btn_join_code.add_theme_font_override("font", font_mono)
	_style_menu_button(btn_join_code, Color(0.2, 0.95, 0.8), Color(0.04, 0.22, 0.18))
	btn_join_code.pressed.connect(_on_join_code_pressed)
	code_row.add_child(btn_join_code)
	mp_join_box.add_child(code_row)

	mp_scan_status = Label.new()
	mp_scan_status.text = ""
	mp_scan_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mp_scan_status.add_theme_font_override("font", font_mono)
	mp_scan_status.add_theme_font_size_override("font_size", 11)
	mp_scan_status.add_theme_color_override("font_color", Color(0.95, 0.75, 0.25))
	mp_join_box.add_child(mp_scan_status)

	# Tab Toggle Signals
	mp_btn_host_tab.pressed.connect(func():
		mp_host_box.visible = true
		mp_join_box.visible = false
		mp_btn_host_tab.modulate = Color(1.0, 1.0, 1.0)
		mp_btn_join_tab.modulate = Color(0.65, 0.65, 0.65)
	)
	mp_btn_join_tab.pressed.connect(func():
		mp_host_box.visible = false
		mp_join_box.visible = true
		mp_btn_join_tab.modulate = Color(1.0, 1.0, 1.0)
		mp_btn_host_tab.modulate = Color(0.65, 0.65, 0.65)
	)
	mp_btn_join_tab.modulate = Color(0.65, 0.65, 0.65)

	# Back Button
	var btn_mp_back = Button.new()
	btn_mp_back.text = "CANCEL / RETURN TO MENU"
	btn_mp_back.custom_minimum_size = Vector2(0, 34)
	btn_mp_back.add_theme_font_override("font", font_mono)
	btn_mp_back.pressed.connect(func():
		hide_multiplayer_menu()
		main_menu.visible = true
	)
	mp_vbox.add_child(btn_mp_back)

	# 3. Multiplayer Lobby Panel
	_build_mp_lobby_panel()

	# 4. Multiplayer Scoreboard / Evaluation Panel
	_build_mp_scoreboard_panel()

	# 5. In-Game Chat System Panel
	_build_mp_chat_panel()

	# 6. Spectator Mode HUD Banner
	_build_mp_spectator_banner()

func _update_mp_map_options_for_day(day_num: int) -> void:
	if not mp_map_select:
		return
	mp_map_select.clear()
	mp_map_select.add_item("Random Sector Variant (Recommended)", -1)
	var count = GameData.get_map_count_for_day(day_num)
	for i in range(count):
		mp_map_select.add_item("Sector Map #%d" % (i + 1), i)
	mp_map_select.select(0)

func _on_create_room_pressed() -> void:
	var r_name = mp_room_input.text.strip_edges()
	if r_name == "":
		r_name = "Shift-Room"
	var day_num = mp_day_select.selected + 1
	var map_idx = mp_map_select.get_selected_id()

	var t_mults = [1.0, 1.5, 2.0, 2.5]
	var s_mults = [1.0, 1.5, 2.0]
	var task_mult = t_mults[clampi(mp_task_select.selected, 0, t_mults.size() - 1)]
	var supply_mult = s_mults[clampi(mp_supply_select.selected, 0, s_mults.size() - 1)]

	if mp_callsign_input.text.strip_edges() != "":
		var net_mgr = get_node_or_null("/root/NetworkManager")
		if net_mgr:
			net_mgr.local_player_name = mp_callsign_input.text.strip_edges()

	mp_host_room_requested.emit(r_name, day_num, map_idx, task_mult, supply_mult)

func _on_join_code_pressed() -> void:
	var code_str = mp_code_input.text.strip_edges()
	if code_str == "":
		show_toast("Vui lòng nhập hoặc dán Mã Phòng!", Color(1.0, 0.4, 0.4))
		return
	if mp_callsign_input.text.strip_edges() != "":
		var net_mgr = get_node_or_null("/root/NetworkManager")
		if net_mgr:
			net_mgr.local_player_name = mp_callsign_input.text.strip_edges()
	mp_scan_status.text = "Đang kết nối tới mã phòng %s..." % code_str
	mp_join_code_requested.emit(code_str)

func _on_join_room_clicked(ip: String, port: int) -> void:
	if mp_callsign_input.text.strip_edges() != "":
		var net_mgr = get_node_or_null("/root/NetworkManager")
		if net_mgr:
			net_mgr.local_player_name = mp_callsign_input.text.strip_edges()
	mp_scan_status.text = "Đang kết nối vào phòng..."
	mp_join_room_requested.emit(ip, port)

func update_room_browser(rooms: Array) -> void:
	if not mp_browser_vbox:
		return
	for c in mp_browser_vbox.get_children():
		c.queue_free()

	if rooms.is_empty():
		var emp = Label.new()
		emp.text = "⏳ Đang tự động dò tìm phòng trong mạng...\n(Khi bạn bè tạo phòng, phòng sẽ xuất hiện ngay tại đây)"
		emp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		emp.add_theme_font_override("font", font_mono)
		emp.add_theme_font_size_override("font_size", 11)
		emp.add_theme_color_override("font_color", Color(0.75, 0.8, 0.85))
		mp_browser_vbox.add_child(emp)
		return

	for r in rooms:
		var r_panel = PanelContainer.new()
		var r_sb = StyleBoxFlat.new()
		r_sb.bg_color = Color(0.04, 0.08, 0.12, 0.88)
		r_sb.border_width_left = 1
		r_sb.border_width_top = 1
		r_sb.border_width_right = 1
		r_sb.border_width_bottom = 1
		r_sb.border_color = Color(0.2, 0.75, 0.6, 0.8)
		r_sb.content_margin_left = 10
		r_sb.content_margin_right = 10
		r_sb.content_margin_top = 8
		r_sb.content_margin_bottom = 8
		r_sb.corner_radius_top_left = 4
		r_sb.corner_radius_top_right = 4
		r_sb.corner_radius_bottom_left = 4
		r_sb.corner_radius_bottom_right = 4
		r_panel.add_theme_stylebox_override("panel", r_sb)

		var r_hb = HBoxContainer.new()
		r_hb.add_theme_constant_override("separation", 10)
		r_panel.add_child(r_hb)

		var info_vbox = VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vbox.add_theme_constant_override("separation", 2)
		r_hb.add_child(info_vbox)

		var r_name_lbl = Label.new()
		r_name_lbl.text = "🏢 " + str(r.get("name", "Shift-Room"))
		r_name_lbl.add_theme_font_override("font", font_mono)
		r_name_lbl.add_theme_font_size_override("font_size", 13)
		r_name_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.8))
		info_vbox.add_child(r_name_lbl)

		var r_sub_lbl = Label.new()
		r_sub_lbl.text = "Chủ phòng: %s  •  Số người: %s/5" % [str(r.get("host", "Janitor")), str(r.get("players", "1"))]
		r_sub_lbl.add_theme_font_override("font", font_mono)
		r_sub_lbl.add_theme_font_size_override("font_size", 11)
		r_sub_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.88))
		info_vbox.add_child(r_sub_lbl)

		var btn_join = Button.new()
		btn_join.text = "👉 VÀO PHÒNG"
		btn_join.custom_minimum_size = Vector2(110, 32)
		btn_join.add_theme_font_override("font", font_mono)
		_style_menu_button(btn_join, Color(0.2, 0.95, 0.55), Color(0.04, 0.22, 0.12))
		var r_code = str(r.get("code", ""))
		var target_ip = str(r.get("ip", "127.0.0.1"))
		var target_port = int(r.get("port", 8910))
		btn_join.pressed.connect(func():
			if r_code != "":
				mp_join_code_requested.emit(r_code)
			else:
				_on_join_room_clicked(target_ip, target_port)
		)
		r_hb.add_child(btn_join)

		mp_browser_vbox.add_child(r_panel)

func _on_direct_connect_pressed() -> void:
	var ip = mp_ip_input.text.strip_edges() if mp_ip_input else "127.0.0.1"
	if ip == "": ip = "127.0.0.1"
	var port = int(mp_port_input.text.strip_edges()) if mp_port_input else 8910
	if port <= 0: port = 8910
	if mp_callsign_input.text.strip_edges() != "":
		var net_mgr = get_node_or_null("/root/NetworkManager")
		if net_mgr:
			net_mgr.local_player_name = mp_callsign_input.text.strip_edges()
	mp_scan_status.text = "Connecting to %s:%d..." % [ip, port]
	mp_join_room_requested.emit(ip, port)

func _on_quick_join_pressed() -> void:
	if mp_callsign_input.text.strip_edges() != "":
		var net_mgr = get_node_or_null("/root/NetworkManager")
		if net_mgr:
			net_mgr.local_player_name = mp_callsign_input.text.strip_edges()
	mp_scan_status.text = "Broadcasting LAN beacon inquiry..."
	mp_quick_join_requested.emit()

func update_lobby_room_code(code: String) -> void:
	if mp_lobby_code_label:
		mp_lobby_code_label.text = "MÃ PHÒNG: " + code
	if mp_scan_status:
		mp_scan_status.text = ""

func update_lobby_ip(_ip_text: String) -> void:
	pass

func update_lobby_upnp_status(_status_str: String) -> void:
	pass

func _build_mp_lobby_panel() -> void:
	mp_lobby_panel = PanelContainer.new()
	mp_lobby_panel.name = "MultiplayerLobbyPanel"
	mp_lobby_panel.visible = false
	mp_lobby_panel.set_anchors_preset(Control.PRESET_CENTER)
	mp_lobby_panel.custom_minimum_size = Vector2(580, 520)
	mp_lobby_panel.offset_left = -290.0
	mp_lobby_panel.offset_right = 290.0
	mp_lobby_panel.offset_top = -260.0
	mp_lobby_panel.offset_bottom = 260.0

	var lob_sb = StyleBoxFlat.new()
	lob_sb.bg_color = Color(0.02, 0.04, 0.08, 0.96)
	lob_sb.border_width_left = 2
	lob_sb.border_width_top = 2
	lob_sb.border_width_right = 2
	lob_sb.border_width_bottom = 2
	lob_sb.border_color = Color(0.95, 0.65, 0.15, 0.9)
	lob_sb.content_margin_left = 18
	lob_sb.content_margin_right = 18
	lob_sb.content_margin_top = 16
	lob_sb.content_margin_bottom = 16
	lob_sb.corner_radius_top_left = 6
	lob_sb.corner_radius_top_right = 6
	lob_sb.corner_radius_bottom_left = 6
	lob_sb.corner_radius_bottom_right = 6
	mp_lobby_panel.add_theme_stylebox_override("panel", lob_sb)
	add_child(mp_lobby_panel)

	var lob_vbox = VBoxContainer.new()
	lob_vbox.add_theme_constant_override("separation", 10)
	mp_lobby_panel.add_child(lob_vbox)

	mp_lobby_title = Label.new()
	mp_lobby_title.text = "CO-OP SHIFT LOBBY"
	mp_lobby_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mp_lobby_title.add_theme_font_override("font", font_mono)
	mp_lobby_title.add_theme_font_size_override("font_size", 18)
	mp_lobby_title.add_theme_color_override("font_color", Color(0.95, 0.75, 0.2))
	lob_vbox.add_child(mp_lobby_title)

	mp_lobby_info = Label.new()
	mp_lobby_info.text = "Room: Shift-Room | Night 1 | Tasks x1.5 | Supplies x1.5"
	mp_lobby_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mp_lobby_info.add_theme_font_override("font", font_mono)
	mp_lobby_info.add_theme_font_size_override("font_size", 12)
	mp_lobby_info.add_theme_color_override("font_color", Color(0.65, 0.75, 0.82))
	lob_vbox.add_child(mp_lobby_info)

	# Room Code & IP Banner Box
	var code_box = PanelContainer.new()
	var cb_sb = StyleBoxFlat.new()
	cb_sb.bg_color = Color(0.04, 0.10, 0.14, 0.95)
	cb_sb.border_width_left = 1
	cb_sb.border_width_top = 1
	cb_sb.border_width_right = 1
	cb_sb.border_width_bottom = 1
	cb_sb.border_color = Color(0.2, 0.95, 0.8, 0.8)
	cb_sb.content_margin_left = 12
	cb_sb.content_margin_right = 12
	cb_sb.content_margin_top = 8
	cb_sb.content_margin_bottom = 8
	cb_sb.corner_radius_top_left = 5
	cb_sb.corner_radius_top_right = 5
	cb_sb.corner_radius_bottom_left = 5
	cb_sb.corner_radius_bottom_right = 5
	code_box.add_theme_stylebox_override("panel", cb_sb)
	lob_vbox.add_child(code_box)

	var code_inner_vbox = VBoxContainer.new()
	code_inner_vbox.add_theme_constant_override("separation", 6)
	code_box.add_child(code_inner_vbox)

	# 1. Room Code Row
	var code_hb = HBoxContainer.new()
	code_hb.add_theme_constant_override("separation", 10)
	code_inner_vbox.add_child(code_hb)

	mp_lobby_code_label = Label.new()
	mp_lobby_code_label.text = "MÃ PHÒNG: [Đang khởi tạo...]"
	mp_lobby_code_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mp_lobby_code_label.add_theme_font_override("font", font_mono)
	mp_lobby_code_label.add_theme_font_size_override("font_size", 14)
	mp_lobby_code_label.add_theme_color_override("font_color", Color(0.25, 1.0, 0.8))
	code_hb.add_child(mp_lobby_code_label)

	mp_btn_copy_code = Button.new()
	mp_btn_copy_code.text = "📋 SAO CHÉP MÃ"
	mp_btn_copy_code.custom_minimum_size = Vector2(130, 28)
	mp_btn_copy_code.add_theme_font_override("font", font_mono)
	mp_btn_copy_code.pressed.connect(func():
		var net_mgr = get_node_or_null("/root/NetworkManager")
		var code = ""
		if net_mgr:
			code = net_mgr.get("room_code") if "room_code" in net_mgr else net_mgr.get("current_room_code")
		if (code == null or code == "") and mp_lobby_code_label.text.contains("AGY-"):
			code = mp_lobby_code_label.text.split("MÃ PHÒNG: ")[-1].strip_edges()
		if code != null and code != "":
			DisplayServer.clipboard_set(str(code))
			show_toast("Đã sao chép mã phòng: %s" % str(code), Color(0.2, 1.0, 0.6))
		else:
			show_toast("Mã phòng chưa sẵn sàng!", Color(1.0, 0.6, 0.2))
	)
	code_hb.add_child(mp_btn_copy_code)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 220)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lob_vbox.add_child(scroll)

	mp_lobby_player_list = VBoxContainer.new()
	mp_lobby_player_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mp_lobby_player_list.add_theme_constant_override("separation", 6)
	scroll.add_child(mp_lobby_player_list)

	var lob_btns = HBoxContainer.new()
	lob_btns.add_theme_constant_override("separation", 10)
	lob_vbox.add_child(lob_btns)

	mp_btn_lobby_ready = Button.new()
	mp_btn_lobby_ready.text = "READY UP"
	mp_btn_lobby_ready.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mp_btn_lobby_ready.add_theme_font_override("font", font_mono)
	mp_btn_lobby_ready.pressed.connect(func():
		mp_local_is_ready = not mp_local_is_ready
		mp_btn_lobby_ready.text = "CANCEL READY" if mp_local_is_ready else "READY UP"
		mp_toggle_ready_requested.emit(mp_local_is_ready)
	)
	lob_btns.add_child(mp_btn_lobby_ready)

	mp_btn_lobby_start = Button.new()
	mp_btn_lobby_start.text = "START SHIFT (HOST)"
	mp_btn_lobby_start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mp_btn_lobby_start.add_theme_font_override("font", font_mono)
	mp_btn_lobby_start.pressed.connect(func():
		mp_start_shift_requested.emit()
	)
	lob_btns.add_child(mp_btn_lobby_start)

	var btn_leave = Button.new()
	btn_leave.text = "LEAVE"
	btn_leave.custom_minimum_size = Vector2(90, 0)
	btn_leave.add_theme_font_override("font", font_mono)
	btn_leave.pressed.connect(func():
		mp_leave_room_requested.emit()
		hide_mp_lobby()
		main_menu.visible = true
	)
	lob_btns.add_child(btn_leave)

func _build_mp_scoreboard_panel() -> void:
	mp_scoreboard_panel = PanelContainer.new()
	mp_scoreboard_panel.name = "MultiplayerScoreboardPanel"
	mp_scoreboard_panel.visible = false
	mp_scoreboard_panel.set_anchors_preset(Control.PRESET_CENTER)
	mp_scoreboard_panel.custom_minimum_size = Vector2(680, 480)
	mp_scoreboard_panel.offset_left = -340.0
	mp_scoreboard_panel.offset_right = 340.0
	mp_scoreboard_panel.offset_top = -240.0
	mp_scoreboard_panel.offset_bottom = 240.0

	var sc_sb = StyleBoxFlat.new()
	sc_sb.bg_color = Color(0.02, 0.03, 0.06, 0.97)
	sc_sb.border_width_left = 2
	sc_sb.border_width_top = 2
	sc_sb.border_width_right = 2
	sc_sb.border_width_bottom = 2
	sc_sb.border_color = Color(0.95, 0.8, 0.2, 0.9)
	sc_sb.content_margin_left = 20
	sc_sb.content_margin_right = 20
	sc_sb.content_margin_top = 16
	sc_sb.content_margin_bottom = 16
	sc_sb.corner_radius_top_left = 6
	sc_sb.corner_radius_top_right = 6
	sc_sb.corner_radius_bottom_left = 6
	sc_sb.corner_radius_bottom_right = 6
	mp_scoreboard_panel.add_theme_stylebox_override("panel", sc_sb)
	add_child(mp_scoreboard_panel)

	var sc_vbox = VBoxContainer.new()
	sc_vbox.add_theme_constant_override("separation", 10)
	mp_scoreboard_panel.add_child(sc_vbox)

	mp_scoreboard_title = Label.new()
	mp_scoreboard_title.text = "★ SHIFT SUMMARY — EMPLOYEE EVALUATION ★"
	mp_scoreboard_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mp_scoreboard_title.add_theme_font_override("font", font_mono)
	mp_scoreboard_title.add_theme_font_size_override("font_size", 18)
	mp_scoreboard_title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.25))
	sc_vbox.add_child(mp_scoreboard_title)

	mp_scoreboard_winner = Label.new()
	mp_scoreboard_winner.text = "WINNER: Janitor #1"
	mp_scoreboard_winner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mp_scoreboard_winner.add_theme_font_override("font", font_mono)
	mp_scoreboard_winner.add_theme_font_size_override("font_size", 14)
	mp_scoreboard_winner.add_theme_color_override("font_color", Color(0.3, 0.95, 0.65))
	sc_vbox.add_child(mp_scoreboard_winner)

	# Headers Row
	var hdr = HBoxContainer.new()
	var h_rank = Label.new(); h_rank.text = "RANK"; h_rank.custom_minimum_size = Vector2(48, 0)
	var h_name = Label.new(); h_name.text = "JANITOR"; h_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h_wages = Label.new(); h_wages.text = "WAGES"; h_wages.custom_minimum_size = Vector2(80, 0); h_wages.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var h_stuns = Label.new(); h_stuns.text = "STUNS"; h_stuns.custom_minimum_size = Vector2(65, 0); h_stuns.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var h_kills = Label.new(); h_kills.text = "KILLS"; h_kills.custom_minimum_size = Vector2(65, 0); h_kills.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var h_deaths = Label.new(); h_deaths.text = "DOWNED"; h_deaths.custom_minimum_size = Vector2(65, 0); h_deaths.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var h_tasks = Label.new(); h_tasks.text = "TASKS"; h_tasks.custom_minimum_size = Vector2(65, 0); h_tasks.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	for h in [h_rank, h_name, h_wages, h_stuns, h_kills, h_deaths, h_tasks]:
		h.add_theme_font_override("font", font_mono)
		h.add_theme_font_size_override("font_size", 11)
		h.add_theme_color_override("font_color", Color(0.65, 0.72, 0.8))
		hdr.add_child(h)
	sc_vbox.add_child(hdr)

	var sep = HSeparator.new()
	sc_vbox.add_child(sep)

	var sc_scroll = ScrollContainer.new()
	sc_scroll.custom_minimum_size = Vector2(0, 180)
	sc_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc_vbox.add_child(sc_scroll)

	mp_scoreboard_table = VBoxContainer.new()
	mp_scoreboard_table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mp_scoreboard_table.add_theme_constant_override("separation", 6)
	sc_scroll.add_child(mp_scoreboard_table)

	var tie_info = Label.new()
	tie_info.text = "Tie-breaker order: Total Wages ($) > Boss Stuns > Specimens Killed > Fewest Downed > Tasks Completed"
	tie_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tie_info.add_theme_font_override("font", font_mono)
	tie_info.add_theme_font_size_override("font_size", 10)
	tie_info.add_theme_color_override("font_color", Color(0.48, 0.55, 0.62))
	sc_vbox.add_child(tie_info)

	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	sc_vbox.add_child(btn_row)

	mp_btn_scoreboard_next = Button.new()
	mp_btn_scoreboard_next.text = "CONTINUE TO NEXT SHIFT (HOST)"
	mp_btn_scoreboard_next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mp_btn_scoreboard_next.add_theme_font_override("font", font_mono)
	mp_btn_scoreboard_next.pressed.connect(func():
		hide_mp_scoreboard()
		mp_start_shift_requested.emit()
	)
	btn_row.add_child(mp_btn_scoreboard_next)

	mp_btn_scoreboard_menu = Button.new()
	mp_btn_scoreboard_menu.text = "EXIT TO LOBBY / MENU"
	mp_btn_scoreboard_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mp_btn_scoreboard_menu.add_theme_font_override("font", font_mono)
	mp_btn_scoreboard_menu.pressed.connect(func():
		hide_mp_scoreboard()
		quit_to_menu.emit()
	)
	btn_row.add_child(mp_btn_scoreboard_menu)

func show_multiplayer_menu() -> void:
	if mp_panel:
		mp_panel.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		var net_mgr = get_node_or_null("/root/NetworkManager")
		if net_mgr and net_mgr.has_method("start_room_browser"):
			net_mgr.start_room_browser()

func hide_multiplayer_menu() -> void:
	if mp_panel:
		mp_panel.visible = false
		var net_mgr = get_node_or_null("/root/NetworkManager")
		if net_mgr and net_mgr.has_method("stop_room_browser"):
			net_mgr.stop_room_browser()

func show_mp_lobby(room_name: String, day_num: int, map_idx: int, task_mult: float, supplies_mult: float) -> void:
	hide_multiplayer_menu()
	if mp_lobby_panel:
		mp_lobby_panel.visible = true
		var map_str = "Random Variant" if map_idx < 0 else ("Map #%d" % (map_idx + 1))
		mp_lobby_info.text = "Room: %s  |  Night %d (%s)  |  Tasks x%.1f  |  Supplies x%.1f" % [
			room_name, day_num, map_str, task_mult, supplies_mult
		]
		mp_local_is_ready = false
		mp_btn_lobby_ready.text = "READY UP"
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func hide_mp_lobby() -> void:
	if mp_lobby_panel:
		mp_lobby_panel.visible = false

func update_mp_lobby(players: Dictionary, is_host: bool) -> void:
	if not mp_lobby_player_list:
		return
	for child in mp_lobby_player_list.get_children():
		child.queue_free()

	if mp_btn_lobby_start:
		mp_btn_lobby_start.visible = is_host
	if mp_btn_copy_code:
		mp_btn_copy_code.visible = is_host

	for pid in players.keys():
		var p = players[pid]
		var row = HBoxContainer.new()
		var badge = Label.new()
		badge.text = "[HOST]" if p.get("is_host", false) else "[JANITOR]"
		badge.custom_minimum_size = Vector2(75, 0)
		badge.add_theme_font_override("font", font_mono)
		badge.add_theme_font_size_override("font_size", 12)
		badge.add_theme_color_override("font_color", Color(0.95, 0.75, 0.2) if p.get("is_host", false) else Color(0.45, 0.75, 0.95))
		row.add_child(badge)

		var name_lbl = Label.new()
		name_lbl.text = str(p.get("name", "Janitor"))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_override("font", font_mono)
		name_lbl.add_theme_font_size_override("font_size", 13)
		row.add_child(name_lbl)

		var ready_lbl = Label.new()
		var rdy = (p.get("ready", false) == true)
		ready_lbl.text = "[READY]" if rdy else "[PREPARING]"
		ready_lbl.add_theme_font_override("font", font_mono)
		ready_lbl.add_theme_font_size_override("font_size", 12)
		ready_lbl.add_theme_color_override("font_color", Color(0.2, 0.95, 0.45) if rdy else Color(0.95, 0.55, 0.2))
		row.add_child(ready_lbl)

		mp_lobby_player_list.add_child(row)

func show_mp_scoreboard(stats: Array, is_final_night: bool, is_host: bool) -> void:
	if not mp_scoreboard_panel:
		return
	mp_scoreboard_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if is_final_night:
		mp_scoreboard_title.text = "★ GRAND JANITOR EVALUATION — NIGHT 5 FINAL ★"
		mp_btn_scoreboard_next.text = "CONCLUDE EVALUATION (HOST)"
	else:
		mp_scoreboard_title.text = "SHIFT EVALUATION — JANITOR PERFORMANCE & WAGES"
		mp_btn_scoreboard_next.text = "PROCEED TO NEXT SHIFT (HOST)"

	mp_btn_scoreboard_next.visible = is_host

	for c in mp_scoreboard_table.get_children():
		c.queue_free()

	if stats.is_empty():
		return

	var top_p = stats[0]
	if is_final_night:
		mp_scoreboard_winner.text = "🏆 WINNER: %s — EARNED $%d TOTAL WAGES!" % [
			top_p.get("name", "Janitor"),
			top_p.get("wages", 0)
		]
	else:
		mp_scoreboard_winner.text = "★ EMPLOYEE OF THE SHIFT: %s ($%d Wages)" % [
			top_p.get("name", "Janitor"),
			top_p.get("wages", 0)
		]

	for i in range(stats.size()):
		var p = stats[i]
		var r_box = HBoxContainer.new()

		var rk = Label.new()
		rk.text = "#%d" % (i + 1)
		rk.custom_minimum_size = Vector2(48, 0)
		rk.add_theme_font_override("font", font_mono)
		rk.add_theme_font_size_override("font_size", 12)
		rk.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2) if i == 0 else Color(0.7, 0.75, 0.8))
		r_box.add_child(rk)

		var nm = Label.new()
		nm.text = str(p.get("name", "Janitor"))
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.add_theme_font_override("font", font_mono)
		nm.add_theme_font_size_override("font_size", 13)
		nm.add_theme_color_override("font_color", Color(1.0, 0.95, 0.5) if i == 0 else Color(0.9, 0.92, 0.95))
		r_box.add_child(nm)

		var wg = Label.new()
		wg.text = "$%d" % int(p.get("wages", 0))
		wg.custom_minimum_size = Vector2(80, 0)
		wg.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		wg.add_theme_font_override("font", font_mono)
		wg.add_theme_font_size_override("font_size", 13)
		wg.add_theme_color_override("font_color", Color(0.3, 0.95, 0.55))
		r_box.add_child(wg)

		var stn = Label.new()
		stn.text = str(p.get("stuns", 0))
		stn.custom_minimum_size = Vector2(65, 0)
		stn.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stn.add_theme_font_override("font", font_mono)
		stn.add_theme_font_size_override("font_size", 12)
		r_box.add_child(stn)

		var kl = Label.new()
		kl.text = str(p.get("kills", 0))
		kl.custom_minimum_size = Vector2(65, 0)
		kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		kl.add_theme_font_override("font", font_mono)
		kl.add_theme_font_size_override("font_size", 12)
		r_box.add_child(kl)

		var dt = Label.new()
		dt.text = str(p.get("deaths", 0))
		dt.custom_minimum_size = Vector2(65, 0)
		dt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		dt.add_theme_font_override("font", font_mono)
		dt.add_theme_font_size_override("font_size", 12)
		r_box.add_child(dt)

		var tk = Label.new()
		tk.text = str(p.get("tasks", 0))
		tk.custom_minimum_size = Vector2(65, 0)
		tk.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		tk.add_theme_font_override("font", font_mono)
		tk.add_theme_font_size_override("font_size", 12)
		r_box.add_child(tk)

		mp_scoreboard_table.add_child(r_box)

func hide_mp_scoreboard() -> void:
	if mp_scoreboard_panel:
		mp_scoreboard_panel.visible = false

# --- IN-GAME CHAT SYSTEM ---
func _build_mp_chat_panel() -> void:
	mp_chat_panel = PanelContainer.new()
	mp_chat_panel.name = "MultiplayerChatPanel"
	mp_chat_panel.visible = false
	mp_chat_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	mp_chat_panel.custom_minimum_size = Vector2(380, 180)
	mp_chat_panel.offset_left = 18.0
	mp_chat_panel.offset_top = -365.0
	mp_chat_panel.offset_right = 398.0
	mp_chat_panel.offset_bottom = -185.0
	mp_chat_panel.mouse_filter = Control.MOUSE_FILTER_PASS

	var chat_sb = StyleBoxFlat.new()
	chat_sb.bg_color = Color(0.02, 0.04, 0.07, 0.75)
	chat_sb.border_width_left = 1
	chat_sb.border_width_top = 1
	chat_sb.border_width_right = 1
	chat_sb.border_width_bottom = 1
	chat_sb.border_color = Color(0.18, 0.35, 0.45, 0.7)
	chat_sb.content_margin_left = 8
	chat_sb.content_margin_right = 8
	chat_sb.content_margin_top = 6
	chat_sb.content_margin_bottom = 6
	chat_sb.corner_radius_top_left = 4
	chat_sb.corner_radius_top_right = 4
	chat_sb.corner_radius_bottom_left = 4
	chat_sb.corner_radius_bottom_right = 4
	mp_chat_panel.add_theme_stylebox_override("panel", chat_sb)
	game_hud.add_child(mp_chat_panel)

	var chat_vbox = VBoxContainer.new()
	chat_vbox.add_theme_constant_override("separation", 4)
	mp_chat_panel.add_child(chat_vbox)

	# Message Log Scroll
	mp_chat_scroll = ScrollContainer.new()
	mp_chat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mp_chat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	chat_vbox.add_child(mp_chat_scroll)

	mp_chat_vbox = VBoxContainer.new()
	mp_chat_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mp_chat_vbox.add_theme_constant_override("separation", 2)
	mp_chat_scroll.add_child(mp_chat_vbox)

	# Input row
	var input_row = HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 6)
	chat_vbox.add_child(input_row)

	mp_chat_input = LineEdit.new()
	mp_chat_input.placeholder_text = "Nhập tin nhắn [Enter]..."
	mp_chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mp_chat_input.custom_minimum_size = Vector2(0, 26)
	mp_chat_input.add_theme_font_override("font", font_mono)
	mp_chat_input.add_theme_font_size_override("font_size", 12)
	input_row.add_child(mp_chat_input)

	mp_btn_send_chat = Button.new()
	mp_btn_send_chat.text = "GỬI"
	mp_btn_send_chat.custom_minimum_size = Vector2(50, 26)
	mp_btn_send_chat.add_theme_font_override("font", font_mono)
	mp_btn_send_chat.add_theme_font_size_override("font_size", 11)
	input_row.add_child(mp_btn_send_chat)

	mp_chat_input.text_submitted.connect(_on_chat_text_submitted)
	mp_btn_send_chat.pressed.connect(func(): _on_chat_text_submitted(mp_chat_input.text))

func _on_chat_text_submitted(txt: String) -> void:
	var msg = txt.strip_edges()
	if msg != "":
		var net_mgr = get_node_or_null("/root/NetworkManager")
		if net_mgr and net_mgr.get("is_multiplayer_active") == true:
			var sender = str(net_mgr.get("local_player_name"))
			if net_mgr.has_method("send_chat_message"):
				net_mgr.send_chat_message(sender, msg, false)
			else:
				net_mgr.rpc("rpc_send_chat", sender, msg, false)
	close_chat_input()

func add_chat_message(sender: String, message: String, is_system: bool = false) -> void:
	if not mp_chat_vbox:
		return
	mp_chat_panel.visible = true

	var lbl = RichTextLabel.new()
	lbl.fit_content = true
	lbl.bbcode_enabled = true
	lbl.scroll_active = false
	lbl.custom_minimum_size = Vector2(0, 16)
	lbl.add_theme_font_override("normal_font", font_mono)
	lbl.add_theme_font_size_override("normal_font_size", 12)

	if is_system:
		lbl.text = "[color=#f2c94c]<b>[HỆ THỐNG]:</b>[/color] [color=#e0e0e0]%s[/color]" % message
	else:
		lbl.text = "[color=#27ae60]<b>[%s]:</b>[/color] [color=#ffffff]%s[/color]" % [sender, message]

	mp_chat_vbox.add_child(lbl)

	# Keep maximum 50 messages
	while mp_chat_vbox.get_child_count() > 50:
		var c = mp_chat_vbox.get_child(0)
		mp_chat_vbox.remove_child(c)
		c.queue_free()

	# Auto scroll to bottom next frame
	get_tree().process_frame.connect(func():
		if mp_chat_scroll:
			mp_chat_scroll.scroll_vertical = int(mp_chat_scroll.get_v_scroll_bar().max_value)
	, CONNECT_ONE_SHOT)

func open_chat_input() -> void:
	if mp_chat_panel:
		mp_chat_panel.visible = true
	if mp_chat_input:
		mp_chat_input.grab_focus()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_chat_input() -> void:
	if mp_chat_input:
		mp_chat_input.text = ""
		mp_chat_input.release_focus()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func toggle_chat_input() -> void:
	if is_chat_focused():
		close_chat_input()
	else:
		open_chat_input()

func is_chat_focused() -> bool:
	return mp_chat_input and mp_chat_input.has_focus()

# --- SPECTATOR MODE HUD ---
func _build_mp_spectator_banner() -> void:
	mp_spectator_banner = PanelContainer.new()
	mp_spectator_banner.name = "SpectatorBanner"
	mp_spectator_banner.visible = false
	mp_spectator_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	mp_spectator_banner.custom_minimum_size = Vector2(440, 56)
	mp_spectator_banner.offset_left = -220.0
	mp_spectator_banner.offset_top = 22.0
	mp_spectator_banner.offset_right = 220.0
	mp_spectator_banner.offset_bottom = 78.0
	mp_spectator_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var spec_sb = StyleBoxFlat.new()
	spec_sb.bg_color = Color(0.12, 0.02, 0.03, 0.88)
	spec_sb.border_width_left = 2
	spec_sb.border_width_top = 2
	spec_sb.border_width_right = 2
	spec_sb.border_width_bottom = 2
	spec_sb.border_color = Color(0.95, 0.25, 0.25, 0.9)
	spec_sb.corner_radius_top_left = 6
	spec_sb.corner_radius_top_right = 6
	spec_sb.corner_radius_bottom_left = 6
	spec_sb.corner_radius_bottom_right = 6
	mp_spectator_banner.add_theme_stylebox_override("panel", spec_sb)
	game_hud.add_child(mp_spectator_banner)

	mp_spectator_label = Label.new()
	mp_spectator_label.text = "🔴 BẠN ĐÃ TỬ NẠN — ĐANG QUAN SÁT ĐỒNG ĐỘI\n[A] / [D] hoặc [Click Chuột] để chuyển người"
	mp_spectator_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mp_spectator_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mp_spectator_label.add_theme_font_override("font", font_mono)
	mp_spectator_label.add_theme_font_size_override("font_size", 12)
	mp_spectator_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.85))
	mp_spectator_banner.add_child(mp_spectator_label)

func show_spectator_banner(text: String) -> void:
	if mp_spectator_banner:
		mp_spectator_banner.visible = true
	if mp_spectator_label:
		mp_spectator_label.text = text

func hide_spectator_banner() -> void:
	if mp_spectator_banner:
		mp_spectator_banner.visible = false


