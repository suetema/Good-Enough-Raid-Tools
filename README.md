# Good Enough Raid Tools

Good Enough Raid Tools is a World of Warcraft TBC Classic Anniversary addon that builds a compact raid consumable and buff matrix for raid leaders, assistants, or anyone who wants a local snapshot.

## Install

1. Create or open your TBC Classic Anniversary addons directory.
2. Install this repo as:
   `Interface/AddOns/GoodEnoughRaidTools`
3. Ensure the addon folder contains `GoodEnoughRaidTools.toc`.

## Commands

- `/gert` toggles the matrix window.
- `/gert scan` refreshes the local roster scan.
- `/gert report [all|category]` reports missing statuses for all categories or one category.
- `/gert optouts` prints stored opt-outs.
- `/gert optout add <player> <category|all>` stores a local opt-out for public mentions.
- `/gert optout remove <player> <category|all>` removes a stored opt-out.

Supported categories:

- `foodbuff`
- `flask`
- `elixir`
- `weaponbuff`
- `raidbuff`
- `blessing`

## Privacy Behavior

- Players do not need the addon installed.
- The addon listens for whispers:
  - `gert unsub foodbuff`
  - `gert unsub flask`
  - `gert unsub all`
  - `gert sub foodbuff`
  - `gert sub all`
- Opt-outs only affect public reports.
- The local matrix always keeps the reporter's full scan data visible.

## Limitations

- V1 only scans active visible buffs on units.
- It does not inspect bags.
- It does not infer potion readiness.
- Unreliable checks should remain `unknown`.
- Consumable coverage depends on detectable buffs and practical spell ID coverage.

## Verification

- Confirm the addon loads under TBC Classic Anniversary with interface `20505`.
- Confirm `/gert` opens the window and the Scan and Report buttons work.
- Confirm public reporting is only allowed for raid leaders or assistants.
- Confirm whisper opt-out commands receive a confirmation whisper.
