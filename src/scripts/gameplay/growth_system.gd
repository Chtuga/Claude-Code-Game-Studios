class_name GrowthSystem
extends Node

## Accumulates points from eaten objects and drives hole level progression.
## LevelFlowSystem calls start(config) to initialise and connect signals.
## Emits hole_level_up(new_level) — HoleController, Camera, and VFX listen to this.
## See design/gdd/growth-system.md for full specification.

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when accumulated_points crosses a threshold and hole_level increases.
## Subscribers: HoleController, CameraSystem, VFX System, HUD System.
signal hole_level_up(new_level: int)

## Emitted after every eat with updated point totals. HUD points bar listens to this.
signal points_changed(accumulated: int, hole_level: int)

# ---------------------------------------------------------------------------
# Public readable state
# ---------------------------------------------------------------------------

## Total points accumulated this level. HUD reads this for the points bar.
var accumulated_points: int = 0

## Current hole level (1–10). HUD reads this for the level indicator.
var hole_level: int = 1

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

var _config: LevelConfig = null
var _started: bool = false


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Called by LevelFlowSystem on first player touch.
## Resets state, connects to all "consumables" group nodes.
func start(config: LevelConfig) -> void:
	_config = config
	accumulated_points = 0
	hole_level = 1
	_started = true
	_connect_consumables()


# ---------------------------------------------------------------------------
# Signal connections
# ---------------------------------------------------------------------------

func _connect_consumables() -> void:
	for node in get_tree().get_nodes_in_group("consumables"):
		if node.has_signal("eaten") and not node.eaten.is_connected(_on_eaten):
			node.eaten.connect(_on_eaten)


# ---------------------------------------------------------------------------
# Eat handler
# ---------------------------------------------------------------------------

func _on_eaten(object_id: String, points: int) -> void:
	if not _started:
		return

	accumulated_points += points
	_process_level_ups()
	points_changed.emit(accumulated_points, hole_level)


func _process_level_ups() -> void:
	var thresholds: Array[int] = _config.progression_config.point_thresholds

	while hole_level < 10 and accumulated_points >= thresholds[hole_level - 1]:
		hole_level += 1
		hole_level_up.emit(hole_level)
