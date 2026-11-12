extends Node3D

@export var size_curve: Curve
@export var color_gradient: Gradient
var progress: float = 0.0
@onready var box := $CSGBox3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	scale = Vector3.ONE * size_curve.sample(progress)
	box.material.albedo_color = color_gradient.sample(progress)

func set_progress(prog: float):
	print("prog: ", prog)
	create_tween().tween_property(self, "progress", prog, 0.2)

func cast_please():
	print("CASTING PLEASE")

func uncast_please():
	queue_free()


func _on_area_3d_body_entered(body: Node3D) -> void:
	print("damaged")
	body.take_damage(10)
	body.damage_shield(10)
	pass # Replace with function body.
