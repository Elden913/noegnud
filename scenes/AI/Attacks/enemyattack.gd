extends CSGBox3D
@export var damage:float = 20.0
@onready var timer: Timer = $Timer
var mod:float = 1.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	timer.start()
	get_parent().can_move = false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_area_3d_body_entered(body: Node3D) -> void:
	body.take_damage(damage)


func _on_timer_timeout() -> void:
	get_parent().can_move = true
	queue_free()
