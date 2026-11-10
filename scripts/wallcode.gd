extends CSGBox3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	await get_tree().process_frame
	size.z = get_parent_node_3d().get_parent().size.z
	pass # Replace with function body.
