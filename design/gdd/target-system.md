# Target System

> **Status**: In Design
> **Author**: Design session + systems-designer
> **Last Updated**: 2026-04-01
> **Implements Pillar**: Goals Give Permission to Explore

## Overview

The Target System tracks progress toward a level's goal conditions. At level start
it reads `LevelConfig.goals` and queries the `"goal_objects"` group to build a
counter per goal type (`object_id → remaining_count`). It then subscribes to
`ConsumableObject.eaten` on every goal object. Each time a goal object is eaten,
its counter decrements. When all counters reach zero, the Target System emits
`all_goals_complete` — the signal Level Flow System listens to in order to trigger
the win condition. The Target System owns no object removal, no physics, and no
point logic — it is a pure progress tracker that translates eat events into
win-condition state.

## Player Fantasy

The player never thinks about the Target System — they think about the glowing
fridge in the corner they haven't reached yet. What the system delivers is the
clarity of a hunt: you always know what you need, you can feel the list getting
shorter, and when the last target disappears there's a moment of "I did it" before
the win screen arrives. Done right, this system is invisible. Done wrong — a counter
that doesn't update, a goal object that looks identical to filler — and the whole
pillar of "goals give permission to explore" collapses.

## Detailed Design

### Core Rules

1. At level load, the Target System reads `LevelConfig.goals` to get the list of
   `{ object_id, required_count }` pairs
2. It queries the `"goal_objects"` group and builds a counter map:
   `goal_counters: Dictionary[String, int]` — `object_id → remaining_count`,
   initialised from `required_count`
3. It subscribes to `ConsumableObject.eaten` **only on nodes in the
   `"goal_objects"` group** — filler objects are not connected
4. On `eaten(object_id, points)`: look up `object_id` in `goal_counters`; if
   found, decrement by 1
5. After each decrement, check if all values in `goal_counters` are zero — if
   so, emit `all_goals_complete`
6. `start()` is called by Level Flow System when gameplay begins — connects
   signals to goal objects and initialises counters

### States and Transitions

The Target System has no state machine. It exists only within the level scene and
is destroyed when the scene unloads. Before `start()` is called no signals are
connected and no counters exist. After `all_goals_complete` is emitted the system
remains alive but receives no further meaningful signals — all goal objects have
been freed.

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| Level Configuration | Reads from | Reads `LevelConfig.goals` at `start()` to initialise `goal_counters` |
| Object Configuration | Reads from (indirect) | `object_id` values in goals must exist in the catalogue with `can_be_target: true` — validated at level load by Level Configuration, trusted at runtime |
| ConsumableObject | Reads from | Connects to `eaten(object_id: String, points: int)` on nodes in `"goal_objects"` group only |
| Level Flow System | Emits to | Emits `all_goals_complete` when all counters reach zero — Level Flow System triggers win sequence |
| HUD System | This is depended on by | Reads `goal_counters: Dictionary[String, int]` as a readable property to display per-goal progress |

**Readable properties:**
```gdscript
var goal_counters: Dictionary   # object_id → remaining_count; HUD reads this directly
```

## Formulas

### Counter Initialisation

```
for goal in LevelConfig.goals:
    goal_counters[goal.object_id] = goal.required_count
```

### Decrement on Eat

```
goal_counters[object_id] -= 1
```

### Win Condition Check

```
all_complete = goal_counters.values().all(func(v): return v == 0)
if all_complete:
    emit all_goals_complete
```

| Variable | Type | Source | Description |
|----------|------|--------|-------------|
| `goal_counters` | `Dictionary[String, int]` | Runtime | `object_id → remaining_count`; initialised from `LevelConfig.goals` |
| `all_complete` | bool | Derived | True when every counter has reached zero |

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|------------------|-----------|
| A goal object is eaten before `start()` is called | Not possible — Hole Controller is not active until Level Flow System calls `start()` on all systems; signal connections don't exist before that | Level Flow System must activate systems before enabling the hole |
| `eaten` fires with an `object_id` not in `goal_counters` | Silently ignored — goal objects only connect to nodes in `"goal_objects"` group; a mismatch here is a level authoring error already caught at load | Runtime trust: if it's in `"goal_objects"` its `object_id` is valid |
| Multiple goal types; one completes before others | `all_goals_complete` is not emitted until all counters are zero — partial completion has no effect on win condition | Win requires all goals, not any goal |
| Single-object goal (required_count = 1) | Eating the one instance immediately satisfies that goal; win triggers if it was the last outstanding goal | Valid configuration — one-shot goals are fine |
| Two goal objects with the same `object_id` both eaten in the same frame | Each `eaten` signal fires independently and decrements once; order does not matter | Signal queue processes sequentially |
| Level has only one goal type | `all_goals_complete` fires as soon as that type's counter hits zero | No special case needed |

## Dependencies

| System | Direction | Nature |
|--------|-----------|--------|
| Level Configuration | This depends on | Hard — `LevelConfig.goals` is required to initialise counters; system cannot function without it |
| Object Configuration | This depends on (indirect) | Hard — `object_id` values must be valid catalogue entries with `can_be_target: true`; validated at load by Level Configuration, trusted at runtime |
| ConsumableObject | This depends on | Hard — `eaten` signal on goal objects is the only input; no signal = no counter updates |
| Level Flow System | This is depended on by | Hard — `all_goals_complete` triggers the win sequence; must call `start()` to activate |
| HUD System | This is depended on by | Soft — reads `goal_counters` for display; game functions without HUD |

## Tuning Knobs

The Target System has no tuning knobs of its own. All goal authoring parameters
(`required_count`, goal object types, filler object ratios) are owned by Level
Configuration. See `LevelConfig.goals` tuning notes in `level-configuration.md`.

## Acceptance Criteria

- [ ] `start()` correctly builds `goal_counters` from `LevelConfig.goals` — each
      `object_id` maps to its `required_count`
- [ ] `ConsumableObject.eaten` is connected only to nodes in the `"goal_objects"`
      group; filler object eats produce no counter changes
- [ ] Eating a goal object decrements its counter by exactly 1
- [ ] `all_goals_complete` is emitted only when every counter is zero, not when
      any single counter reaches zero
- [ ] `goal_counters` is readable at any time by HUD System and reflects the
      current remaining count
- [ ] A level with multiple goal types completes only after all types reach zero
- [ ] `all_goals_complete` is emitted exactly once per level — not re-emitted if
      more signals somehow arrive after all counters are zero

## Open Questions

| Question | Owner | Resolution |
|----------|-------|------------|
| Should `all_goals_complete` carry any payload (e.g. time remaining at completion)? Or does Level Flow System read `timer.remaining` directly? | Systems designer | Resolve when Level Flow System GDD is designed |
| Should the HUD show individual goal object icons + counters, or a single "X/Y targets" aggregate? Affects what `goal_counters` needs to expose | UX designer | Resolve when HUD System GDD is designed |
