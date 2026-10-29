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

signal start_game_clicked()
signal pause_resumed()
signal quit_to_menu()
signal retry_clicked()
signal victory_finish_clicked()
signal override_completed(success: bool)

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
signal dev_repair_mop()
signal dev_unlock_map()
signal dev_panel_closed()
signal dev_test_cutscene(cutscene_id: String)
signal quit_modal_dismissed()

var quit_warning_modal: PanelContainer = null
var quit_warning_title: Label = null
var quit_warning_body: Label = null
var pause_warning_label: Label = null

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
			quit_to_menu.emit()
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
		# 1. Draped dark cloth hood borders around screen edges so player feels inside the Cloak
		var fold_w: float = w * lerpf(0.08, 0.34, r)
		var fold_h: float = h * lerpf(0.07, 0.30, r)
		var cloth_col := Color(0.03, 0.02, 0.05, lerpf(0.65, 0.96, r))
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
				var b_col := Color(0.05, 0.03, 0.08, band_a)
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

func show_toast(msg: String, col: Color = Color(0.95, 0.88, 0.35)) -> void:
	if not toast_label:
		return
	toast_label.text = msg
	toast_label.modulate = col
	toast_label.visible = true
	toast_timer = 3.2

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
		facility_title.text = "CONTAINMENT BREACH — RUN!"
		facility_dot.color = Color(0.95, 0.1, 0.15)
		# Raw step counter box is ONLY shown in Dev Mode (matching HTML lines 4279-4280 & 4472-4475)
		chase_hud_box.visible = dev_mode_enabled
		dist_warning.text = "⚠ ENTITY UNLEASHED — DO NOT STOP MOVING!"
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
	bites: int = 0,
	bait_left: int = 3
) -> void:
	_cached_keycards = keycards
	_cached_max_keycards = max_keycards
	var lines: Array[String] = []
	if current_hud_phase == "work":
		lines.append("• Mop spills: %d / %d" % [spills, max_spills])
		lines.append("• Check terminals: %d / %d" % [terms, max_terms])
		lines.append("• Clean blood stains: %d / 3 (+$15 each)" % blood_cleaned)
		lines.append("• Wages: $%d  |  Bait [B]: %d" % [wages, bait_left])
	else:
		lines.append("• Grab Keycards: %d / %d" % [keycards, max_keycards])
		lines.append("• Wages: $%d  |  Bait [B]: %d" % [wages, bait_left])
		if bites > 0:
			lines.append("• Bites: %d / %d — %d = death" % [bites, GameData.CRAWLER_BITE_MAX, GameData.CRAWLER_BITE_MAX])
		# Only reveal raw step deadline / Final Mode window when Dev Mode (F9) is active!
		if dev_mode_enabled:
			var final_tag = " (FINAL INVINCIBLE!)" if _cached_dist <= GameData.FINAL_TRIGGER_STEPS else " (Final at <=%d)" % GameData.FINAL_TRIGGER_STEPS
			lines.append("• [DEV] Deadline: %d steps%s · ~%d steps away" % [_cached_dist, final_tag, _cached_hunter_steps])
	if relics > 0:
		lines.append("• Relics: %d / 15" % relics)
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

func set_interaction_prompt(prompt: String) -> void:
	if prompt != "":
		interaction_label.visible = true
		interaction_label.text = prompt
		reticle.modulate = Color(0.2, 1.0, 0.4)
	else:
		interaction_label.visible = false
		reticle.modulate = Color(1.0, 1.0, 1.0, 0.7)

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
