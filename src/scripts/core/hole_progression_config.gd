class_name HoleProgressionConfig
extends Resource

## Data resource defining all tuning values for hole growth across 10 levels.
## Edit values in the Inspector — never hardcode in scripts.
## See design/gdd/growth-system.md for full specification.

## Starting radius of the hole at level 1 (metres).
@export var base_radius: float = 0.5

## Multiplier applied to base_radius at each level (10 values, index 0 = level 1).
## sphere_radius = base_radius * radius_multipliers[hole_level - 1]
@export var radius_multipliers: Array[float] = [
	1.0, 1.2, 1.45, 1.75, 2.1,
	2.5, 3.0, 3.6, 4.3, 5.2
]

## Points required to reach each level-up (9 values: threshold to go 1→2, 2→3 ... 9→10).
@export var point_thresholds: Array[int] = [
	100, 250, 500, 900, 1400,
	2100, 3000, 4200, 5800
]

## Speed multiplier at each level (10 values, index 0 = level 1).
@export var speed_multipliers: Array[float] = [
	1.0, 1.05, 1.1, 1.15, 1.2,
	1.25, 1.3, 1.35, 1.4, 1.45
]

## Vertical scale multiplier for the hole mesh at each level (10 values).
@export var level_height_multipliers: Array[float] = [
	1.0, 1.1, 1.2, 1.3, 1.4,
	1.55, 1.7, 1.85, 2.0, 2.2
]
