extends Node3D
var difficulty:float = 0
var parent:Node3D
var support_enemies_present:int = 0

@export var normal_enemies:Dictionary[int, PackedScene] = {}
#int -> difficulty
@export var support_enemies:Array[PackedScene] = []
@export var spawn_radius := 10.0

var enemies_to_spawn:Array = []

func _ready() -> void:
	await get_tree().process_frame
	normal_enemies.sort()
	if get_parent() != null:
		parent = get_parent()
	if "difficulty" in parent:
		difficulty = parent.difficulty
	if difficulty >= 5:
		support_enemies_present = roundi(difficulty/10)
	allocate_budget()

func _process(delta: float) -> void:
	pass

func allocate_budget():
	if support_enemies_present > 0 and !support_enemies.is_empty():
		for i in support_enemies_present:
			enemies_to_spawn.append(support_enemies[i%(support_enemies.size())])
			difficulty -= 1
	else: 
		print("no support enemies present (check packedscene) or js not enough diff")
		
	remove_enemies()
	
	while difficulty > 0:
		if not normal_enemies.is_empty():
			enemies_to_spawn.append(normal_enemies.values().back())
			difficulty -= normal_enemies.keys().back()
			remove_enemies()
		else:
			print("no normal enemies")
			break

	spawn_enemies()

func remove_enemies():
	for enemy in normal_enemies:
		if enemy > difficulty:
			normal_enemies.erase(enemy)

func spawn_enemies():
	var spawned_pos:Array[Vector3] = []
	if not enemies_to_spawn.is_empty():
		for i in enemies_to_spawn:
			var enemy = i.instantiate()
			add_child(enemy)
			var spawnpos = global_position + Vector3(randf_range(-spawn_radius, spawn_radius), 0, randf_range(-spawn_radius, spawn_radius))
			enemy.global_position = spawnpos
			spawned_pos.append(spawnpos)
	else: print("no enemies to spawn")
