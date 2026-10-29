#Requires AutoHotkey v2.0
#SingleInstance Force
#Include %A_ScriptDir%/Lib/Tools/Image.ahk
#Include %A_ScriptDir%/Lib/Functions/Functions.ahk
#Include %A_ScriptDir%/Lib/Theme.ahk

; Application Info
global GameName := "Anime Adventures"
global GameTitle := "Skinnypigthe2nd's Anime Adventure Mango "
global ShortTitle := "Mango" ; Used in window titles
global version := "v1.1.0"
global rblxID := "ahk_exe RobloxPlayerBeta.exe"
; Update Checker
global repoOwner := "MrCheeseThe1st"
global repoName := "Anime-Adventure-Mango"
;Coordinate and Positioning Variables
global WM_SIZING := 0x0214
global WM_SIZE := 0x0005
global targetWidth := 816
global targetHeight := 638
global offsetX := -5
global offsetY := 1
global centerX := 408
global centerY := 320
global successfulCoordinates := []
global totalUnits := Map()
;Statistics Tracking
global mode := ""
global StartTime := A_TickCount
global currentTime := GetCurrentTime()
; Config and Settings
global UnitConfigMap := Map()
;Auto Challenge
global firstStartup := true
; Testing
global waitingState := Map()
;Custom Unit Placement
global waitingForClick := false
global savedCoords := Map()
global placementProfiles := Map()
global placementProfileFile := A_ScriptDir "\Settings\Profiles\PlacementProfiles.json"
; Custom Walk
global recording := false
global allWalks := Map()
global keyDownTimes := Map()
global lastActionTime := 0
global movementProfiles := Map()
global movementProfileFile := A_ScriptDir "\Settings\Profiles\MovementProfiles.json"
; Custom Tiny Task
global allRecordings := Map()
global recordedActions := []
global recordingProfiles := Map()
global recordingProfileFile := A_ScriptDir "\Settings\Profiles\RecordingProfiles.json"
;Nuke Ability
global nukeCoords := { x: 282, y: 291 }
;Hotkeys
global F1Key := "F1"
global F2Key := "F2"
global F3Key := "F3"
global F4Key := "F4"
;Gui creation
global uiBorders := []
global uiBackgrounds := []
global uiTheme := []
global UnitData := []
global MainUI := Gui("+AlwaysOnTop -Caption")
global CardGUI := Gui("+AlwaysOnTop")
global lastlog := ""
global MainUIHwnd := MainUI.Hwnd
global ActiveControlGroup := ""
global ControlGroups := Map()
;Theme colors - loaded from Settings\Theme.ini (defaults if missing) and editable in-app
;(Settings > Customize Theme...). Fills uiTheme[] and uiColors. See Lib\Tools\Theme.ahk
Theme_Init()
;Logs/Save settings
;Custom Pictures
GithubImage := "Images\github-logo.png"
DiscordImage := "Images\another_discord.png"

if !DirExist(A_ScriptDir "\Logs") {
    DirCreate(A_ScriptDir "\Logs")
}

global currentOutputFile := A_ScriptDir "\Logs\LogFile.txt"

if !DirExist(A_ScriptDir "\Settings") {
    DirCreate(A_ScriptDir "\Settings")
}

setupOutputFile()

global CardModeConfigs := Map()   ; modeName -> config Map
global currentCardMode := ""      ; active mode name
global currentConfig := ""      ; active config Map (same object as in CardModeConfigs)

global customDropdowns := [
    "Custom",
    "Planet Greenie",
    "Walled City",
    "Snowy Town",
    "Sand Village",
    "Navy Bay",
    "Fiend City",
    "Spirit World",
    "Ant Kingdom",
    "Magic Town",
    "Haunted Academy",
    "Magic Hills",
    "Space Center",
    "Alien Spaceship",
    "Fabled Kingdom",
    "Ruined City",
    "Puppet Island",
    "Virtual Dungeon",
    "Snowy Kingdom",
    "Dungeon Throne",
    "Mountain Temple",
    "Rain Village",
    "Shibuya District",
    ; Raids
    "Sacred Planet",
    "Strange Town",
    "Cursed Festival",
    "Storm Hideout",
    "Nightmare Train",
    "Future City",
    ; Legend Stages
    "Spirit Town",
    ; Event / other maps the loading-screen detection can recognise
    "Assassin Park",
    "Haunted Mansion",
    "Air Craft",
    "Hellish City"
]

; ========== Constants and Theme Setup ==========
mainWidth := 1364
mainHeight := 697
robloxWidth := 802
; uiColors / uiTheme are created and kept in sync by Theme_Init() / Theme_Apply()

; ========== Helper Functions ==========
AddUI(type, options, text := "", onClickFunc := unset) {
    ctrl := MainUI.Add(type, options, text)
    if IsSet(onClickFunc)
        ctrl.OnEvent("Click", onClickFunc)
    return ctrl
}

AddBorder(x, y, w, h) {
    return MainUI.Add("Text", Format("x{} y{} w{} h{} +Background{}", x, y, w, h, uiColors["Border"]))
}
; ========== GUI Initialization ==========

MainUI.BackColor := uiColors["Background"]
global Webhookdiverter := AddUI("Edit", "x0 y0 w1 h1 +Hidden")

; ===== Game Mode Selection box =====
x := 808, y := 38, w := 500, h := 45
borderColor := uiTheme[1]
fillColor := uiTheme[2]

; Create the four borders and keep references
global gameModeBorders := []
gameModeBorders.Push(AddBorder(x, y + 7, w, 1))           ; Top
gameModeBorders.Push(AddBorder(x, y + h - 1, w, 1))       ; Bottom
gameModeBorders.Push(AddBorder(x, y + 7, 1, h - 7))       ; Left
gameModeBorders.Push(AddBorder(x + w - 1, y + 7, 1, h - 7)) ; Right

; Title text
MainUI.SetFont("s9 Bold c" uiTheme[1])
gameModeTitle := MainUI.Add("Text", "x" x " y" (y - 7) " w" w " Center BackgroundTrans", "Game Mode Selection")
MainUI.SetFont()

; ========== Borders ==========
uiBorders.Push(AddBorder(0, 0, mainWidth, 1))                          ; Top
uiBorders.Push(AddBorder(0, 0, 1, mainHeight))                         ; Left
uiBorders.Push(AddBorder(mainWidth - 1, 0, 1, 630))                    ; Right
uiBorders.Push(AddBorder(mainWidth - 1, 0, 1, mainHeight))            ; Full Right
uiBorders.Push(AddBorder(0, 30, mainWidth - 1, 1))                     ; Under Title
uiBorders.Push(AddBorder(803, 443, 560, 1))                            ; Placement Bottom
uiBorders.Push(AddBorder(803, 527, 560, 1))                            ; Process Bottom
uiBorders.Push(AddBorder(802, 30, 1, 667))                             ; Roblox Right
uiBorders.Push(AddBorder(0, mainHeight - 1, mainWidth, 1))            ; Bottom Line
uiBorders.Push(AddBorder(0, 630, robloxWidth + 0.5, 1))               ; Game Bottom

; ========== Backgrounds ==========
uiBackgrounds.Push(MainUI.Add("Text", Format("x3 y3 w{} h27 +Background{}", mainWidth - 4, uiColors["Background"])))

; ========== Roblox Window Area ==========
global robloxHolder := MainUI.Add("Text", Format("x3 y33 w797 h597 +Background{}", uiColors["RobloxBox"]), "")

; ========== Exit and Minimize Buttons ==========
global exitButton := AddUI("Picture", "x1330 y1 w32 h32 +BackgroundTrans", Exitbutton, (*) => Destroy())
global minimizeButton := AddUI("Picture", "x1305 y3 w27 h27 +Background" uiColors["Background"], Minimize, (*) =>
    minimizeUI())

; ========== Import ==========
global importUnitConfigButton := AddUI("Picture", "x1312 y48 w20 h20 +BackgroundTrans", Import, (*) =>
    LoadUnitSettingsByMode(true))
global exportUnitConfigButton := AddUI("Picture", "x1337 y48 w20 h20 +BackgroundTrans", Export, (*) =>
    SaveSettingsForMode(true))

; ========== Title ==========
MainUI.SetFont("Bold s16 c" uiColors["Primary"], Theme_Get("TitleFont"))
global windowTitle := MainUI.Add("Text", "x10 y2 w1200 h29 +BackgroundTrans", GameTitle "" . "" version)

; ========== Console Label ==========
MainUI.Add("Text", "x805 y501 w558 h25 +Center +BackgroundTrans", "Console")
uiBorders.Push(AddBorder(803, 499, 560, 1)) ; Console Top Border

; ========== Process Text Lines ==========
MainUI.SetFont("norm s11 c" uiColors["Primary"])
global processList := []
baseY := 536

loop 7 {
    yOffset := (A_Index - 1) * 22
    text := ""
    color := uiColors["Primary"]
    if A_Index = 1 {
        text := "➤ By Skinnypigthe2nd · Based on Ryn's macro (@TheRealTension)"
        color := uiColors["ProcessHighlight"]
    }
    process := MainUI.Add("Text", Format("x810 y{} w538 h18 +BackgroundTrans c{}", baseY + yOffset, color), text)
    processList.Push(process)
}

; ========== Transparency ==========
WinSetTransColor(uiColors["RobloxBox"], MainUI)

OpenGuide(*) {
    global GameName

    ; Colours come from the active theme so this window matches the main UI
    gBg := Theme_Get("Background")
    gBody := Theme_Get("Body")
    gHi := Theme_Get("Highlight")
    gSub := Theme_Mix(gBody, gBg, 0.25)     ; secondary text
    gMuted := Theme_Mix(gBody, gBg, 0.50)   ; muted text

    GuideGUI := Gui("+AlwaysOnTop +Resize", ShortTitle " Setup Guide")
    GuideGUI.BackColor := gBg
    GuideGUI.MarginX := 24
    GuideGUI.MarginY := 20
    GuideGUI.SetFont("s10", "Segoe UI")

    try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", GuideGUI.Hwnd, "int", 20, "int*", Theme_DarkInt(gBg), "int", 4)

    ; ── Header ──────────────────────────────────────────
    GuideGUI.SetFont("s16 bold", "Segoe UI")
    GuideGUI.Add("Text", "x24 y20 w700 c" gBody, ShortTitle " Setup Guide")

    GuideGUI.SetFont("s10", "Segoe UI")
    GuideGUI.Add("Text", "x24 y52 w700 c" gMuted,
        "Follow these steps before starting the macro.")

    GuideGUI.Add("Text", "x24 y82 w700 h2 0x10")

    y := 102

    ; ── Step 1: Windows Display Settings ────────────────
    GuideGUI.SetFont("s12 bold", "Segoe UI")
    GuideGUI.Add("Text", "x24 y" y " w700 c" gHi, "01  |  Configure Windows Display Settings")

    y += 32

    GuideGUI.SetFont("s10", "Segoe UI")
    GuideGUI.Add("Text", "x44 y" y " w660 c" gSub, "Open Windows Settings > System > Display and configure the following:")

    y += 30

    GuideGUI.SetFont("s10 bold", "Segoe UI")
    GuideGUI.Add("Text", "x62 y" y " w20 c" gHi " BackgroundTrans", "•")

    GuideGUI.SetFont("s10", "Segoe UI")
    GuideGUI.Add("Text", "x84 y" y " w590 c" gBody " BackgroundTrans", "Display resolution: 1920 × 1080 (Recommended)")

    y += 30

    GuideGUI.SetFont("s10 bold", "Segoe UI")
    GuideGUI.Add("Text", "x62 y" y " w20 c" gHi " BackgroundTrans", "•")

    GuideGUI.SetFont("s10", "Segoe UI")
    GuideGUI.Add("Text", "x84 y" y " w590 c" gBody " BackgroundTrans", "Scale: 100%")

    y += 30

    GuideGUI.SetFont("s10 bold", "Segoe UI")
    GuideGUI.Add("Text", "x62 y" y " w20 c" gHi " BackgroundTrans", "•")

    GuideGUI.SetFont("s10", "Segoe UI")
    GuideGUI.Add("Text", "x84 y" y " w590 c" gBody " BackgroundTrans", "HDR: Disabled")

    y += 38

    GuideGUI.Add("Text", "x24 y" y " w700 h2 0x10")
    y += 22

    ; ── Step 2: Roblox Settings ─────────────────────────
    GuideGUI.SetFont("s12 bold", "Segoe UI")
    GuideGUI.Add("Text", "x24 y" y " w700 c" gHi, "02  |  Configure Roblox Settings")

    y += 32

    GuideGUI.SetFont("s10", "Segoe UI")
    GuideGUI.Add("Text", "x44 y" y " w660 c" gSub, "Open the Roblox in-game settings menu and configure the following:")

    y += 30

    GuideGUI.SetFont("s10 bold", "Segoe UI")
    GuideGUI.Add("Text", "x62 y" y " w20 c" gHi " BackgroundTrans", "•")

    GuideGUI.SetFont("s10", "Segoe UI")
    GuideGUI.Add("Text", "x84 y" y " w590 c" gBody " BackgroundTrans", "Language: English (United States)")

    y += 30

    GuideGUI.SetFont("s10 bold", "Segoe UI")
    GuideGUI.Add("Text", "x62 y" y " w20 c" gHi " BackgroundTrans", "•")

    GuideGUI.SetFont("s10", "Segoe UI")
    GuideGUI.Add("Text", "x84 y" y " w590 c" gBody " BackgroundTrans", "Performance Stats: Off")

    y += 30

    GuideGUI.SetFont("s10 bold", "Segoe UI")
    GuideGUI.Add("Text", "x62 y" y " w20 c" gHi " BackgroundTrans", "•")

    GuideGUI.SetFont("s10", "Segoe UI")
    GuideGUI.Add("Text", "x84 y" y " w590 c" gBody " BackgroundTrans", "Micro Profiler: Off")

    y += 30

    GuideGUI.SetFont("s10 bold", "Segoe UI")
    GuideGUI.Add("Text", "x62 y" y " w20 c" gHi " BackgroundTrans", "•")

    GuideGUI.SetFont("s10", "Segoe UI")
    GuideGUI.Add("Text", "x84 y" y " w590 c" gBody " BackgroundTrans", "Camera Mode: Default (Classic)")

    y += 30

    GuideGUI.SetFont("s10 bold", "Segoe UI")
    GuideGUI.Add("Text", "x62 y" y " w20 c" gHi " BackgroundTrans", "•")

    GuideGUI.SetFont("s10", "Segoe UI")
    GuideGUI.Add("Text", "x84 y" y " w590 c" gBody " BackgroundTrans", "Graphics Mode: Manual")

    y += 30

    GuideGUI.SetFont("s10 bold", "Segoe UI")
    GuideGUI.Add("Text", "x62 y" y " w20 c" gHi " BackgroundTrans", "•")

    GuideGUI.SetFont("s10", "Segoe UI")
    GuideGUI.Add("Text", "x84 y" y " w590 c" gBody " BackgroundTrans", "Graphics Quality: Lowest")

    y += 30

    GuideGUI.SetFont("s10 bold", "Segoe UI")
    GuideGUI.Add("Text", "x62 y" y " w20 c" gHi " BackgroundTrans", "•")

    GuideGUI.SetFont("s10", "Segoe UI")
    GuideGUI.Add("Text", "x84 y" y " w590 c" gBody " BackgroundTrans", "Fullscreen: Disabled")


    y += 30
    
    GuideGUI.SetFont("s10 bold", "Segoe UI")
    GuideGUI.Add("Text", "x62 y" y " w20 c" gHi " BackgroundTrans", "•")

    GuideGUI.SetFont("s10", "Segoe UI")
    GuideGUI.Add("Text", "x84 y" y " w590 c" gBody " BackgroundTrans", "Roblox Font: Default")


    y += 30
    
    GuideGUI.SetFont("s10 bold", "Segoe UI")
    GuideGUI.Add("Text", "x62 y" y " w20 c" gHi " BackgroundTrans", "•")

    GuideGUI.SetFont("s10", "Segoe UI")
    GuideGUI.Add("Text", "x84 y" y " w590 c" gBody " BackgroundTrans",
        "Roblox Font: Default")

    y += 38

    GuideGUI.Add("Text", "x24 y" y " w700 h2 0x10")
    y += 22

    ; ── Step 3: Anime Adventures Settings ───────────────
    GuideGUI.SetFont("s12 bold", "Segoe UI")
    GuideGUI.Add("Text", "x24 y" y " w700 c" gHi, "03  |  Configure Anime Adventures Settings")

    y += 32

    GuideGUI.SetFont("s10", "Segoe UI")
    GuideGUI.Add("Text", "x44 y" y " w660 c" gSub, "Open Anime Adventures settings and make sure these two settings are configured correctly.")

    y += 30

    GuideGUI.SetFont("s10 bold", "Segoe UI")
    GuideGUI.Add("Text", "x62 y" y " w20 c" gHi " BackgroundTrans", "•")

    GuideGUI.SetFont("s10", "Segoe UI")
    GuideGUI.Add("Text", "x84 y" y " w590 c" gBody " BackgroundTrans", "Auto-Skip Waves: Enabled")

    y += 30

    GuideGUI.SetFont("s10 bold", "Segoe UI")
    GuideGUI.Add("Text", "x62 y" y " w20 c" gHi " BackgroundTrans", "•")

    GuideGUI.SetFont("s10", "Segoe UI")
    GuideGUI.Add("Text", "x84 y" y " w590 c" gBody " BackgroundTrans", "Disable Auto-Open Upgrade UI: Disabled")

    y += 30

    GuideGUI.SetFont("s10 bold", "Segoe UI")
    GuideGUI.Add("Text", "x62 y" y " w20 c" gHi " BackgroundTrans", "•")

    GuideGUI.SetFont("s10", "Segoe UI")
    GuideGUI.Add("Text", "x84 y" y " w590 c" gBody " BackgroundTrans", "Show Upgrade UI on Left: Enabled")

    y += 38

    GuideGUI.Add("Text", "x24 y" y " w700 h2 0x10")
    y += 22

    ; ── Step 4: Unit Setup ──────────────────────────────
    GuideGUI.SetFont("s12 bold", "Segoe UI")
    GuideGUI.Add("Text", "x24 y" y " w700 c" gHi, "04  |  Configure Discord Settings")

    y += 32

    GuideGUI.SetFont("s10", "Segoe UI")
    GuideGUI.Add("Text", "x44 y" y " w660 c" gSub,
        "Please ensure that your Discord settings are configured correctly if you are using these features.")

    y += 30

    GuideGUI.SetFont("s10 bold", "Segoe UI")
    GuideGUI.Add("Text", "x62 y" y " w20 c" gHi " BackgroundTrans", "•")

    GuideGUI.SetFont("s10", "Segoe UI")
    GuideGUI.Add("Text", "x84 y" y " w590 c" gBody " BackgroundTrans", "Disable Voice Overlay")

    y += 38

    ; ── Footer ──────────────────────────────────────────
    GuideGUI.Add("Text", "x24 y" y " w700 h2 0x10")
    y += 18

    GuideGUI.SetFont("s10 bold", "Segoe UI")
    GuideGUI.Add("Text", "x24 y" y " w700 Center c" gHi,
        "You're all set. Good luck!")

    y += 42

    ; ── Show Guide ──────────────────────────────────────
    GuideGUI.Show("w748 h" y)
}

OpenDebugMenu(*) {
    static DebugGUI := ""
    if IsObject(DebugGUI) {            ; already open -> just bring it forward
        try {
            DebugGUI.Show()
            return
        }
    }

    ; ---------- Theme ----------
    ; Pulled from the macro's uiTheme array so the menu always matches the main UI.
    ; Order: 1 Header, 2 Background, 3 Highlight, 4 Accent, 5 Trans, 6 Textbox, 7 Highlight
    Hex := (c) => RegExReplace(c, "i)^0x")    ; strips "0x" prefix (e.g. "0x3d3c36")
    bgC := Theme_Get("Background"), bodyC := Theme_Get("Body"), hiC := Theme_Get("Highlight")
    C := {
        bg: bgC,
        panel: Theme_Mix(bgC, bodyC, 0.07),
        accent: hiC,
        accentHi: Theme_Mix(hiC, "FFFFFF", 0.25),
        btn: Theme_Mix(bgC, bodyC, 0.14),
        btnHi: Theme_Mix(bgC, bodyC, 0.24),
        text: bodyC,
        muted: Theme_Mix(bodyC, bgC, 0.45),
        ok: "3fb950",
        busy: "d29922"
    }
    isDark := Theme_DarkInt(bgC)
    W := 520, PAD := 24, IW := W - PAD * 2

    DebugGUI := Gui("+AlwaysOnTop -MaximizeBox", ShortTitle " - Debug Menu")
    DebugGUI.BackColor := C.bg
    DebugGUI.MarginX := PAD
    DebugGUI.MarginY := PAD

    ; Dark title bar (Windows 10 1809+ / 11)
    try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", DebugGUI.Hwnd, "int", 20, "int*", isDark, "int", 4)

    ; ---------- Header ----------
    DebugGUI.SetFont("s17 w700 c" C.text, "Segoe UI")
    DebugGUI.Add("Text", "x" PAD " y18 w" IW, "Debug Menu")
    DebugGUI.SetFont("s9 w400 c" C.muted, "Segoe UI")
    DebugGUI.Add("Text", "x" PAD " y50 w" IW, "Run a detection test and see the result below")
    DebugGUI.Add("Text", "x" PAD " y76 w" IW " h2 Background" C.accent)   ; accent divider

    ; ---------- Test selector ----------
    TestOptions := [
        "Check for the lobby",
        "Check for successful unit placement",
        "Check for results screen",
        "Check for game over options",
        "Check all on-screen cards",
        "Check story map coordinates",
        "Check legend stage map coordinates",
        "Check raid map coordinates",
        "Check captcha numbers",
        "Check for upgrade limit text",
        "Show lobby detection region",
        "Test screen resolution / DPI",
        "Find placement spots around the path",
        "Check the placement bubble",
        "Check the Unit Overview",
        "Check Unit Overview scrolling",
        "Count the units in the Unit Overview",
    ]
    Descriptions := Map(
        "Check for the lobby", "Looks for the lobby screen to confirm you're not in a match.",
        "Check for successful unit placement",
        "Checks whether a unit placement was detected (i.e if the unit interface active).",
        "Check for results screen", "Looks for the game-over / results screen.",
        "Check for game over options", "Looks for the replay / return to lobby options.",
        "Check all on-screen cards", "Scans the card selection screen for all cards.",
        "Check story map coordinates", "Ensure that the story maps interface is open and scrolled to the top.",
        "Check legend stage map coordinates", "Ensure that the legend stage maps interface is open and scrolled to the top.",
        "Check raid map coordinates", "Ensure that the raid maps interface is open and scrolled to the top.",
        "Check captcha numbers", "Ensure that the captcha numbers are correct.",
        "Check for upgrade limit text", "Check all upgrade limit text currently displayed.",
        "Show lobby detection region", "Shows a red box around the lobby detection region.",
        "Test screen resolution / DPI", "Reports your resolution and DPI scaling for troubleshooting.",
        "Check the placement bubble", "Hold a unit and rest the mouse on a spot. The mouse jumps away and back to compare - reports whether the bubble reads as red (can't place).",
        "Find placement spots around the path", "In a match: clicks P 4 times to find the path, then shows the spots - cyan/white by the path, orange for Farm units.",
        "Check the Unit Overview", "Opens the Unit Overview (F) and reports each card's level, Max state and Upg button position.",
        "Check Unit Overview scrolling", "Needs more units than fit on screen. Calibrates scrolling, then scrolls to every card.",
        "Count the units in the Unit Overview", "In a match: counts the placed units the way the macro does when its own count is off (scrolls up from the bottom).",
    )

    DebugGUI.SetFont("s9 w700 c" C.muted, "Segoe UI")
    DebugGUI.Add("Text", "x" PAD " y94 w" IW, "Debug Selections")
    DebugGUI.SetFont("s10 w400 c" C.text, "Segoe UI")
    DDL := DebugGUI.Add("DropDownList", "x" PAD " y114 w" IW " Background" C.panel, TestOptions)
    DDL.Choose(1)
    if isDark
        try DllCall("uxtheme\SetWindowTheme", "ptr", DDL.Hwnd, "str", "DarkMode_CFD", "str", "")

    DebugGUI.SetFont("s9 w400 c" C.muted, "Segoe UI")
    DescText := DebugGUI.Add("Text", "x" PAD " y150 w" IW " h20", Descriptions[TestOptions[1]])
    DDL.OnEvent("Change", (*) => DescText.Text := Descriptions[DDL.Text])

    ; ---------- Log ----------
    DebugGUI.SetFont("s9 w700 c" C.muted, "Segoe UI")
    DebugGUI.Add("Text", "x" PAD " y184 w120", "RESULT / LOG")
    DebugGUI.SetFont("s9 w700 c" C.ok, "Segoe UI")
    StatusText := DebugGUI.Add("Text", "x" (W - PAD - 160) " y184 w160 Right", "● Ready")

    DebugGUI.SetFont("s9 w400 c" C.text, "Consolas")
    ResultEdit := DebugGUI.Add("Edit", "x" PAD " y206 w" IW " h150 Multi ReadOnly -E0x200 Background" C.panel,
        "Ready...")
    if isDark
        try DllCall("uxtheme\SetWindowTheme", "ptr", ResultEdit.Hwnd, "str", "DarkMode_Explorer", "str", "")

    ; ---------- Buttons (flat, with hover) ----------
    Buttons := Map()
    AddButton(label, x, w, normal, hover, callback) {
        DebugGUI.SetFont("s10 w700 c" C.text, "Segoe UI")
        ctrl := DebugGUI.Add("Text", "x" x " y376 w" w " h40 +0x200 Center Background" normal, label)
        ctrl.OnEvent("Click", callback)
        Buttons[ctrl.Hwnd] := { ctrl: ctrl, normal: normal, hover: hover, on: false }
        return ctrl
    }

    gap := 12
    wMain := 200, wSide := (IW - wMain - gap * 2) // 2
    AddButton("▶  Test Selected", PAD, wMain, C.accent, C.accentHi, RunTest)
    AddButton("Clear Log", PAD + wMain + gap, wSide, C.btn, C.btnHi, (*) => ClearLog())
    AddButton("Close", PAD + wMain + wSide + gap * 2, wSide, C.btn, C.btnHi, (*) => CloseGui())

    ; ---------- Handlers ----------
    RunTest(*) {
        StatusText.SetFont("c" C.busy), StatusText.Text := "● Running..."
        try RunDebugTest(DDL.Text, "", ResultEdit)
        catch as err
            ResultEdit.Value .= "`r`nError: " err.Message
        StatusText.SetFont("c" C.ok), StatusText.Text := "● Done"
    }
    ClearLog() {
        ResultEdit.Value := ""
        StatusText.SetFont("c" C.ok), StatusText.Text := "● Ready"
    }
    CloseGui(*) {
        OnMessage(0x200, OnHover, 0)
        DebugGUI.Destroy()
        DebugGUI := ""
    }
    OnHover(*) {
        MouseGetPos(, , , &hCtrl, 2)
        for hwnd, b in Buttons {
            over := (hwnd = hCtrl)
            if (over != b.on) {
                b.on := over
                b.ctrl.Opt("Background" (over ? b.hover : b.normal))
                b.ctrl.Redraw()
            }
        }
    }
    OnMessage(0x200, OnHover)               ; WM_MOUSEMOVE
    DebugGUI.OnEvent("Close", CloseGui)
    DebugGUI.OnEvent("Escape", CloseGui)
    FocusSink := DebugGUI.Add("Button", "x-50 y-50 w1 h1")
    DebugGUI.Show("w" W " h" 376 + 40 + PAD)
    FocusSink.Focus()
}

; ========== Test runner ==========
RunDebugTest(selected, customCode, ResultEdit) {
    ResultEdit.Value := "Running: " selected "`n`n"

    try {
        if (!WinActive(rblxID)) {
            WinActivate(rblxID)
            Sleep 1000
        }
        switch selected {
            case "Check for the lobby":
                ResultEdit.Value .= "Checking for the lobby...`n"
                result := CheckForLobby()
                ResultEdit.Value .= result ? "Found!" : "Not found"

            case "Check for successful unit placement":
                answer := InputBox("How many units are placed right now?", "Unit placement check", "w260 h110")
                if (answer.Result != "OK" || !IsInteger(answer.Value) || Integer(answer.Value) < 1) {
                    ResultEdit.Value .= "Cancelled"
                } else {
                    WinActivate(rblxID)
                    Sleep(500)
                    ResultEdit.Value .= "Checking the Unit Overview for " answer.Value " units...`n"
                    result := OverviewHasUnits(Integer(answer.Value))
                    CloseUnitOverview()
                    ResultEdit.Value .= result ? "Count matches - placement check works" : "Count doesn't match"
                }

            case "Check for results screen":
                ResultEdit.Value .= "Checking for results screen...`n"
                result := CheckForXP(false, false)
                ResultEdit.Value .= result ? "Results screen found!" : "Results screen not found"

            case "Check for game over options":
                ResultEdit.Value .= "Checking for game over options...`n"
                result := CheckAllGameOptions(&report)
                ResultEdit.Value .= report

            case "Check all on-screen cards":
                count := CheckForActiveCards("", &report, true)
                ResultEdit.Value .= report

            case "Check story map coordinates":
                ResultEdit.Value .= "Testing all story maps...`n"
                TestAllStoryMaps()

            case "Check legend stage map coordinates":
                ResultEdit.Value .= "Testing all legend stage maps...`n"
                TestAllLegendMaps()

            case "Check raid map coordinates":
                ResultEdit.Value .= "Testing all raid maps...`n"
                TestAllRaidMaps()

            case "Check the Unit Overview":
                ResultEdit.Value .= "Reading the Unit Overview...`n"
                ResultEdit.Value .= TestUnitOverview()

            case "Check Unit Overview scrolling":
                answer := InputBox("How many units are placed right now?", "Unit Overview scrolling", "w260 h110")
                if (answer.Result != "OK" || !IsInteger(answer.Value) || Integer(answer.Value) < 1) {
                    ResultEdit.Value .= "Cancelled"
                } else {
                    WinActivate(rblxID)
                    Sleep(500)
                    ResultEdit.Value .= "Calibrating and scrolling (don't touch the mouse)...`n"
                    ResultEdit.Value .= TestOverviewScrolling(Integer(answer.Value))
                }

            case "Count the units in the Unit Overview":
                WinActivate(rblxID)
                Sleep(500)
                ResultEdit.Value .= "Counting (don't touch the mouse)...`n"
                n := CountOverviewUnits()
                CloseUnitOverview()
                ResultEdit.Value .= (n < 0 ? "Couldn't count the units" : "Counted " n " unit" (n = 1 ? "" : "s"))

            case "Check the placement bubble":
                ResultEdit.Value .= "Hold a unit and rest the mouse on a spot - checking in 3 seconds...`n"
                Sleep(3000)
                CoordMode("Mouse", "Client")
                MouseGetPos(&bx, &by)
                red := PlacementBubbleIsRed(bx, by, &score, &share)
                ResultEdit.Value .= (red ? "RED - this spot would be skipped" : "Not red - the script would try to place here")
                    . "`n(tint change " score " - below 0 is redder, above 0 bluer; " share "% of samples turned redder."
                    . " Red needs change <= -12 and >= 55%)"

            case "Find placement spots around the path":
                ResultEdit.Value .= "Scanning for the path...`n"
                ResultEdit.Value .= TestPathSpots()
            case "Check captcha numbers":
                ResultEdit.Value .= "Testing all captcha numbers...`n"
                CaptchaDetect(235, 262, 569, 309, 400, 335, true, false, ResultEdit)

            case "Check for upgrade limit text":
                TestUpgradeLimitTexts(ResultEdit)

            case "Show lobby detection region":
                ResultEdit.Value .= "Showing lobby detection region...`n"
                ShowRegionByCoords(11, 557, 45, 591, 5000, rblxID)

            case "Test screen resolution / DPI":
                ResultEdit.Value .= "Screen: " A_ScreenWidth "x" A_ScreenHeight ""
                ResultEdit.Value .= "`nDPI: " A_ScreenDPI
        }
    } catch as err {
        ResultEdit.Value .= "ERROR: " err.Message
    }
}

OpenPrivateServerGuide(*) {
    GuideGUI := Gui("+AlwaysOnTop +Resize", ShortTitle " Private Server Guide")
    GuideGUI.BackColor := Theme_Get("Background")
    GuideGUI.MarginX := 20
    GuideGUI.MarginY := 20

    ; Reset font for steps
    GuideGUI.SetFont("s12 bold", "Segoe UI")

    ; Add each step individually
    GuideGUI.Add("Text", "c" Theme_Get("Body"), "Step 1. Create a private server")
    GuideGUI.Add("Text", "c" Theme_Get("Body"), "Step 2. Name the server however you like")
    GuideGUI.Add("Text", "c" Theme_Get("Body"), "Step 3. Configure the private server")
    GuideGUI.Add("Text", "c" Theme_Get("Body"), "Step 4. Generate a link for the server")
    GuideGUI.Add("Text", "c" Theme_Get("Body"), "Step 5. Paste the link into your browser")
    GuideGUI.Add("Text", "c" Theme_Get("Body"), "Step 6. Wait for the link to change into the new version")
    GuideGUI.Add("Text", "c" Theme_Get("Body"), "Step 7. Copy the URL")
    GuideGUI.Add("Text", "c" Theme_Get("Body"), "Step 8. Paste the URL into the private server section of the macro")
    GuideGUI.Add("Text", "c" Theme_Get("Body"), "It should look like this at the end: privateServerLinkCode=12345")

    ; Show GUI
    GuideGUI.Show("AutoSize Center")
}

MainUI.SetFont("s9 Bold c" uiTheme[1])

ActiveConfigurationText := MainUI.Add("Text", "x840 y7 +Center c" uiTheme[1], "Active Configuration: ")
ConfigurationDropdown := MainUI.Add("DropDownList", "x990 y4.5 w110 h180 +Center Choose1", ["Unit", "Cards", "Movement", "Mode", "Placement", "Upgrade", "Recording", "Debug"])
ConfigurationDropdown.OnEvent("Change", UpdateActiveConfiguration)

global guideBtn := MainUI.Add("Button", "x1108 y5 w90 h20", "Guide")
guideBtn.OnEvent("Click", OpenGuide)

global settingsBtn := MainUI.Add("Button", "x1208 y5 w90 h20", "Settings")
settingsBtn.OnEvent("Click", (*) => ToggleControlGroup("Settings"))

placementSaveBtn := MainUI.Add("Button", "x807 y471 w80 h20", "Save")
placementSaveBtn.OnEvent("Click", (*) => SaveSettingsForMode())

MainUI.SetFont("s9")

global NextLevelBox := MainUI.Add("Checkbox", "x900 y451 cffffff", "Next Level")
global ReturnLobbyBox := MainUI.Add("CheckBox", "x1005 y451 cffffff", "Return To Lobby")
global TypeStrategyBox := MainUI.Add("CheckBox", "x1135 y451 cffffff", "Unit-Type Strategy")

global MatchMaking := MainUI.Add("Checkbox", "x900 y476 cffffff", "Matchmaking")

;Fool's Hunt Options
global BringOwnTeam := MainUI.Add("CheckBox", "x1015 y476 cffffff", "Bring your own units")

;Contract Options
global TeamSwap := MainUI.Add("CheckBox", "x1015 y476 cffffff", "Allow Team Swaps")
PhysicalTeamText := MainUI.Add("Text", "x1135 y451 w115 h20 +Center", "Physical Team")
global PhysicalTeam := MainUI.Add("DropDownList", "x1170 y471 w45 h180 Choose1 +Center", ["1", "2", "3", "4", "5", "6"])
MagicTeamText := MainUI.Add("Text", "x1250 y451 w80 h20 +Center", "Magic Team")
global MagicTeam := MainUI.Add("DropDownList", "x1270 y471 w45 h180 Choose1 +Center", ["1", "2", "3", "4", "5", "6"])

;Portal Options
global SwapFromPortal := MainUI.Add("CheckBox", "x1015 y476 cffffff", "Rotate Portals / Infinite when out of portals")

PlacementPatternText := MainUI.Add("Text", "x815 y390 w125 h20", "Placement Pattern")
global PlacementPatternDropdown := MainUI.Add("DropDownList", "x825 y410 w100 h180 Choose1 +Center", ["Circle",
    "Custom", "Grid", "3x3 Grid", "Spiral", "Up and Down", "Random", "Path"])

PlaceSpeedText := MainUI.Add("Text", "x1030 y390 w115 h20", "Placement Speed")
global PlaceSpeed := MainUI.Add("DropDownList", "x1035 y410 w100 h180 Choose3 +Center", ["Super Fast (1s)", "Fast (1.5s)", "Default (2s)", "Slow (2.5s)", "Very Slow (3s)", "Toaster (4s)"])

PlacementSelectionText := MainUI.Add("Text", "x1235 y390 w125 h20", "Placement Order")
global PlacementSelection := MainUI.Add("DropDownList", "x1240 y410 w100 h180 Choose1 +Center", ["Default",
    "By Priority", "Evenly"])

;=== Card Config GUI ===
global CardBorder := MainUI.Add("GroupBox", "x808 y85 w550 h296 +Center Hidden c" uiTheme[1], "Card Priority")

global FoolsHuntCardText := MainUI.Add("Text", "x825 y110 Hidden cffffff", "Fool's Hunt Cards: ")
global FoolsHuntCardButton := MainUI.Add("Button", "x975 y108 w80 h20 Hidden cffffff", "Edit Cards")
FoolsHuntCardButton.OnEvent("Click", (*) => SwitchCardMode("Fool's Hunt", true))

; === Event Configuration ===
global EventBorder := MainUI.Add("GroupBox", "x808 y85 w550 h296 +Center Hidden c" uiTheme[1], "Event Configuration")

placementSaveText := MainUI.Add("Text", "x807 y451 w80 h20", "Save Config")

Hotkeytext := MainUI.Add("Text", "x807 y35 w200", F1Key ": Fix Roblox Position")
Hotkeytext2 := MainUI.Add("Text", "x807 y50 w200", F2Key ": Start Macro")
Hotkeytext3 := MainUI.Add("Text", "x807 y65 w200", F3Key ": Stop Macro")

DiscordButton := MainUI.Add("Picture", "x30 y645 w60 h34 BackgroundTrans", DiscordImage)
; === End of Custom Walk Settings ===

; === Settings GUI ===
global WebhookBorder := MainUI.Add("GroupBox", "x808 y85 w550 h296 +Center Hidden c" uiTheme[1], "Webhook Settings")
global WebhookEnabled := MainUI.Add("CheckBox", "x825 y110 Hidden cffffff", "Webhook Enabled")
WebhookEnabled.OnEvent("Click", (*) => ValidateWebhook())
global WebhookLogsEnabled := MainUI.Add("CheckBox", "x825 y130 Hidden cffffff", "Send Console Logs")
global WebhookURLBox := MainUI.Add("Edit", "x1000 y108 w260 h20 Hidden c" uiTheme[6], "")
WebhookURLBox.OnEvent("Change", UpdateWebhookURL)

global PrivateSettingsBorder := MainUI.Add("GroupBox", "x808 y145 w550 h236 +Center Hidden c" uiTheme[1], "Reconnection Settings")
global PrivateServerEnabled := MainUI.Add("CheckBox", "x825 y165 Hidden cffffff", "Reconnect to Private Server")
global PrivateServerURLBox := MainUI.Add("Edit", "x1050 y163 w160 h20 Hidden c" uiTheme[6], "")
PrivateServerTestButton := MainUI.Add("Button", "x1225 y163 w50 h20 Hidden", "Test")
PrivateServerTestButton.OnEvent("Click", (*) => Reconnect(true))
PrivateServerGuideButton := MainUI.Add("Button", "x1285 y163 w50 h20 Hidden", "Guide")
PrivateServerGuideButton.OnEvent("Click", OpenPrivateServerGuide)
global TeleportFailsafe := MainUI.Add("CheckBox", "x825 y185 Hidden cffffff", "Enable Teleport Failsafe")
global TeleportFailsafeTimerText := MainUI.Add("Text", "x1050 y188 h20 Hidden c" uiTheme[1], "Time until reconnect:")
global TeleportFailsafeTimer := MainUI.Add("Edit", "x1195 y186 w50 h20 Hidden Number c" uiTheme[6], "60")
; === End of Settings GUI ===

; HotKeys
global KeybindBorder := MainUI.Add("GroupBox", "x808 y205 w195 h176 +Center Hidden c" uiTheme[1], "Keybind Settings")
global F1Text := MainUI.Add("Text", "x825 y230 Hidden c" uiTheme[1], "Position Roblox:")
global F1Box := MainUI.Add("Edit", "x950 y228 w30 h20 Hidden c" uiTheme[6], F1Key)
global F2Text := MainUI.Add("Text", "x825 y260 Hidden c" uiTheme[1], "Start Macro:")
global F2Box := MainUI.Add("Edit", "x950 y258 w30 h20 Hidden c" uiTheme[6], F2Key)
global F3Text := MainUI.Add("Text", "x825 y290 Hidden c" uiTheme[1], "Stop Macro:")
global F3Box := MainUI.Add("Edit", "x950 y288 w30 h20 Hidden c" uiTheme[6], F3Key)
global F4Text := MainUI.Add("Text", "x825 y320 Hidden c" uiTheme[1], "Pause Macro:")
global F4Box := MainUI.Add("Edit", "x950 y318 w30 h20 Hidden c" uiTheme[6], F4Key)

keybindSaveBtn := MainUI.Add("Button", "x880 y350 w50 h20 Hidden", "Save")
keybindSaveBtn.OnEvent("Click", SaveKeybindSettings)

global UpgradeBorder := MainUI.Add("GroupBox", "x808 y85 w550 h296 +Center Hidden c" uiTheme[1], "Upgrade Settings")
global EnableUpgrading := MainUI.Add("CheckBox", "x825 y110 Hidden cffffff Checked", "Enable Upgrading")
global UnitManagerUpgradeSystem := MainUI.Add("CheckBox", "x825 y130 Hidden cffffff", "Use the Unit Overview (F) to upgrade your units")
global PriorityUpgrade := MainUI.Add("CheckBox", "x825 y150 cffffff Hidden Checked",  "Use Unit Priority while upgrading")
global EvenUpgrade := MainUI.Add("CheckBox", "x825 y170 cffffff Hidden", "Upgrade evenly (one level per unit, in priority order, repeating)")

global ZoomSettingsBorder := MainUI.Add("GroupBox", "x1000 y205 w165 h176 +Center Hidden c" uiTheme[1], "Zoom Tech Settings")
global ZoomText := MainUI.Add("Text", "x1018 y230 Hidden c" uiTheme[1], "Zoom Level:")
global ZoomBox := MainUI.Add("Edit", "x1115 y228 w30 h20 Hidden cBlack Number", "20")
global ZoomTech := MainUI.Add("Checkbox", "x1018 y260 Hidden Checked c" uiTheme[1], "Enable Zoom Tech")
global ZoomInOption := MainUI.Add("Checkbox", "x1018 y290 Hidden Checked c" uiTheme[1], "Zoom in then out")
global ZoomTeleport := MainUI.Add("Checkbox", "x1018 y320 Hidden Checked c" uiTheme[1], "Teleport to spawn")
ZoomBox.OnEvent("Change", (*) => ValidateEditBox(ZoomBox))

global MiscSettingsBorder := MainUI.Add("GroupBox", "x1163 y205 w195 h176 +Center Hidden c" uiTheme[1], "Misc Settings"
)
global UpdateChecker := MainUI.Add("Checkbox", "x1175 y230 Hidden cffffff Checked", "Enable update checker")
global ForceCheckUpdateButton := MainUI.Add("Button", "x1195 y260 h20 Hidden", "Check for updates")
ForceCheckUpdateButton.OnEvent("Click", (*) => CheckForUpdates())

global ModeBorder := MainUI.Add("GroupBox", "x808 y85 w550 h296 +Center Hidden c" uiTheme[1], "Mode Configuration")
global ModeConfigurations := MainUI.Add("CheckBox", "x825 y110 Hidden cffffff", "Enable Per-Mode Unit Settings")

global StoryBorder := MainUI.Add("GroupBox", "x808 y85 w550 h296 +Center Hidden c" uiTheme[1], "Story Settings")
global NightmareDifficulty := MainUI.Add("CheckBox", "x825 y110 Hidden cffffff", "Nightmare Difficulty")

global PortalBorder := MainUI.Add("GroupBox", "x808 y85 w550 h296 +Center Hidden c" uiTheme[1], "Portal Settings")
global PortalLobby := MainUI.Add("CheckBox", "x825 y280 Hidden cffffff", "Starting portal from the lobby")
; === End Unit Config GUI ===

; === Custom Recording GUI ===
global RecordBorder := MainUI.Add("GroupBox", "x808 y85 w550 h296 +Center Hidden c" uiTheme[1], "Custom Recording Configuration")
global RecordMapText := MainUI.Add("Text", "x875 y110 Hidden cffffff", "Map:")
global RecordMapDropdown := MainUI.Add("DropDownList", "x915 y108 w200 h180 Choose1 +Center Hidden", customDropdowns)
AddRecordingProfileButton := MainUI.Add("Picture", "x1120 y103 w15 h15 Hidden", Add)
AddRecordingProfileButton.OnEvent("Click", (*) => AddRecordingProfile())
DeleteRecordingProfileButton := MainUI.Add("Picture", "x1120 y118 w15 h15 Hidden", Trash)
DeleteRecordingProfileButton.OnEvent("Click", (*) => DeleteRecordingProfile())
ImportRecording := MainUI.Add("Picture", "x820 y108 w20 h20 +BackgroundTrans Hidden", Import)
ImportRecording.OnEvent("Click", ImportRecordings)
ExportRecording := MainUI.Add("Picture", "x845 y108 w20 h20 +BackgroundTrans Hidden", Export)
ExportRecording.OnEvent("Click", (*) => ExportRecordings(RecordMapDropdown.Text))
global ShouldUseRecording := MainUI.Add("CheckBox", "x825 y140 Hidden cffffff",
    "Use custom recording instead of the default macro")
global ShouldUseSetup := MainUI.Add("CheckBox", "x825 y170 Hidden cffffff",
    "Use the macro's setup feature (zoom, walk to custom path)")
global ShouldHandleGameEnd := MainUI.Add("CheckBox", "x825 y230 Hidden cffffff",
    "Automatically restart recording when/if the game ends")
global ShouldLoopRecording := MainUI.Add("CheckBox", "x825 y200 Hidden cffffff", "Loop recorded actions infintely")
RecordStartButton := MainUI.Add("Button", "x1140 y110 w60 h20 Hidden", "Set")
RecordStartButton.OnEvent("Click", StartRecordingActionsForMap)
RecordClearButton := MainUI.Add("Button", "x1215 y110 w60 h20 Hidden", "Clear")
RecordClearButton.OnEvent("Click", ClearRecordings)
RecordTestButton := MainUI.Add("Button", "x1290 y110 w60 h20 Hidden", "Test")
RecordTestButton.OnEvent("Click", (*) => PlayRecordedActions())
RecordImport := MainUI.Add("Picture", "x820 y108 w20 h20 +BackgroundTrans Hidden", Import)

;=== Custom Walk GUI ===
global CustomWalkBorder := MainUI.Add("GroupBox", "x808 y85 w550 h296 +Center Hidden c" uiTheme[1],
    "Custom Walk Configuration")
global WalkMapText := MainUI.Add("Text", "x875 y110 Hidden cffffff", "Map:")
global WalkMapDropdown := MainUI.Add("DropDownList", "x915 y108 w200 h180 Choose1 +Center Hidden", customDropdowns)
WalkMapDropdown.OnEvent("Change", UpdateWalkListView)
AddMovementProfileButton := MainUI.Add("Picture", "x1120 y103 w15 h15 Hidden", Add)
AddMovementProfileButton.OnEvent("Click", (*) => AddMovementProfile())
DeleteMovementProfileButton := MainUI.Add("Picture", "x1120 y118 w15 h15 Hidden", Trash)
DeleteMovementProfileButton.OnEvent("Click", (*) => DeleteMovementProfile())
MovementSetButton := MainUI.Add("Button", "x1140 y110 w60 h20 +BackgroundTrans Hidden", "Set")
MovementSetButton.OnEvent("Click", StartRecordingWalk)
MovementClearButton := MainUI.Add("Button", "x1215 y110 w60 h20 Hidden", "Clear")
MovementClearButton.OnEvent("Click", ClearMovement)
MovementTestButton := MainUI.Add("Button", "x1290 y110 w60 h20 Hidden", "Test")
MovementTestButton.OnEvent("Click", (*) => StartWalk(true))
MovementImport := MainUI.Add("Picture", "x820 y108 w20 h20 +BackgroundTrans Hidden", Import)
MovementImport.OnEvent("Click", (*) => ImportMovements())
MovementExport := MainUI.Add("Picture", "x845 y108 w20 h20 +BackgroundTrans Hidden", Export)
MovementExport.OnEvent("Click", (*) => ExportMovements(WalkMapDropdown.Text))

global WalkTipText := MainUI.Add("Text", "x825 y140 w510 h105 Hidden cffffff",
    "Useful Information: Press Left Shift to stop recording" .
    "`n`nNote: Some map movements may be incorrect due to multiple spawn angles" .
    "`n`nCurrent Recorded Movements:")

global WalkListView := MainUI.Add("ListView", "x825 y215 w420 h150 Hidden -Multi cBlack", ["#", "Direction", "Duration",
    "Delay"])
WalkListView.OnEvent("DoubleClick", EditSelectedMovement)
global WalkRemoveBtn := MainUI.Add("Button", "x1255 y215 w80 h25 Hidden", "Remove")
WalkRemoveBtn.OnEvent("Click", RemoveSelectedMovement)
global WalkEditBtn := MainUI.Add("Button", "x1255 y280 w80 h25 Hidden", "Edit")
WalkEditBtn.OnEvent("Click", EditSelectedMovement)
;=== Custom Placement GUI ===
global CustomPlacementBorder := MainUI.Add("GroupBox", "x808 y85 w550 h296 +Center Hidden c" uiTheme[1],
    "Custom Placement Configuration")

; --- Toolbar ---
global PlacementSettingsImportButton := MainUI.Add("Picture", "x820 y105 w20 h20 +BackgroundTrans Hidden", Import)
PlacementSettingsImportButton.OnEvent("Click", (*) => ImportCustomCoords())
global PlacementSettingsExportButton := MainUI.Add("Picture", "x845 y105 w20 h20 +BackgroundTrans Hidden", Export)
PlacementSettingsExportButton.OnEvent("Click", (*) => ExportCustomCoords(CustomPlacementMapDropdown.Text))

; --- Centered preset cluster (box center ≈ x1083) ---
global CustomPlacementMap := MainUI.Add("Text", "x940 y105 w55 h24 +0x200 +Right Hidden cffffff", "Preset:")
global CustomPlacementMapDropdown := MainUI.Add("DropDownList", "x1002 y106 w200 h200 +Center Hidden", customDropdowns)
CustomPlacementMapDropdown.OnEvent("Change", UpdatePlacementListView)
global AddCustomPlacementProfile := MainUI.Add("Picture", "x1210 y101 w15 h15 +BackgroundTrans Hidden", Add)
AddCustomPlacementProfile.OnEvent("Click", (*) => AddPlacementProfile())
global RemoveCustomPlacementProfile := MainUI.Add("Picture", "x1210 y118 w15 h15 +BackgroundTrans Hidden", Trash)
RemoveCustomPlacementProfile.OnEvent("Click", (*) => DeletePlacementProfile())

global fixCameraButton := MainUI.Add("Button", "x1245 y105 w100 h24 Hidden", "Fix Camera")
fixCameraButton.OnEvent("Click", (*) => BasicSetup(true))

; --- Divider ---
global PlacementDivider := MainUI.Add("Text", "x809 y138 w549 h2 +0x10 Hidden")

; --- List (left) ---
global PlacementListView := MainUI.Add("ListView", "x820 y150 w350 h195 Hidden -Multi cBlack", ["#", "X", "Y"])
PlacementListView.OnEvent("DoubleClick", EditSelectedPlacement)
global PlacementStatusText := MainUI.Add("Text", "x820 y353 w350 h18 Hidden cffffff", "0 placements")
global AlwaysUseCustomCheck := MainUI.Add("CheckBox", "x1020 y353 h18 Hidden c" uiTheme[1], "Always use custom")

; --- Actions (right) ---
global PlacementListHeader := MainUI.Add("Text", "x1185 y148 w160 h16 Hidden cffffff", "View List Options")
PlacementListHeader.SetFont("s9 Bold")
global PlacementAddButton := MainUI.Add("Button", "x1185 y168 w160 h26 Hidden", "Add")
PlacementAddButton.OnEvent("Click", AddManualPlacement)
global PlacementListEditButton := MainUI.Add("Button", "x1185 y198 w160 h26 Hidden", "Edit")
PlacementListEditButton.OnEvent("Click", EditSelectedPlacement)
global PlacementListDeleteButton := MainUI.Add("Button", "x1185 y228 w160 h26 Hidden", "Remove")
PlacementListDeleteButton.OnEvent("Click", RemoveSelectedPlacement)

global PlacementCaptureHeader := MainUI.Add("Text", "x1185 y264 w160 h16 Hidden cffffff", "Coordinate Options")
PlacementCaptureHeader.SetFont("s9 Bold")
global CustomPlacementButton := MainUI.Add("Button", "x1185 y284 w160 h26 Hidden", "Set")
CustomPlacementButton.OnEvent("Click", (*) => StartCoordinateCapture())
global CustomPlacementClearButton := MainUI.Add("Button", "x1185 y314 w160 h26 Hidden", "Clear All")
CustomPlacementClearButton.OnEvent("Click", (*) => DeleteCustomCoordsForPreset(CustomPlacementMapDropdown.Text))
global PlacementShowButton := MainUI.Add("Button", "x1185 y344 w160 h26 Hidden", "Show Dots")
PlacementShowButton.OnEvent("Click", (*) => ShowPlacementDots())

; === Debug ===
global DebugBorder := MainUI.Add("GroupBox", "x808 y85 w550 h296 +Center Hidden c" uiTheme[1], "Debug Toggles")
global CheckNormalLoadingScreens := MainUI.Add("Checkbox", "x825 y110 Hidden cffffff", "Enable non-essential loading screen checks")

DiscordButton.OnEvent("Click", (*) => OpenDiscord())
;--------------SETTINGS--------------;
MainUI.SetFont("s10 c" uiTheme[6])
global ModeDropdown := MainUI.Add("DropDownList", "x818 y53 w140 h180 Choose0 +Center", ["Story", "Event", "Contracts", "Infinity Castle", "Legend Stages", "Portal", "Raid", "Custom"])
global EventDropdown := MainUI.Add("DropDownList", "x968 y53 w150 h180 Choose0 +Center Hidden", ["Fool's Hunt"])
global StoryDropdown := MainUI.Add("DropDownList", "x968 y53 w150 h180 Choose0 +Center", ["Planet Greenie",
    "Walled City", "Snowy Town", "Sand Village", "Navy Bay", "Fiend City", "Spirit World", "Ant Kingdom", "Magic Town",
    "Haunted Academy", "Magic Hills", "Space Center", "Alien Spaceship", "Fabled Kingdom", "Ruined City",
    "Puppet Island", "Virtual Dungeon", "Snowy Kingdom", "Dungeon Throne", "Mountain Temple", "Rain Village",
    "Shibuya District"])
global StoryActDropdown := MainUI.Add("DropDownList", "x1128 y53 w80 h180 Choose0 +Center", ["Act 1", "Act 2", "Act 3",
    "Act 4", "Act 5", "Act 6", "Infinity"])
global LegendDropDown := MainUI.Add("DropDownlist", "x968 y53 w150 h180 Choose0 +Center", ["Magic Hills",
    "Spirit Invasion", "Space Center", "Fabled Kingdom", "Ruined City", "Virtual Dungeon", "Dungeon Throne",
    "Rain Village"])
global LegendActDropdown := MainUI.Add("DropDownList", "x1128 y53 w80 h180 Choose0 +Center", ["Act 1", "Act 2", "Act 3",
    "Act 4", "Act 5", "Act 6", "Random"])
global RaidDropdown := MainUI.Add("DropDownList", "x968 y53 w150 h180 Choose0 +Center", ["Ant Kingdom", "Sacred Planet",
    "Strange Town", "Ruined City", "Cursed Festival", "Future City (Tyrant)", "Storm Hideout", "Future City",
    "Nightmare Train", "Sand Village"])
global RaidActDropdown := MainUI.Add("DropDownList", "x1128 y53 w80 h180 Choose0 +Center", ["Act 1", "Act 2", "Act 3",
    "Act 4", "Act 5"])
global InfinityCastleDropdown := MainUI.Add("DropDownList", "x968 y53 w80 h180 Choose1 +Center", ["Normal", "Hard"])
global PortalDropdown := MainUI.Add("DropDownList", "x968 y53 w150 h180 Choose0 +Center", ["Alien Portal",
    "Puppet Portal", "Demon Leader's Portal", "Eclipse Portal", "Noble Portal", "Shibuya Portal"])
global PortalRoleDropdown := MainUI.Add("DropDownList", "x1128 y53 w80 h180 Choose0 +Center", ["Creating", "Joining",
    "Solo"])
global ContractPageDropdown := MainUI.Add("DropDownList", "x968 y53 w80 h180 Choose0 +Center", ["Page 1", "Page 2",
    "Page 3", "Page 4", "Page 5", "Page 6", "Page 4-5"])
global ContractJoinDropdown := MainUI.Add("DropDownList", "x1057 y53 w120 h180 Choose0 +Center", ["Hosting", "Joining",
    "Solo"])
global ConfirmButton := MainUI.Add("Button", "x1218 y53 w80 h25", "Confirm")

LegendDropDown.Visible := false
LegendActDropdown.Visible := false
RaidDropdown.Visible := false
RaidActDropdown.Visible := false
ContractJoinDropdown.Visible := false
ContractPageDropdown.Visible := false
InfinityCastleDropdown.Visible := false

;Fool's Hunt
BringOwnTeam.Visible := false

;Contracts
TeamSwap.Visible := false
MagicTeamText.Visible := false
MagicTeam.Visible := false
PhysicalTeamText.Visible := false
PhysicalTeam.Visible := false

;Portals
SwapFromPortal.Visible := false

Hotkeytext.Visible := false
Hotkeytext2.Visible := false
Hotkeytext3.Visible := false
ModeDropdown.OnEvent("Change", OnModeChange)
EventDropdown.OnEvent("Change", OnEventChange)
StoryDropdown.OnEvent("Change", OnStoryChange)
LegendDropDown.OnEvent("Change", OnLegendChange)
RaidDropdown.OnEvent("Change", OnRaidChange)
PlacementPatternDropdown.OnEvent("Change", OnPlacementChange)
ConfirmButton.OnEvent("Click", OnConfirmClick)
;------MAIN UI------;
AddUnitCard(MainUI, index, x, y) {
    unit := {}

    ; Helper for adding styled text
    AddText(ctrlX, ctrlY, width, height, options := "", text := "") {
        return MainUI.Add("Text", Format("x{} y{} w{} h{} {}", ctrlX, ctrlY, width, height, options), text)
    }

    ; Background and borders
    unit.Background := AddText(x, y, 550, 45, "+Background" uiTheme[4])
    unit.BorderTop := AddText(x, y, 550, 2, "+Background" uiTheme[3])
    unit.BorderBottom := AddText(x, y + 45, 552, 2, "+Background" uiTheme[3])
    unit.BorderLeft := AddText(x, y, 2, 45, "+Background" uiTheme[3])
    unit.BorderRight := AddText(x + 550, y, 2, 45, "+Background" uiTheme[3])
    unit.BorderRight2 := AddText(x + 250, y, 2, 45, "+Background" uiTheme[3])
    unit.BorderRight3 := AddText(x + 420, y, 2, 45, "+Background" uiTheme[3])

    ; Main Labels
    MainUI.SetFont("s11 Bold c" uiTheme[1])
    unit.EnabledTitle := AddText(x + 30, y + 13, 60, 25, "+BackgroundTrans", "Unit " index)

    ; Unit Configuration
    MainUI.SetFont("s9 c" uiTheme[1])
    unit.PlacementText := AddText(x + 90, y + 2, 80, 20, "+BackgroundTrans", "Placements")
    unit.PriorityText := AddText(x + 185, y + 2, 60, 20, "BackgroundTrans", "Priority")

    if (!AutoUpgradeDisabled) {
        unit.AutoUpgradeText := AddText(x + 275, y + 25, 250, 20, "BackgroundTrans", "Enable Auto Upgrade")
    }

    if (!AutoAbilityDisabled) {
        unit.AutoAbilityText := AddText(x + 280, y + 15, 60, 20, "BackgroundTrans", "Ability")
    }

    unit.UnitTypeText := AddText(x + 352, y + 2, 66, 20, "BackgroundTrans", "Unit Type")

    if (!unitUpgradeLimitDisabled) {
        unit.UpgradeCapText := AddText(x + 440, y + 2, 250, 20, "BackgroundTrans", "Upgrade Limit")
        unit.UpgradeLimitTitle := AddText(x + 445, y + 20, 250, 25, "+BackgroundTrans", "Enabled")
    }
    UnitData.Push(unit)
    return unit
}

;Create Unit slot
y_start := 85
y_spacing := 50
loop 6 {
    AddUnitCard(MainUI, A_Index, 808, y_start + ((A_Index - 1) * y_spacing))
}

enabled1 := MainUI.Add("CheckBox", "x818 y100 w15 h15", "")
enabled2 := MainUI.Add("CheckBox", "x818 y150 w15 h15", "")
enabled3 := MainUI.Add("CheckBox", "x818 y200 w15 h15", "")
enabled4 := MainUI.Add("CheckBox", "x818 y250 w15 h15", "")
enabled5 := MainUI.Add("CheckBox", "x818 y300 w15 h15", "")
enabled6 := MainUI.Add("CheckBox", "x818 y350 w15 h15", "")

abilityEnabled1 := MainUI.Add("CheckBox", "x1065 y100 w15 h15", "")
upgradeEnabled1 := MainUI.Add("CheckBox", "x1065 y110 w15 h15 " (autoUpgradeDisabled ? "Hidden" : ""), "")

abilityEnabled2 := MainUI.Add("CheckBox", "x1065 y150 w15 h15", "")
upgradeEnabled2 := MainUI.Add("CheckBox", "x1065 y160 w15 h15 " (autoUpgradeDisabled ? "Hidden" : ""), "")

abilityEnabled3 := MainUI.Add("CheckBox", "x1065 y200 w15 h15", "")
upgradeEnabled3 := MainUI.Add("CheckBox", "x1065 y210 w15 h15 " (autoUpgradeDisabled ? "Hidden" : ""), "")

abilityEnabled4 := MainUI.Add("CheckBox", "x1065 y250 w15 h15", "")
upgradeEnabled4 := MainUI.Add("CheckBox", "x1065 y260 w15 h15 " (autoUpgradeDisabled ? "Hidden" : ""), "")

abilityEnabled5 := MainUI.Add("CheckBox", "x1065 y300 w15 h15", "")
upgradeEnabled5 := MainUI.Add("CheckBox", "x1065 y310 w15 h15 " (autoUpgradeDisabled ? "Hidden" : ""), "")

abilityEnabled6 := MainUI.Add("CheckBox", "x1065 y350 w15 h15", "")
upgradeEnabled6 := MainUI.Add("CheckBox", "x1065 y360 w15 h15 " (autoUpgradeDisabled ? "Hidden" : ""), "")

upgradeLimitEnabled1 := MainUI.Add("CheckBox", "x1235 y105 w15 h15 " (unitUpgradeLimitDisabled ? "Hidden" : ""), "")
upgradeLimitEnabled2 := MainUI.Add("CheckBox", "x1235 y155 w15 h15 " (unitUpgradeLimitDisabled ? "Hidden" : ""), "")
upgradeLimitEnabled3 := MainUI.Add("CheckBox", "x1235 y205 w15 h15 " (unitUpgradeLimitDisabled ? "Hidden" : ""), "")
upgradeLimitEnabled4 := MainUI.Add("CheckBox", "x1235 y255 w15 h15 " (unitUpgradeLimitDisabled ? "Hidden" : ""), "")
upgradeLimitEnabled5 := MainUI.Add("CheckBox", "x1235 y305 w15 h15 " (unitUpgradeLimitDisabled ? "Hidden" : ""), "")
upgradeLimitEnabled6 := MainUI.Add("CheckBox", "x1235 y355 w15 h15 " (unitUpgradeLimitDisabled ? "Hidden" : ""), "")

MainUI.SetFont("s8 c" uiTheme[6])

; Placement dropdowns
placementOptions := ["1", "2", "3", "4", "5", "6"]

if (IncreaseUnitPlacements) {
    loop 14
        placementOptions.Push(String(A_Index + 6))
}

placementRows := IncreaseUnitPlacements ? 20 : 6

Placement1 := MainUI.Add("DropDownList", "x918 y105 w35 r" placementRows " Choose1 +Center", placementOptions)
Placement2 := MainUI.Add("DropDownList", "x918 y155 w35 r" placementRows " Choose1 +Center", placementOptions)
Placement3 := MainUI.Add("DropDownList", "x918 y205 w35 r" placementRows " Choose1 +Center", placementOptions)
Placement4 := MainUI.Add("DropDownList", "x918 y255 w35 r" placementRows " Choose1 +Center", placementOptions)
Placement5 := MainUI.Add("DropDownList", "x918 y305 w35 r" placementRows " Choose1 +Center", placementOptions)
Placement6 := MainUI.Add("DropDownList", "x918 y355 w35 r" placementRows " Choose1 +Center", placementOptions)

Priority1 := MainUI.Add("DropDownList", "x980 y105 w35 h180 Choose1 +Center", ["1", "2", "3", "4", "5", "6"])
Priority1.OnEvent("Change", (*) => OnPriorityChange("Placement", 1, Priority1.Value))

Priority2 := MainUI.Add("DropDownList", "x980 y155 w35 h180 Choose2 +Center", ["1", "2", "3", "4", "5", "6"])
Priority2.OnEvent("Change", (*) => OnPriorityChange("Placement", 2, Priority2.Value))

Priority3 := MainUI.Add("DropDownList", "x980 y205 w35 h180 Choose3 +Center", ["1", "2", "3", "4", "5", "6"])
Priority3.OnEvent("Change", (*) => OnPriorityChange("Placement", 3, Priority3.Value))

Priority4 := MainUI.Add("DropDownList", "x980 y255 w35 h180 Choose4 +Center", ["1", "2", "3", "4", "5", "6"])
Priority4.OnEvent("Change", (*) => OnPriorityChange("Placement", 4, Priority4.Value))

Priority5 := MainUI.Add("DropDownList", "x980 y305 w35 h180 Choose5 +Center", ["1", "2", "3", "4", "5", "6"])
Priority5.OnEvent("Change", (*) => OnPriorityChange("Placement", 5, Priority5.Value))

Priority6 := MainUI.Add("DropDownList", "x980 y355 w35 h180 Choose6 +Center", ["1", "2", "3", "4", "5", "6"])
Priority6.OnEvent("Change", (*) => OnPriorityChange("Placement", 6, Priority6.Value))

UpgradePriority1 := MainUI.Add("DropDownList", "x1020 y105 w35 h180 Choose1 +Center", ["1", "2", "3", "4", "5", "6", ""])
UpgradePriority1.OnEvent("Change", (*) => OnPriorityChange("Upgrade", 1, UpgradePriority1.Text))

UpgradePriority2 := MainUI.Add("DropDownList", "x1020 y155 w35 h180 Choose2 +Center", ["1", "2", "3", "4", "5", "6", ""])
UpgradePriority2.OnEvent("Change", (*) => OnPriorityChange("Upgrade", 2, UpgradePriority2.Text))

UpgradePriority3 := MainUI.Add("DropDownList", "x1020 y205 w35 h180 Choose3 +Center", ["1", "2", "3", "4", "5", "6", ""])
UpgradePriority3.OnEvent("Change", (*) => OnPriorityChange("Upgrade", 3, UpgradePriority3.Text))

UpgradePriority4 := MainUI.Add("DropDownList", "x1020 y255 w35 h180 Choose4 +Center", ["1", "2", "3", "4", "5", "6", ""])
UpgradePriority4.OnEvent("Change", (*) => OnPriorityChange("Upgrade", 4, UpgradePriority4.Text))

UpgradePriority5 := MainUI.Add("DropDownList", "x1020 y305 w35 h180 Choose5 +Center", ["1", "2", "3", "4", "5", "6", ""])
UpgradePriority5.OnEvent("Change", (*) => OnPriorityChange("Upgrade", 5, UpgradePriority5.Text))

UpgradePriority6 := MainUI.Add("DropDownList", "x1020 y355 w35 h180 Choose6 +Center", ["1", "2", "3", "4", "5", "6", ""])
UpgradePriority6.OnEvent("Change", (*) => OnPriorityChange("Upgrade", 6, UpgradePriority6.Text))

; Upgrade Limit
UpgradeLimit1 := MainUI.Add("DropDownList", "x1301 y105 w54 h220 Choose1 +Center", ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "MAX"])
UpgradeLimit2 := MainUI.Add("DropDownList", "x1301 y155 w54 h220 Choose1 +Center", ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "MAX"])
UpgradeLimit3 := MainUI.Add("DropDownList", "x1301 y205 w54 h220 Choose1 +Center", ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "MAX"])
UpgradeLimit4 := MainUI.Add("DropDownList", "x1301 y255 w54 h220 Choose1 +Center", ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "MAX"])
UpgradeLimit5 := MainUI.Add("DropDownList", "x1301 y305 w54 h220 Choose1 +Center", ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "MAX"])
UpgradeLimit6 := MainUI.Add("DropDownList", "x1301 y355 w54 h220 Choose1 +Center", ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "MAX"])

; Unit type for the Unit-Type Strategy (same list as StrategyTypes in TypeStrategy.ahk)
unitType1 := MainUI.Add("DropDownList", "x1160 y105 w64 h160 Choose1 +Center", ["None", "Farm", "DPS", "Support", "Buff", "Summon"])
unitType2 := MainUI.Add("DropDownList", "x1160 y155 w64 h160 Choose1 +Center", ["None", "Farm", "DPS", "Support", "Buff", "Summon"])
unitType3 := MainUI.Add("DropDownList", "x1160 y205 w64 h160 Choose1 +Center", ["None", "Farm", "DPS", "Support", "Buff", "Summon"])
unitType4 := MainUI.Add("DropDownList", "x1160 y255 w64 h160 Choose1 +Center", ["None", "Farm", "DPS", "Support", "Buff", "Summon"])
unitType5 := MainUI.Add("DropDownList", "x1160 y305 w64 h160 Choose1 +Center", ["None", "Farm", "DPS", "Support", "Buff", "Summon"])
unitType6 := MainUI.Add("DropDownList", "x1160 y355 w64 h160 Choose1 +Center", ["None", "Farm", "DPS", "Support", "Buff", "Summon"])

LoadUnitSettingsByMode()

OnMessage(0x201, WM_LBUTTONDOWN)
WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global MainUI
    try {
        if hwnd = MainUI.Hwnd {
            MouseGetPos(&mx, &my)
            if (my <= 12) {
                PostMessage(0xA1, 2, , , "A")
            }
        }
    }
}

; Register every control with a colour role, then apply the saved theme (colours + title font)
Theme_BindMainUI()
Theme_Apply()

MainUI.Show("w1366 h700")
;WinMove(0, 0, , , "ahk_id " MainUIHwnd)
CenterMacroWindow()   ; Window follow was: WinMove(0, 0,,, "ahk_id " aaMainUIHwnd)
SetupDraggableGui()   ; Window follow drag the GUI by its background, Roblox follows
forceRobloxSize()  ; Initial force size and position
SetTimer(checkRobloxSize, 600000)  ; Check every 10 minutes
;------FUNCTIONS------;

AddToLog(current) {
    global processList, currentOutputFile, lastlog
    global WebhookLogsEnabled, WebhookEnabled

    ; Shift values downward and remove arrows
    loop processList.Length {
        i := processList.Length - A_Index + 1
        if (i > 1)
            processList[i].Value := StrReplace(processList[i - 1].Value, "➤ ", "")
    }

    ; Add new entry to the top
    processList[1].Value := "➤ " . current

    ; Optional: Log to file
    elapsedTime := getElapsedTime()
    Sleep(50)

    ; Remove emojis from the log string
    cleanCurrent := CleanString(current)

    ; Optional: Log to file
    elapsedTime := getElapsedTime()
    Sleep(50)
    FileAppend(cleanCurrent . " " . elapsedTime . "`n", currentOutputFile)

    ; Store last log and optionally send webhook
    lastlog := current
    if (WebhookLogsEnabled.Value && WebhookEnabled.Value && scriptInitialized)
        WebhookLog()
}

;Timer
getElapsedTime() {
    global StartTime
    ElapsedTime := A_TickCount - StartTime
    Minutes := Mod(ElapsedTime // 60000, 60)
    Seconds := Mod(ElapsedTime // 1000, 60)
    return Format("{:02}:{:02}", Minutes, Seconds)
}

;Basically the code to move roblox, below

moveRobloxWindow(dragging := false) {
    global MainUIHwnd, offsetX, offsetY, rblxID

    hwnd := WinExist(rblxID)
    if !hwnd {
        if !dragging
            AddToLog("Waiting for Roblox window...")
        return
    }

    if !dragging {
        if !ForceRobloxClientSize() && IsFullscreenWin(hwnd)
            return
    }

    WinGetPos(&x, &y, , , "ahk_id " MainUIHwnd)

    if dragging {
        ; Non-activating, non-sizing, async move
        DllCall("SetWindowPos", "ptr", hwnd, "ptr", 0
            , "int", x + offsetX, "int", y + offsetY
            , "int", 0, "int", 0
            , "uint", 0x4015)   ; NOSIZE | NOZORDER | NOACTIVATE | ASYNCWINDOWPOS
    } else {
        WinMove(x + offsetX, y + offsetY, , , "ahk_id " hwnd)
        if !WinActive("ahk_id " hwnd)
            WinActivate("ahk_id " hwnd)
    }
}

sizeDown() {
    global rblxID, targetWidth, targetHeight

    hwnd := WinExist(rblxID)
    if (!hwnd) {
        AddToLog("❌ Roblox window not found (rblxID: " rblxID ")")
        return false
    }
    id := "ahk_id " hwnd

    ; A maximized (or minimized) window can't be reliably moved, so restore it first
    if (WinGetMinMax(id) != 0) {
        WinRestore(id)
        Sleep(200)
    }

    ; Never ask for a window bigger than the monitor's work area (small/scaled screens)
    GetMonitorWorkArea(hwnd, &L, &T, &R, &B)
    tw := Min(targetWidth, R - L)
    th := Min(targetHeight, B - T)

    ; Already windowed and the right size: nothing to do, and no focus stealing
    WinGetPos(&X, &Y, &W, &H, id)
    if (!IsFullscreenWin(hwnd) && SizeMatches(W, H, tw, th))
        return true

    ; Leave real fullscreen. F11 goes to the FOCUSED window, so we must be sure
    ; Roblox has focus first, otherwise we'd toggle fullscreen on something else
    if IsFullscreenWin(hwnd) {
        WinActivate(id)
        if !WinWaitActive(id, , 2) {
            AddToLog("⚠️ Couldn't focus Roblox (is it running as admin?), not sending F11")
            return false
        }

        Send "{F11}"
        loop 15 {
            Sleep(200)
            if !IsFullscreenWin(hwnd)
                break
        }
        if IsFullscreenWin(hwnd) {
            AddToLog("❌ Roblox is still fullscreen, can't resize")
            return false
        }
        Sleep(200)
    }

    loop 5 {
        WinGetPos(&X, &Y, &W, &H, id)
        WinMove(X, Y, tw, th, id)
        Sleep(200)
        WinGetPos(&X, &Y, &W, &H, id)
        if SizeMatches(W, H, tw, th)
            return true
    }

    AddToLog("❌ Resize failed. Wanted " tw "x" th ", got " W "x" H
        . " | admin=" A_IsAdmin " dpi=" A_ScreenDPI
        . " style=" Format("{:#x}", WinGetStyle(id)))
    return false
}

; Real Roblox fullscreen is a borderless window; windowed mode has a title bar.
; Size alone is not enough (a windowed window can be as big as a small monitor),
; so check for the caption first, then confirm it covers its monitor.
IsFullscreenWin(hwnd) {
    id := "ahk_id " hwnd

    if (WinGetStyle(id) & 0xC00000)   ; WS_CAPTION -> normal windowed
        return false

    WinGetPos(&x, &y, &w, &h, id)
    cx := x + w // 2, cy := y + h // 2
    loop MonitorGetCount() {
        MonitorGet(A_Index, &L, &T, &R, &B)
        if (cx >= L && cx < R && cy >= T && cy < B)
            return (w >= R - L && h >= B - T)
    }
    return false
}

; Forces the Roblox *client* area to exactly 800×600
ForceRobloxClientSize(hwnd := 0) {
    if !hwnd
        hwnd := WinExist(rblxID)
    if !hwnd
        return false

    id := "ahk_id " hwnd

    ; Restore first
    if (WinGetMinMax(id) != 0) {
        WinRestore(id)
        Sleep(100)
    }

    loop 8 {
        ; Measure current outer vs client
        WinGetPos(&ox, &oy, &ow, &oh, id)
        WinGetClientPos(&cx, &cy, &cw, &ch, id)

        if (cw = 800 && ch = 600)
            return true

        ; Calculate required outer size
        newW := ow + (800 - cw)
        newH := oh + (600 - ch)

        ; Keep position, change size
        DllCall("SetWindowPos", "ptr", hwnd, "ptr", 0
            , "int", ox, "int", oy
            , "int", newW, "int", newH
            , "uint", 0x0016)   ; SWP_NOZORDER | SWP_NOACTIVATE

        Sleep(80)
    }
    return false
}

; Compares against the (possibly clamped) target, with a small tolerance
SizeMatches(w, h, tw := unset, th := unset) {
    global targetWidth, targetHeight
    if !IsSet(tw)
        tw := targetWidth
    if !IsSet(th)
        th := targetHeight
    return (Abs(w - tw) <= 2 && Abs(h - th) <= 2)
}

; Work area (excludes taskbar) of the monitor the window is mostly on
GetMonitorWorkArea(hwnd, &L, &T, &R, &B) {
    WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
    cx := x + w // 2, cy := y + h // 2
    loop MonitorGetCount() {
        MonitorGet(A_Index, &mL, &mT, &mR, &mB)
        if (cx >= mL && cx < mR && cy >= mT && cy < mB) {
            MonitorGetWorkArea(A_Index, &L, &T, &R, &B)
            return
        }
    }
    MonitorGetWorkArea(MonitorGetPrimary(), &L, &T, &R, &B)
}

forceRobloxSize() {
    global rblxID

    if !WinExist(rblxID) {
        checkCount := 0
        while !WinExist(rblxID) {
            Sleep(5000)
            if (checkCount >= 5) {
                AddToLog("Attempting to locate the Roblox window")
            }
            checkCount += 1
            if (checkCount > 12) { ; Give up after 1 minute
                AddToLog("Could not find Roblox window")
                return
            }
        }
        AddToLog("Found Roblox window")
    }

    WinActivate(rblxID)
    ;sizeDown()
    ForceRobloxClientSize()
    moveRobloxWindow()
}

; Function to periodically check window size
checkRobloxSize() {
    global rblxID
    if WinExist(rblxID) {
        WinGetPos(&X, &Y, &OutWidth, &OutHeight, rblxID)
        if (OutWidth != targetWidth || OutHeight != targetHeight) {
            ;sizeDown()
            ForceRobloxClientSize()
            moveRobloxWindow()
        }
    }
}

checkSizeTimer() {
    if (WinExist("ahk_exe RobloxPlayerBeta.exe")) {
        WinGetPos(&X, &Y, &OutWidth, &OutHeight, "ahk_exe RobloxPlayerBeta.exe")
        if (OutWidth != 816 || OutHeight != 638) {
            AddToLog("Fixing Roblox window size")
            moveRobloxWindow()
        }
    }
}

UpdateTooltip() {
    global waitingForClick
    if waitingForClick {
        MouseGetPos &x, &y
        ToolTip "Click anywhere to save coordinates...", x + 10, y + 10  ; Offset tooltip slightly
    } else {
        ToolTip()  ; Hide tooltip when not waiting
        SetTimer UpdateTooltip, 0  ; Stop the timer
    }
}

ClearToolTip() {
    ToolTip()  ; Properly clear tooltip
    Sleep 100  ; Small delay to ensure clearing happens across all systems
    ToolTip()  ; Redundant clear to catch edge cases
}

InitControlGroups() {
    global ControlGroups, autoUpgradeDisabled

    ControlGroups["Unit"] := []

    Blacklist := [""]

    ; Add upgradeEnabled to the blacklist if auto-upgrade is disabled
    if (autoUpgradeDisabled)
        Blacklist.Push("upgradeEnabled")

    for name in ["Placement", "enabled", "priority", "upgradePriority", "upgradeEnabled", "upgradeLimitEnabled",
        "upgradeLimit", "abilityEnabled", "unitType"] {
        loop 6 {
            varName := name . A_Index
            baseName := RegExReplace(varName, "\d+$")

            ; Check if baseName is in Blacklist manually
            isBlacklisted := false
            for index, item in Blacklist {
                if (item = baseName) {
                    isBlacklisted := true
                    break
                }
            }

            if (isBlacklisted)
                continue

            if IsSet(%varName%)  ; Check if the variable exists
                ControlGroups["Unit"].Push(%varName%)
            else
                AddToLog("Variable " . varName . " does not exist!")
        }
    }

    ControlGroups["Settings"] := [
        WebhookBorder, WebhookEnabled, WebhookLogsEnabled, WebhookURLBox,
        PrivateSettingsBorder, PrivateServerEnabled, PrivateServerURLBox, PrivateServerTestButton,
        PrivateServerGuideButton,
        TeleportFailsafe, TeleportFailsafeTimerText, TeleportFailsafeTimer,
        KeybindBorder, F1Text, F1Box, F2Text, F2Box, F3Text, F3Box, F4Text, F4Box, keybindSaveBtn,
        ZoomSettingsBorder, ZoomText, ZoomBox, ZoomTech, ZoomInOption, ZoomTeleport,
        MiscSettingsBorder, UpdateChecker, ForceCheckUpdateButton
    ]

    ControlGroups["Upgrade"] := [
        UpgradeBorder, EnableUpgrading, UnitManagerUpgradeSystem, PriorityUpgrade, EvenUpgrade
    ]

    ControlGroups["Mode"] := [
        ModeBorder, ModeConfigurations
    ]

    ControlGroups["Event"] := [
        EventBorder
    ]

    ControlGroups["Story"] := [
        StoryBorder,
        NightmareDifficulty
    ]

    ControlGroups["Portal"] := [
        PortalBorder
    ]

    ControlGroups["Cards"] := [
        CardBorder,
        FoolsHuntCardButton, FoolsHuntCardText
    ]

    ControlGroups["Movement"] := [
        CustomWalkBorder, WalkMapText, WalkMapDropdown, WalkTipText, WalkListView, WalkRemoveBtn, WalkEditBtn,
        MovementSetButton, MovementClearButton, MovementTestButton,
        MovementImport, MovementExport
    ]

    ControlGroups["Placement"] := [
        CustomPlacementBorder,
        PlacementSettingsImportButton, PlacementSettingsExportButton,
        CustomPlacementMap, CustomPlacementMapDropdown, AddCustomPlacementProfile, RemoveCustomPlacementProfile,
        fixCameraButton, PlacementDivider,
        PlacementListView, PlacementStatusText, AlwaysUseCustomCheck,
        PlacementListHeader, PlacementAddButton, PlacementListEditButton, PlacementListDeleteButton,
        PlacementCaptureHeader, CustomPlacementButton, CustomPlacementClearButton, PlacementShowButton
    ]

    ControlGroups["Recording"] := [
        RecordBorder, RecordMapText, RecordMapDropdown, AddRecordingProfileButton, DeleteRecordingProfileButton,
        ImportRecording, ExportRecording, ShouldUseRecording, ShouldUseSetup, ShouldLoopRecording, ShouldHandleGameEnd,
        RecordStartButton, RecordClearButton, RecordTestButton
    ]

    ControlGroups["Debug"] := [
        DebugBorder, CheckNormalLoadingScreens
    ]
}

ShowOnlyControlGroup(groupName) {
    global ControlGroups
    if !ControlGroups.Has(groupName) {
        return false
    }

    for name, groupControls in ControlGroups {
        shouldShow := (name = groupName)
        for ctrl in groupControls {
            if IsObject(ctrl)
                ctrl.Visible := shouldShow
        }
    }
    return true
}

ToggleControlGroup(groupName) {
    global ActiveControlGroup
    if (groupName = "Mode") {
        ActiveControlGroup := "Mode"
    }
    if (groupName = "Settings") {
        if (ActiveControlGroup = "Settings") {
            groupName := "Unit"
            ActiveControlGroup := "Unit"
        } else {
            ActiveControlGroup := "Settings"
        }
    }
    if (ShowOnlyControlGroup((groupName = "Mode" ? ModeDropdown.Text : groupName))) {
        ; AddToLog("Displaying: " (groupName = "Settings" ? "Settings UI" : groupName " Settings UI"))
        SetUnitCardVisibility((groupName = "Unit") ? true : false)
    }
}

SetUnitCardVisibility(visible) {
    global autoUpgradeDisabled

    for _, unit in UnitData {
        for _, ctrl in unit.OwnProps() {
            if IsObject(ctrl)
                ctrl.Visible := visible
        }
    }

    Blacklist := [""]

    ; Respect the same rule as InitControlGroups
    if (autoUpgradeDisabled)
        Blacklist.Push("upgradeEnabled")

    for name in ["Placement", "Enabled", "UpgradeEnabled", "Priority", "UpgradePriority", "AbilityEnabled", "UnitType"] {
        loop 6 {
            varName := name . A_Index
            baseName := RegExReplace(varName, "\d+$")
            baseName := StrLower(baseName)   ; normalize so it matches the blacklist

            ; Check blacklist
            isBlacklisted := false
            for _, item in Blacklist {
                if (StrLower(item) = baseName) {
                    isBlacklisted := true
                    break
                }
            }

            if (isBlacklisted)
                continue

            ctrl := %varName%
            if IsObject(ctrl)
                ctrl.Visible := visible
        }
    }
}

ValidateWebhook() {
    global WebhookURLBox

    url := WebhookURLBox.Value

    if (url == "") {
        WebhookEnabled.Value := false
        WebhookURLBox.Value := ""
        MsgBox("Webhook URL cannot be blank. Please enter a valid Webhook URL.", "Missing URL", "+0x1000")
        return
    }

    if (!RegExMatch(url, "^https://discord\.com/api/webhooks/.*")) {
        WebhookEnabled.Value := false
        WebhookURLBox.Value := ""
        MsgBox("Invalid Webhook URL! Please ensure it follows the correct format.", "Invalid URL", "+0x1000")
        return
    }
}

ValidateEditBox(ctrl) {
    val := Trim(ctrl.Value)
    ; If the input is not a number, reset to 0
    if !IsInteger(val) {
        ctrl.Value := "0"
        return
    }

    ; Convert to integer
    num := Integer(val)

    if (num < 0)
        ctrl.Value := "0"

    if (ctrl == ZoomBox) {
        if (num > 20)
            ctrl.Value := "20"  ; Limit to a maximum of 20
    }
}

HandleCoordinateClick(*) {
    global waitingForClick, savedCoords, nukeCoords

    if !waitingForClick
        return

    ; Handle special “Nuke” mode
    if (WaitingFor("Nuke")) {
        MouseGetPos(&x, &y)
        nukeCoords := { x: x, y: y }
        ToolTip("Nuke Coords Set", x + 10, y + 10)
        AddToLog("Nuke Coords Saved → X: " x ", Y: " y)
        SetTimer(ClearToolTip, -1000)
        RemoveWaiting()
        return
    }

    ; Normal placement coordinate capture
    mode := ModeDropdown.Text
    mapName := (mode = "Event") ? EventDropdown.Text : CustomPlacementMapDropdown.Text
    if (mapName = "") {
        AddToLog("⚠️ No map selected.")
        return
    }

    MouseGetPos(&x, &y)
    coords := GetOrInitCustomCoords(mapName)
    if SpotTooClose(coords, x, y) {
        ToolTip("Too close to a saved spot - ignored", x + 10, y + 10)
        SetTimer(ClearToolTip, -1000)
        return
    }
    coords.Push({ x: x, y: y, mapName: mapName })
    savedCoords[mapName] := coords

    ToolTip("Coords Set: " coords.Length, x + 10, y + 10)
    AddToLog("📌 [Map: " mapName "] Saved → X: " x ", Y: " y " | Total: " coords.Length)
    SetTimer(ClearToolTip, -1000)
}

StopCoordinateCapture(*) {
    global waitingForClick, activeHotkeys

    if !waitingForClick
        return

    waitingForClick := false

    ; Remove all dynamically created hotkeys
    for hk in activeHotkeys {
        try hk.Delete()
    }

    activeHotkeys := []

    SetTimer(UpdateTooltip, 0)
    SetTimer(ClearToolTip, -500)
    AddToLog("✅ Coordinate capture stopped.")
    UpdatePlacementListView()
}

SetClickThrough(enable := true) {
    static WS_EX_TRANSPARENT := 0x20
    static GWL_EXSTYLE := -20

    hwnd := MainUI.Hwnd
    exStyle := WinGetExStyle("ahk_id " hwnd)

    if enable
        exStyle |= WS_EX_TRANSPARENT
    else
        exStyle &= ~WS_EX_TRANSPARENT

    WinSetExStyle(exStyle, "ahk_id " hwnd)
}

; Put the GUI in the middle of the main screen, then Roblox follows it
CenterMacroWindow() {
    global MainUI
    MonitorGetWorkArea(MonitorGetPrimary(), &left, &top, &right, &bottom)
    WinGetPos(, , &w, &h, "ahk_id " MainUI.hWnd)
    x := Max(left, left + (right - left - w) // 2)
    y := Max(top, top + (bottom - top - h) // 2)
    WinMove(x, y, , , "ahk_id " MainUI.hWnd)
}

SetupDraggableGui() {
    OnMessage(0x0201, MacroGui_OnLButtonDown)   ; WM_LBUTTONDOWN
    OnMessage(0x0003, MacroGui_OnMove)          ; WM_MOVE (continuous while dragging)
    OnMessage(0x0232, MacroGui_OnMoveEnd)       ; WM_EXITSIZEMOVE (final full sync)
}

MacroGui_OnLButtonDown(wParam, lParam, msg, hwnd) {
    global MainUI
    if (hwnd = MainUI.hWnd) {
        DllCall("ReleaseCapture")
        SendMessage(0xA1, 2, 0, , "ahk_id " MainUI.hWnd)   ; WM_NCLBUTTONDOWN, HTCAPTION
        return 0
    }
}

MacroGui_OnMove(wParam, lParam, msg, hwnd) {
    global MainUI
    static busy := false
    if (hwnd != MainUI.hWnd || busy)
        return
    busy := true
    try moveRobloxWindow(true)
    busy := false
}

MacroGui_OnMoveEnd(wParam, lParam, msg, hwnd) {
    global MainUI
    if (hwnd = MainUI.hWnd)
        moveRobloxWindow()   ; full version: resize check, exact position, focus
}
