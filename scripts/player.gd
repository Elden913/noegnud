# ProtoController v1.0 by Brackeys (Modified)
# CC0 License - Intended for rapid prototyping of first-person games.

class_name ProtoController
extends CharacterBody3D

## Signals for UI Decoupling
signal dashed(cooldown_duration: float)
signal dash_cooldown_progress(current_cooldown: float, max_cooldown: float)

@export var spells: Array[SpellResource] = []

@export_group("Movement")
## Can we move around?
@export var can_move: bool = true
## Normal walking speed.
@export var base_speed: float = 7.0
## Can we hold to run?
@export var can_sprint: bool = false
## How fast do we run?
@export var sprint_speed: float = 10.0
## Are we affected by gravity?
@export var has_gravity: bool = true

@export_group("Jumping & Dashing")
## Can we press to jump?
@export var can_jump: bool = true
## Initial vertical impulse of jump.
@export var jump_velocity: float = 4.5
## Speed multiplier during a dash.
@export var dash_speed: float = 30.0
## How long the dash phase lasts in seconds.
@export var dash_duration: float = 0.2
## Cooldown in seconds before another dash can be executed.
@export var dash_cooldown: float = 2.0

@export_group("Freefly Mode")
## Can we press to enter freefly mode (noclip)?
@export var can_freefly: bool = true
## Speed when moving in freefly mode.
@export var freefly_speed: float = 25.0

@export_group("Look & Camera")
## Look around rotation sensitivity.
@export var look_speed: float = 0.002
## Maximum range for cone casting / targeting raycasts.
@export var far_distance: float = 100.0
## Higher values = tighter follow, lower values = looser/smoother follow (e.g. 15.0 - 25.0)
@export var camera_follow_speed: float = 20.0
@export var camera_rotation_speed: float = 25.0
# Node References
@onready var fake_head: Node3D = $FakeHead
@onready var static_camera: Node3D = $FakeHead/StaticCamera
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var collider: CollisionShape3D = $Collider
@onready var raycast: RayCast3D = $Head/RayCast3D


# Internal State Variables
var vel: Vector3 = Vector3.ZERO
var look_rotation: Vector2 = Vector2.ZERO
var move_speed: float = 0.0
var mouse_captured: bool = false
var freeflying: bool = false

# Dash State Variables
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: Vector3 = Vector3.ZERO
var spawn_position: Vector3 = Vector3.ZERO

var current_spell: SpellResource = null
var spell_inputs: PackedByteArray = []
var spell_uncast_timer: Timer = Timer.new()


func _ready() -> void:
	#global_position = spawn_position
	look_rotation.y = rotation.y
	look_rotation.x = fake_head.rotation.x
	spell_uncast_timer.one_shot = true
	spell_uncast_timer.wait_time = 1.0
	spell_uncast_timer.timeout.connect(spell_uncast)
	add_child(spell_uncast_timer)
	head.reparent.call_deferred(get_tree().current_scene)


func _unhandled_input(event: InputEvent) -> void:
	# Mouse capture toggles
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		capture_mouse()
	elif Input.is_key_pressed(KEY_ESCAPE):
		release_mouse()
	if Input.is_key_pressed(KEY_1):
		cast_spell(0)
	if Input.is_key_pressed(KEY_2):
		cast_spell(1)
	if current_spell and event is InputEventKey and event.is_pressed() and not event.is_echo():
		var ch = event.as_text().to_lower()
		match ch:
			"w", "a", "s", "d":
				pass
			var c when len(c) == 1 and c >= 'a' and c <= 'z':
				spell_inputs.append(ord(ch))
				SignalBus.spell_input.emit(ord(ch))
				if current_spell.inputs == spell_inputs:
					var spell_scene := current_spell.scene.instantiate()
					get_tree().current_scene.add_child(spell_scene)
					spell_scene.global_transform = global_transform
					spell_inputs.clear()
				spell_uncast_timer.start()
				

	
	# Mouse look processing
	if mouse_captured and event is InputEventMouseMotion:
		rotate_look(event.relative)

	# Freefly mode toggle
	if can_freefly and Input.is_action_just_pressed("player_freefly"):
		print('freefly pressed')
		if freeflying:
			disable_freefly()
		else:
			enable_freefly()


func _physics_process(delta: float) -> void:
	# Smooth camera follow
	var pos_weight:float = 1.0 - exp(-camera_follow_speed*delta)
	var rot_weight:float = 1.0 - exp(-camera_rotation_speed*delta)
	head.global_position = head.global_position.lerp(static_camera.global_position, pos_weight)
	
	var current_quat: Quaternion = head.global_transform.basis.get_rotation_quaternion()
	var target_quat: Quaternion = static_camera.global_transform.basis.get_rotation_quaternion()
	var smooth_quat: Quaternion = current_quat.slerp(target_quat, rot_weight)

	head.global_transform.basis = Basis(smooth_quat)

	# Freefly branch
	if can_freefly and freeflying:
		_freefly_movement()
		return

	# Grounded movement branch
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED

	_gravity(delta)
	_dash_cooldown(delta)
	_dash_input()
	_horizontal_movement(delta)

	velocity = vel
	move_and_slide()


# --- MOVEMENT HELPERS ---

func _gravity(delta: float) -> void:
	if has_gravity and not is_on_floor():
		vel += get_gravity() * delta


func _dash_cooldown(delta: float) -> void:
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta
		dash_cooldown_progress.emit(maxf(0.0, dash_cooldown_timer), dash_cooldown)

	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false


func _dash_input() -> void:
	if Input.is_action_just_pressed("player_dash") and can_move and dash_cooldown_timer <= 0.0:
		is_dashing = true
		dash_timer = dash_duration
		dash_cooldown_timer = dash_cooldown
		dashed.emit(dash_cooldown)

		var input_dir := Input.get_vector("player_left", "player_right", "player_forward", "player_back")
		if input_dir != Vector2.ZERO:
			dash_direction = (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
		else:
			dash_direction = -transform.basis.z


func _horizontal_movement(_delta: float) -> void:
	if is_dashing:
		vel.x = dash_direction.x * dash_speed
		vel.z = dash_direction.z * dash_speed
		return

	# Jumping logic
	if can_jump and Input.is_action_just_pressed("player_jump") and is_on_floor():
		vel.y = jump_velocity

	# Sprinting logic
	move_speed = sprint_speed if (can_sprint and Input.is_action_pressed("player_sprint")) else base_speed

	# WASD Input
	if can_move:
		var input_dir := Input.get_vector("player_left", "player_right", "player_forward", "player_back")
		var move_dir := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

		if move_dir != Vector3.ZERO:
			vel.x = move_dir.x * move_speed
			vel.z = move_dir.z * move_speed
		else:
			vel.x = move_toward(vel.x, 0.0, move_speed)
			vel.z = move_toward(vel.z, 0.0, move_speed)
	else:
		vel.x = 0.0
		vel.z = 0.0


func _freefly_movement() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var input_dir := Input.get_vector("player_left", "player_right", "player_forward", "player_back")
	var move_dir := (fake_head.global_basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	velocity = move_dir * freefly_speed
	vel = Vector3.ZERO
	move_and_slide()


# --- CAMERA & TARGETING ---

func rotate_look(rot_input: Vector2) -> void:
	look_rotation.x = clampf(look_rotation.x - rot_input.y * look_speed, deg_to_rad(-85.0), deg_to_rad(85.0))
	look_rotation.y -= rot_input.x * look_speed

	transform.basis = Basis()
	rotate_y(look_rotation.y)

	fake_head.transform.basis = Basis()
	fake_head.rotate_x(look_rotation.x)


func get_col_point() -> Vector3:
	if raycast.is_colliding():
		return raycast.get_collision_point()
	return raycast.global_position + (raycast.global_basis * Vector3.FORWARD * 1000.0)

# --- STATE TOGGLES ---

func enable_freefly() -> void:
	freeflying = true
	vel = Vector3.ZERO


func disable_freefly() -> void:
	freeflying = false


func capture_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_captured = true


func release_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	mouse_captured = false

func cast_spell(index: int):
	current_spell = spells[index]
	spell_inputs.clear()
	spell_uncast_timer.start()
	SignalBus.spell_cast_inputs.emit(current_spell.inputs)

func spell_uncast():
	print("UNCASTING")
	spell_uncast_timer.stop()
	current_spell = null
	spell_inputs.clear()
	SignalBus.spell_uncast.emit()
