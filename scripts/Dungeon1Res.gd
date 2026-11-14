class_name Dungeon1Data
extends Resource

@export var Rooms: Array[PackedScene] = [
	preload("uid://lhwneeftc0d4"),
	preload("uid://dt6wsoe5nrgxq"),
	preload("uid://tr4uluq1elyc")
]
@export var Corridors: Dictionary[String, PackedScene] = {
	"hall": preload("uid://7ynm0iqloqnl")
}
@export var DeadEnd: Array[PackedScene] = [
	preload("uid://nqcvf6ggotys")
	]
@export var BossChamber: PackedScene = preload("uid://73hl8j78uxe5")
@export var Spawn: PackedScene = preload("uid://dvajlwfvkpn8s")
