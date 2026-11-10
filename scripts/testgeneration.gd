extends Node3D
## thanks to claude i can rest early
@export var data: Dungeon1Data
## Total number of rooms in the dungeon (spawn room and boss chamber included, minimum 2).
@export var RoomCount: int = 5
## Hall length range (even values are tried). Widen this if rooms fail to fit.
@export var corridor_length_min: int = 20
@export var corridor_length_max: int = 60
## Bounding boxes are shrunk by this before overlap tests so pieces that touch at a door don't collide.
@export var overlap_margin: float = 0.1
## How far a room's centre may be from the corridor's axis before the placement is rejected.
@export var axis_tolerance: float = 0.5
## Whole-dungeon retries per mode (strict / relaxed) and room count.
@export var max_generation_attempts: int = 50
## If leftover doors remain (fallback only), free those Door nodes. Only useful if the Door node holds the doorway cutout/mesh.
@export var remove_unused_doors: bool = false

var target_rooms: int = 0
var strict_doors: bool = true   # true = every door must end up used
var rooms_placed: int = 0
var boss_spawned: bool = false
var open_doors: Array[Dictionary] = []  # {door: Node3D, room: Node3D, depth: int}
var used_doors: Dictionary = {}         # door -> true (something is attached)
var placed_bounds: Dictionary = {}      # piece -> AABB (world space, shrunk)
var warned_scenes: Dictionary = {}

# Door-count planning
var door_counts: Dictionary = {}        # PackedScene -> door count
var spawn_doors: int = 0
var boss_extra: int = 0                 # boss doors beyond its entrance
var room_extras: Array[int] = []        # distinct "doors beyond entrance" values across data.Rooms
var budget_cache: Dictionary = {}

## Change this if you'd rather RoomCount mean "regular rooms only" (e.g. return RoomCount + 2).
func total_rooms() -> int:
	return RoomCount

func _ready() -> void:
	load_dungeon()

func load_dungeon() -> void:
	if not data or not data.Spawn or not data.BossChamber:
		push_error("Dungeon1Data needs Spawn and BossChamber scenes!")
		return

	var requested := total_rooms()
	if requested < 2:
		push_warning("RoomCount must be at least 2 (spawn + boss). Using 2.")
	var target := maxi(requested, 2)

	if target > 2 and data.Rooms.is_empty():
		push_error("Dungeon1Data.Rooms is empty!")
		return

	prepare_door_counts()

	if not budget_ok(spawn_doors, target - 1):
		push_warning("%d rooms can't be built with every door used given your rooms' door counts (spawn: %d, boss: %d). You need some 1-door rooms to close branches. Falling back to allowing unused doors." % [target, spawn_doors, boss_extra + 1])

	for t in range(target, 1, -1):
		if budget_ok(spawn_doors, t - 1) and run_attempts(t, true):
			finish_generation(target)
			return
		if run_attempts(t, false):
			finish_generation(target)
			return

	clear_dungeon()
	push_error("Could not place even the spawn room + boss chamber. Check corridor length range and door alignment.")

func run_attempts(t: int, strict: bool) -> bool:
	target_rooms = t
	strict_doors = strict
	for attempt in max_generation_attempts:
		if build_dungeon():
			return true
	return false

func finish_generation(requested_target: int) -> void:
	if target_rooms < requested_target:
		push_warning("Only %d of %d rooms fit, but the boss chamber was placed." % [target_rooms, requested_target])

	spawn_dead_ends()

## Scans for any open door without a connection and caps it with a random DeadEnd scene
## Scans for any open door without a connection and caps it with a random DeadEnd scene
func spawn_dead_ends() -> void:
	if not data or data.DeadEnd.is_empty():
		return

	var leftover: Array[Dictionary] = []
	for piece in placed_bounds.keys():
		var doors = piece.get_node_or_null("Doors")
		if not doors:
			continue
		for door in doors.get_children():
			if not used_doors.has(door):
				leftover.append({"door": door, "room": piece})

	for entry in leftover:
		var door: Node3D = entry["door"]
		var room: Node3D = entry["room"]

		if used_doors.has(door):
			continue

		var dir := get_outward_dir(door.global_position, get_room_centre(room))
		var scene: PackedScene = data.DeadEnd.pick_random()
		if not scene:
			continue

		var dead_end: Node3D = scene.instantiate()
		add_child(dead_end)

		if not place_piece(dead_end, door, dir, room, false):
			discard_piece(dead_end)
			if remove_unused_doors:
				door.queue_free()

func build_dungeon() -> bool:
	clear_dungeon()

	# Spawn room
	var spawn_room: Node3D = data.Spawn.instantiate()
	add_child(spawn_room)
	spawn_room.global_position = Vector3.ZERO
	placed_bounds[spawn_room] = get_world_aabb(spawn_room).grow(-overlap_margin)
	rooms_placed = 1
	add_open_doors(spawn_room, 0)

	# Add rooms (each one comes with its own straight corridor); the boss is always last
	while rooms_placed < target_rooms:
		var is_boss := rooms_placed == target_rooms - 1
		if not extend_dungeon(is_boss):
			return false

	return boss_spawned

func clear_dungeon() -> void:
	for piece in placed_bounds.keys():
		remove_child(piece)
		piece.queue_free()
	placed_bounds.clear()
	used_doors.clear()
	open_doors.clear()
	rooms_placed = 0
	boss_spawned = false

# ---------- Door-count planning ----------

func count_doors(scene: PackedScene) -> int:
	if door_counts.has(scene):
		return door_counts[scene]
	var inst: Node = scene.instantiate() # not added to the tree, so no _ready runs
	var doors = inst.get_node_or_null("Doors")
	var n: int = doors.get_child_count() if doors else 0
	inst.free()
	door_counts[scene] = n
	return n

func prepare_door_counts() -> void:
	budget_cache.clear()
	spawn_doors = count_doors(data.Spawn)
	boss_extra = maxi(count_doors(data.BossChamber) - 1, 0)
	room_extras.clear()
	for scene in data.Rooms:
		var extra := maxi(count_doors(scene) - 1, 0)
		if not room_extras.has(extra):
			room_extras.append(extra)

## Can `open` open doors be completely filled using exactly `rem` more rooms (the last one being the boss)?
func budget_ok(open: int, rem: int) -> bool:
	if rem == 0:
		return open == 0
	if open < 1 or open > rem:
		return false # every open door needs its own room

	var key := open * 10000 + rem
	if budget_cache.has(key):
		return budget_cache[key]

	var ok := false
	if rem == 1:
		ok = budget_ok(open - 1 + boss_extra, 0)
	else:
		for extra in room_extras:
			if budget_ok(open - 1 + extra, rem - 1):
				ok = true
				break

	budget_cache[key] = ok
	return ok

# ---------- Generation ----------

## Registers every unused door of a room as a place the dungeon can grow from
func add_open_doors(room: Node3D, depth: int) -> void:
	var doors_node = room.get_node_or_null("Doors")
	if not doors_node:
		return
	for door in doors_node.get_children():
		if not used_doors.has(door):
			open_doors.append({"door": door, "room": room, "depth": depth})

## Attaches one new room (+ its corridor) to some open door. Returns false if nothing fits anywhere.
func extend_dungeon(is_boss: bool) -> bool:
	var entries := open_doors.duplicate()
	entries.shuffle()
	if is_boss:
		entries.sort_custom(func(a, b): return a["depth"] > b["depth"]) # boss goes as deep as possible

	for entry in entries:
		var new_room := try_attach_room(entry, is_boss)
		if new_room:
			open_doors.erase(entry)
			rooms_placed += 1
			if is_boss:
				boss_spawned = true
			add_open_doors(new_room, entry["depth"] + 1)
			return true

	return false

## Tries every corridor/length/room combination on one door
func try_attach_room(entry: Dictionary, is_boss: bool) -> Node3D:
	var source_room: Node3D = entry["room"]
	var door: Node3D = entry["door"]
	var dir := get_outward_dir(door.global_position, get_room_centre(source_room))

	var candidates: Array = []
	if is_boss:
		candidates.append(data.BossChamber)
	else:
		candidates.assign(data.Rooms)
	candidates.shuffle()

	# In strict mode only keep rooms that still allow every door to be used in the end
	var room_scenes: Array = []
	var rem_after := target_rooms - rooms_placed - 1
	for scene in candidates:
		if strict_doors:
			var open_after := open_doors.size() - 1 + maxi(count_doors(scene) - 1, 0)
			if not budget_ok(open_after, rem_after):
				continue
		room_scenes.append(scene)

	if room_scenes.is_empty():
		return null

	var corridor_scenes: Array = data.Corridors.values()
	corridor_scenes.shuffle()

	# Instantiate each candidate room once and reuse it across attempts
	var room_nodes: Array[Node3D] = []
	for scene in room_scenes:
		var node: Node3D = scene.instantiate()
		add_child(node)
		room_nodes.append(node)

	var result := search_fit(door, dir, source_room, corridor_scenes, room_nodes)

	for node in room_nodes:
		if node != result:
			discard_piece(node)

	return result

func search_fit(door: Node3D, dir: Vector3, source_room: Node3D, corridor_scenes: Array, room_nodes: Array[Node3D]) -> Node3D:
	for corridor_scene in corridor_scenes:
		var is_hall: bool = corridor_scene == data.Corridors.get("hall")

		var lengths: Array = [0]
		if is_hall:
			lengths = range(corridor_length_min, corridor_length_max + 1, 2)
			lengths.shuffle()

		var corridor: Node3D = corridor_scene.instantiate()
		add_child(corridor)

		for length in lengths:
			if is_hall:
				apply_hall_length(corridor, length)

			if not place_piece(corridor, door, dir, source_room, false):
				continue

			var exit_door: Node3D = corridor.get_node("Doors").get_child(1)
			for room in room_nodes:
				if place_piece(room, exit_door, dir, corridor, true):
					return room

			# No room fits at this length: undo the corridor and try the next length
			unregister_piece(corridor)

		discard_piece(corridor)

	return null

func apply_hall_length(corridor: Node3D, length: float) -> void:
	var box := corridor as CSGBox3D
	if not box:
		return
	box.size.z = length
	var doorlocmod := -1
	for c_door in corridor.get_node("Doors").get_children():
		c_door.position.z = -1 * doorlocmod * (box.size.z / 2.0)
		doorlocmod *= -1

## Aligns a piece to a door. Rejects it if it overlaps something, or (optionally) if its centre isn't on the corridor's axis.
func place_piece(piece: Node3D, target_door: Node3D, outward_dir: Vector3, parent_piece: Node3D, centre_on_axis: bool) -> bool:
	align_node_to_door(piece, target_door, outward_dir)

	if centre_on_axis:
		var off := get_room_centre(piece) - target_door.global_position
		off.y = 0.0
		off -= outward_dir * off.dot(outward_dir)
		if off.length() > axis_tolerance:
			if not warned_scenes.has(piece.scene_file_path):
				warned_scenes[piece.scene_file_path] = true
				push_warning("'%s': entrance door isn't centred on its wall, so the corridor can't hit the room's centre in a straight line." % piece.scene_file_path)
			return false

	var bounds := get_world_aabb(piece).grow(-overlap_margin)
	for other in placed_bounds:
		if other == parent_piece:
			continue
		if bounds.intersects(placed_bounds[other]):
			return false

	placed_bounds[piece] = bounds
	piece.set_meta("attached_door", target_door)
	used_doors[target_door] = true
	used_doors[piece.get_node("Doors").get_child(0)] = true
	return true

## Undoes place_piece without freeing the node (so it can be re-tried)
func unregister_piece(piece: Node3D) -> void:
	placed_bounds.erase(piece)
	var target = piece.get_meta("attached_door", null)
	if target:
		used_doors.erase(target)
	used_doors.erase(piece.get_node("Doors").get_child(0))

func discard_piece(piece: Node3D) -> void:
	remove_child(piece)
	piece.queue_free()

## Centre marker of a room (Centre/<first child>), or the node's origin if it has none (e.g. corridors)
func get_room_centre(node: Node3D) -> Vector3:
	var centre_node = node.get_node_or_null("Centre")
	if centre_node and centre_node.get_child_count() > 0:
		return centre_node.get_child(0).global_position
	return node.global_position

## Snaps a vector to the nearest cardinal axis on the XZ plane (ZERO stays ZERO)
func snap_cardinal(v: Vector3) -> Vector3:
	if abs(v.x) > abs(v.z):
		return Vector3(sign(v.x), 0, 0)
	return Vector3(0, 0, sign(v.z))

func get_outward_dir(door_pos: Vector3, centre_pos: Vector3) -> Vector3:
	var dir := snap_cardinal(Vector3(door_pos.x - centre_pos.x, 0, door_pos.z - centre_pos.z))
	return Vector3.FORWARD if dir == Vector3.ZERO else dir

## Rotates the node (90-degree steps) so its Door 0 faces back toward the piece it attaches to,
## then moves it so Door 0 sits exactly on the target door.
func align_node_to_door(node_to_place: Node3D, target_door: Node3D, outward_dir: Vector3) -> void:
	var entrance_door: Node3D = node_to_place.get_node("Doors").get_child(0)

	# Measure where the entrance door sits relative to the node's centre at zero rotation
	node_to_place.global_rotation = Vector3.ZERO
	var local_vec := entrance_door.global_position - get_room_centre(node_to_place)
	local_vec.y = 0.0
	var local_dir := snap_cardinal(local_vec)

	# Find the 90-degree rotation that makes the entrance face the corridor (opposite of outward)
	var yaw := 0.0
	var want := -outward_dir
	for k in 4:
		var angle := k * PI / 2.0
		if (Basis(Vector3.UP, angle) * local_dir).dot(want) > 0.5:
			yaw = angle
			break
	node_to_place.global_rotation = Vector3(0.0, yaw, 0.0)

	# Snap Door 0 onto the target door
	var door_offset: Vector3 = entrance_door.global_position - node_to_place.global_position
	node_to_place.global_position = target_door.global_position - door_offset

## Combined world-space bounding box of everything visual inside a piece
func get_world_aabb(root: Node3D) -> AABB:
	var boxes: Array[AABB] = []
	_collect_aabbs(root, boxes)

	if boxes.is_empty():
		return AABB(root.global_position - Vector3.ONE, Vector3.ONE * 2.0)

	var merged := boxes[0]
	for i in range(1, boxes.size()):
		merged = merged.merge(boxes[i])
	return merged

func _collect_aabbs(node: Node, boxes: Array[AABB]) -> void:
	if node is CSGBox3D:
		var b := node as CSGBox3D
		boxes.append(b.global_transform * AABB(-b.size / 2.0, b.size))
	elif node is VisualInstance3D:
		var local_box: AABB = node.get_aabb()
		if local_box.size != Vector3.ZERO:
			boxes.append(node.global_transform * local_box)

	for child in node.get_children():
		_collect_aabbs(child, boxes)
