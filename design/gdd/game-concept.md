# Game Concept: Hungry Void

*Created: 2026-03-30*
*Status: Draft*

---

## Elevator Pitch

> It's a casual arcade game where you control a growing hole that can swallow
> any object of the right size — eat freely to grow, but the level only ends
> when you've devoured all the marked target objects before time runs out.

---

## Core Identity

| Aspect | Detail |
| ---- | ---- |
| **Genre** | Casual arcade / action puzzle |
| **Platform** | Web (Browser + WebGL) |
| **Target Audience** | Casual to mid-core; ages 16–40 |
| **Player Count** | Single-player |
| **Session Length** | 3–10 minutes per level; 15–30 min per session |
| **Monetization** | F2P + Ads (interstitial + rewarded) + IAP (remove ads, cosmetics, content) |
| **Estimated Scope** | Small (4–8 weeks solo) |
| **Comparable Titles** | Hole.io, Donut County, PowerWash Simulator |

---

## Core Fantasy

You are an unstoppable void. Dropped into a world full of objects, you
start tiny — eating pebbles and coins — and grow until you're swallowing
buses and buildings. The world is designed to be eaten, and you will eat
all of it. The fantasy is inevitability: you WILL consume this diorama,
and the only question is whether you can devour your targets in time.

---

## Unique Hook

Like Hole.io, AND ALSO every level has marked target objects that must be
devoured to complete it — you can eat anything to grow, but strategy comes
from planning the growth path that lets you reach the targets in time.

---

## Player Experience Analysis (MDA Framework)

### Target Aesthetics (What the player FEELS)

| Aesthetic | Priority | How We Deliver It |
| ---- | ---- | ---- |
| **Sensation** (sensory pleasure) | 1 | WebGL juice: particles, screen shake, bloom, grow flash on level-up |
| **Challenge** (obstacle course, mastery) | 2 | Time pressure + targets require strategic growth path planning |
| **Submission** (relaxation, comfort zone) | 3 | No fail state for eating small objects; hole always finds something |
| **Fantasy** (make-believe, role-playing) | 4 | You are a cosmic void devouring a miniature world |
| **Discovery** (exploration, secrets) | 5 | Hidden bonus objects in each diorama |
| **Narrative** | N/A | No story |
| **Fellowship** | N/A | No multiplayer |
| **Expression** | N/A | No creation tools |

### Key Dynamics (Emergent player behaviors)

- Players will naturally prioritize eating the smallest nearby objects first
  to grow quickly, discovering this is more efficient than chasing targets directly
- Players will scan the diorama for the largest target and mentally
  plan a growth path — eating non-target objects as stepping stones
- Players will replay levels to beat their star rating or find bonus objects

### Core Mechanics (Systems we build)

1. **Hole movement** — Mouse/touch drag controls the hole position in 3D diorama space
2. **Size-gated eating** — Objects at or below the hole's current size threshold are consumed
3. **10-level point threshold growth** — Eating objects awards points by object size; accumulating thresholds triggers hole level-up (size increase)
4. **Target completion system** — Each level has 3–6 glowing target objects; the hole can eat ANY object of appropriate size freely, but the level only completes when all targets have been consumed
5. **Time pressure** — Countdown timer; level ends on target completion or timeout (star rating based on time remaining)

---

## Player Motivation Profile

### Primary Psychological Needs Served

| Need | How This Game Satisfies It | Strength |
| ---- | ---- | ---- |
| **Autonomy** | Player chooses their growth path — what to eat first, how to approach targets | Supporting |
| **Competence** | Clear feedback on growth level, star ratings validate skill, time pressure rewards efficiency | Core |
| **Relatedness** | Connection to the diorama worlds (charming aesthetics) | Minimal |

### Player Type Appeal (Bartle Taxonomy)

- [x] **Achievers** — Star ratings per level, total stars unlock bonus content, clear completion goals
- [x] **Explorers** — Hidden bonus objects reward thorough players
- [ ] **Socializers** — Not applicable (no multiplayer)
- [ ] **Killers/Competitors** — Optional: per-level leaderboards for score attack

### Flow State Design

- **Onboarding curve**: Level 1 drops you in with one large obvious target and
  plenty of small objects around it — no tutorial text, the mechanic teaches itself
- **Difficulty scaling**: Later levels place targets behind size gates requiring
  deliberate growth paths; tighter time limits in World 2+
- **Feedback clarity**: Hole level indicator (1–10) always visible; objects glow
  green when edible, grey when too large; point accumulation bar is prominent
- **Recovery from failure**: Level replays instantly; no energy system, no wait timers

---

## Core Loop

### Moment-to-Moment (30 seconds)
Move the hole over objects. Objects within size range get pulled in with a
satisfying crunch + particle burst. Points accumulate. The hole pulses and
glows as the level bar fills. Every eat is juicy.

### Short-Term (5–10 minutes)
Scan the level for marked targets. Plan: "I need to eat to Level 6 to reach
that target car." Eat efficiently, hit targets, beat the clock. Star rating
revealed at end — 1/2/3 stars based on time remaining. Next level unlocks.

### Session-Level (15–30 minutes)
Complete a World (5–8 levels). Each world has a theme (Kitchen, City Block,
Office, Forest). Beat the world → new world unlocks. Session ends naturally
at world completion or at a self-imposed stopping point.

### Long-Term Progression
- 3 Worlds × 6 levels = 18 levels total
- Star collection unlocks bonus levels and cosmetic hole skins
- "3-star every level in World 1" completionist goal
- Optional leaderboard entry per level for replay motivation

### Retention Hooks
- **Curiosity**: "What does the next world's diorama look like?"
- **Investment**: Star count visible on world select — gap between current
  and perfect score creates pull
- **Mastery**: Tighter time limits on 3-star runs create skill ceiling
- **Social**: Shareable "I 3-starred World 2!" moment

---

## Game Pillars

### Pillar 1: Every Eat Feels Good
Every consumed object triggers satisfying audio, visual, and tactile feedback —
regardless of size. No eat should feel silent or empty.

*Design test*: If we're debating whether to add a particle effect to small
object consumption to save performance budget, this pillar says keep the
effect and optimize elsewhere.

### Pillar 2: Goals Give Permission to Explore
Marked targets are always clearly visible. The player knows exactly what
they need to eat. Everything else is freedom — eat whatever helps you grow.

*Design test*: If we're debating whether targets should be hidden or
revealed gradually, this pillar says reveal them upfront.

### Pillar 3: Grow, Don't Grind
The path from tiny hole to target-eating powerhouse should feel fast,
inevitable, and satisfying — never blocked or frustrating. Levels are
designed so edible objects are always nearby at every size tier.

*Design test*: If playtesting shows players hitting a wall where nothing
nearby is edible, the level layout must be redesigned.

### Pillar 4: Web-Native Delight
Loads in under 5 seconds, runs at 60fps on mid-range hardware, no install.
Every WebGL effect serves the feel, not the spec sheet.

*Design test*: If a visual effect drops frame rate below 60fps on target
hardware, it gets simplified or cut — regardless of how good it looks.

### Anti-Pillars (What This Game Is NOT)

- **NOT competitive multiplayer**: No other holes, no PvP. Adds scope and
  complexity that would dilute the pure single-hole fantasy.
- **NOT a physics simulation**: Physics is for feel and juiciness, not
  accuracy. We cheat for satisfaction (e.g., objects magnetically pulled in).
- **NOT text-heavy**: No tutorial popups, no story cutscenes, no dialogue.
  The mechanic must teach itself in the first 30 seconds.
- **NOT pay-to-win**: IAPs are cosmetic or convenience (remove ads, skins,
  extra worlds) — never stat boosts or progression gates that block free players.

---

## Inspiration and References

| Reference | What We Take From It | What We Do Differently | Why It Matters |
| ---- | ---- | ---- | ---- |
| Hole.io | Core hole-eating mechanic, growth snowball | Hand-crafted dioramas + specific targets (not open world) | Proves the hole mechanic has mass appeal (50M+ downloads) |
| Donut County | Charming diorama aesthetic, single-player hole | Time pressure + point threshold system for structure | Validates hole games work with art-forward presentation |
| PowerWash Simulator | Satisfying object-by-object completion, no fail state | Speed and growth as the core tension | Proves "cleaning up a scene" is deeply satisfying solo |

**Non-game inspirations**: ASMR destruction videos; satisfying oddly-satisfying
content on social media; the inherent appeal of watching miniature worlds consumed.

---

## Target Player Profile

| Attribute | Detail |
| ---- | ---- |
| **Age range** | 16–40 |
| **Gaming experience** | Casual to mid-core |
| **Time availability** | Short bursts — commute, break time, lunch |
| **Platform preference** | Browser / web; plays on laptop or desktop |
| **Current games they play** | Hole.io, Cookie Clicker, Mini Metro, casual itch.io games |
| **What they're looking for** | Quick, satisfying game that feels good to play with zero onboarding friction |
| **What would turn them away** | Slow load times, unskippable tutorials, energy systems, frustrating difficulty spikes |

---

## Monetization Model

The game is free to play with no hard paywalls. Revenue comes from three sources:

### Ads

| Ad Type | Placement | Frequency | Player Control |
| ---- | ---- | ---- | ---- |
| **Interstitial** | Between levels (not mid-level) | Every 2–3 level completions | Skippable after 5s; removed by IAP |
| **Rewarded Video** | Opt-in at level timeout | On demand (player-triggered only) | Always optional — grants a 30s time extension |
| **Banner** | World select / menu screens | Always on (non-gameplay screens) | Removed by IAP |

**Ad principles**:
- Never interrupt active gameplay
- Rewarded ads are always opt-in, never forced
- Ad cadence respects the short session length — no ad every level

### IAPs

| Item | Type | Price tier | Description |
| ---- | ---- | ---- | ---- |
| **Remove Ads** | One-time | Low ($1.99–$2.99) | Permanently removes all interstitial and banner ads |
| **Hole Skin Pack** | Cosmetic | Low ($0.99–$1.99) | Alternate hole visual themes (galaxy, fire, etc.) |
| **World Pack** | Content | Mid ($2.99–$4.99) | Extra worlds beyond the 3 base worlds |
| **Starter Bundle** | Bundle | Low ($2.99) | Remove Ads + 1 Skin Pack at a discount |

### Monetization Anti-patterns (Do Not Do)
- No energy/lives system that blocks play
- No loot boxes or randomized paid content
- No stat-affecting purchases
- No unskippable ads longer than 5 seconds

---

## Technical Considerations

| Consideration | Assessment |
| ---- | ---- |
| **Recommended Engine** | Godot 4 + HTML5 export — free, no royalties, solid WebGL output, fast GDScript prototyping |
| **Key Technical Challenges** | Object count performance (many physics objects); smooth hole growth interpolation; size-gating detection at scale |
| **Art Style** | Low-poly 3D with flat/pastel colors; stylized, not realistic |
| **Art Pipeline Complexity** | Medium — custom low-poly 3D diorama assets per world; reuse + rescale objects across levels |
| **Audio Needs** | Moderate — satisfying per-object eat SFX, level-up chime, ambient world music per theme |
| **Networking** | None (optional: REST-based leaderboard only) |
| **Content Volume** | 3 worlds × 6 levels = 18 levels; ~15 unique object types per world; 10 hole size levels |
| **Procedural Systems** | None — all levels hand-crafted for quality control |

---

## Risks and Open Questions

### Design Risks
- **Point threshold tuning**: Wrong thresholds make growth feel grindy or trivially fast — requires playtesting to calibrate
- **Target variety**: 3–6 targets per level may not be enough to create meaningful path decisions in smaller dioramas

### Technical Risks
- **WebGL performance**: Many simultaneous physics-enabled objects may cause frame drops in browser; may need to fake physics (animation-only) for smaller objects
- **Godot HTML5 export quality**: Audio latency and loading times need profiling early; known pain point in Godot web exports

### Market Risks
- **Discoverability on web portals**: Itch.io and similar portals are crowded; needs strong thumbnail/GIF to stand out
- **Session length**: 3–10 min levels may be too short for portal algorithms that reward time-on-site

### Scope Risks
- **Diorama art creation**: Each world requires a unique set of 3D assets — the biggest solo bottleneck
- **Polish time underestimated**: WebGL juice (particles, screen shake, grow effects) takes longer to tune than to build

### Open Questions
- **Is the 10-level growth curve the right number?** Prototype with 5 and 10 levels to compare feel.
- **Does the marked target system create enough tension?** Core loop prototype will answer this.
- **What's the right time limit?** Need playtesting — too tight = frustrating, too loose = no pressure.

---

## MVP Definition

**Core hypothesis**: Players find the free-eating + target-completion loop
engaging for a full 3-level session and want to replay levels for a better
star rating.

**Required for MVP**:
1. Hole movement (mouse drag in 3D diorama space)
2. Size-gated eating with point accumulation and 10-level growth
3. 3 target objects per level (glowing); hole can eat anything of right size, level ends when all targets eaten
4. Timer + 1–3 star rating on completion
5. At least 3 levels in 1 world to validate session loop
6. Core WebGL juice: eat particles, level-up flash, screen shake

**Explicitly NOT in MVP** (defer to later):
- Multiple worlds / themed dioramas (use simple placeholder scene)
- Cosmetic hole skins
- Leaderboards
- Bonus hidden objects
- Audio (placeholder or silent)

### Scope Tiers

| Tier | Content | Features | Timeline |
| ---- | ---- | ---- | ---- |
| **MVP** | 1 world, 3 levels | Core loop, growth system, timer, stars | 1–2 weeks |
| **Vertical Slice** | 1 polished world, 6 levels | Full juice, audio, UI polish | 3–4 weeks |
| **Alpha** | 2 worlds, 12 levels | All features, rough art | 5–6 weeks |
| **Full Vision** | 3 worlds, 18 levels + bonus | All features, polished, leaderboards | 7–8 weeks |

---

## Next Steps

- [ ] Get concept approval from creative-director
- [ ] Run `/setup-engine godot 4.6` to configure engine and populate version-aware reference docs
- [ ] Run `/design-review design/gdd/game-concept.md` to validate completeness
- [ ] Run `/map-systems` to decompose concept into individual systems with dependencies
- [ ] Run `/prototype hole-eating-loop` to validate the core loop hypothesis
- [ ] Run `/playtest-report` after prototype to validate or invalidate the hypothesis
- [ ] Run `/sprint-plan new` to plan the MVP sprint
