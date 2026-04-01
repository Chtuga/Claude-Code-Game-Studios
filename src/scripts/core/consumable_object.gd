class_name ConsumableObject
extends RigidBody3D

## Base class for all eatable objects in Hungry Void.
## Every consumable scene must have this script (or a subclass) on its root node.
## The Hole Controller calls eat() via duck-typing on body_entered.

signal eaten(object_id: String, points: int)

@export var object_id: String = ""
@export var points: int = 0


## Called by HoleController when this object enters the hole's Area3D.
## Awards points, notifies all subscribers, and removes the object from the scene.
func eat() -> void:
	eaten.emit(object_id, points)
	queue_free()
