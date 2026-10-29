extends Area3D

signal interacted(player_node)

@export var prompt_text: String = "[E] Interact"
@export var is_active: bool = true

func _ready() -> void:
    collision_layer = 4
    collision_mask = 0

func interact(player_node) -> void:
    if is_active:
        interacted.emit(player_node)
