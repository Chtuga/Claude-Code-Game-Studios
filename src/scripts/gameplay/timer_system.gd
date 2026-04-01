class_name TimerSystem
extends Node

## Countdown timer for a level.
## LevelFlowSystem calls start(duration) on level begin, pause() / resume() on
## player input, and add_time() if the player buys a continue.
## Does NOT use Godot's tree pause — only the countdown is frozen on pause so
## physics and rendering continue settling naturally.
## See design/gdd/timer-system.md for full specification.

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted every _process frame while the timer is running.
signal time_changed(remaining: float, is_urgent: bool)

## Emitted exactly once when remaining reaches 0.0.
signal time_up

## Emitted when the timer is paused / resumed by the player.
signal timer_paused
signal timer_resumed

# ---------------------------------------------------------------------------
# Public state
# ---------------------------------------------------------------------------

## Current time remaining in seconds. Readable by any system at any time.
var remaining: float = 0.0

# ---------------------------------------------------------------------------
# Tuning knobs
# ---------------------------------------------------------------------------

## Seconds remaining below which is_urgent becomes true.
## Default: 15 s. Safe range: 5–30 s. See timer-system.md Tuning Knobs.
@export var urgency_threshold: float = 15.0

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

enum State { IDLE, RUNNING, PAUSED, FINISHED }

var _state: State = State.IDLE
var _duration: float = 0.0


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Called by LevelFlowSystem when the level begins (first player touch).
## Initialises the countdown and starts ticking.
func start(duration: float) -> void:
	_duration = duration
	remaining = duration
	_state = State.RUNNING


## Freeze the countdown. Physics and rendering continue.
## Silently ignored if the timer is not currently running.
func pause() -> void:
	if _state != State.RUNNING:
		return
	_state = State.PAUSED
	timer_paused.emit()


## Resume from the frozen value. No time is lost during the pause.
## Silently ignored if the timer is not currently paused.
func resume() -> void:
	if _state != State.PAUSED:
		return
	_state = State.RUNNING
	timer_resumed.emit()


## Add bonus seconds (e.g. +30 s on continue offer accept).
## Clamped so remaining never exceeds the original duration.
func add_time(seconds: float) -> void:
	remaining = min(remaining + seconds, _duration)


## Reset to idle — used by LevelFlowSystem on level restart without scene reload.
func reset() -> void:
	remaining = _duration
	_state = State.IDLE


# ---------------------------------------------------------------------------
# Process
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _state != State.RUNNING:
		return

	remaining = maxf(remaining - delta, 0.0)
	var is_urgent: bool = remaining <= urgency_threshold
	time_changed.emit(remaining, is_urgent)

	if remaining <= 0.0:
		_state = State.FINISHED
		time_up.emit()
