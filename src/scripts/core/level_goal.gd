class_name LevelGoal
extends Resource

## A single goal entry for a level — one object type and how many must be eaten.
## Add instances of this to LevelConfig.goals in the Inspector.

## Must match the object_id metadata on goal object nodes in the level scene.
@export var object_id: String = ""

## How many of this object type must be eaten to satisfy the goal.
@export var required_count: int = 1
