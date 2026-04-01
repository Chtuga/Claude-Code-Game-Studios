class_name LevelFlowSystem
extends Node

## Orchestrates the full level lifecycle.
## Receives initialize(config, hole) from LevelBase on scene ready.
## Waits for first player touch, then starts all systems simultaneously.
## Listens for win/fail signals and routes to the appropriate outcome.
## See design/gdd/level-flow-system.md for full specification.

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal level_complete(stars: int)
signal level_failed

# ---------------------------------------------------------------------------
# Sibling system references — resolved within Systems.tscn
# ---------------------------------------------------------------------------

@onready var _growth: GrowthSystem = $"../GrowthSystem"
@onready var _target: TargetSystem = $"../TargetSystem"
@onready var _timer: TimerSystem = $"../TimerSystem"

# ---------------------------------------------------------------------------
# State machine
# ---------------------------------------------------------------------------

enum State {
	WAITING_FOR_FIRST_TOUCH,
	GAMEPLAY,
	WIN_DELAY,
	WIN,
	CONTINUE_OFFER,
	FAIL
}

var _state: State = State.WAITING_FOR_FIRST_TOUCH

# ---------------------------------------------------------------------------
# Private references (set by initialize)
# ---------------------------------------------------------------------------

var _config: LevelConfig = null
var _hole: HoleController = null

## Duration of the pause between all_goals_complete and emitting level_complete.
const WIN_DELAY_SECONDS: float = 0.3


# ---------------------------------------------------------------------------
# Initialization — called by LevelBase._ready()
# ---------------------------------------------------------------------------

## Entry point. Called once per level load by the level root script.
## Connects all cross-system signals and waits for first player touch.
func initialize(config: LevelConfig, hole: HoleController) -> void:
	_config = config
	_hole = hole

	# Wire win/fail signals from systems into this coordinator
	_target.all_goals_complete.connect(_on_all_goals_complete)
	_timer.time_up.connect(_on_time_up)

	# Wire hole expansion to HoleController
	_growth.hole_level_up.connect(_hole.on_hole_level_up)

	_state = State.WAITING_FOR_FIRST_TOUCH
	set_process_unhandled_input(true)


# ---------------------------------------------------------------------------
# First touch detection
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _state != State.WAITING_FOR_FIRST_TOUCH:
		return

	var is_start_input: bool = (
		(event is InputEventMouseButton
			and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT)
		or (event is InputEventScreenTouch and event.pressed)
	)

	if is_start_input:
		get_viewport().set_input_as_handled()
		_start_gameplay()


# ---------------------------------------------------------------------------
# Gameplay start
# ---------------------------------------------------------------------------

func _start_gameplay() -> void:
	_state = State.GAMEPLAY
	set_process_unhandled_input(false)

	_growth.start(_config)
	_target.start(_config)
	_timer.start(_config.time_limit)
	_hole.start(_config)


# ---------------------------------------------------------------------------
# Win path
# ---------------------------------------------------------------------------

func _on_all_goals_complete() -> void:
	if _state != State.GAMEPLAY:
		return

	_state = State.WIN_DELAY
	_hole.stop()
	_timer.pause()

	await get_tree().create_timer(WIN_DELAY_SECONDS).timeout
	_finish_win()


func _finish_win() -> void:
	_state = State.WIN
	var stars: int = _calculate_stars()
	level_complete.emit(stars)


func _calculate_stars() -> int:
	var remaining: float = _timer.remaining
	var t: Array[float] = _config.star_thresholds
	if remaining >= t[2]:
		return 3
	elif remaining >= t[1]:
		return 2
	else:
		return 1


# ---------------------------------------------------------------------------
# Fail path
# ---------------------------------------------------------------------------

func _on_time_up() -> void:
	if _state != State.GAMEPLAY:
		return

	# Sprint 1: go straight to fail.
	# Post-MVP: transition to CONTINUE_OFFER state and show the continue screen.
	_state = State.FAIL
	_hole.stop()
	level_failed.emit()
