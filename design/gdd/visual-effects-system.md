# Visual Effects System

> **Status**: In Design
> **Author**: Design session + systems-designer
> **Last Updated**: 2026-04-01
> **Implements Pillar**: Every Eat Feels Good / Web-Native Delight

## Overview

The Visual Effects System drives all in-level visual feedback: particle bursts on
eat, growth flash and screen shake on level-up, and outcome effects on win and fail.
It subscribes to `ConsumableObject.eaten`, `hole_level_up`, `level_complete`, and
`level_failed` — translating each event into a corresponding visual response. It
owns no game state and applies no logic; it is a pure output system. All effects
are designed to run at 60fps on a mid-range laptop in Chrome — particle counts are
capped and effects degrade gracefully on lower hardware. The system also owns the
hole's void shader, which is the highest visual risk in the project and must be
spiked early.

## Player Fantasy

Every eat should feel like a small act of destruction — a satisfying crunch that
rewards the player for positioning well. The level-up should feel like an event:
the hole pulses, the world shudders slightly, and for a moment the player feels
unstoppable. The win effect should feel earned; the fail effect should sting just
enough to motivate a retry without feeling cruel. Collectively the effects are the
difference between a game that feels alive and one that feels like a spreadsheet
with a camera. They are not decoration — they are the primary delivery mechanism
for Pillar 1.

## Detailed Design

### Core Rules

1. The VFX System subscribes to events at level load; all subscriptions are torn
   down with the scene
2. Effects are fire-and-forget — the system spawns an effect and does not track
   it; the effect node frees itself on completion
3. All `GPUParticles3D` instances are pooled or pre-placed in the scene — no
   runtime `instantiate()` calls during gameplay to avoid GC hitches
4. Particle counts are hard-capped per effect (see Effect Catalogue)
5. Screen shake is applied via `Camera3D` positional offset — not scene tree
   pause, not `get_viewport()` transform
6. If a screen shake is already running when a new `hole_level_up` fires, the
   shake resets to full duration — one shake plays at a time, no stacking
7. The hole void shader is always active — it is a persistent material on
   `HoleMesh`, not an event-driven effect
8. Effects do not block gameplay — they run in parallel with physics and input

### Effect Catalogue

| Effect | Trigger | Type | Description | Particle Cap | Duration |
|--------|---------|------|-------------|--------------|---------|
| **Floating Score Text** | `ConsumableObject.eaten` | `Label3D` or `Control` in world space | `+[points]` floats up from eaten object position and fades out; size scales with point value | — | 0.6s |
| **Level-Up Flash** | `hole_level_up` | `ColorRect` full-screen flash | Brief white flash that fades out; intensity scales with new level | — | 0.3s |
| **Screen Shake** | `hole_level_up` | `Camera3D` offset | Sinusoidal positional offset; amplitude scales with new level; resets if already running | — | 0.4s |
| **Hole Pulse** | `hole_level_up` | `Tween` on `HoleMesh.scale` | Hole briefly overshoots new radius then settles — elastic bounce feel | — | 0.5s |
| **Win Burst** | `level_complete` | `GPUParticles3D` | Large celebratory burst from hole position; bright multicolour | 64 particles | 1.0s |
| **Fail Dim** | `level_failed` | `ColorRect` full-screen overlay | Screen dims to dark grey | — | 0.5s |
| **Void Shader** | Persistent | `ShaderMaterial` on `HoleMesh` | Dark void material with edge glow/distortion; spiked early — highest visual risk | — | Persistent |

Special object effects (bomb explosion burst, booster glow, etc.) are post-MVP —
each `ConsumableObject` subclass can override its own `eat()` to trigger a
dedicated effect.

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| ConsumableObject | Reads from | Subscribes to `eaten(object_id, points)` on all consumables at level load; reads `points` for score text value and object world position for spawn location |
| Growth System | Reads from | Subscribes to `hole_level_up(new_level: int)` for flash, shake, and hole pulse; reads `new_level` to scale effect intensity |
| Level Flow System | Reads from | Subscribes to `level_complete` for win burst; subscribes to `level_failed` for fail dim |
| Hole Controller | Reads from | Reads `global_position` for win burst spawn location |

## Formulas

### Screen Shake Amplitude

```
shake_amplitude = base_shake + (new_level - 1) * shake_per_level
```

| Variable | Default | Description |
|----------|---------|-------------|
| `base_shake` | 0.05 m | Shake offset at level 2 (first level-up) |
| `shake_per_level` | 0.01 m | Additional amplitude per level |
| `shake_amplitude` at level 10 | 0.14 m | Maximum shake ⚠️ Provisional |

### Level-Up Flash Intensity

```
flash_alpha = base_flash_alpha + (new_level - 1) * flash_per_level
```

| Variable | Default | Description |
|----------|---------|-------------|
| `base_flash_alpha` | 0.15 | Alpha at level 2 |
| `flash_per_level` | 0.05 | Additional alpha per level |
| `flash_alpha` at level 10 | 0.6 | Maximum flash ⚠️ Provisional — must not obscure gameplay |

### Floating Score Text Size

```
text_scale = base_text_scale * point_size_multipliers[size_category]

point_size_multipliers = { small: 1.0, medium: 1.3, large: 1.7, huge: 2.2 }
```

⚠️ All values provisional — calibrate during first VFX spike.

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|------------------|-----------|
| Many objects eaten in rapid succession | Each fires an independent floating score text; texts are lightweight `Label3D` nodes that free themselves | Score texts are cheaper than particles — no cap needed |
| Multiple `hole_level_up` signals in one frame (multi-threshold eat) | Flash and shake each trigger but shake resets to full duration on each signal — only one shake plays at a time | Prevents disorienting stacked shakes |
| `hole_level_up` fires while hole pulse is still running | New pulse tween kills the previous one and restarts — hole always snaps to correct final radius | Tween override prevents conflicting scale animations |
| Win burst fires while floating score texts are still active | Both play simultaneously — no conflict, texts complete their fade independently | Fire-and-forget effects don't interact |
| Void shader fails to compile on target hardware | Fallback to a plain dark `StandardMaterial3D` — gameplay is unaffected, visual quality degrades gracefully | WebGL shader compatibility varies; never crash on shader failure |
| `flash_alpha` at level 10 (0.6) covers gameplay content | Level designers must verify legibility at max flash during playtesting; reduce `flash_per_level` if needed | Flash is tunable; gameplay legibility takes priority |

## Dependencies

| System | Direction | Nature |
|--------|-----------|--------|
| ConsumableObject | This depends on | Hard — `eaten` signal provides points value and spawn position for floating score text |
| Growth System | This depends on | Hard — `hole_level_up` signal triggers flash, shake, and hole pulse |
| Level Flow System | This depends on | Hard — `level_complete` and `level_failed` trigger win/fail effects |
| Hole Controller | This depends on | Soft — reads `global_position` for win burst spawn; fallback to world origin if unavailable |

## Tuning Knobs

| Parameter | Default | Safe Range | Too High | Too Low |
|-----------|---------|------------|----------|---------|
| `base_shake` | 0.05 m | 0.01 – 0.15 m | Disorienting even on early level-ups | Level-ups feel weightless |
| `shake_per_level` | 0.01 m | 0.005 – 0.03 m | Late-game shake is disorienting | No noticeable escalation |
| `shake_duration` | 0.4s | 0.2 – 0.8s | Shake lingers too long; feels wrong | Shake barely registers |
| `base_flash_alpha` | 0.15 | 0.05 – 0.3 | Early level-ups already feel dramatic | Flash barely visible |
| `flash_per_level` | 0.05 | 0.02 – 0.08 | Level 10 flash obscures gameplay | No escalation in impact |
| `flash_duration` | 0.3s | 0.1 – 0.5s | Flash lingers; gameplay obscured | Flash not perceptible |
| `hole_pulse_overshoot` | 1.2× radius | 1.1 – 1.4× | Hole looks broken/glitchy | Pulse invisible |
| `score_text_duration` | 0.6s | 0.3 – 1.0s | Text clutters screen on rapid eats | Text disappears before readable |
| `win_burst_particle_count` | 64 | 32 – 128 | Frame drop on win screen | Sparse, underwhelming |

## Acceptance Criteria

- [ ] Eating any object displays a floating `+[points]` text at the object's last
      position that rises and fades within 0.6s
- [ ] Score text size scales correctly with size category (small < medium < large
      < huge)
- [ ] `hole_level_up` triggers flash, shake, and hole pulse simultaneously
- [ ] Screen shake does not stack — a second `hole_level_up` while shaking resets
      shake duration
- [ ] Hole pulse overshoots to 1.2× radius and settles back to exact new radius;
      no residual scale error
- [ ] Flash alpha scales with `new_level`; level 2 flash is noticeably subtler
      than level 10
- [ ] `level_complete` triggers win burst at hole position; 64 particles max
- [ ] `level_failed` dims screen to dark grey overlay
- [ ] Void shader renders on target hardware (mid-range laptop, Chrome); fallback
      to dark material if shader fails
- [ ] All effects run at 60fps on target hardware with a full level's worth of
      consumables in scene
- [ ] No effects play after scene unload — all subscriptions torn down cleanly

## Open Questions

| Question | Owner | Resolution |
|----------|-------|------------|
| Should floating score text use `Label3D` (world space) or a `CanvasLayer` `Label` (screen space)? World space looks more integrated; screen space is easier to control readability at all camera heights | UI programmer | Resolve during first VFX spike |
| What does the void shader look like exactly? Dark sphere with rim glow? Depth distortion? This is the highest visual risk — needs a prototype before committing to an approach | Technical artist | Spike in first implementation sprint |
| Should the win burst also trigger when the level is completed via a continue (+30s)? The player still won — but the celebration may feel incongruous after a fail/recover | Game designer | Resolve during first playtest |
