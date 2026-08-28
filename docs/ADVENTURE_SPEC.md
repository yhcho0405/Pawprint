<div align="center">

**English** · [한국어](ADVENTURE_SPEC.ko.md) · [日本語](ADVENTURE_SPEC.ja.md) · [Deutsch](ADVENTURE_SPEC.de.md)

</div>

# Pawprint Adventure Mode Implementation Specification

This document describes the **current turn-based adventure implementation** on the RPG integration
development branch that preserves the base Pawprint 0.10.0 UI. This is a development-build
specification and is not included in the public Pawprint 0.10.0 DMG. It documents the values and
rules in the code that runs today, not design ideas or future goals.

> Key conclusion: a cat's rarity grade provides small bonuses to HP, attack, and guard.
> **Adventure level now unlocks routes at levels 2, 4, and 6, but it still does not increase combat
> stats.** Bonds and route stamps remain stored counters without combat effects.

## At a glance

| Item | Current implementation |
|---|---|
| Party | Exactly 3 distinct cats from previous days |
| Expedition structure | Skirmish → relic → skirmish → relic → boss battle |
| Actions | Choose 1 cat each turn and use a basic attack or role skill |
| Routes | 6 authored routes covering all affinities; 3 begin unlocked and 3 unlock by level |
| Combat resources | Shared party HP and shared mana |
| Permanent progress | Adventure XP (level is derived from XP), completed runs, route stamps, and per-cat bonds |
| Temporary rewards | Up to 2 relics that apply only to the current expedition |
| Automatic progress | None. A turn advances only when the player submits a command with a button |
| Level-based stat scaling | None |
| Level-based unlocks | Dawn Garden at level 2, Noon Station at level 4, Deep-Night Lab at level 6 |
| Bond and stamp effects | Accumulation is stored, but combat effects and ways to spend them are not implemented |
| Active expedition restoration | None. Relaunching the app does not restore an active expedition |

The standard flow is:

```text
Open Adventure from the Gallery
  → choose 3 cats from previous days
  → choose a route
  → skirmish 1
  → choose 1 relic
  → skirmish 2
  → choose 1 relic
  → boss battle
  → calculate score, rank, and rewards
```

## Three distinct kinds of grade

| Name | Range | Determined by | Current effect |
|---|---|---|---|
| Cat rarity grade | S–D | Existing Pawpet rarity | Small bonuses to HP, attack, and guard |
| Expedition result rank | S–D | Completion score or failure status | Determines base XP before the route multiplier |
| Adventure level | 1 and up, with no cap | Total adventure XP | Unlocks routes at levels 2, 4, and 6; no stat scaling |

A cat's S grade and an expedition's S rank share a label but are otherwise unrelated. Result rank,
XP, adventure level, bonds, and route stamps neither rewrite the cat's rarity grade nor change its
combat stats. Adventure level only changes route availability.

## Cats eligible for an adventure

### Candidate and party rules

- Only completed gallery cats dated before today are eligible. Today's cat is excluded.
- The default candidate list and automatic recommendation process candidates from newest to oldest.
  The HUD displays them by grade in S→A→B→C→D order, then newest first within each grade.
- A party requires exactly 3 cats with distinct date IDs.
- Duplicate roles are allowed. A party does not have to contain one Guardian, one Striker, and one
  Support.
- When possible, automatic recommendation first selects 1 cat of each role, then fills any
  remaining slots with the newest candidates.
- A party containing all three roles receives no separate numerical composition bonus. Its
  advantage is that it can counter every announced enemy intent.

### Mapping Pawpet appearance to RPG traits

Only four traits from the existing cat are passed directly to the adventure engine. Other appearance
and activity traits are not passed directly, but traits included in the existing Pawpet rarity
calculation can indirectly affect HP, attack, and guard through the cat's grade.

| Pawpet trait | RPG trait |
|---|---|
| Pattern (`pattern`) | Role |
| Aura (`aura`) | Affinity |
| Expression (`expression`) | Passive |
| Rarity grade (`rarityGrade`) | Cat grade |

#### Pattern → role

| Pattern code | Role |
|---|---|
| `plain`, `tuxedo`, `bicolor` | Guardian (`guardian`) |
| `tabby`, `spotted`, `calico` | Striker (`striker`) |
| `colorpoint`, `star` | Support (`support`) |

#### Expression → passive

| Expression code | Passive |
|---|---|
| `content`, `zen` | Steady (`steady`) |
| `sleepy`, `tired`, `dizzy` | Resilient (`resilient`) |
| `determined`, `focused`, `sparkle` | Focused (`focused`) |
| `chaotic`, `mischief` | Opportunist (`opportunist`) |
| `surprised`, `wide` | Alert (`alert`) |

#### Activity time → aura → affinity

The aura is determined by the existing Pawpet rules and mapped `1:1` to the adventure affinity
with the same time-period code. Localized display names may differ between the two UIs. The
reference time is selected in this order:
`golden hour → hour of the busiest minute → first activity hour → noon`.

| Reference time | Pawpet aura | Adventure affinity |
|---:|---|---|
| 00:00–04:59 | Small hours (`deepNight`) | Deep night (`deepNight`) |
| 05:00–07:59 | Dawn (`dawn`) | Dawn (`dawn`) |
| 08:00–11:59 | Morning (`morning`) | Morning (`morning`) |
| 12:00–16:59 | Afternoon (`afternoon`) | Afternoon (`afternoon`) |
| 17:00–20:59 | Evening (`evening`) | Evening (`evening`) |
| 21:00–23:59 | Night (`night`) | Night (`night`) |

### Rarity and cat grade

The grade used by Adventure is not a direct copy of the daily activity score grade. It is the
existing Pawpet **rarity grade**.

```text
Raw rarity score =
  0.70 × item rarity score
  + 0.30 × (Pawpet activity effort × 100)

Integer rarity = raw rarity score rounded to the nearest integer
```

Pawpet activity effort ranges from `0...1`; the item rarity score and raw rarity score range from
`0...100`. The raw score is calculated after rounding to two decimal places, and the adventure grade
is determined by rounding that value to the nearest integer again. This value is recalculated from
the existing daily record and is not a separate RPG persistence field.

| Integer rarity | Cat grade |
|---:|---:|
| 85 or higher | S |
| 70–84 | A |
| 50–69 | B |
| 30–49 | C |
| 0–29 | D |

The adventure engine receives only this final grade. It does not recalculate rarity or effort.

## Party stats

### Notation

| Symbol | Meaning |
|---|---|
| `A` | The acting cat's attack after grade bonuses |
| `G` | The acting cat's guard after grade and Steady bonuses |
| `P` | The current enemy's power |
| `HPmax` | The sum of the three cats' maximum HP |
| `w` | The deterministic random adjustment for the current turn |

All division of positive values uses integer division and discards the fractional part.

### Base stats by role

| Role | Base HP | Base attack | Base guard | Base healing power | Role skill |
|---|---:|---:|---:|---:|---|
| Guardian | 112 | 22 | 10 | 0 | Paw Shield |
| Striker | 100 | 30 | 2 | 0 | Lightning Pounce |
| Support | 106 | 20 | 4 | 10 | Comforting Groom |

The combat formulas below describe each role skill's detailed damage, guard, and healing bonuses.

### Cat grade bonuses

| Cat grade | Internal bonus `B` | HP increase | Attack increase | Guard increase | Healing power increase |
|---|---:|---:|---:|---:|---:|
| D | 0 | 0 | 0 | 0 | 0 |
| C | 2 | 2 | 1 | 0 | 0 |
| B | 4 | 4 | 2 | 1 | 0 |
| A | 6 | 6 | 3 | 1 | 0 |
| S | 8 | 8 | 4 | 2 | 0 |

```text
Maximum HP = role base HP + B
Attack = role base attack + B / 2
Guard = role base guard + B / 4 + (3 if Steady)
Healing power = (10 for Support, otherwise 0) + (3 if Focused)
```

The actual role and grade values before passive bonuses are shown below. Each cell is
`HP / attack / guard`.

| Grade | Guardian | Striker | Support |
|---|---:|---:|---:|
| D | 112 / 22 / 10 | 100 / 30 / 2 | 106 / 20 / 4 |
| C | 114 / 23 / 10 | 102 / 31 / 2 | 108 / 21 / 4 |
| B | 116 / 24 / 11 | 104 / 32 / 3 | 110 / 22 / 5 |
| A | 118 / 25 / 11 | 106 / 33 / 3 | 112 / 23 / 5 |
| S | 120 / 26 / 12 | 108 / 34 / 4 | 114 / 24 / 6 |

Rarity grade does not increase healing power. When duplicate roles are allowed, the possible range
of maximum party HP is `300...360`.

### Shared party HP and the acting cat

- The maximum HP of the three cats is combined into one shared party HP pool.
- There is no individual HP or individual incapacitation state.
- Each turn uses only the selected cat's attack, guard, affinity, and passive in the action
  calculation.
- The two cats that do not act contribute only to the shared maximum HP for that turn.
- Displayed guard `G` is not subtracted directly from damage. Base mitigation uses `G / 2`.

The grade-based guard bonus is applied to `G` before another integer division by `G / 2`. Therefore,
`+1` guard does not necessarily appear immediately as `+1` mitigation for every cat and turn.

## Turns and actions

### Basic attack

```text
Initial damage = max(1, 2A / 3 + w), w = -2...2
```

- Restores 1 shared mana, up to the maximum.
- Does not receive the role-specific damage bonus of a role skill.
- A Support cat's basic attack does not heal.
- If the cat's role matches the enemy intent, the attack can receive the weaker counter bonus and
  count as a successful counter.

### Role skill

```text
Initial damage = A + w + role damage bonus, w = -2...2
```

| Role | Role damage bonus | Additional effect |
|---|---:|---|
| Guardian | +4 | +8 mitigation potential |
| Striker | +8 | No additional effect |
| Support | +0 | Heals the party |

A role skill consumes 1 shared mana. At 0 mana, the action is rejected without changing the turn or
random state.

### Player damage calculation order

1. Calculate the initial damage for a basic attack or role skill.
2. Add affinity match, passive, enemy-intent counter, and relic bonuses.
3. If the enemy is in Guarded Stance and the player did not counter with a Striker, subtract enemy
   guard `max(6, P / 5)`.
4. Clamp actual damage to `min(current enemy HP, max(1, attempted damage - enemy guard))`.

A valid action deals at least 1 damage. The recorded value cannot exceed the enemy's remaining HP,
so a `damage +4` effect may appear to add less than 4 immediately before a kill.

## Affinities and passives

### Affinity match

A damage bonus applies **only when** the acting cat's affinity exactly matches the enemy's affinity.

| Action | Matching damage bonus |
|---|---:|
| Basic attack | `max(2, A / 10)` |
| Role skill | `max(3, A / 6)` |

Affinities do not form a rock-paper-scissors relationship and have no disadvantage state. A match
grants a bonus; a mismatch is neutral. The affinities of cats that do not act have no effect on that
turn.

### Passive effects

| Passive | Condition | Effect in the current turn-based combat |
|---|---|---|
| Steady | Always | Guard `+3`; an additional `+4` mitigation against an enemy response |
| Resilient | Party HP is at or below 50% of maximum at the start of the action | Additional mitigation `+8` |
| Focused | Uses a role skill | Healing power `+3` and role-skill healing `+4` |
| Opportunist | 25% chance on each action | Damage `+7` |
| Alert | First turn of each battle | Damage `+5` |

Steady's `+3` guard is reflected in `G / 2`, after which the additional `+4` mitigation is added
separately. The 50% condition for Resilient is evaluated before healing on that turn. Alert can
activate again on the first turn of each of the three battles, rather than only on the first turn of
the entire expedition.

## Enemy intents and counters

Enemy intent is public information. Selecting a cat with the countering role records even a basic
attack as a successful counter, but role skills have stronger effects.

| Enemy intent | Countering role | Effect when not countered | Role-skill counter | Basic-attack counter |
|---|---|---|---|---|
| Heavy Strike | Guardian | High enemy attack | Damage `+3`, mitigation `+max(12, P / 3)` | Damage `+1`, half of the preceding mitigation bonus |
| Guarded Stance | Striker | Enemy guard `max(6, P / 5)` | Removes enemy guard, damage `+10` | Removes enemy guard, damage `+5` |
| Draining Mist | Support | Additional damage `max(8, P / 7)` | Removes additional damage, damage `+3`, mitigation `+max(8, P / 5)`, healing `+8` | Removes additional damage, damage `+1`, half of the preceding mitigation bonus, no healing |

The enemy attack uses a separate random adjustment `w` in `-2...2`.

| Enemy intent | Attempted enemy attack |
|---|---:|
| Heavy Strike | `3P / 4 + w` |
| Guarded Stance | `2P / 5 + w` |
| Draining Mist, not countered | `P / 2 + max(8, P / 7) + w` |
| Draining Mist, countered | `P / 2 + w` |

The enemy attack is clamped to at least 1 before mitigation.

## Guard and incoming damage

```text
Mitigation potential =
  G / 2
  + Guardian action bonus
  + intent counter bonus
  + passive bonus
  + relic bonus
```

| Item | Mitigation bonus |
|---|---:|
| Guardian basic attack | +3 |
| Guardian role skill | +8 |
| Steady | +4, separate from the `G +3` guard effect |
| Resilient at or below 50% HP | +8 |
| Padded Cape | +4 |
| Countering Heavy Strike or Draining Mist | Values from the counter table above |

```text
Actual mitigation = min(enemy attack, max(0, mitigation potential))
Damage received = min(party HP after healing, max(0, enemy attack - actual mitigation))
```

If the player's action defeats the enemy first, the enemy does not respond. Both damage received and
recorded mitigation are 0 in that case.

## Healing

Healing occurs only on role skills. It is applied after player damage is resolved and before the
enemy responds.

```text
Healing capacity =
  healing power
  + Support role-skill bonus
  + Draining Mist counter bonus
  + Focused role-skill bonus
  + Healing Herb bonus

Actual healing = min(healing capacity, HPmax - current party HP)
```

| Item | Healing bonus |
|---|---:|
| Support role skill | +12 |
| Countering Draining Mist with Support | +8 |
| Role skill while Focused | +4 |
| Support role skill with Healing Herb | +8 |

Representative healing capacities are:

| Acting cat | Normal role skill | Countering Draining Mist | With Healing Herb: normal / counter |
|---|---:|---:|---:|
| Non-Focused Guardian or Striker | 0 | Not applicable | Not applicable |
| Focused Guardian or Striker | 7 | Not applicable | Not applicable |
| Non-Focused Support | 22 | 30 | 30 / 38 |
| Focused Support | 29 | 37 | 37 / 45 |

The Focused passive gives even a non-Support role skill a healing capacity of 7. Actual healing is 0
when no HP is missing. The passive named `Resilient` adds mitigation when HP is low; it is distinct
from the healing power discussed here.

## Randomness and reproducibility

- Player damage wobble is `-2...2` for every action.
- Enemy attack wobble is `-2...2` for every action.
- Opportunist activates when a value drawn from `0...3` is 0, so its probability is exactly 25%.
- Every encounter owns an ordered intent pattern. The seed chooses its starting offset, after which
  the authored pattern repeats. Repeated entries make an intent occur more often without adding a
  hidden random roll.
- Choosing the same cat and action from the same complete battle state produces the same result.
  When the seed, stage, and round are the same, both damage wobbles, the Opportunist check, and the
  intent sequence are the same.
- A rejected action, hiding a window, reconstructing the UI, or waiting does not alter randomness or
  combat state.
- There is no real-time limit, automatic turn, idle progress, or offline progress.

## Routes and stages

Every route always consists of 2 skirmishes followed by 1 boss battle. Skirmishes allow 3 turns
each, and the boss allows 5. Production routes author every encounter separately: earlier stages
are no longer generated as fractions of boss power. Enemy power `P` is clamped to `1...1000` and
authored maximum HP to `1...2000`. The compatibility initializer still defaults HP to `2P`, but the
six routes below pass explicit HP values.

| Route | Affinity | Minimum level | Difficulty | XP multiplier |
|---|---|---:|---|---:|
| Sunlit Trail | Morning | 1 | Easy | 100% |
| Signal Rooftops | Evening | 1 | Normal | 100% |
| Midnight Archive | Night | 1 | Normal | 100% |
| Dawn Garden | Dawn | 2 | Normal | 115% |
| Noon Station | Afternoon | 4 | Hard | 130% |
| Deep-Night Lab | Deep night | 6 | Expert | 130% |

Difficulty is descriptive route metadata; it does not apply another hidden scaling formula. A
locked route can be previewed in the route picker, but the expedition cannot start until the
required adventure level is reached. Stamps and completed-run count do not unlock routes.

In the pattern column, `H` means Heavy Strike, `G` Guarded Stance, and `D` Draining Mist. The shown
order is the authored cycle; the seed may rotate its first entry.

| Route | Stage and enemy | `P / HP` | Intent pattern |
|---|---|---:|---|
| Sunlit Trail | 1 · Moss Scout | 34 / 72 | `H-G-D` |
| Sunlit Trail | 2 · Pollen Trickster | 43 / 88 | `G-D-H` |
| Sunlit Trail | Boss · Sunbeam Guardian | 60 / 124 | `H-H-G-D` |
| Signal Rooftops | 1 · Wire Sparrow | 36 / 72 | `G-G-H` |
| Signal Rooftops | 2 · Neon Prowler | 45 / 94 | `G-H-D` |
| Signal Rooftops | Boss · Signal Warden | 64 / 132 | `G-G-D-H` |
| Midnight Archive | 1 · Dust Wisp | 38 / 68 | `D-D-G` |
| Midnight Archive | 2 · Ink Shadow | 48 / 84 | `D-H-D` |
| Midnight Archive | Boss · Archive Keeper | 68 / 120 | `D-D-H` |
| Dawn Garden | 1 · Dew Sprite | 39 / 72 | `H-D-H` |
| Dawn Garden | 2 · Glasswing | 50 / 96 | `H-H-G` |
| Dawn Garden | Boss · Dawn Bloom | 72 / 142 | `H-D-H` |
| Noon Station | 1 · Platform Spark | 40 / 82 | `G-G-D` |
| Noon Station | 2 · Clockwork Rival | 51 / 106 | `G-H-D` |
| Noon Station | Boss · Station Keeper | 74 / 150 | `G-G-H-D` |
| Deep-Night Lab | 1 · Static Wisp | 42 / 84 | `D-H-D-G` |
| Deep-Night Lab | 2 · Sleeping Process | 54 / 110 | `H-D-G-D` |
| Deep-Night Lab | Boss · Kernel Guardian | 78 / 158 | `D-H-G-D` |

### Battle outcomes and stage transitions

- The battle is won immediately when enemy HP reaches 0.
- The battle is lost when party HP reaches 0.
- If the enemy is still alive after the last allowed turn, the battle is lost.
- Defeating the enemy on the last turn takes precedence over a turn-limit defeat.
- Losing a skirmish immediately ends the entire expedition.
- Party HP and mana carry their pre-relic-effect values into the next stage. Warm Tea changes HP,
  while Mana Bell changes current and maximum mana before the next battle begins.
- There is no automatic full heal between stages.

## Mana

| Item | Rule |
|---|---|
| Starting mana | 2 |
| Base maximum mana | 3 |
| Basic attack | Mana `+1`, capped at the maximum |
| Role skill | Mana `-1` |
| Role skill at 0 mana | Action rejected |
| Stage transition | Current mana is retained |
| Maximum after acquiring Mana Bell | 4 |

Remaining mana is included in the result state but does not affect score or XP.

## Relics

After winning each of the first and second skirmishes, the player is offered 3 relics not already
owned. One must be selected before the next battle begins.

- There are 6 relics in total.
- The same relic cannot be acquired more than once.
- A party that reaches the boss owns 2 relics.
- Offers are determined by the expedition seed and stage.
- Every relic applies only to the current expedition and is not stored permanently.

| Relic | Exact effect |
|---|---|
| Sharpened Claw | Attempted damage `+4` for every basic attack and role skill |
| Padded Cape | Mitigation `+4` against enemy responses |
| Mana Bell | Maximum mana `+1`; current mana `+1` immediately when selected |
| Warm Tea | Immediately restores `max(1, HPmax / 5)`, capped at maximum HP |
| Echo Charm | Mana `+1` after the action's base mana change when an enemy intent is countered |
| Healing Herb | Healing capacity `+8` for Support role skills |

Successfully countering with a role skill while carrying Echo Charm can refund the 1 mana consumed.
If a basic-attack counter has already brought mana to its maximum, the additional restoration cannot
exceed that maximum.

## Completion score and result rank

Defeat and withdrawal always score 0. The following formula is used only after defeating the boss.

```text
Health points = remaining party HP × 25 / maximum party HP
Counter points = successful counters × 20 / total actions
Efficiency points = max(0, 10 - 3 × max(0, total actions - 8))

Final score = min(100, 40 + health points + counter points + efficiency points)
```

The fractional part of every division is discarded.

| Score component | Maximum points |
|---|---:|
| Completion base | 40 |
| Remaining HP ratio | 25 |
| Enemy-intent counter ratio | 20 |
| Turn efficiency | 10 |
| Maximum in the current implementation | 95 |

| Total actions | Efficiency points |
|---:|---:|
| 8 or fewer | 10 |
| 9 | 7 |
| 10 | 4 |
| 11 | 1 |

| Result rank | Condition |
|---|---:|
| S | Completion score 90 or higher |
| A | Completion score 85–89 |
| B | Completion score 75–84 |
| C | Completion score 74 or lower |
| D | Defeat or withdrawal |

Because the maximum number of actions across the current three stages is 11, the practical completion
score range is `41...95`. The current rank rules cannot produce a D rank for a completed expedition.
The engine still contains a 40 XP branch for a D-rank completion, but the current rank calculation
cannot reach it.

The score formula does not directly read final remaining mana or the number of relics. However, mana
management and selected relic effects can influence combat performance and therefore affect the score
indirectly. The following can also have an indirect effect through combat performance:

- The selected route's authored enemies, HP values, intent patterns, and fixed difficulty
- Cat rarity grades and party role composition

Adventure level decides which routes can be started, but is not read by combat or score calculation
after a route has been chosen. Bonds and route stamps have no direct or indirect effect on current
combat or score.

## XP and permanent rewards

### Completion

| Result rank | Base adventure XP | Selected route stamp | Participating cat bonds |
|---|---:|---:|---:|
| S | 120 | +1 | +1 each |
| A | 100 | +1 | +1 each |
| B | 80 | +1 | +1 each |
| C | 60 | +1 | +1 each |
| D branch | 40 | +1 | +1 each |

Completing an expedition also increments the total completed-run count by 1. The D-rank completion
reward branch is currently unreachable.

The route multiplier is applied to every positive XP grant, including partial XP after defeat:

```text
Granted adventure XP = base adventure XP × route multiplier / 100
```

Integer division discards the remainder. For example, 20 base XP becomes 23 on Dawn Garden and 26
on either 130% route. Stamps and bonds are not multiplied.

### Defeat and withdrawal

```text
Defeat XP = number of battles won before defeat × 10
```

| Result | Base adventure XP | Stamp | Bonds |
|---|---:|---:|---:|
| Defeat in the first skirmish | 0 | 0 | 0 |
| Defeat after 1 skirmish win | 10 | 0 | 0 |
| Defeat in the boss battle after 2 skirmish wins | 20 | 0 | 0 |
| Withdrawal at any point | 0 | 0 | 0 |

Withdrawal always awards 0 XP, even after winning earlier skirmishes. A unique grant ID for each
expedition and a recent grant history prevent the same result from being applied more than once.

## Adventure XP and level

```text
Adventure level = total adventure XP / 250 + 1
XP within current level = total adventure XP % 250
XP required per level = 250
```

| Total XP | Adventure level |
|---:|---:|
| 0–249 | 1 |
| 250–499 | 2 |
| 500–749 | 3 |
| 750–999 | 4 |
| Thereafter | Continues to increase every 250 XP |

There is currently no level cap. Level and XP progress are shown in the UI. Levels now unlock
routes as follows:

| Adventure level | Newly available route |
|---:|---|
| 1 | Sunlit Trail, Signal Rooftops, and Midnight Archive |
| 2 | Dawn Garden |
| 4 | Noon Station |
| 6 | Deep-Night Lab |

The following effects are **not implemented**:

- Increases to attack, maximum HP, guard, mitigation, or healing
- Increased maximum mana
- Stat, enemy-power, or enemy-HP scaling from adventure level
- Relic, skill, or other feature unlocks

Adventure level is therefore progression and a route gate. It does not directly change party stats,
mana, enemy values, or the score formula. Higher XP multipliers belong to the authored routes, not
to a general level-scaling formula.

## Route stamps and cat bonds

### Route stamps

- 1 stamp is awarded only for completing a route, and stamps accumulate separately for each route.
- The UI displays the stamp count for each route.
- There are currently no bonuses, ways to spend stamps, or unlock conditions.

### Cat bonds

- Completing an expedition awards 1 bond to each of the three participating cats.
- Bonds accumulate under each cat's original activity-date ID.
- Defeat and withdrawal award no bonds.
- There is currently no UI that displays the value, no bond level, no stat scaling, and no skill
  unlock.
- Deleting the original daily record also deletes that date cat's bond.

## Persistence and reset behavior

Adventure progress is stored as JSON in Pawprint's SQLite store, separately from existing activity
statistics.

| Permanently stored item | Behavior |
|---|---|
| Total adventure XP | Stored |
| Total completed runs | Stored |
| Route stamps | Stored |
| Per-cat bonds | Stored |
| Duplicate-grant prevention IDs | Stores the most recent 256 IDs that produced a positive reward |

| Item not stored permanently | Result |
|---|---|
| Active expedition and current stage | Not restored after relaunching the app |
| Current HP, mana, and relics | Not restored after relaunching the app |
| Combat log, turn history, and expedition seed | Not restored after relaunching the app |
| Party and route draft for the next expedition | Not restored after relaunching the app |

The exact storage location is the `adventure_progress_v1` key in the `app_settings` table. If an
early development build has data in UserDefaults and SQLite has none, that data is migrated once.

- Deleting a specific daily record removes that cat's bond and its adventure candidate. If the
  deleted cat belongs to the current party, the active expedition also ends.
- Retention cleanup also removes out-of-range bonds and candidates and ends an active expedition
  containing an affected cat. Total XP, total completed runs, route stamps, and duplicate-grant
  prevention IDs are retained.
- Deleting all data resets XP, completed runs, stamps, bonds, and grant history.
- Closing or resetting only the active expedition retains all progress already awarded.

## Extensions not currently implemented

| Feature | Current status |
|---|---|
| Stat growth by level | None |
| Bond effects and bond display | Stored counter only |
| Stamp rewards, spending, or unlocks | None |
| Numerical bonus for a 3-role party | None |
| Enemy difficulty scaling by level | None |
| Permanent relic, equipment, or item inventory and upgrades | None |
| Active expedition save and restoration | None |
| Idle, offline, or background progress | None |

## Implementation scope note

`AdventureEngine.resolve()` retains the original 3-round automatic-combat formula for API
compatibility and tests. The current production adventure UI does not call this API. The combat
rules in this document cover only `AdventureEngine.performTurn()` and `AdventureExpeditionEngine`,
which the current UI uses.

## Code reference points

- [AdventureEngine.swift](../Sources/PawprintCore/Engine/AdventureEngine.swift): cat stats, actions,
  damage, guard, healing, passives, authored enemy HP, and intent patterns
- [AdventureExpeditionEngine.swift](../Sources/PawprintCore/Adventure/AdventureExpeditionEngine.swift):
  3-battle expeditions, mana, relics, score, rank, and route-multiplied XP rewards
- [PawpetAdventureAdapter.swift](../Sources/Pawprint/Adventure/PawpetAdventureAdapter.swift):
  mapping Pawpet appearance to RPG traits
- [AdventureRosterCatalog.swift](../Sources/Pawprint/Adventure/AdventureRosterCatalog.swift):
  candidate eligibility rules
- [AdventureExpeditionCenter.swift](../Sources/Pawprint/Adventure/AdventureExpeditionCenter.swift):
  the six authored route catalogs, level gates, party draft, and active expedition lifecycle
- [AdventureRewardStore.swift](../Sources/Pawprint/Adventure/AdventureRewardStore.swift):
  XP, level, stamp, and bond persistence
- [PawprintStore.swift](../Sources/PawprintCore/Storage/PawprintStore.swift):
  SQLite storage location and full-data lifecycle
- [PawpetTraits.swift](../Sources/Pawprint/UI/Components/PawpetTraits.swift):
  rarity grade and aura calculation
- [CatLustre.swift](../Sources/PawprintCore/Engine/CatLustre.swift): Pawpet activity-effort
  calculation
