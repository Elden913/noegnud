extends CSGBox3D
@export var damage:float = 20.0
@onready var timer: Timer = $Timer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	timer.start()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_area_3d_body_entered(body: Node3D) -> void:
	body.take_damage(damage)


func _on_timer_timeout() -> void:
	queue_free()
