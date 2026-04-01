class_name LevelConfig
extends Resource

## Per-level configuration resource.
## Assign a .tres instance of this to the Level root node's `config` export.
## See design/gdd/level-configuration.md for full specification.

## Total time allowed for this level in seconds.
@export var time_limit: float = 90.0

## Seconds remaining thresholds for 1-, 2-, and 3-star ratings.
## stars = 3 if remaining >= star_thresholds[2], 2 if >= [1], else 1.
@export var star_thresholds: Array[float] = [1.0, 30.0, 60.0]

## XZ bounding rectangle for hole movement clamping.
## position = min corner (x, z), size = width / depth.
@export var play_bounds: Rect2 = Rect2(-10.0, -10.0, 20.0, 20.0)

## Progression config for this level (usually the default shared resource).
@export var progression_config: HoleProgressionConfig
