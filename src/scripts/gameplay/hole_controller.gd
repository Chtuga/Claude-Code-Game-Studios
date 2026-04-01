class_name HoleController
extends Node3D

## The hole sits flat at ground level. Objects that enter the Area3D get pulled
## downward and eaten after a short fall delay — not instantly destroyed.

@onready var _area: Area3D = $Area3D
@onready var _collision_shape: CollisionShape3D = $Area3D/CollisionShape3D
@onready var _hole_mesh: MeshInstance3D = $HoleMesh

@export var max_speed: float = 5.0

var config: LevelConfig = null
var sphere_radius: float = 0.0
var hole_level: int = 1

var _active: bool = false
var _y_position: float = 0.0
var _effective_speed: float = 0.0
var _swallowing: Array[Node3D] = []


func _ready() -> void:
	_area.body_entered.connect(_on_body_entered)
	set_process_unhandled_input(false)



func start(level_config: LevelConfig) -> void:
	config = level_config
	assert(config != null, "HoleController: config is null")

	hole_level = 1
	_swallowing.clear()
	_y_position = global_position.y

	_apply_level_values(hole_level)
	_active = true
	set_process_unhandled_input(true)


func stop() -> void:
	_active = false
	set_process_unhandled_input(false)


# ---------------------------------------------------------------------------
# Input
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


func _apply_movement(delta: Vector2) -> void:
	var capped: Vector2 = delta.limit_length(_effective_speed * get_physics_process_delta_time())
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
# Swallow — object falls in, then gets eaten
# ---------------------------------------------------------------------------

func _on_body_entered(body: Node3D) -> void:
	if not body.has_method("eat"):
		return
	if _swallowing.has(body):
		return
	_swallowing.append(body)
	_swallow(body)


func _swallow(body: Node3D) -> void:
	if not (body is RigidBody3D):
		body.eat()
		_swallowing.erase(body)
		return

	var rb := body as RigidBody3D
	rb.collision_mask = 0  # stop colliding with floor — gravity does the rest

	# Wait until it has fallen below floor level, then eat
	while is_instance_valid(body) and body.global_position.y > _y_position - 1.0:
		await get_tree().process_frame

	if is_instance_valid(body):
		body.eat()
	_swallowing.erase(body)


# ---------------------------------------------------------------------------
# Growth
# ---------------------------------------------------------------------------

func on_hole_level_up(new_level: int) -> void:
	hole_level = new_level
	_apply_level_values(hole_level)


func _apply_level_values(level: int) -> void:
	var prog: HoleProgressionConfig = config.progression_config
	sphere_radius = prog.base_radius * prog.radius_multipliers[level - 1]
	_effective_speed = max_speed * prog.speed_multipliers[level - 1]

	var cyl := _collision_shape.shape as CylinderShape3D
	cyl.radius = sphere_radius
	cyl.height = 0.5

	_hole_mesh.scale = Vector3(sphere_radius * 2.0, 1.0, sphere_radius * 2.0)
