extends Node
var chunk:Vector2
var chunk_pos_x:float
var chunk_pos_z:float

@onready var player: ProtoController = $".."
@export var chunk_size:int = 25


func _ready() -> void:
	await get_tree().process_frame
	chunk_pos_x = player.global_position.x
	pass

func _physics_process(delta: float) -> void:
	pass
