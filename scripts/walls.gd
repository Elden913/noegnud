extends Node3D
@onready var nav_region: NavigationRegion3D = $"../NavigationRegion3D"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	await get_tree().process_frame
	for i in get_children():
		i.size.z = get_node("../NavigationRegion3D/Mesh").size.z
