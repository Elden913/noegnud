extends CharacterBody3D

@export_group("combat")
@export var SPEED:float = 5.0
@export var health:float = 100.0
@export var can_stagger:bool = false
@export var stagger:float = 100.0
@export var can_shield:bool = false
@export var shield_mana:float = 100.0
@export var cooldown_min:float = 3.0
@export var cooldown_max:float = 6.0
@export var attacks:Array[PackedScene] = []

@onready var nav: NavigationAgent3D = $NavigationAgent3D

var spawn_pos:Vector3
var has_target:bool = false
var targets:Array = []
var target:Node3D
var timer:float = 0.0

func _ready() -> void:
	spawn_pos = global_position
	pass
	
func _physics_process(delta: float) -> void:
	if has_target:
		if global_position.distance_squared_to(target.global_position) <= 20 * 20:
			attack_sequence(target, delta)
		nav.target_position =  targets[0].global_position
		var next_path_pos := nav.get_next_path_position()
		var dir := global_position.direction_to(next_path_pos)
		velocity = SPEED * dir
		
		if nav.is_navigation_finished():
			if targets.is_empty():
				has_target = false
				velocity = Vector3.ZERO
			
		var rotation_speed:float = 4.0
		var target_rotation := dir.signed_angle_to(Vector3.MODEL_FRONT, Vector3.DOWN)
		rotation.y = rotate_toward(rotation.y, target_rotation, delta * rotation_speed)
	move_and_slide()
	pass

func attack_sequence(target:Node3D, delta:float)->void:
	if timer <= 0:
		print("attempting attack")
		if attacks.is_empty():
			print("tried attacking, no attacks found")
		else:
			var attack = attacks.pick_random().instantiate()
			targets.push_back(targets.pop_front())
			target = targets[0]
		timer = randf_range(cooldown_min, cooldown_max)
	else: timer -= delta
	pass

func _on_area_3d_body_entered(body: Node3D) -> void:
	if !targets.has(body):
		print("target spotted")
		targets.append(body)
		target = targets[0]
	has_target = true
	pass # Replace with function body.
