# Good Enough Raid Tools

Good Enough Raid Tools is a World of Warcraft TBC Classic Anniversary addon that builds a compact raid consumable and buff matrix for raid leaders, assistants, or anyone who wants a local snapshot.

## License

This project is licensed under the MIT License. See [LICENSE](/Users/maarten.seutens/Documents/gert/LICENSE).

## Install

1. Create or open your TBC Classic Anniversary addons directory.
2. Install this repo as:
   `Interface/AddOns/GoodEnoughRaidTools`
3. Ensure the addon folder contains `GoodEnoughRaidTools.toc`.

## CurseForge Distribution

To have the addon managed by the CurseForge app, the addon must exist as a real CurseForge project and have at least one approved `Release` file. CurseForge's author docs state that project creation starts in the author dashboard, file uploads must be `.zip`, and a project needs an approved `Release` or `Beta` file to sync into the CurseForge app.

This repo now includes:

- `scripts/build-release.sh` to build `dist/GoodEnoughRaidTools.zip`
- `.github/workflows/curseforge-release.yml` to upload a tagged release through the CurseForge upload API

What you still need to do outside the repo:

1. Create the WoW addon project in the CurseForge author dashboard.
2. Copy the project ID from the CurseForge project URL.
3. Generate a CurseForge API token.
4. Add GitHub repository secrets:
   - `CURSEFORGE_API_TOKEN`
   - `CURSEFORGE_PROJECT_ID`
5. Verify `CURSEFORGE_GAME_VERSION_NAMES` in the workflow matches the exact CurseForge game version names before the first upload. The current workflow is set to:
   - `2.5.5`
6. Push a tag like `v1.0.2` to trigger the upload workflow.

Local package build:

- `bash scripts/build-release.sh`

Important:

- Do not use GitHub's auto-generated source zip for manual addon installs. It extracts to a repository-style folder name such as `Good-Enough-Raid-Tools-1.0.2`, which WoW will not load as the addon folder.
- Use the packaged addon archive `GoodEnoughRaidTools.zip` instead. It extracts to `GoodEnoughRaidTools/`, which matches `GoodEnoughRaidTools.toc`.

## Commands

- `/gert` toggles the matrix window.
- `/gert scan` refreshes the local roster scan.
- `/gert report [all|category]` reports missing statuses and visible buffs expiring in under 4 minutes for all categories or one category.
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
- Public reports count both missing categories and categories with visible tracked buffs expiring in under 4 minutes.
- Category opt-outs suppress public name mentions for both missing and expiring entries.
- The addon listens for whispers:
  - `gert unsub foodbuff`
  - `gert unsub flask`
  - `gert unsub all`
  - `gert sub foodbuff`
  - `gert sub all`
- Opt-outs only affect public reports.
- The local matrix always keeps the reporter's full scan data visible.

## Matrix States

- `OK` means the category is present.
- `WARN` means the category is present but the visible tracked buff expires in under 4 minutes.
- `MISS` means the category is missing.
- `?` means the addon could not make a reliable determination.

## Limitations

- V1 only scans active visible buffs on units.
- Expiry warnings use a fixed 4 minute threshold.
- Expiry warnings only appear when `UnitBuff` exposes reliable duration and expiration data for the visible tracked buff.
- It does not inspect bags.
- It does not infer potion readiness.
- Unreliable checks should remain `unknown`.
- Consumable coverage depends on detectable buffs and practical spell ID coverage.

## Verification

- Run `node scripts/verify.js` for local repo checks.
- Run `bash scripts/build-release.sh` and confirm it creates `dist/GoodEnoughRaidTools.zip`.
- Confirm the addon loads under TBC Classic Anniversary with interface `20505`.
- Confirm `/gert` opens the window and the Scan and Report buttons work.
- Confirm expiring visible buffs render as `WARN` in the matrix and count in `/gert report`.
- Confirm public reporting is only allowed for raid leaders or assistants.
- Confirm whisper opt-out commands receive a confirmation whisper.
