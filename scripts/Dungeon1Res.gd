class_name Dungeon1Data
extends Resource

@export var Rooms: Array[PackedScene] = [
	preload("uid://lobj1djvdwht"),
	preload("uid://f1w3l7fjgstp"),
	preload("uid://dx1f60qp3y0vx")
]
@export var Corridors: Dictionary[String, PackedScene] = {
	"hall": preload("uid://cuif807vbjriq")
}
@export var DeadEnd: Array[PackedScene] = [
	preload("uid://bp85tv2hnd1fn")
	]
@export var BossChamber: PackedScene = preload("uid://73hl8j78uxe5")
@export var Spawn: PackedScene = preload("uid://c3to43rj1j2bw")
