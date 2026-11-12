extends CharacterBody3D

@export_group("combat")
@export var SPEED:float = 5.0
@export var health:float = 100.0
var current_health:float
@export var shield_val:float = 100.0
var current_shield_val:float
@export var cooldown_min:float = 3.0
@export var cooldown_max:float = 6.0
@export var attacks:Array[PackedScene] = []
@onready var nav: NavigationAgent3D = $NavigationAgent3D
@onready var bars: Sprite3D = $Bars
@onready var hp_bar: ProgressBar = $Bars/SubViewport/HPBar
@onready var shield_bar: ProgressBar = $Bars/SubViewport/ShieldBar
@onready var broken_shield_timer: Timer = $Misc/BrokenShieldTimer

var spawn_pos:Vector3
var has_target:bool = false
var targets:Array = []
var target:Node3D
var timer:float = 0.0
var shield_broken:bool = false

func _ready() -> void:
	current_shield_val = shield_val
	current_health = health
	update_bars()
	spawn_pos = global_position
	bars.transparency = 1
	pass
	
func _physics_process(delta: float) -> void:
	if has_target:
		if global_position.distance_squared_to(target.global_position) <= 400:
			attack_sequence(target, delta)
		nav.target_position =  targets[0].global_position
		var next_path_pos := nav.get_next_path_position()
		var dir := global_position.direction_to(next_path_pos)
		velocity = SPEED * dir
		
		if nav.is_navigation_finished():
			if targets.is_empty():
				has_target = false
				bars.transparency = 1
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
	bars.transparency = 0
	pass # Replace with function body.

func take_damage(amt:float)->void:
	if not shield_broken:
		current_health = clampf(current_health - (amt*0.75), 0, 100)
	else:
		current_health = clampf(current_health - (amt*2), 0, 100)
	update_bars()
	pass
	
func damage_shield(amt:float)->void:
	if not shield_broken:
		current_shield_val = clampf(current_shield_val - (amt*1.25), 0, 100)
		if current_shield_val == 0:
			broken_shield()
		else: update_bars()
	else: pass
	
func broken_shield()->void:
	print("broken")
	shield_broken = true
	broken_shield_timer.start()
	shield_bar.modulate = Color.BLACK
	shield_bar.value = 100
	current_shield_val = shield_val
	var bar_tween = create_tween()
	bar_tween.set_trans(Tween.TRANS_LINEAR)
	bar_tween.tween_property(shield_bar, "value", 0, broken_shield_timer.wait_time-0.01)

func update_bars()->void:
	shield_bar.value = (current_shield_val/shield_val) * 100
	hp_bar.value = (current_health/health) * 100
	pass


func _on_broken_shield_timer_timeout() -> void:
	shield_broken = false
	current_shield_val = shield_val
	update_bars()
	shield_bar.modulate = Color.WHITE
	
