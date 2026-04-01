# Level Configuration

> **Status**: In Design
> **Author**: Design session + systems-designer
> **Last Updated**: 2026-03-31
> **Implements Pillar**: Goals Give Permission / Web-Native Delight

## Overview

Level Configuration is the authoring contract for every level in Hungry Void. A
level consists of two files: a Godot scene (`.tscn`) that contains the diorama's
visual layout — static environment, pre-placed consumable `RigidBody3D` objects,
hole spawn point, and camera anchor — and a `LevelConfig` Resource (`.tres`) that
carries the non-visual metadata: level name, world ID, timer duration, star
thresholds, and the goal definition. Goals are type-based collection targets: each
goal entry specifies an object type (by `id` from Object Configuration) and a
required count. The scene must contain exactly that many instances of each goal
type; all remaining objects are filler. A level is complete when every goal counter
is satisfied. Level Configuration is the single source of truth for what a level
asks the player to do and how long they have to do it.

## Player Fantasy

The player never reads a config file — they read the room. A kitchen diorama
covered in fruit and appliances wordlessly communicates what the level is about.
The goals ("eat 5 avocados") give permission to move with purpose: instead of
vacuum-cleaning every object, the player scans for their targets, plots a growth
path through the filler, and feels the satisfaction of a plan coming together.
Level Configuration makes this possible by ensuring every level is a coherent
authored space — the right objects, in the right places, with the right amount
of time. A badly configured level (too few goal objects to find, too little time
to grow, goal objects gated behind a size the player can't reach) shatters the
fantasy instantly. Configuration is invisible when right and catastrophic when
wrong.

## Detailed Design

### Level File Structure

Each level is represented by two files:

| File | Type | Purpose |
|------|------|---------|
| `res://assets/levels/[world_id]/level_[N].tscn` | Godot Scene | Visual diorama layout — static environment, consumable objects, spawn points |
| `res://assets/levels/[world_id]/level_[N].tres` | Godot Resource | Non-visual metadata — name, timer, star thresholds, goal definition |

The `.tscn` references its `.tres` via an exported variable on the root node:
`@export var config: LevelConfig`. The Level Flow System loads the scene; the
scene self-contains its config.

**World structure:**
```
assets/levels/
├── world_01/
│   ├── level_01.tscn + level_01.tres
│   ├── level_02.tscn + level_02.tres
│   ├── level_03.tscn + level_03.tres
│   ├── level_04.tscn + level_04.tres
│   └── level_05.tscn + level_05.tres
└── world_02/
    ├── level_01.tscn … level_05.tscn
    └── level_01.tres … level_05.tres
```

**Central level registry:** a single `res://assets/levels/levels_registry.tres`
lists all 10 levels in order (world ID + level number + scene path). The Level
Flow System and World/Level Unlock System use this to navigate between levels
without hardcoding paths.

### Level Goal Definition

Goals are defined in the `LevelConfig` Resource as an array of `LevelGoal` entries:

```gdscript
class_name LevelGoal
extends Resource

@export var object_id: String      # matches Object Configuration catalogue id
@export var required_count: int    # exactly this many of this type in the scene
```

```gdscript
class_name LevelConfig
extends Resource

@export var level_name: String
@export var world_id: String               # e.g. "world_01"
@export var level_number: int              # 1–5
@export var timer_duration: float          # seconds
@export var star_thresholds: Array[float]  # [1-star secs, 2-star secs, 3-star secs] — time remaining at goal completion
@export var play_bounds: Rect2             # XZ playable area: position = min corner (x,z), size = width/depth
@export var goals: Array[LevelGoal]
```

**Goal authoring rules:**
- `goals` must have at least 1 entry; no upper limit enforced by the system
  (though more than 3 is discouraged for readability)
- Each `object_id` must exist in the Object Configuration catalogue and have
  `can_be_target: true`
- The scene must contain **exactly** `required_count` instances of each goal
  object type — validated at level load
- `star_thresholds` must be an array of exactly 3 ascending floats representing
  **seconds remaining** at goal completion: `[s1, s2, s3]` where `s1 < s2 < s3`
  - `time_remaining >= s3` → 3 stars (fastest)
  - `time_remaining >= s2` → 2 stars
  - `time_remaining >= s1` → 1 star
  - Goals complete with `time_remaining < s1` → 1 star (completion always awards at least 1)
  - Timer runs out before goals complete → level failed, 0 stars

### Scene Hierarchy

Every level scene must follow this node structure. Deviating from it will break
systems that navigate by node path or group.

```
Level (Node3D)                          ← root, holds @export var config: LevelConfig
├── Environment (Node3D)                ← StaticBody3D floor, walls, surfaces, decorative geometry
├── Boundary (Area3D)                   ← layer 4 per Physics Configuration; triggers out-of-bounds
├── Objects (Node3D)                    ← all consumable RigidBody3D objects pre-placed by designer
│   ├── [object nodes...]               ← named by type, e.g. "Avocado", "Fridge_01"
├── HoleSpawn (Marker3D)                ← world position where the hole starts each level
└── CameraAnchor (Node3D)              ← position + rotation reference for Camera System
```

**Node naming rules:**
- Goal objects must be added to the Godot group `"goal_objects"` in the editor
  — Target System uses this to find and track them
- Each goal object node must carry a metadata entry `object_id` matching its
  Object Configuration `id` (e.g. `"avocado"`) — Target System reads this to
  match eaten objects to goals
- ALL consumable `RigidBody3D` objects (both filler and goal) must be added to
  the Godot group `"consumables"` in the editor — Growth System uses this group
  to connect to each object's `eaten` signal at level load. This group is distinct
  from `"goal_objects"`: every consumable is in `"consumables"`, but only goal
  objects are also in `"goal_objects"`
- Filler objects do not need `"goal_objects"` membership or `object_id` metadata;
  `ConsumableObject.eat()` awards points via Growth System regardless
- `Objects` node must be a plain `Node3D` — no physics body — so scene hierarchy
  stays clean and the node can be used as a logical grouping without affecting physics

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| Level Flow System | Reads from this | Loads the level scene by path from `levels_registry.tres`; reads `LevelConfig` from the scene root to initialise timer, goals, and star thresholds |
| Target System | Reads from this | At level start, queries `"goal_objects"` group to find all goal object nodes; reads `object_id` metadata per node to build goal counters from `LevelConfig.goals` |
| Timer System | Reads from this | Reads `timer_duration` from `LevelConfig` to set the countdown at level start |
| Camera System | Reads from this | Reads `CameraAnchor` node position/rotation to set initial camera framing |
| ConsumableObject | No direct dependency | Each object's `eat()` handles points and removal independently — does not read `LevelConfig` directly |
| Star Rating System | Reads from this | Reads `star_thresholds` (seconds remaining) from `LevelConfig` at goal completion to compute star count |
| World/Level Unlock System | Reads from this | Reads `levels_registry.tres` to determine level order and unlock progression |

## Formulas

Level Configuration has no runtime formulas. The following validation constraints
must hold at level load time:

**Goal object count validation:**
```
For each goal in LevelConfig.goals:
    scene_count(goal.object_id) == goal.required_count
```
Where `scene_count(id)` = number of nodes in group `"goal_objects"` with
metadata `object_id == id`.

**Star threshold ordering** (seconds remaining at goal completion):
```
star_thresholds[0] < star_thresholds[1] < star_thresholds[2]
```
All three values must also be less than `timer_duration` — a threshold at or
above the starting time is unreachable.

**Timer sanity:**
```
timer_duration > 0
```

**Goal object reachability** *(designer responsibility, not runtime-validated):*
```
For each goal in LevelConfig.goals:
    object_max_size(goal.object_id) <= hole_radius_at_level_10
```
The game cannot validate this automatically — it is a level design obligation
to ensure all goal objects are within the hole's maximum reachable size.

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|------------------|-----------|
| Scene contains fewer goal objects than `required_count` | Level fails to load; error logged with offending `object_id` and counts | A broken goal is uncompletable — better to catch at load than fail silently mid-play |
| Scene contains more goal objects than `required_count` | Level fails to load; error logged | Exact count is the authoring contract — extras indicate a configuration mistake |
| `goals` array is empty | Level fails to load | A level with no goals has no win condition; it is an incomplete level |
| Goal references an `object_id` not in Object Configuration catalogue | Level fails to load; error logged with missing `id` | Prevents silent type mismatches between level data and catalogue |
| Goal references an `object_id` with `can_be_target: false` | Level fails to load | Enforces the catalogue contract; catches accidental goal assignment to non-targetable types |
| `star_thresholds` has fewer or more than 3 entries | Level fails to load | Star Rating System always expects exactly 3 thresholds |
| `star_thresholds` values are not strictly ascending | Level fails to load; error logged | Non-ascending thresholds produce impossible or nonsensical star ratings |
| Any `star_thresholds` value >= `timer_duration` | Level fails to load; error logged | A threshold at or above starting time is unreachable — level would be impossible to 3-star |
| Player eats a goal object before the Target System has initialised | Target System must initialise before the hole is controllable — enforced by Level Flow System scene load order | Prevents missed eat events at level start |
| `levels_registry.tres` is missing or malformed | Game falls back to main menu with an error; no crash | Registry is required for navigation — missing it is a build error, not a runtime fallback |

## Dependencies

| System | Direction | Nature |
|--------|-----------|--------|
| Object Configuration | This depends on | Hard — `LevelGoal.object_id` must exist in the catalogue; `can_be_target` flag must be `true` for all goal objects |
| Level Flow System | This is depended on by | Hard — loads level scenes via `levels_registry.tres`; reads `LevelConfig` to initialise the session |
| Target System | This is depended on by | Hard — reads `"goal_objects"` group and `object_id` metadata to build goal counters |
| Timer System | This is depended on by | Hard — reads `timer_duration` from `LevelConfig` at level start |
| Camera System | This is depended on by | Soft — reads `CameraAnchor` for initial framing; Camera System has fallback if anchor is missing |
| Star Rating System | This is depended on by | Hard — reads `star_thresholds` (seconds remaining) at goal completion |
| World/Level Unlock System | This is depended on by | Hard — reads `levels_registry.tres` for level order and unlock state |
| Physics Configuration | This depends on (soft) | `Boundary` Area3D must use layer 4 per Physics Configuration's layer assignment |

## Tuning Knobs

| Parameter | Default Value | Safe Range | Too High | Too Low |
|-----------|--------------|------------|----------|---------|
| `timer_duration` | 90s | 60–180s | Level feels trivial; no time pressure | Goal objects physically unreachable before time runs out |
| `goals[].required_count` | 3–8 per goal type | 1–15 | Level requires eating nearly everything; feels like cleanup, not selection | Single-object goal feels arbitrary; no hunt required |
| `star_thresholds[0]` (1-star) | ~10s remaining | 5–20s | 1-star nearly impossible; player must complete with almost no time left | 1-star awarded even for slow, leisurely completion |
| `star_thresholds[1]` (2-star) | ~30s remaining | 15–45s | Requires very fast play; 2-star feels like 3-star effort | 2-star awarded without meaningful urgency |
| `star_thresholds[2]` (3-star) | ~50s remaining | 30–70s | Requires near-perfect routing; frustrating for casual audience | 3-star trivially achieved on first attempt |
| Filler object count | ~2–3× goal object count | 1–5× | Too many filler objects dilute goal visibility | Too few filler objects leave player unable to grow to goal size |

**Note:** `timer_duration` and `required_count` interact — increasing required count
without increasing timer creates a hidden difficulty spike. Tune them together.

## Acceptance Criteria

- [ ] A level with correct goal counts loads without errors; a level with mismatched counts fails to load with a descriptive error message
- [ ] Eating all `required_count` instances of a goal object type triggers that goal as satisfied; eating filler objects does not affect goal counters
- [ ] A level with multiple goals completes only when all goal counters are simultaneously satisfied
- [ ] When all goals are satisfied, the time remaining is captured and passed to Star Rating System — `time_remaining >= star_thresholds[2]` awards 3 stars, `>= star_thresholds[1]` awards 2, `>= star_thresholds[0]` awards 1, otherwise still 1 star (completion guarantee)
- [ ] Timer running out before all goals complete = level failed, 0 stars
- [ ] `star_thresholds` with non-ascending values or any value >= `timer_duration` are rejected at load time
- [ ] `timer_duration` is correctly passed to Timer System at level start
- [ ] `CameraAnchor` position is correctly read by Camera System at level start
- [ ] Goal objects in group `"goal_objects"` with correct `object_id` metadata are found by Target System at level start
- [ ] `levels_registry.tres` correctly lists all 10 levels; Level Flow System navigates in order without hardcoded paths
- [ ] A goal referencing an `object_id` with `can_be_target: false` is rejected at load time

## Open Questions

| Question | Owner | Resolution |
|----------|-------|------------|
| What are the correct default `star_thresholds` values for each level? 10/30/50s remaining are placeholders — requires playtesting to find thresholds that feel achievable but rewarding | Level designer | Resolve during first playtest pass |
| Should there be a difficulty ramp within a world's 5 levels (e.g. tighter star thresholds, more goals in later levels)? | Level designer | Resolve when first world levels are authored |
| Does the `levels_registry.tres` need to store world metadata (world name, unlock requirement, thumbnail) or just level paths? World/Level Unlock System GDD (not yet designed) may require richer registry entries | Systems designer | Resolve when World/Level Unlock System GDD is designed |
