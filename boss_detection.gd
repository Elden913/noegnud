extends Area3D
var parent:Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	parent = get_parent()
	body_entered.connect(_on_body_entered)
	pass # Replace with function body.

func _on_body_entered(body:Node3D)->void:
	print("player detected")
	parent.boss_activation(body)
	pass
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
