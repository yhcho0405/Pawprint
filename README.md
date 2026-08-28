<div align="center">

<img src="docs/images/banner.png" alt="Pawprint" width="100%">

**English** · [한국어](docs/README.ko.md) · [日本語](docs/README.ja.md) · [Deutsch](docs/README.de.md)

<a href="https://github.com/yhcho0405/Pawprint/releases/latest/download/Pawprint.dmg">
<img src="https://img.shields.io/badge/Download%20for%20macOS-.dmg-1a7f37?style=for-the-badge&logo=apple&logoColor=white" alt="Download for macOS" height="42">
</a>

<br><br>

<img src="https://img.shields.io/badge/macOS-14%2B-000000?style=flat-square&logo=apple&logoColor=white" alt="macOS 14+">
<img src="https://img.shields.io/badge/universal-Apple%20Silicon%20%2B%20Intel-555555?style=flat-square" alt="Universal binary">
<img src="https://img.shields.io/badge/Swift-5.10-F05138?style=flat-square&logo=swift&logoColor=white" alt="Swift 5.10">
<img src="https://img.shields.io/badge/license-Apache%202.0-blue?style=flat-square" alt="Apache 2.0">
<a href="https://github.com/yhcho0405/Pawprint/releases/latest"><img src="https://img.shields.io/github/v/release/yhcho0405/Pawprint?style=flat-square&color=8957e5" alt="Latest release"></a>

<br><br>

**How busy was your Mac today? Pawprint keeps count, and gives you a cat for it.**<br>
Keys and clicks, yes — but also how far your cursor walked, how many screens you scrolled past,
how often you jumped between apps, how long you actually stayed put, and how much battery the
whole business cost. Counts and durations only, never content. Everything stays on your Mac.

<br>

<table>
<tr>
<td align="center"><img src="docs/images/shots/menubar-paw.gif" alt="Paw icon" width="230"></td>
<td align="center"><img src="docs/images/shots/menubar-cat.gif" alt="Cat icon" width="230"></td>
<td align="center"><img src="docs/images/shots/menubar-cat-asleep.gif" alt="Sleeping cat icon" width="230"></td>
</tr>
<tr>
<td align="center"><sub>A paw, wiggling along</sub></td>
<td align="center"><sub>…or a cat, swishing its tail</sub></td>
<td align="center"><sub>…which curls up when you stop</sub></td>
</tr>
</table>

<sub>Both speed up when you do and doze off when you don't. Pick either in Settings.</sub>

<br>

<table>
<tr>
<td width="50%"><img src="docs/images/shots/en-popover-today.png" alt="Today"></td>
<td width="50%"><img src="docs/images/shots/en-popover-today-more.png" alt="Further down the Today tab"></td>
</tr>
<tr>
<td align="center"><b>One number for the whole day</b><br><sub>Scored out of 100, given a persona to match, and ranked against every day you've ever recorded — with a 24-hour clock of when you were actually at it.</sub></td>
<td align="center"><b>Keep scrolling</b><br><sub>Your day converted into things you can picture — metres your cursor covered, screen-heights you scrolled, what the battery you spent could have charged — and which keys took the beating.</sub></td>
</tr>
<tr>
<td><img src="docs/images/shots/en-popover-calendar.png" alt="Calendar"></td>
<td><img src="docs/images/shots/en-popover-records.png" alt="Records"></td>
</tr>
<tr>
<td align="center"><b>Months at a glance</b><br><sub>Every day coloured by whichever metric you pick. Streaks and averages, plus a weekly rhythm grid that shows which hours of which days are really yours.</sub></td>
<td align="center"><b>Levels that never run out</b><br><sub>Eleven tracks — typing, clicking, scrolling, focus, screen time, power, app switching and more — with targets that keep growing. Lifetime totals and a monthly retrospective sit underneath.</sub></td>
</tr>
<tr>
<td><img src="docs/images/shots/en-popover-gallery.png" alt="Cats"></td>
<td><img src="docs/images/shots/en-share-card.png" alt="Shareable card"></td>
</tr>
<tr>
<td align="center"><b>One cat per day, kept</b><br><sub>Every day mints a cat and scores it out of 100 for rarity. A quiet Sunday and a frantic Tuesday produce visibly different animals.</sub></td>
<td align="center"><b>Worth showing off</b><br><sub>One button copies the day — or your lifetime totals — as an image, ready to paste anywhere.</sub></td>
</tr>
<tr>
<td><img src="docs/images/shots/en-achievements.png" alt="Achievements"></td>
<td><img src="docs/images/shots/en-items.png" alt="Item list"></td>
</tr>
<tr>
<td align="center"><b>Nine hidden achievements</b><br><sub>Empty slots until they fire. Their conditions look for an unusual <i>shape</i> in a day, not simply a bigger number.</sub></td>
<td align="center"><b>Every item, explained</b><br><sub>What each frame, charm, collar and expression means, when it shows up, and what it is worth.</sub></td>
</tr>
</table>

<img src="docs/images/shots/foil-showcase.gif" alt="Holographic finish in motion" width="300">

<sub>The finish only exists in motion — a still frame is one instant of something whose whole point is that it moves.<br>
This is the top grade, with the light travelling across it.</sub>

<br>

<img src="docs/images/cat-wall.png" alt="48 high-grade cats" width="100%">

<sub>48 high-grade days — bronze through rainbow frames, seven paw charms, three kinds of wings.<br>
Around <b>171 trillion</b> combinations are reachable.</sub>

</div>

<br>

## Take your cats exploring

> Development branch preview: this RPG mode is not included in the public Pawprint 0.10.0 DMG.

The RPG mode under development lets you pick three cats from previous days and take them through
a three-battle, turn-based expedition. Six authored routes now cover all six affinities, with
different enemies, health values and repeatable intent patterns. Three routes are available at
adventure level 1; Dawn Garden, Noon Station and Deep-Night Lab unlock at levels 2, 4 and 6.
The level-gated routes award 15% or 30% more adventure XP, including partial XP after defeat.

A cat's coat pattern sets its role, its aura sets its affinity, its expression becomes a passive,
and its rarity grade adds only a small stat edge. A balanced party is recommended, never required.
Adventure level unlocks routes but does not directly raise combat stats.

Nothing advances in the background. Adventure XP, route stamps and each cat's bond stay on this
Mac, while the active run, health, mana and relics live only in memory. Adventure rewards never
rewrite activity history or change a cat's grade. See the
[current implementation specification](docs/ADVENTURE_SPEC.md) for complete formulas and
rewards, plus a list of features that are not implemented yet.

## What it notices

| | |
|---|---|
| **Keyboard** | Presses per physical key, typing speed, longest unbroken stretch, shortcuts, how much of it was backspace |
| **Pointer** | Clicks, double-clicks, drags, distance your cursor travelled, distance you scrolled, how often you changed direction |
| **Apps** | Which app you were in and for how long, switches, restless two-second visits, and where each key and click actually landed |
| **Focus** | Uninterrupted stretches, and which app kept breaking them |
| **Time** | Active time, screen-on time, first and last activity of the day |
| **Your Mac** | Battery spent, charger and lid, locks and wakes, external displays, audio output changes, bytes moved |
| **Clipboard** | Copy, paste and cut counts, and whether it was text, an image or a file |

Everything above is a **number or a duration**. None of it describes what you were doing.

## What it never stores

- The characters you type, or the order you typed them — the keyboard heatmap counts presses per
  physical key, which is not the same thing: it cannot tell an `a` in a password from an `a` in a
  search box, and holds no sequence to reconstruct either
- Passwords
- Clipboard **contents**
- Screenshots, window titles, document or web page contents
- Long-term raw cursor paths

Data lives in `~/Library/Application Support/Pawprint/` and goes nowhere else.

Pawprint makes two kinds of request, both to GitHub and both behind the same switch in
Settings → Updates: it checks for a new version, and it fetches the notices shown in the popover.
Neither sends anything about you or your Mac. Turn that switch off and the app is entirely
offline. There is no analytics or usage reporting of any kind.

Recording is always visible in the menu bar, can be paused at any time, and individual apps can be
excluded. Deleting everything takes one button.

## Permissions

| Permission | Why |
|---|---|
| **Accessibility** | Detect mouse events and app switches |
| **Input Monitoring** | See that a key was pressed, and which physical key it was — never the character it produced |

A setup wizard walks you through both on first launch, and you can reopen it any time from
Settings → General.

Runs on macOS 14 or later, on both Apple Silicon and Intel Macs. The interface is available in
English, Korean, Japanese and German, and follows your system language unless you pick one in
Settings → General.

## Updates

Pawprint checks for new versions on its own and offers them in the popover. One click downloads,
verifies and installs.

Every release archive is signed with an Ed25519 key whose public half is compiled into the app.
Nothing is unpacked, let alone run, until that signature checks out — so a substituted download
URL cannot become a substituted app. See [SECURITY.md](SECURITY.md) to verify a download yourself.

## Building from source

**You don't need to.** Building is for people who want to change something — to just use
Pawprint, grab the ready-made app:

<div align="center">
<a href="https://github.com/yhcho0405/Pawprint/releases/latest/download/Pawprint.dmg">
<img src="https://img.shields.io/badge/Download%20for%20macOS-.dmg-1a7f37?style=for-the-badge&logo=apple&logoColor=white" alt="Download for macOS" height="38">
</a>
</div>

Still want to build it yourself?

```bash
git clone https://github.com/yhcho0405/Pawprint.git
cd Pawprint
./scripts/build_app.sh release
open ./build/Pawprint.app
```

To package a `.dmg`:

```bash
./scripts/make_dmg.sh --build
```

The release process is documented in [docs/RELEASING.md](docs/RELEASING.md).

## Troubleshooting

<details>
<summary>macOS won't open the app on first launch</summary>

<br>

Right-click Pawprint in Applications and choose **Open**, then confirm. This is only needed once.

</details>

<details>
<summary>Every counter reads zero</summary>

<br>

Accessibility or Input Monitoring was probably revoked. Settings → General shows the live status
of both, and the setup wizard can be reopened from the same place.

</details>

<details>
<summary>Only modifier keys appear in the heatmap</summary>

<br>

Input Monitoring was granted after Pawprint started, and the listener created before it stays
dead. Turn Pawprint off and on again in System Settings → Privacy & Security → Input Monitoring,
then quit and reopen the app.

</details>

## License

[Apache 2.0](LICENSE)
