class_name LevelBase
extends Node3D

## Root script for every level scene.
## Owns the LevelConfig resource and passes it to LevelFlowSystem on ready.
## Attach this to the root node of every level .tscn file.
## Set @export var config to the level-specific .tres in the Inspector.

@export var config: LevelConfig

@onready var _level_flow: LevelFlowSystem = $Systems/LevelFlowSystem
@onready var _hole: HoleController = $Hole


func _ready() -> void:
	assert(config != null, "LevelBase: config not assigned in Inspector on " + name)
	_level_flow.initialize(config, _hole)
