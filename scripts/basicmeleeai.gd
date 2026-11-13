extends CharacterBody3D
@export var difficulty_rating:float = 1.0

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
@onready var freeze_timer: Timer = $Misc/FreezeTimer

var spawn_pos:Vector3
var has_target:bool = false
var targets:Array = []
var target:Node3D
var timer:float = 0.0
var shield_broken:bool = false
var is_alive = true
var player_in_front:Array = []
var is_buffed:bool = false
var is_healing:bool = false
var can_move:bool = true

func _ready() -> void:
	current_shield_val = shield_val
	current_health = health
	update_bars()
	spawn_pos = global_position
	bars.transparency = 1
	pass
	
func _physics_process(delta: float) -> void:
	if is_alive:
		if has_target and can_move:
			if global_position.distance_squared_to(target.global_position) <= 400:
				attack_sequence(delta)
			nav.target_position =  targets[0].global_position
			var next_path_pos := nav.get_next_path_position()
			var dir := global_position.direction_to(next_path_pos)
			
			if nav.avoidance_enabled: 
				nav.set_velocity(SPEED*dir)
			else:
				_on_navigation_agent_3d_velocity_computed(SPEED*dir)
			
			if nav.is_navigation_finished():
				if targets.is_empty():
					has_target = false
					bars.transparency = 1
					velocity = Vector3.ZERO
				
			var rotation_speed:float = 4.0
			var target_rotation := dir.signed_angle_to(Vector3.MODEL_FRONT, Vector3.DOWN)
			rotation.y = rotate_toward(rotation.y, target_rotation, delta * rotation_speed)
		move_and_slide()

func attack_sequence(delta:float)->void:
	if timer <= 0:
		#print("attempting attack")
		if attacks.is_empty():
			#print("tried attacking, no attacks found")
			pass
		else:
			if player_in_front.has(target):
				#print("attacked player")
				var attack = attacks.pick_random().instantiate()
				add_child(attack)
				if is_buffed: 
					attack.mod += 0.50
				attack.global_position = global_position
				targets.push_back(targets.pop_front())
				target = targets[0]
				timer = randf_range(cooldown_min, cooldown_max)
			else: 
				#print("selecting new target")
				targets.push_back(targets.pop_front())
				target = targets[0]
	else: timer -= delta
	pass

func _on_area_3d_body_entered(body: Node3D) -> void:
	if is_alive:
		if !targets.has(body):
			#print("target spotted")
			targets.append(body)
			target = targets[0]
		has_target = true
		bars.transparency = 0

func freeze(t:float):
	#print("frozen ", t)
	can_move = false
	nav.avoidance_enabled = false
	velocity = Vector3.ZERO
	freeze_timer.wait_time = t
	freeze_timer.start()

func take_damage(amt:float)->void:
	if not shield_broken:
		if is_buffed: current_health = clampf(current_health - (amt*0.25), 0, health)
		else: current_health = clampf(current_health - (amt*0.5), 0, health)
	else:
		current_health = clampf(current_health - (amt*2), 0, health)
	if current_health == 0:
		is_alive = false
		bars.transparency = 1
	update_bars()
	pass
	
func damage_shield(amt:float)->void:
	if not shield_broken:
		current_shield_val = clampf(current_shield_val - (amt*1.5), 0, shield_val)
		if current_shield_val == 0:
			broken_shield()
		else: update_bars()
	
func broken_shield()->void:
	#print("broken")
	shield_broken = true
	freeze(broken_shield_timer.wait_time)
	broken_shield_timer.start()
	shield_bar.modulate = Color.BLACK
	shield_bar.value = 100
	current_shield_val = shield_val
	var bar_tween = create_tween()
	bar_tween.set_trans(Tween.TRANS_LINEAR)
	bar_tween.tween_property(shield_bar, "value", 0, broken_shield_timer.wait_time-0.001)

func update_bars()->void:
	shield_bar.value = (current_shield_val/shield_val) * 100
	hp_bar.value = (current_health/health) * 100
	pass

func _on_broken_shield_timer_timeout() -> void:
	shield_broken = false
	current_shield_val = shield_val
	update_bars()
	shield_bar.modulate = Color.WHITE

func _on_front_detection_body_entered(body: Node3D) -> void:
	player_in_front.append(body)

func _on_front_detection_body_exited(body: Node3D) -> void:
	player_in_front.erase(body)

func _on_navigation_agent_3d_velocity_computed(safe_velocity: Vector3) -> void:
	velocity = safe_velocity

func _on_freeze_timer_timeout() -> void:
	can_move = true
	nav.avoidance_enabled = true
