# Skinnypigthe2nd's Anime Adventure Mango

An AutoHotkey v2 macro for the Roblox game **Anime Adventures**.

## Credits

This macro is built on **Ryn's Anime Adventures Macro** (free v0.3.6) by **Ryn (@TheRealTension)**:
https://github.com/itsRynsRoblox/Anime-Adventures-Redux

Ryn wrote the original macro and gave permission to share this modified version. All credit for the
original goes to Ryn. Skinnypigthe2nd's changes are listed below.

Bundled libraries keep their own authors and licenses: FindText, AHKv2-Gdip, jsongo, OCR
and Discord-Webhook (see the `Lib` folder).

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

## v1.1.0

- **Merged Ryn's free v0.3.6:** Infinity Castle matchmaking, rewritten end-game screen handling (drop
  clicks, 10% tolerance on end buttons, force reconnect if stuck), updated captcha region and OCR library,
  universal lobby check, map-detection tie-break, Contracts map detection, smoother window dragging,
  window resize without admin, webhook stats fields. RapidOCR removed (it was unused).
- **Captcha fix:** matchmaking now waits for the matchmaking prompt (walks back and forth to find it in
  Event/Infinity Castle) before reading the captcha, using the new captcha region. The 1-minute
  private-server rejoin still applies.
- **Captcha fix:** the auto-ability timer stops when a match ends, so it can't click around in the
  lobby while the captcha is being typed.
- **No more mid-match "Found in lobby" restarts:** the lobby check no longer matches in-game screens.
- **Faster placement:** a placement is confirmed by the unit's upgrade panel popping up (keep the
  game's auto-open upgrade UI on), and the panel is closed right away. The Unit Overview isn't used for
  placing anymore.
- **New Path pattern:** finds the path by toggling P (effects and units are ignored) and reads which way
  the chevrons point. Attackers go in a line right outside the path's edge lines and Farm units
  (Unit Type = Farm) in a second line just outside them, both filling from the start of the path. The
  path is remembered per map, so later matches on the same map start placing right away.

## Install

1. Install [AutoHotkey v2](https://www.autohotkey.com/).
2. Download the latest `.zip` from the
   [Releases page](https://github.com/MrCheeseThe1st/Anime-Adventure-Mango/releases) and unzip it.
3. Run `Main.ahk`. The setup guide opens on the first run.

## Updates

With **Check for updates** turned on, the macro checks this repo's releases when it starts and offers
new versions. Your `Settings` folder is backed up first, and your own settings files are kept.
