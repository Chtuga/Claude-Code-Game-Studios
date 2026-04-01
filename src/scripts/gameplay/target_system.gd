class_name TargetSystem
extends Node

## Tracks goal object consumption and emits all_goals_complete when done.
## LevelFlowSystem calls start(config) to initialise counters and connect signals.
## Pure progress tracker — no physics, no points, no object removal.
## See design/gdd/target-system.md for full specification.

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when every goal counter reaches zero.
## LevelFlowSystem listens to this to trigger the win sequence.
signal all_goals_complete

# ---------------------------------------------------------------------------
# Public readable state
# ---------------------------------------------------------------------------

## object_id → remaining_count. HUD reads this to display per-goal progress.
var goal_counters: Dictionary = {}

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

var _started: bool = false


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Called by LevelFlowSystem on first player touch.
## Builds counters from config.goals and connects to goal object signals.
func start(config: LevelConfig) -> void:
	goal_counters.clear()

	for goal: LevelGoal in config.goals:
		goal_counters[goal.object_id] = goal.required_count

	_connect_goal_objects()
	_started = true


# ---------------------------------------------------------------------------
# Signal connections
# ---------------------------------------------------------------------------

func _connect_goal_objects() -> void:
	for node in get_tree().get_nodes_in_group("goal_objects"):
		if node.has_signal("eaten") and not node.eaten.is_connected(_on_goal_eaten):
			node.eaten.connect(_on_goal_eaten)


# ---------------------------------------------------------------------------
# Eat handler
# ---------------------------------------------------------------------------

func _on_goal_eaten(object_id: String, _points: int) -> void:
	if not _started:
		return

	if not goal_counters.has(object_id):
		return

	goal_counters[object_id] = maxi(goal_counters[object_id] - 1, 0)

	_check_win_condition()


func _check_win_condition() -> void:
	for count: int in goal_counters.values():
		if count > 0:
			return

	all_goals_complete.emit()
