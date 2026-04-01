class_name LevelBase
extends Node3D

## Root script for every level scene.
## Owns the LevelConfig resource and passes it to LevelFlowSystem on ready.
## Attach this to the root node of every level .tscn file.
## Set @export var config to the level-specific .tres in the Inspector.

@export var config: LevelConfig

@onready var _level_flow: LevelFlowSystem = $Systems/LevelFlowSystem
@onready var _growth: GrowthSystem = $Systems/GrowthSystem
@onready var _target: TargetSystem = $Systems/TargetSystem
@onready var _timer: TimerSystem = $Systems/TimerSystem
@onready var _hole: HoleController = $Hole
@onready var _hud: HudSystem = $HUD


func _ready() -> void:
	assert(config != null, "LevelBase: config not assigned in Inspector on " + name)
	_level_flow.initialize(config, _hole)
	_wire_hud()


func _wire_hud() -> void:
	var thresholds: Array[int] = config.progression_config.point_thresholds
	_timer.time_changed.connect(_hud.set_timer)
	_growth.hole_level_up.connect(_hud.set_level)
	_growth.points_changed.connect(
		func(pts: int, lvl: int): _hud.set_points(pts, thresholds, lvl)
	)
	_target.goal_count_changed.connect(_hud.set_goals)
	_level_flow.level_complete.connect(_hud.show_win)
	_level_flow.level_failed.connect(_hud.show_fail)
