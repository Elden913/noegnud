extends MeshInstance3D

@onready var parent: CharacterBody3D = $".."

@export var dissolve_amt:float = 1.0
@export var dissolve_speed:= 1.0
var dissolve_material: ShaderMaterial

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	dissolve_material = material_override as ShaderMaterial
	dissolve_material.set_shader_parameter("dissolve_amt", 0.0)
	pass # Replace with function body.

func dissolve():
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
	tween.tween_property(dissolve_material, "shader_parameter/dissolve_amt", dissolve_amt, dissolve_speed)
	await tween.finished
	parent.queue_free()
