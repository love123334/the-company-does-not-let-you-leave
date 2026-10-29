extends Control

var current_slides: Array = []
var slide_index: int = 0
var on_finished: Callable
var current_art: String = ""
var anim_t: float = 0.0

@onready var speaker_label: Label = $VBox/Speaker
@onready var text_label: RichTextLabel = $VBox/Text
@onready var continue_btn: Button = $VBox/ContinueBtn

func _ready() -> void:
    continue_btn.pressed.connect(_advance_slide)

func _process(delta: float) -> void:
    if visible:
        anim_t += delta
        queue_redraw()

func play(slides: Array, callback: Callable) -> void:
    current_slides = slides
    slide_index = 0
    on_finished = callback
    visible = true
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    _display_slide()

func _display_slide() -> void:
    if slide_index < current_slides.size():
        var s = current_slides[slide_index]
        speaker_label.text = s.get("speaker", "NARRATOR")
        text_label.text = s.get("text", "")
        current_art = s.get("art", "window")
        anim_t = 0.0
        SoundEffects.play(SoundEffects.snd_click, -4.0)
        queue_redraw()

func _advance_slide() -> void:
    slide_index += 1
    if slide_index >= current_slides.size():
        visible = false
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
        if on_finished.is_valid():
            on_finished.call()
    else:
        _display_slide()

# Animatic Canvas Drawing (Matching HTML Canvas Art)
func _draw() -> void:
    var w = size.x
    var h = size.y
    
    # Base background
    draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.02, 0.035, 1.0))
    
    match current_art:
        "window":
            # Dark room with rain on window
            var win_rect = Rect2(w/2.0 - 130, h/2.0 - 150, 260, 210)
            draw_rect(win_rect, Color(0.04, 0.08, 0.16))
            draw_rect(win_rect, Color(0.12, 0.22, 0.38), false, 4.0)
            draw_line(Vector2(w/2.0, h/2.0 - 150), Vector2(w/2.0, h/2.0 + 60), Color(0.12, 0.22, 0.38), 3.0)
            draw_line(Vector2(w/2.0 - 130, h/2.0 - 45), Vector2(w/2.0 + 130, h/2.0 - 45), Color(0.12, 0.22, 0.38), 3.0)
            # Falling rain
            for i in range(45):
                var rx = fposmod(float(i * 37) + anim_t * 60.0, w)
                var ry = fposmod(float(i * 53) + anim_t * 500.0, h)
                draw_line(Vector2(rx, ry), Vector2(rx + 3, ry + 16), Color(0.4, 0.6, 0.85, 0.25), 1.5)
                
        "bills":
            # Stack of overdue bills
            for i in range(4):
                var b_rect = Rect2(w/2.0 - 90 + float(i * 6), h/2.0 - 60 + float(i * 8), 180, 100)
                draw_rect(b_rect, Color(0.7, 0.65, 0.45, 0.2))
                draw_rect(b_rect, Color(0.85, 0.3, 0.3, 0.7), false, 2.0)
                
        "flyer":
            # Alley brick wall
            for r in range(0, int(h), 40):
                draw_line(Vector2(0, r), Vector2(w, r), Color(0.08, 0.04, 0.04), 2.0)
            # Wet flyer
            var fl = Rect2(w/2.0 - 110, h/2.0 - 100, 220, 150)
            draw_rect(fl, Color(0.95, 0.92, 0.78, 0.95))
            draw_rect(fl, Color(0.4, 0.2, 0.1), false, 3.0)
            
        "elevator":
            # Heavy metal doors
            var left_d = Rect2(w/2.0 - 140, 60, 135, h - 140)
            var right_d = Rect2(w/2.0 + 5, 60, 135, h - 140)
            draw_rect(left_d, Color(0.12, 0.15, 0.2))
            draw_rect(right_d, Color(0.12, 0.15, 0.2))
            draw_rect(left_d, Color(0.25, 0.3, 0.4), false, 3.0)
            draw_rect(right_d, Color(0.25, 0.3, 0.4), false, 3.0)
            
        "alarm":
            # Flashing red alarm strobes
            var pulse = (sin(anim_t * 6.0) * 0.5 + 0.5) * 0.45
            draw_rect(Rect2(Vector2.ZERO, size), Color(0.85, 0.05, 0.05, pulse))
            for i in range(5):
                draw_circle(Vector2(float(i) * (w / 4.0), 40), 70, Color(1.0, 0.1, 0.1, 0.25))
                
        "eyes":
            # Pitch black with glowing predator eyes
            draw_circle(Vector2(w/2.0 - 45, h/2.0 - 20), 12, Color(1.0, 0.05, 0.05))
            draw_circle(Vector2(w/2.0 + 45, h/2.0 - 20), 12, Color(1.0, 0.05, 0.05))
            draw_circle(Vector2(w/2.0 - 20, h/2.0 + 15), 7, Color(1.0, 0.1, 0.1))
            draw_circle(Vector2(w/2.0 + 20, h/2.0 + 15), 7, Color(1.0, 0.1, 0.1))
            
        "street":
            # Rainy street with distant lit window
            draw_rect(Rect2(0, h * 0.6, w, h * 0.4), Color(0.04, 0.06, 0.1))
            draw_rect(Rect2(w/2.0 - 15, h * 0.35, 30, 45), Color(0.9, 0.15, 0.15, 0.8))
