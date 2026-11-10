@tool
class_name SpellResource
extends Resource

@export var spell: String = "":
	set(value):
		spell = value
		inputs = []
		for c in spell:
			inputs.append(ord(c))
			

var inputs: PackedByteArray = []
@export var scene: PackedScene
@export var damage: int
