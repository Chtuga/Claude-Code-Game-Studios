class_name HoleController
extends Node3D

## Owns the hole's Area3D, CollisionShape3D (SphereShape3D resource), movement,
## and eat detection. Receives movement input directly for Sprint 1; will be
## wired to the Input System signal in a future sprint.
## Config is passed via setup() from LevelFlowSystem — not set in Inspector.
## See design/gdd/hole-controller.md for full specification.

# ---------------------------------------------------------------------------
# Node references — matched to Hole.tscn structure
# ---------------------------------------------------------------------------

@onready var _area: Area3D = $Area3D
@onready var _collision_shape: CollisionShape3D = $Area3D/CollisionShape3D
@onready var _hole_mesh: MeshInstance3D = $HoleMesh

# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------

## Marker3D in the level scene — the hole teleports here on level start.
## Assign in the Level Inspector (Hole node → Hole Spawn → drag HoleSpawn).
@export var hole_spawn: Marker3D

## Base movement speed in metres per second (level 1).
## Tuning knob — default 5.0 m/s. Safe range: 1.0–20.0.
@export var max_speed: float = 5.0

# ---------------------------------------------------------------------------
# Config — injected by LevelFlowSystem, not set in Inspector
# ---------------------------------------------------------------------------

var config: LevelConfig = null

# ---------------------------------------------------------------------------
# Public readable state
# ---------------------------------------------------------------------------

## Current collision sphere radius — authoritative hole size.
var sphere_radius: float = 0.0

## Current hole level (1–10).
var hole_level: int = 1

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

var _active: bool = false
var _y_position: float = 0.0
var _effective_speed: float = 0.0


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_area.body_entered.connect(_on_body_entered)
	set_process_unhandled_input(false)


## Called by LevelFlowSystem when the player makes their first touch.
## Receives config from LevelFlowSystem — do not assign config in Inspector.
func start(level_config: LevelConfig) -> void:
	config = level_config
	assert(config != null, "HoleController: config is null — check LevelBase.config")
	assert(hole_spawn != null, "HoleController: hole_spawn not assigned in Inspector")

	hole_level = 1
	_y_position = hole_spawn.global_position.y
	global_position = Vector3(
		hole_spawn.global_position.x,
		_y_position,
		hole_spawn.global_position.z
	)

	_apply_level_values(hole_level)
	_active = true
	set_process_unhandled_input(true)


## Called by LevelFlowSystem on level complete or fail — disables movement.
func stop() -> void:
	_active = false
	set_process_unhandled_input(false)


# ---------------------------------------------------------------------------
# Input — Sprint 1 direct handling (replace with Input System signal later)
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	var delta := Vector2.ZERO

	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			delta = event.relative
	elif event is InputEventScreenDrag:
		delta = event.relative

	if delta != Vector2.ZERO:
		_apply_movement(delta)


# ---------------------------------------------------------------------------
# Movement
# ---------------------------------------------------------------------------

func _apply_movement(delta: Vector2) -> void:
	var capped: Vector2 = delta.limit_length(_effective_speed * get_process_delta_time())
	var new_pos := global_position + Vector3(capped.x, 0.0, capped.y)
	new_pos.y = _y_position
	global_position = _clamp_to_bounds(new_pos)


func _clamp_to_bounds(pos: Vector3) -> Vector3:
	var r: float = sphere_radius
	var bounds: Rect2 = config.play_bounds
	pos.x = clampf(pos.x, bounds.position.x + r, bounds.position.x + bounds.size.x - r)
	pos.z = clampf(pos.z, bounds.position.y + r, bounds.position.y + bounds.size.y - r)
	return pos


# ---------------------------------------------------------------------------
# Eat detection
# ---------------------------------------------------------------------------

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("eat"):
		body.eat()


# ---------------------------------------------------------------------------
# Growth System integration
# ---------------------------------------------------------------------------

## Connected to GrowthSystem.hole_level_up by LevelFlowSystem.
func on_hole_level_up(new_level: int) -> void:
	hole_level = new_level
	_apply_level_values(hole_level)


func _apply_level_values(level: int) -> void:
	var prog: HoleProgressionConfig = config.progression_config
	sphere_radius = prog.base_radius * prog.radius_multipliers[level - 1]
	_effective_speed = max_speed * prog.speed_multipliers[level - 1]

	var sphere := _collision_shape.shape as SphereShape3D
	sphere.radius = sphere_radius

	# Scale mesh to match sphere diameter
	_hole_mesh.scale = Vector3.ONE * sphere_radius * 2.0
