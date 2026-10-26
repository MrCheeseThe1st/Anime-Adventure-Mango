# Skinnypigthe2nd's Anime Adventure Mango

An AutoHotkey v2 macro for the Roblox game **Anime Adventures**.

## Credits

This macro is built on **Ryn's Anime Adventures Macro** (free v0.2.7) by **Ryn (@TheRealTension)**:
https://github.com/itsRynsRoblox/Anime-Adventures-Redux

Ryn wrote the original macro and gave permission to share this modified version. All credit for the
original goes to Ryn. Skinnypigthe2nd's changes are listed below.

Bundled libraries keep their own authors and licenses: FindText, AHKv2-Gdip, jsongo, OCR, RapidOcr,
ImagePut and Discord-Webhook (see the `Lib` folder).

## What's new compared to Ryn's macro

- **Upgrading through the Unit Overview (F):** reads every unit's level, scrolls long lists, and
  respects per-unit upgrade limits (0-9 or MAX).
- **Even upgrading and even placement.**
- **Placement confirmation** from the Unit Overview count, plus red/blue placement-bubble checking.
- **Unit-Type Strategy:** give each slot a type (Farm, DPS, Support, Buff, Summon) and the macro follows a
  step-by-step place-and-upgrade plan that spends spare money as it goes.
- **Path placement pattern:** finds the enemy path (any path colour) and places units next to it.
- **Custom placements:** click to add spots until Esc, a 15 px duplicate filter, random spot cycling,
  and a fallback to path placement on maps with no saved spots.
- **Stage end and card pop-ups** are handled while placing and upgrading. Return to Lobby keeps clicking
  until the lobby loads.
- **Map detection fixes** (including Spirit Town). When detection fails, the macro saves pictures to
  `Logs\MapDetect` so the problem can be fixed.
- `;` pauses the macro (as well as the normal pause key).
- **Webhook fixes:** every run is sent, with a text-only fallback.

## Install

1. Install [AutoHotkey v2](https://www.autohotkey.com/).
2. Download the latest `.zip` from the
   [Releases page](https://github.com/MrCheeseThe1st/Anime-Adventure-Mango/releases) and unzip it.
3. Run `Main.ahk`. The setup guide opens on the first run.

## Updates

With **Check for updates** turned on, the macro checks this repo's releases when it starts and offers
new versions. Your `Settings` folder is backed up first, and your own settings files are kept.
