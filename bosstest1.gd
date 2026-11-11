extends RigidBody3D
@export_group("Boss Movements")
@export var speed:float = 1.0

var is_activated:bool = false
var is_moving:bool = true	
var targets:Array = []

@export_group("Boss Attacks")
@export var attacks:Dictionary[String, PackedScene] = {}

func _ready() -> void:
	pass # Replace with function body.

func boss_activation(target:Node3D)->void:
	targets.append(target)
	is_activated = true

func _physics_process(delta: float) -> void:
	if is_activated and is_moving:
		var dir = global_position.direction_to(targets[0].global_position)
		global_position += dir * speed * delta
		look_at(targets[0].global_position, Vector3.UP)
