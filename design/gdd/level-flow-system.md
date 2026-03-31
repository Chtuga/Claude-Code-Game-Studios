# Level Flow System

> **Status**: In Design
> **Author**: Design session + systems-designer
> **Last Updated**: 2026-04-01
> **Implements Pillar**: Goals Give Permission to Explore / Grow Don't Grind

## Overview

The Level Flow System is the coordinator of the level lifecycle. It owns the
sequence from scene load through gameplay to outcome — orchestrating the startup
of all gameplay systems, listening for win and fail signals, computing the star
rating at completion, and triggering the appropriate end screen. On level load it
calls `start()` on the Timer System, Growth System, Target System, and Hole
Controller in the correct order. It listens to `all_goals_complete` from the Target
System (win path) and `time_up` from the Timer System (fail path). On win it reads
`timer.remaining`, computes stars from `LevelConfig.star_thresholds`, and emits
`level_complete(stars: int)`. On fail it emits `level_failed`. It also handles level
restart — resetting all systems to their initial state without unloading the scene.
The Level Flow System owns no gameplay logic itself; it is a sequencer that connects
the pieces.

## Player Fantasy

The player should never notice this system. What they feel is that the level starts
immediately, the win moment lands cleanly without delay, and the restart button
works. A badly implemented flow system is felt as jank: a half-second freeze before
gameplay starts, a win screen that pops before the last object finishes its eat
animation, a restart that carries over stale state. Done right, the level feels like
a single cohesive experience rather than a sequence of systems being bolted together.

## Scenario Flow

```
SCENE LOAD
│
▼
WAITING FOR FIRST TOUCH
(level visible, hole visible,
 timer not running yet)
│
│ first touch → hole starts moving
▼
GAMEPLAY ◄─────────────────────────────────────────────┐
│   ▲                                                   │
│   │ resume                                            │
│   │                                                   │
├── pause ──────────► PAUSED                            │
│                        │                              │
│                        ├── resume ────────────────────┘
│                        ├── restart ──────► RESET ──► WAITING FOR FIRST TOUCH
│                        └── [BOOSTER SHOP] ───────────┘ (buy/use → resume)
│
├── all_goals_complete ──► WIN_DELAY (0.3s) ──► COMPUTE STARS
│                                                    │
│                                         emit level_complete(stars: int)
│                                                    │
│                                              WIN SCREEN
│
└── time_up ──────────► CONTINUE OFFER
                               │
                  ┌────────────┴────────────┐
                  │ spend soft currency      │ decline
                  ▼                          ▼
           TIME EXTENDED               → MAIN MENU
           (+30s added to timer,         (level replayable
            current state kept,          from scratch)
            back to GAMEPLAY)
```

## Detailed Design

### Core Rules

1. On scene load: initialise all gameplay systems (Growth, Target, Timer, Hole
   Controller), load `LevelConfig` — enter **WAITING FOR FIRST TOUCH** state;
   timer does not run
2. On first touch (hole moves): call `start()` on Timer System, Growth System,
   Target System, Hole Controller — enter **GAMEPLAY** state
3. On `all_goals_complete` (from Target System): pause the Timer, wait one brief
   frame delay (≈0.3s), compute stars, emit `level_complete(stars: int)` — enter
   **WIN** state
4. On `time_up` (from Timer System): enter **CONTINUE OFFER** state; show offer
   to spend soft currency
   - If accepted: add 30s to timer (`timer.remaining += 30`), resume timer,
     re-enter **GAMEPLAY**
   - If declined: emit `level_failed`, transition to main menu scene
5. On pause input: pause Timer System (custom pause), enter **PAUSED** state;
   hole movement disabled
6. On resume: unpause Timer System, re-enter **GAMEPLAY**
7. On restart (from PAUSED): reset Growth System, Target System, Timer System,
   Hole Controller to initial state — re-enter **WAITING FOR FIRST TOUCH**

### States and Transitions

| State | Description | Valid Transitions |
|-------|-------------|-------------------|
| `WAITING_FOR_FIRST_TOUCH` | Scene loaded; systems initialised; timer frozen; hole visible | → `GAMEPLAY` on first touch input |
| `GAMEPLAY` | All systems active; timer running | → `PAUSED` on pause input; → `WIN_DELAY` on `all_goals_complete`; → `CONTINUE_OFFER` on `time_up` |
| `PAUSED` | Timer paused; hole frozen | → `GAMEPLAY` on resume; → `WAITING_FOR_FIRST_TOUCH` on restart; → `PAUSED` on booster shop close |
| `WIN_DELAY` | Goals complete; 0.3s wait for eat animation to settle | → `WIN` after delay |
| `WIN` | Stars computed; `level_complete(stars)` emitted | → next level or main menu (Screen Flow System) |
| `CONTINUE_OFFER` | Timer expired; soft currency offer shown | → `GAMEPLAY` on accept (+30s); → main menu scene on decline |

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| Level Configuration | Reads from | Loads `LevelConfig` at scene start; reads `star_thresholds` at goal completion |
| Timer System | Calls into | Calls `start()` on first touch; pauses/resumes on pause input; reads `timer.remaining` at goal completion; adds 30s on continue accept |
| Growth System | Calls into | Calls `start()` on first touch; calls reset on restart |
| Target System | Calls into / Reads from | Calls `start()` on first touch; listens to `all_goals_complete` signal |
| Hole Controller | Calls into | Calls `start()` on first touch; disables/enables movement on pause/resume; calls reset on restart |
| Screen Flow System | Emits to | Emits `level_complete(stars: int)` on win; emits `level_failed` on declined continue |
| Save System | Emits to (indirect) | `level_complete(stars)` is the signal Save System subscribes to for persisting results |
| Visual Effects System | Emits to | Emits `level_complete` and `level_failed` — VFX System subscribes for win/fail effects |
| HUD System | This is depended on by | HUD reads current state to show/hide pause screen, continue offer, win screen |
| Ad Integration System | Emits to | Emits `level_complete` — Ad System listens to trigger interstitial cadence |

## Formulas

### Star Rating

```
remaining = timer.remaining   # read at the moment all_goals_complete fires

if   remaining >= star_thresholds[2]: stars = 3
elif remaining >= star_thresholds[1]: stars = 2
else:                                  stars = 1
```

| Variable | Type | Source | Description |
|----------|------|--------|-------------|
| `remaining` | float (s) | Timer System | Seconds left on clock at goal completion |
| `star_thresholds` | Array[float] (3 values) | `LevelConfig` | `[1-star min, 2-star min, 3-star min]` seconds remaining; must be ascending |
| `stars` | int (1–3) | Derived | 1 star guaranteed on any completion |

### Continue Time Extension

```
timer.remaining += 30.0
```

| Variable | Type | Description |
|----------|------|-------------|
| `30.0` | float (s) | Fixed continue bonus — tuning knob |

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|------------------|-----------|
| `all_goals_complete` and `time_up` fire in the same frame | Win takes priority — `all_goals_complete` is checked first; `time_up` is ignored | Completing goals on the last frame should reward the player, not punish them |
| Player accepts continue but eats last goal before the +30s is added | Not possible — `CONTINUE_OFFER` state disables the hole; no eats can occur while offer is shown | State guards prevent race conditions |
| Player restarts during `WIN_DELAY` (0.3s window) | Not possible — restart is only available from `PAUSED` state; `WIN_DELAY` and `WIN` have no restart transition | Clean state machine prevents premature restart |
| Player accepts continue more than once | Each accept adds +30s; no limit enforced by the system — economy limit (soft currency cost) is the gate | Economy system handles repeat purchases; Level Flow System just adds time |
| Level is restarted — some consumables were already freed | Restart triggers full scene re-initialisation; see Open Questions for whether restart reloads scene or resets in-place | TBD |
| `star_thresholds` array has fewer than 3 values | Clamp index access; log a warning; award 1 star as fallback | Authoring error — fail safe rather than crash |
| First touch fires before scene is fully initialised | `start()` calls are deferred until all system references are valid; input is ignored until ready | Prevents null-reference errors on fast devices |

## Dependencies

| System | Direction | Nature |
|--------|-----------|--------|
| Level Configuration | This depends on | Hard — `LevelConfig` and `star_thresholds` required at scene load |
| Timer System | This depends on | Hard — `start()`, pause/resume, `remaining` read, `time_up` signal, and +30s extension all required |
| Growth System | This depends on | Hard — `start()` and reset required for level lifecycle |
| Target System | This depends on | Hard — `start()` required; `all_goals_complete` is the win trigger |
| Hole Controller | This depends on | Hard — `start()`, movement enable/disable, and reset required |
| Screen Flow System | This is depended on by | Hard — listens to `level_complete(stars)` and `level_failed` to drive scene transitions |
| Save System | This is depended on by | Hard — subscribes to `level_complete(stars)` to persist result |
| Visual Effects System | This is depended on by | Soft — subscribes to `level_complete` and `level_failed` for win/fail effects |
| HUD System | This is depended on by | Soft — reads current state to display correct overlay |
| Ad Integration System | This is depended on by | Soft — subscribes to `level_complete` for interstitial cadence |

## Tuning Knobs

| Parameter | Default | Safe Range | Too High | Too Low |
|-----------|---------|------------|----------|---------|
| `continue_time_bonus` | 30s | 15 – 60s | Continue feels too generous; reduces tension and devalues the timer | Player pays but still can't complete; frustrating and feels unfair |
| `win_delay` | 0.3s | 0.1 – 1.0s | Win screen feels slow to arrive after last eat | Last eat animation overlaps with win screen pop; jarring |
| `star_thresholds` | Per-level in `LevelConfig` | Designer-set | All runs yield 1 star; no replay motivation | Nearly impossible to get 1 star; players feel punished for completing |

## Acceptance Criteria

- [ ] Scene loads into `WAITING_FOR_FIRST_TOUCH` state — timer is frozen, hole is
      visible but not moving
- [ ] First touch simultaneously starts the timer and enables hole movement — all
      systems receive `start()`
- [ ] `all_goals_complete` triggers `WIN_DELAY` → star computation →
      `level_complete(stars)` emitted with correct star count
- [ ] If `all_goals_complete` and `time_up` fire in the same frame, win takes
      priority
- [ ] `time_up` triggers `CONTINUE_OFFER` state — hole is disabled, offer UI
      is shown
- [ ] Accepting continue adds exactly 30s to `timer.remaining` and resumes gameplay
- [ ] Declining continue emits `level_failed` and transitions to main menu scene
- [ ] Pause disables hole movement and freezes timer; resume restores both
- [ ] Restart from `PAUSED` resets all systems and returns to
      `WAITING_FOR_FIRST_TOUCH`
- [ ] Star rating: `remaining >= star_thresholds[2]` → 3 stars;
      `>= star_thresholds[1]` → 2 stars; otherwise → 1 star
- [ ] 1 star is always awarded on goal completion regardless of time remaining

## Open Questions

| Question | Owner | Resolution |
|----------|-------|------------|
| Does restart reload the level scene or reset systems in-place? Scene reload guarantees clean object state (freed consumables restored) but costs load time; in-place reset is faster but requires every system to implement a full reset | Gameplay programmer | Resolve during first implementation sprint — performance vs. complexity trade-off |
| How is the [BOOSTER SHOP] state implemented? What currency, what booster types, what UI? Placeholder in this GDD — architecture must support it but details deferred | Game designer + economy designer | Resolve in post-MVP booster design sprint |
| Should the continue offer be skippable (e.g. player can dismiss without choosing)? Or is dismiss equivalent to decline? | UX designer | Resolve when HUD System GDD is designed |
