# Timer System

> **Status**: In Design
> **Author**: Design session + systems-designer
> **Last Updated**: 2026-03-31
> **Implements Pillar**: Goals Give Permission

## Overview

The Timer System counts down from the level's configured duration and broadcasts
the remaining time to other systems. It starts automatically when a level begins,
runs continuously during active play, and pauses only when the player explicitly
triggers the pause state. When the countdown reaches zero and level goals are not
yet satisfied, the Timer System emits a `time_up` signal that causes the Level
Flow System to fail the level. When level goals are satisfied before time runs
out, the Timer System's current remaining time is read by the Star Rating System
to compute the star count. The Timer System owns no win/fail logic itself — it
is a clock that other systems listen to.

## Player Fantasy

The timer is pressure made visible. It doesn't punish the player for existing —
it creates urgency that makes every eat feel consequential. A player with 60
seconds left plays differently than one with 10. The countdown creates the arc
of a level: comfortable exploration early, focused hunting mid-game, desperate
scrambling at the end. Done right, the timer tightens the experience without
making it feel unfair — the player always feels they had enough time if they'd
been smarter. Done wrong — too short to grow large enough, or ticking down while
a loading screen plays — and it feels like the game cheated.

## Detailed Design

### Timer Lifecycle

| State | Trigger | Description |
|-------|---------|-------------|
| `idle` | Default | Timer holds `timer_duration` value, not counting. Waiting for level start. |
| `running` | Level Flow System emits `level_started` | Countdown begins. Emits `time_changed(remaining: float)` every frame. |
| `paused` | Player presses pause button | Countdown frozen. Emits `timer_paused`. |
| `running` | Player resumes | Countdown resumes from frozen value. Emits `timer_resumed`. |
| `finished` | `remaining` reaches 0.0 | Emits `time_up`. Transitions to `idle`. Level Flow System handles fail logic. |

**Initialisation:** at level start, Timer System reads `LevelConfig.timer_duration`
and sets `remaining = timer_duration`. The countdown does not begin until
`level_started` is received — the timer never ticks during scene loading.

**Readable property:**
```gdscript
var remaining: float  # current time left in seconds; readable by any system at any time
```

**Signals emitted:**
```gdscript
signal time_changed(remaining: float, is_urgent: bool)  # every _process frame while running
signal time_up                                           # when remaining hits 0.0
signal timer_paused
signal timer_resumed
```

### Pause Behaviour

Pause is triggered by a player-facing pause button (owned by HUD System). The
HUD emits a `pause_requested` signal; Timer System listens and freezes `remaining`.
On resume, `remaining` continues from its frozen value — no time is lost or added
during the pause.

**Godot engine pause vs. Timer System pause:** this system uses its own pause
state, not Godot's built-in `get_tree().paused`. Reason: Godot's scene tree pause
freezes all nodes including physics, which could leave the cascade collapse
mid-animation in a jarring state. Timer System pause freezes only the countdown
— physics and rendering continue so the scene settles naturally while paused.

**Pause is not available during:**
- Level complete sequence (goals already satisfied — timer is irrelevant)
- Level failed sequence (time already up)
- Scene loading (timer is in `idle` state)

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| Level Configuration | Reads from | Reads `LevelConfig.timer_duration` at level start to initialise `remaining` |
| Level Flow System | Bidirectional | Receives `level_started` to begin countdown; emits `time_up` which Level Flow System uses to trigger level fail |
| Star Rating System | Provides to | Star Rating System reads `remaining` property at the moment goals are satisfied to compute star count |
| HUD System | Provides to | Receives `time_changed(remaining, is_urgent)` every frame to update the countdown display and urgency state; receives `timer_paused` / `timer_resumed` to update pause UI state |
| Input System | Indirect | Input System is disabled on pause — but this is coordinated by Level Flow System, not Timer System directly |

## Formulas

### Countdown

```
remaining -= delta
remaining = max(remaining, 0.0)
```

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `remaining` | float (s) | 0.0 – `timer_duration` | Current time left; clamped to 0.0 to prevent negative values |
| `delta` | float (s) | ~0.016 at 60 fps | Godot's `_process(delta)` frame time |

`time_up` is emitted on the frame where `remaining` first reaches 0.0. The clamp
ensures `remaining` never goes negative even on a slow frame where
`delta > remaining`.

### Urgency Threshold

HUD System uses `remaining` to trigger a visual urgency state (e.g. red timer,
pulsing). The threshold is:

```
is_urgent = remaining <= urgency_threshold
```

| Variable | Default | Range | Description |
|----------|---------|-------|-------------|
| `urgency_threshold` | 15.0 s | 5.0 – 30.0 s | When remaining drops below this, HUD enters urgency state |

The urgency state is computed by Timer System and passed via the `is_urgent`
parameter of `time_changed` — HUD System does not recompute or redefine the
threshold independently.

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|------------------|-----------|
| `delta` larger than `remaining` on a slow frame | `remaining = max(remaining - delta, 0.0)` — clamped to 0.0, `time_up` emitted once | Prevents negative remaining; slow frames don't skip the fail state |
| Goals satisfied on the exact frame `remaining` hits 0.0 | Goals-complete wins over time-up — Level Flow System receives both signals on the same frame and resolves in favour of level complete | Player completed the goal; failing them on a technicality is unfair |
| Pause requested while timer is already in `idle` or `finished` state | Pause request ignored silently — no state change | Cannot pause a timer that isn't running |
| Level restarted without scene reload | Timer System resets `remaining` to `timer_duration` and returns to `idle` on `level_started` signal — no stale state | Restart must be a clean slate |
| `timer_duration` is 0 or negative in `LevelConfig` | Level fails to load per Level Configuration validation — Timer System never receives an invalid value | Input validation is Level Configuration's responsibility |
| Browser tab loses focus mid-level | `delta` continues accumulating via Godot's `_process` — timer keeps running. No auto-pause on tab switch for MVP | Web focus handling is a post-MVP concern; auto-pause could be added later |

## Dependencies

| System | Direction | Nature |
|--------|-----------|--------|
| Level Configuration | This depends on | Hard — reads `timer_duration` to initialise; Level Configuration must be loaded before timer starts |
| Level Flow System | Bidirectional | Hard — receives `level_started` to begin; emits `time_up` for Level Flow System to handle fail |
| Star Rating System | This is depended on by | Hard — reads `remaining` at goal completion for star calculation |
| HUD System | This is depended on by | Hard — receives `time_changed` every frame for display; receives urgency threshold for visual state |

## Tuning Knobs

| Parameter | Default | Safe Range | Too High | Too Low |
|-----------|---------|------------|----------|---------|
| `urgency_threshold` | 15.0 s | 5.0 – 30.0 s | Urgency triggers too early; most of the level feels stressed | Player has no warning before sudden fail |

## Acceptance Criteria

- [ ] Timer starts at `LevelConfig.timer_duration` and counts down to 0.0
- [ ] `time_changed(remaining)` is emitted every `_process` frame while running
- [ ] `time_up` is emitted exactly once when `remaining` reaches 0.0
- [ ] Timer does not tick during scene loading — countdown begins only on `level_started`
- [ ] Pause freezes `remaining`; resume continues from frozen value — no time lost
- [ ] On a slow frame where `delta > remaining`, timer clamps to 0.0 and emits `time_up` — does not go negative
- [ ] Goals satisfied on the same frame as `time_up`: Level Flow System resolves as level complete, not failed
- [ ] Level restart resets `remaining` to `timer_duration` cleanly

## Open Questions

| Question | Owner | Resolution |
|----------|-------|------------|
| Should the browser tab losing focus auto-pause the timer? Deferred for MVP — revisit if playtesting shows this is a pain point | Producer | Post-MVP |
