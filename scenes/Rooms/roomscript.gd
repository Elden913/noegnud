extends CSGBox3D
var loot:float = 0.0
var difficulty:float = 0.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	await get_tree().process_frame
	#print(self, " loot, diff: ", loot, " ", difficulty)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
