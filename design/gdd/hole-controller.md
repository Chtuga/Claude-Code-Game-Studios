# Hole Controller

> **Status**: In Design
> **Author**: Design session + systems-designer
> **Last Updated**: 2026-03-31
> **Implements Pillar**: Every Eat Feels Good / Grow Don't Grind

## Overview

The Hole Controller owns the void's physical presence in the level: its `Area3D`
node, `SphereShape3D` collision shape, world position, and movement logic. It
receives movement input from the Input System, applies a speed cap, clamps to
level bounds, and translates the hole to its new position each frame. It also
owns the hole's collision radius — updating the `SphereShape3D` when the Growth
System signals a level-up. The Hole Controller is the authoritative source of
the hole's current position and size; all other systems that need this information
read it from here. It detects when a consumable enters the void (via `body_entered`
on the `Area3D`) and calls `eat()` on the object — the object is responsible for
awarding points, triggering effects, and removing itself. The Hole Controller does
not own growth points (Growth System) or rendering (visual shader effects are owned
by the Visual Effects System).

## Player Fantasy

The hole should feel like it has weight without feeling sluggish. It responds
instantly to input — there is no wind-up or ramp-up — but `max_speed` prevents
it from teleporting across the level on a fast flick. As the hole grows through
levels, the `SphereShape3D` radius expands and the player can feel the difference:
objects that were unreachable are now swallowed on contact, and the growing void
starts to dominate the screen. The hole's position is the player's cursor — every
moment of play, the player is aware of exactly where it is and what it can reach.
A hole that stutters, drifts, or clips into the floor breaks this awareness
instantly.

## Detailed Design

### Hole Node Structure

The hole is a single scene (`res://src/hole/hole.tscn`) instanced into the level
at `HoleSpawn` position at level start.

```
Hole (Node3D)                    ← root, owned by Hole Controller script
├── Area3D                       ← layer: hole (1), mask: consumable (2)
│   └── SphereShape3D            ← radius driven by Growth System
└── HoleMesh (MeshInstance3D)    ← visual representation; shader owned by Visual Effects System
```

**Key rules:**
- `Area3D` uses layer `hole` (1) and mask `consumable` (2) per Physics Configuration
- `SphereShape3D.radius` is the authoritative hole size — all size comparisons use this value
- The hole sits at a fixed Y position on the diorama floor plane — it never moves vertically
- `HoleMesh` scale is kept in sync with `SphereShape3D.radius` by Hole Controller each frame:
  `mesh.scale = Vector3.ONE * radius * 2`
- The hole has no `RigidBody3D` or `StaticBody3D` — it is not a physics body, only a detector

### Movement

Hole Controller receives `movement_delta: Vector2` from Input System per input
event and applies it to the hole's XZ position, capped by `max_speed`.

```gdscript
func _on_movement_delta(delta: Vector2) -> void:
    var capped = delta.limit_length(max_speed * get_physics_process_delta_time())
    var new_pos = global_position + Vector3(capped.x, 0, capped.y)
    global_position = clamp_to_bounds(new_pos)
```

**`max_speed`:** maximum hole movement in metres per second. Applied as a
per-event length cap scaled by the last physics delta. Prevents flick gestures
from teleporting the hole while keeping normal drag responsive.

**Y position:** set once at level start from `HoleSpawn.global_position.y` and
never changed. The hole glides along the floor plane.

**No momentum:** when drag stops, the hole stops instantly. No deceleration.

**Level reset:** on every new level start, Hole Controller resets all growth-dependent
state to level 1 values: `hole_level = 1`, `sphere_radius = base_radius`,
`effective_speed = max_speed * speed_multipliers[0]`. The hole also teleports
to `HoleSpawn` position. No state carries over between levels.

**No physics forces:** the Hole Controller never applies forces, impulses, or
attraction to nearby `RigidBody3D` objects. The hole is a passive detector —
objects fall through it because they are physically positioned over it (pushed
by cascade, or the hole moved under them), not because the hole pulls them.
Force application of any kind on consumables is forbidden in this system.

### Boundary Clamping

The hole is clamped to a rectangular bounds on the XZ plane so it cannot move
outside the playable area. Bounds are defined as a `Rect2` added to `LevelConfig`:

```gdscript
@export var play_bounds: Rect2  # XZ bounds of the playable area
                                 # position = min corner (x, z), size = width/depth
```

```gdscript
func clamp_to_bounds(pos: Vector3) -> Vector3:
    var r = sphere_radius  # current hole radius
    var bounds = level_config.play_bounds
    pos.x = clamp(pos.x, bounds.position.x + r, bounds.position.x + bounds.size.x - r)
    pos.z = clamp(pos.z, bounds.position.y + r, bounds.position.y + bounds.size.y - r)
    return pos
```

The clamp insets by `sphere_radius` so the hole edge never crosses the boundary
— the hole is always fully within the playable area even at max size.

**Bounds shrink with hole growth:** as `sphere_radius` increases, the effective
range for the hole's centre shrinks. At level 10, the hole has less room to move
than at level 1. Level designers must ensure `play_bounds` is large enough that
the hole retains meaningful movement range at all sizes.

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| Input System | Reads from | Subscribes to `movement_delta(delta: Vector2)` signal; applies per-event |
| Growth System | Reads from | Subscribes to `hole_level_up(new_level: int)`; updates `SphereShape3D.radius` and `HoleMesh.scale` |
| Level Configuration | Reads from | Reads `HoleSpawn` position at level start; reads `play_bounds` for boundary clamping |
| ConsumableObject | Calls into | On `body_entered`, calls `body.eat()` (duck-typed); the object handles points, effects, and `queue_free()` |
| Camera System | This is depended on by (indirect) | Camera System receives `hole_level_up` from Growth System — not from Hole Controller directly |
| HUD System | This is depended on by | Reads `sphere_radius` and `global_position` for any HUD elements displaying hole state |
| Level Flow System | Reads from | Enables/disables Hole Controller movement on level start/complete/fail |

**Readable properties:**
```gdscript
var sphere_radius: float   # current SphereShape3D radius — authoritative hole size
var hole_level: int        # current hole level (1–10)
```

## Formulas

### Movement Cap

```
effective_speed = max_speed * speed_multipliers[hole_level - 1]
capped_delta = movement_delta.limit_length(effective_speed * physics_delta)
new_position = current_position + Vector3(capped_delta.x, 0, capped_delta.y)
```

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `movement_delta` | Vector2 (m) | Unbounded | Raw delta from Input System |
| `max_speed` | float (m/s) | 1.0 – 20.0 | Base speed at level 1, default 5.0 ⚠️ Provisional |
| `speed_multipliers` | Array[float] (10 values) | 1.0 – 3.0 | Per-level speed scale; default `[1.0, 1.1, 1.2, 1.3, 1.45, 1.6, 1.75, 1.9, 2.1, 2.3]` ⚠️ Provisional. Stored in `HoleProgressionConfig` |
| `effective_speed` | float (m/s) | `max_speed` – `max_speed * max_multiplier` | Speed cap this level |
| `physics_delta` | float (s) | ~0.016 | Last physics frame time |
| `capped_delta` | Vector2 (m) | ≤ `effective_speed * physics_delta` | Delta after speed cap applied |

**Design intent:** a larger hole should feel faster and more dominant. Speed
multipliers let level designers tune this curve alongside growth thresholds and
camera pullback. Both `speed_multipliers` and `level_height_multipliers` live in
`HoleProgressionConfig` — the single resource for all per-level growth data,
owned by Growth System.

### Boundary Clamp

```
final_x = clamp(new_pos.x, bounds.x_min + r, bounds.x_max - r)
final_z = clamp(new_pos.z, bounds.z_min + r, bounds.z_max - r)
```

| Variable | Type | Description |
|----------|------|-------------|
| `r` | float (m) | `sphere_radius` — current hole radius |
| `bounds` | Rect2 | `LevelConfig.play_bounds` |

### Radius Update on Level-Up

```
sphere_radius = base_radius * radius_multipliers[new_level - 1]
SphereShape3D.radius = sphere_radius
HoleMesh.scale = Vector3.ONE * sphere_radius * 2
```

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `base_radius` | float (m) | 0.1 – 0.5 | Hole radius at level 1 ⚠️ Provisional. Stored in `HoleProgressionConfig` |
| `radius_multipliers` | Array[float] (10 values) | 1.0 – 4.0 | Per-level radius scale; index 0 = level 1 (1.0) ⚠️ Provisional. Stored in `HoleProgressionConfig` |
| `sphere_radius` | float (m) | `base_radius` – `base_radius * radius_multipliers[9]` | Current authoritative radius |

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|------------------|-----------|
| New level starts (including restart) | All growth-dependent state resets to level 1: `hole_level = 1`, `sphere_radius = base_radius`, `effective_speed = max_speed * speed_multipliers[0]`, position = `HoleSpawn`. No state from the previous level carries over | Each level is a fresh run — carrying over a large hole or high speed would break balance |
| `movement_delta` arrives when hole is disabled (level complete/fail) | Delta ignored — Hole Controller checks enabled state before applying movement | Level Flow System disables the controller; no position changes after level ends |
| Hole clamped to boundary on all sides (bounds too small for hole at max size) | Hole stays at centre of bounds; logs a warning | Degenerate level configuration — shouldn't happen if `play_bounds` is authored correctly |
| `hole_level_up` fires with `new_level` out of range (< 1 or > 10) | Clamped to [1, 10]; warning logged | Defensive guard against Growth System emitting unexpected values |
| `speed_multipliers` array has fewer than 10 entries | Clamps index to last available value; warning logged | Consistent with camera height multiplier guard |
| Hole moves under a resting object | No forces applied — object stays until it enters the `Area3D` sphere, at which point `body_entered` fires and Hole Controller calls `eat()` on the object | Objects don't react to hole proximity — only to entering the void |
| Player flicks so fast that `capped_delta` equals the full bounds width | Hole moves to boundary edge — clamped. No sub-step movement | Boundary clamp handles extreme cases cleanly |

## Dependencies

| System | Direction | Nature |
|--------|-----------|--------|
| Input System | This depends on | Hard — `movement_delta` signal drives all hole movement |
| Physics Configuration | This depends on | Hard — `Area3D` layer/mask assignments and `SphereShape3D` contract |
| Level Configuration | This depends on | Hard — `HoleSpawn` position and `play_bounds` required at level start |
| Growth System | This depends on | Hard — `hole_level_up` signal triggers radius, speed, and level updates; owns `HoleProgressionConfig` |
| ConsumableObject | Calls into | Hard — every consumable must implement `eat()`; Hole Controller calls it on `body_entered` |
| Camera System | This is depended on by (indirect) | Camera reads `HoleProgressionConfig` and listens to Growth System — not Hole Controller directly |
| HUD System | This is depended on by | Reads `sphere_radius` and `global_position` |
| Level Flow System | This depends on (soft) | Enables/disables controller; triggers level reset |

## Tuning Knobs

All per-level arrays live in `HoleProgressionConfig` (owned by Growth System).

| Parameter | Default | Safe Range | Too High | Too Low |
|-----------|---------|------------|----------|---------|
| `base_radius` | 0.2 m | 0.1 – 0.5 m | Level 1 hole already eats medium objects; no arc | Hole too small to eat anything; frustrating start |
| `radius_multipliers` | see `HoleProgressionConfig` | 1.0 – 4.0 per value; non-decreasing | Hole reaches huge size too quickly; growth feels cheap | 10 levels pass with barely noticeable size change |
| `max_speed` | 5.0 m/s | 1.0 – 20.0 m/s | Hole zips across level in one drag; no precision | Hole crawls; player can't reach objects in time |
| `speed_multipliers` | [1.0, 1.1, 1.2, 1.3, 1.45, 1.6, 1.75, 1.9, 2.1, 2.3] | Per-value: 1.0–3.0 | Level 10 hole uncontrollably fast | Speed never changes; growth feels one-dimensional |

## Acceptance Criteria

- [ ] Hole moves in response to drag input with no perceptible lag
- [ ] `max_speed` cap prevents any single input event from moving the hole more than `effective_speed * physics_delta` metres
- [ ] Hole never crosses `play_bounds` edge at any hole size — boundary clamp holds
- [ ] On `hole_level_up`, `SphereShape3D.radius`, `HoleMesh.scale`, and `effective_speed` update correctly
- [ ] On level start or restart, `hole_level`, `sphere_radius`, `effective_speed`, and position all reset to level 1 values from `HoleProgressionConfig`
- [ ] Hole applies zero forces to any `RigidBody3D` — confirmed via physics debug
- [ ] `body_entered` fires on the `Area3D` when a consumable enters the sphere and `eat()` is called on the body
- [ ] `sphere_radius` and `hole_level` are readable at any time by other systems

## Open Questions

| Question | Owner | Resolution |
|----------|-------|------------|
| What are the correct `base_radius` and `radius_multipliers` values? Depends on Object Configuration size category ranges and diorama scale — all provisional | Gameplay programmer | Resolve during first physics spike |
| Should `max_speed` default (5.0 m/s) feel correct at diorama scale? Depends on actual level dimensions and `play_bounds` size — untested | Gameplay programmer | Resolve during first playtest pass |
