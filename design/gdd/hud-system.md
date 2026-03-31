# HUD System

> **Status**: In Design
> **Author**: Design session + systems-designer
> **Last Updated**: 2026-04-01
> **Implements Pillar**: Every Eat Feels Good / Goals Give Permission to Explore

## Overview

The HUD System owns all player-facing UI: the in-gameplay overlay (timer, hole
level, points bar, goal counters) and the full-screen overlays triggered by level
state changes (pause screen, continue offer, win screen, fail screen). It reads
live data from Timer System, Growth System, and Target System each frame, and
reacts to signals from Level Flow System to show or hide the appropriate overlay.
The HUD System does not own any game logic — it is a read-only view of the game
state. All screens that require player input (pause resume/restart, continue
accept/decline, win next/menu) dispatch their decisions back to Level Flow System.

## Player Fantasy

Information is always available but never intrusive — the player knows their hole
level, time remaining, and what targets are left without breaking flow. The urgency
ramp (timer turning red, pulsing) should create genuine tension in the final 15
seconds without feeling punishing. The win screen should land with a moment of
celebration; the fail screen should feel like a fair result, not a cruel one. The
continue offer should feel like an opportunity, not a predatory interruption.

## Detailed Design

### Core Rules

1. The HUD is always present in the level scene; individual elements show/hide
   based on Level Flow System state
2. The **gameplay overlay** is visible only during `WAITING_FOR_FIRST_TOUCH` and
   `GAMEPLAY` states; hidden during all full-screen overlays
3. All gameplay overlay values are polled each frame from their source systems —
   no caching
4. The **timer** display reads `timer.remaining`; switches to urgent style when
   `is_urgent = true` (≤15s)
5. The **points bar** displays `growth_system.accumulated_points` progress toward
   the next threshold in `HoleProgressionConfig.point_thresholds[hole_level - 1]`
6. The **hole level** indicator displays `growth_system.hole_level` (1–10)
7. The **goal counters** display one icon + remaining count per entry in
   `target_system.goal_counters`; icons sourced from Object Configuration catalogue
   by `object_id`
8. Full-screen overlays are shown/hidden by subscribing to Level Flow System state
   transitions:
   - `PAUSED` → show pause screen
   - `CONTINUE_OFFER` → show continue offer screen
   - `WIN` → show win screen with star display
   - `level_failed` → show fail screen
9. All player input on overlays (buttons) calls methods on Level Flow System — HUD
   owns no game logic

### UI Screens

#### Gameplay Overlay
Visible during `WAITING_FOR_FIRST_TOUCH` and `GAMEPLAY`:

| Element | Data Source | Position | Urgent Style |
|---------|-------------|----------|--------------|
| Timer | `timer.remaining` (MM:SS) | Top-centre | Red colour + pulse animation when `is_urgent` |
| Hole level | `growth_system.hole_level` | Top-left | — |
| Points bar | `accumulated_points` / next threshold | Below hole level | — |
| Goal counters | `target_system.goal_counters` (icon + count per type) | Top-right | Completed goals greyed out |

#### Pause Screen
Full-screen overlay on `PAUSED`:

| Element | Action |
|---------|--------|
| Resume button | → Level Flow System: resume |
| Restart button | → Level Flow System: restart |
| [Booster Shop] button | → Level Flow System: open booster shop (placeholder) |
| Main Menu button | → Level Flow System: exit to main menu |

#### Continue Offer Screen
Full-screen overlay on `CONTINUE_OFFER`:

| Element | Action |
|---------|--------|
| "Continue for [X] coins?" prompt | — |
| Accept button | → Level Flow System: continue accept |
| Decline button | → Level Flow System: continue decline |

#### Win Screen
Full-screen overlay on `WIN`:

| Element | Data Source |
|---------|-------------|
| Star display (1–3 stars) | `level_complete(stars)` payload |
| Time remaining at completion | `timer.remaining` at win moment |
| Next Level button | → Screen Flow System |
| Main Menu button | → Screen Flow System |

#### Fail Screen
Full-screen overlay on `level_failed`:

| Element | Action |
|---------|--------|
| "Level Failed" message | — |
| Retry button | → Screen Flow System: reload level |
| Main Menu button | → Screen Flow System: main menu |

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| Timer System | Reads from | Polls `timer.remaining` each frame; subscribes to `time_changed(remaining, is_urgent)` for urgent style trigger |
| Growth System | Reads from | Polls `accumulated_points` and `hole_level` each frame for points bar and level indicator |
| Target System | Reads from | Polls `goal_counters` each frame; reads `object_id` keys to look up icons |
| Object Configuration | Reads from | Reads per-object icon asset reference by `object_id` for goal counter icons |
| Level Flow System | Reads from | Subscribes to state transitions to show/hide overlays; button inputs call Level Flow System methods |
| Screen Flow System | Emits to | Win/fail screen buttons trigger scene transitions via Screen Flow System |

## Formulas

### Timer Display

```
minutes = floor(remaining / 60)
seconds = floor(fmod(remaining, 60))
display = "%02d:%02d" % [minutes, seconds]
```

### Points Bar Fill

```
fill = accumulated_points / point_thresholds[hole_level - 1]   # 0.0 – 1.0
```

At level 10 (no next threshold): `fill = 1.0` — bar stays full.

| Variable | Type | Source | Description |
|----------|------|--------|-------------|
| `accumulated_points` | int | Growth System | Points earned this level |
| `point_thresholds[hole_level - 1]` | int | `HoleProgressionConfig` | Points needed for next level-up |
| `fill` | float (0.0–1.0) | Derived | Progress bar fill fraction |

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|------------------|-----------|
| `hole_level` is 10 — no next threshold | Points bar shows full (1.0 fill) | No misleading empty bar at max level |
| Goal counter icon missing for an `object_id` | Fallback to a generic placeholder icon; log a warning | Missing icon is an asset pipeline error — should not crash HUD |
| `goal_counters` entry reaches 0 | Icon + counter greys out; does not disappear | Player can still see what they completed |
| Timer reaches 0:00 | Timer display holds at 0:00; urgent style stays active | Level Flow System handles the state transition; HUD just reflects it |
| `time_changed` signal fires while pause screen is visible | Urgent style updates silently — timer display is hidden; no visible flicker | Signal updates backing state regardless of visibility |
| Win screen shown while points bar is mid-animation | Gameplay overlay hides immediately on WIN state; no need to complete animation | Clean overlay swap, no half-rendered state |
| Screen is resized (browser window drag) | Godot's `CanvasLayer` handles anchoring automatically; HUD elements stay in correct positions | Engine handles this natively with proper anchor setup |

## Dependencies

| System | Direction | Nature |
|--------|-----------|--------|
| Timer System | This depends on | Hard — `remaining` and `time_changed` signal required for timer display and urgency |
| Growth System | This depends on | Hard — `accumulated_points` and `hole_level` required for points bar and level indicator |
| Target System | This depends on | Hard — `goal_counters` required for goal display |
| Object Configuration | This depends on | Hard — icon asset references required for per-type goal counter icons |
| Level Flow System | This depends on | Hard — state transitions drive overlay visibility; button callbacks call Level Flow System |
| Screen Flow System | This depends on (soft) | Soft — win/fail navigation requires Screen Flow System; HUD can render without it |

## Tuning Knobs

| Parameter | Default | Safe Range | Too High | Too Low |
|-----------|---------|------------|----------|---------|
| `urgency_threshold` | 15s | 5 – 30s | Player feels stressed too early; urgency loses meaning | Urgency kicks in too late; no time to feel tension before `time_up` |
| `win_delay` | 0.3s | 0.1 – 1.0s | Win screen feels slow | Eat animation overlaps with win screen pop |
| `goal_counter_icon_size` | Designer-set | Readable at 1080p and 720p | Clutters top-right corner | Icons too small to identify at a glance |

**Note:** `urgency_threshold` must match Timer System's `urgency_threshold` (15s)
— these are the same value and must stay in sync. Consider storing it in one place
only (Timer System owns it; HUD reads `is_urgent` from the signal).

## Acceptance Criteria

- [ ] Timer displays `MM:SS` format and counts down in real time during `GAMEPLAY`
- [ ] Timer switches to urgent style (red + pulse) when `is_urgent = true`; reverts
      if timer is extended past threshold
- [ ] Points bar fill is accurate: `accumulated_points / point_thresholds[hole_level
      - 1]`; shows full at level 10
- [ ] Hole level indicator updates immediately on `hole_level_up`
- [ ] Goal counters show one icon + remaining count per goal type; icons match
      `object_id` from Object Configuration
- [ ] Completed goal entries (count = 0) grey out and remain visible
- [ ] Gameplay overlay is hidden when any full-screen overlay is shown
- [ ] Pause screen shows correctly on pause input; all buttons dispatch to Level
      Flow System
- [ ] Continue offer screen shows on `CONTINUE_OFFER` state with correct coin cost
      displayed
- [ ] Win screen shows correct star count from `level_complete(stars)` payload
- [ ] Fail screen shows on `level_failed`; retry and main menu buttons work
- [ ] Missing goal counter icon falls back to placeholder without crash

## Open Questions

| Question | Owner | Resolution |
|----------|-------|------------|
| Object Configuration needs an `icon` field added to the catalogue schema — required for per-type goal counter icons | Systems designer | ✅ Flagged — add `icon: Texture2D` (or path) to Object Configuration GDD before implementation |
| What is the soft currency cost shown on the continue offer screen? This is an economy decision not yet made | Economy designer | Resolve during economy/monetisation design sprint |
| Should the win screen show absolute time remaining or a "completion time" (elapsed)? Time remaining is already captured; elapsed requires a separate counter | UX designer | Resolve during first UI prototype |
