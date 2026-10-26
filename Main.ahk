#Requires AutoHotkey v2.0
#SingleInstance Force

; =====================================================================================
;  Skinnypigthe2nd's Anime Adventure Mango
;  https://github.com/MrCheeseThe1st/Anime-Adventure-Mango
;
;  Based on Ryn's Anime Adventures Macro (free v0.2.7) by Ryn (@TheRealTension)
;  https://github.com/itsRynsRoblox/Anime-Adventures-Redux - shared with Ryn's permission.
;  All credit for the original macro goes to Ryn. See README.md for what changed.
; =====================================================================================
SendMode "Event"
TraySetIcon("Images\Icon.ico")
CoordMode "Mouse", "Client"

/*if !A_IsAdmin {
    result := MsgBox(
        "Some features may require administrator privileges to work correctly.`n`n"
        "Would you like to restart the macro as an administrator?`n`n"
        "• Yes — Restart with administrator privileges`n"
        "• No — Continue without administrator privileges",
        "Administrator Mode",
        "YesNo Icon!"
    )

    if (result = "Yes") {
        try {
            Run('*RunAs "' A_ScriptFullPath '"')
            ExitApp
        } catch {
            MsgBox(
                "Unable to restart as administrator.`n`n"
                "You can continue without administrator privileges.",
                "Administrator Mode",
                "Iconx"
            )
        }
    }
}*/

global scriptInitialized := false

; Settings files are written into these folders - a fresh download doesn't have them yet
DirCreate(A_ScriptDir "\Settings\Modes")
DirCreate(A_ScriptDir "\Settings\Export")

; === Testing and Debugging ===
#Include %A_ScriptDir%/lib/Toggles.ahk

; === Main Script ===
#Include %A_ScriptDir%/lib/GUI.ahk
#Include %A_ScriptDir%/lib/Theme.ahk
#Include %A_ScriptDir%/lib/GameMango.ahk

; === Saving and Loading Configs ===
#Include %A_ScriptDir%/lib/Functions/CardManager.ahk
#Include %A_ScriptDir%/lib/Config.ahk

; === Tool Libraries ===
#Include %A_ScriptDir%/lib/Tools/FindText.ahk
#Include %A_ScriptDir%/lib/Tools/Image.ahk
#Include %A_ScriptDir%\Lib\OCR-main\Lib\OCR.ahk
#Include Lib\RapidOcr\ImagePut.ahk
#Include %A_ScriptDir%/lib/Tools/RapidOcr.ahk
#Include %A_ScriptDir%/lib/Tools/jsongo.v2.ahk
#Include %A_ScriptDir%/lib/Tools/WindowFollow.ahk

; === Game Modes ===
#Include %A_ScriptDir%/lib/Modes/Challenge.ahk
#Include %A_ScriptDir%/lib/Modes/Infinity Castle.ahk
#Include %A_ScriptDir%/lib/Modes/Legend Stages.ahk
#Include %A_ScriptDir%/lib/Modes/Portal.ahk
#Include %A_ScriptDir%/lib/Modes/Story.ahk
#Include %A_ScriptDir%/lib/Modes/Raid.ahk

; === Limited Time Game Modes ===
#Include %A_ScriptDir%/lib/Modes/Limited/Events.ahk
#Include %A_ScriptDir%/lib/Modes/Limited/Contracts.ahk
#Include %A_ScriptDir%/lib/Modes/Limited/Fool's Hunt.ahk

; === Core Mechanics ===
#Include %A_ScriptDir%/lib/Functions/Functions.ahk
#Include %A_ScriptDir%/lib/Functions/Matchmaking.ahk
#Include %A_ScriptDir%/lib/Functions/Upgrading.ahk
#Include %A_ScriptDir%/lib/Functions/UnitOverview.ahk
#Include %A_ScriptDir%/lib/Functions/UnitPlacement.ahk
#Include %A_ScriptDir%/lib/Functions/TypeStrategy.ahk
#Include %A_ScriptDir%/lib/Functions/PathPlacement.ahk
#Include %A_ScriptDir%/lib/Functions/AutoAbilityManager.ahk
#Include %A_ScriptDir%/lib/Functions/WalkManager.ahk
#Include %A_ScriptDir%/lib/PlacementPatterns.ahk
#Include %A_ScriptDir%/lib/Functions/TimerManager.ahk
#Include %A_ScriptDir%/lib/Functions/CustomPlacements.ahk
#Include %A_ScriptDir%/lib/Functions/ProfileManager.ahk
#Include %A_ScriptDir%/lib/Functions/CustomRecording.ahk

; === Update Checker ===
#Include %A_ScriptDir%/lib/Functions/UpdateChecker.ahk

; === Webhook Integration ===
#Include %A_ScriptDir%/lib/WebhookSettings.ahk

global scriptInitialized := true
