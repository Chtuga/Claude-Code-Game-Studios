# ADR-0001: Core Gameplay Architecture for Hungry Void

## Status

Accepted

## Date

2026-04-01

## Decision Makers

Game designer, systems designer (design session)

## Context

### Problem Statement

Before writing any production code, the core architectural shape of the gameplay
loop must be decided: how do systems communicate, how is game data stored, how
are objects detected and removed, and how does level content get into the game?
These decisions constrain every downstream system and must be made explicitly
rather than discovered through implementation.

### Constraints

- **Engine**: Godot 4.6.2, GDScript, HTML5/WebGL export
- **Jolt physics**: `Area3D.body_entered` is the collision detection mechanism;
  manual distance math is not needed and not used
- **Solo development**: architecture must be simple enough to maintain without
  a team; no over-engineering
- **Scope**: MVP is 12 systems, all designed before any code is written; the
  architecture must support all 12 as defined in the GDDs

### Requirements

- Systems must be independently testable
- Gameplay tuning values must be changeable without code edits
- Adding new consumable object types must not require modifying existing systems
- Scene teardown must cleanly sever all system connections — no dangling state

---

## Decision

Four architectural decisions are made together as a coherent system:

### Decision 1: ConsumableObject Eat Contract

Eat detection and eat behavior are split across two owners:

- **Hole Controller** owns detection: on `Area3D.body_entered`, calls `body.eat()` (duck-typed)
- **Each `ConsumableObject` script** owns behavior: `eat()` emits `eaten(object_id, points)` then calls `queue_free()`

There is no standalone Eating System.

### Decision 2: Signal-Driven System Communication

Systems do not call each other directly. All cross-system communication flows
through Godot signals. Each system emits signals for its outputs and subscribes
to signals for its inputs. The Level Flow System is the only coordinator —
it calls `start()` on systems at level load and connects the win/fail signal
paths. No other system has a reference to another system's node.

### Decision 3: HoleProgressionConfig as Preloaded .tres Resource

All tuning data (point thresholds, radius multipliers, speed multipliers,
star thresholds) lives in `.tres` Godot Resource files. The primary resource
is `HoleProgressionConfig`, a `class_name Resource` with `@export` arrays.
Systems load it by path at `_ready()` — no Autoload singleton, no dependency
injection. Level-specific data lives in `LevelConfig.tres` referenced by
the level scene root.

### Decision 4: No Runtime Object Spawning

All consumable objects are pre-placed in level `.tscn` files by level designers.
There is no `ObjectSpawner` system. This eliminates a class of runtime GC hitches,
guarantees deterministic level layout, and keeps level authoring in the Godot
editor where it belongs.

---

### Architecture

```
Level Scene (.tscn)
│
├── LevelConfig.tres ←── star_thresholds, play_bounds, HoleSpawn position
│
├── HoleController (Area3D)
│   ├── SphereShape3D              ← radius driven by Growth System via hole_level_up
│   └── body_entered ──────────────► body.eat() [duck-typed on ConsumableObject]
│
├── Objects (Node3D)
│   ├── Avocado (ConsumableObject / RigidBody3D)  [group: "consumables", "goal_objects"]
│   ├── Fridge (ConsumableObject / RigidBody3D)   [group: "consumables"]
│   └── ...
│       └── eat() ──► emit eaten(object_id, points) ──► queue_free()
│
├── GrowthSystem
│   ├── subscribes: ConsumableObject.eaten (all "consumables" group nodes)
│   └── emits: hole_level_up(new_level: int)
│
├── TargetSystem
│   ├── subscribes: ConsumableObject.eaten (all "goal_objects" group nodes)
│   └── emits: all_goals_complete
│
├── TimerSystem
│   └── emits: time_up, time_changed(remaining, is_urgent)
│
└── LevelFlowSystem
    ├── calls start() on: TimerSystem, GrowthSystem, TargetSystem, HoleController
    ├── subscribes: all_goals_complete → WIN path
    ├── subscribes: time_up → CONTINUE_OFFER path
    └── emits: level_complete(stars: int), level_failed
```

### Key Interfaces

```gdscript
# ConsumableObject base contract
class_name ConsumableObject
extends RigidBody3D

signal eaten(object_id: String, points: int)

@export var object_id: String
@export var points: int

func eat() -> void:
    eaten.emit(object_id, points)
    queue_free()

# HoleProgressionConfig data resource
class_name HoleProgressionConfig
extends Resource

@export var base_radius: float
@export var radius_multipliers: Array[float]        # 10 values
@export var point_thresholds: Array[int]            # 9 values (levels 1→2 through 9→10)
@export var speed_multipliers: Array[float]         # 10 values
@export var level_height_multipliers: Array[float]  # 10 values

# LevelConfig data resource
class_name LevelConfig
extends Resource

@export var star_thresholds: Array[float]   # 3 values [1-star, 2-star, 3-star] seconds remaining
@export var play_bounds: Rect2              # XZ playable area
@export var progression_config: HoleProgressionConfig
```

### Implementation Guidelines

- The `"consumables"` Godot group must contain every consumable `RigidBody3D` in the level — Growth System connects to `eaten` on all nodes in this group at level load.
- The `"goal_objects"` group is a subset of `"consumables"` — Target System connects to `eaten` only on nodes in this group.
- `HoleController.body_entered` must call `body.eat()` only if `body` has an `eat` method (duck-type check via `body.has_method("eat")`). Non-consumable colliders on wrong layers should never reach this handler — the check is a safety net, not the gate.
- Each system subscribes to signals in `_ready()` after `start()` is called by Level Flow System. Systems must not process signals before `start()`.
- `.tres` resources are loaded with `preload()` where the path is static (HoleProgressionConfig), and `load()` where the path is dynamic (per-level LevelConfig from the scene's `@export`).

---

## Alternatives Considered

### Alternative 1: Standalone Eating System

- **Description**: A dedicated `EatingSystem` node owns `body_entered` detection and all eat logic — it calls Growth System, Target System, and VFX System directly on each eat.
- **Pros**: Single point of control for eat events; easy to debug.
- **Cons**: Creates a god object; any new object type requires modifying EatingSystem; tight coupling makes individual systems untestable.
- **Rejection Reason**: The ConsumableObject pattern achieves the same single point of control via the `eaten` signal, without coupling systems together. New object types only require a new subclass.

### Alternative 2: Autoload Singletons for System Communication

- **Description**: Core systems (GrowthSystem, TargetSystem, TimerSystem) are Autoloads accessible globally via `GrowthSystem.instance`.
- **Pros**: Easy access from any script; no dependency wiring needed.
- **Cons**: Singletons persist across scene loads; resetting state on restart is error-prone; systems cannot be tested in isolation; coupling is invisible and hard to trace.
- **Rejection Reason**: Signal-driven communication with scene-local system nodes achieves the same accessibility without shared global state. Level teardown automatically disconnects all signals.

### Alternative 3: Runtime Object Spawner

- **Description**: An ObjectSpawner system instantiates consumable objects from the catalogue at runtime based on level data.
- **Pros**: Levels defined as pure data (no .tscn per level); easier to generate levels procedurally.
- **Cons**: Runtime `instantiate()` causes GC hitches; spawning logic is additional complexity; Godot's scene editor is a better level authoring tool than JSON/data; procedural generation is not in scope.
- **Rejection Reason**: Pre-placed objects in .tscn files eliminate GC hitches, leverage the editor, and match the diorama visual design intent. Object Spawner dropped from MVP.

### Alternative 4: Central Event Bus Autoload

- **Description**: A single `EventBus` Autoload exposes all signals; systems subscribe and emit through it.
- **Pros**: Decoupled; all signals in one place; easy to add logging.
- **Cons**: Global state; signals persist across scene loads requiring manual disconnection; indirection makes signal origin harder to trace; overkill for 12 systems.
- **Rejection Reason**: Direct node-to-node signal connections within a scene scope are simpler, automatically torn down on scene unload, and sufficient for the system count.

---

## Consequences

### Positive

- Systems are independently testable — each can be instantiated alone with mock signals
- New consumable types (bombs, boosters) are additive — subclass `ConsumableObject`, override `eat()`, no existing system changes
- Level teardown automatically severs all signal connections — no explicit cleanup code needed
- Tuning values are editable in the Godot Inspector without touching code
- Level content is authored visually in the Godot editor — no separate data pipeline

### Negative

- Duck-typed `body.eat()` call loses static type checking — a missing `eat()` method is a runtime error, not a compile-time error
- Systems must be found by node path or `@export` reference — no global access; Level Flow System must hold references to all systems
- Pre-placed level objects mean each level is a separate `.tscn` file — larger project size than a data-driven spawner approach

### Neutral

- Signal-driven architecture means execution order depends on signal subscription order — deterministic but requires awareness when debugging multi-system reactions to a single eat event
- `.tres` resource files must be version-controlled alongside code — standard Git workflow handles this correctly

---

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Duck-typed `eat()` call on non-ConsumableObject body | Low | Medium | `has_method("eat")` guard in Hole Controller; enforce collision layer 2 for consumables only |
| Signal connections not cleaned up on scene reload | Low | High | Scene-local nodes; all subscriptions are within the level scene scope; teardown is automatic |
| `.tres` resource data out of sync with GDD tuning tables | Medium | Medium | Tuning knob tables in GDDs are the source of truth; `.tres` values are set from these during implementation |
| HoleProgressionConfig preload path changes during refactor | Low | Low | Path is referenced in one place per system; update is a single-file find/replace |

---

## Performance Implications

| Metric | Concern | Mitigation |
|--------|---------|------------|
| Signal overhead on rapid eats | `eaten` signal fires on every eat; at 10+ eats/second, multiple subscribers process each | Subscribers are lightweight (dict lookup, counter decrement) — acceptable overhead |
| Pre-placed objects memory | All level objects loaded at scene load, not streamed | Diorama scope is small (≤150 objects); acceptable for WebGL target |

---

## Validation Criteria

- [ ] `ConsumableObject.eat()` emits `eaten(object_id, points)` and calls `queue_free()` — verified by GUT test
- [ ] Growth System accumulates points and emits `hole_level_up` without a direct reference to Hole Controller
- [ ] Target System tracks goal progress without a direct reference to Growth System
- [ ] Scene reload produces zero stale signal connections — verified by checking signal connection count before and after reload
- [ ] `HoleProgressionConfig.tres` values editable in Inspector without code change — verified manually

---

## Related

- `design/gdd/hole-controller.md` — Hole Controller eat detection spec
- `design/gdd/object-configuration.md` — ConsumableObject contract definition
- `design/gdd/growth-system.md` — HoleProgressionConfig structure and level-up loop
- `design/gdd/level-configuration.md` — Scene hierarchy, groups, pre-placed objects
- `design/gdd/level-flow-system.md` — start() orchestration and signal-driven win/fail paths
- `design/gdd/systems-index.md` — Full system dependency map
