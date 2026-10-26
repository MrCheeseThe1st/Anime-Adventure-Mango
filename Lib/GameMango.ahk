#Requires AutoHotkey v2.0
#Include %A_ScriptDir%/lib/Tools/Image.ahk
global macroStartTime := A_TickCount
global stageStartTime := A_TickCount
global cachedCardPriorities := Map()
LoadKeybindSettings()  ; Load saved keybinds
CheckForUpdates()
StartRapidOcr()
UpdatePlacementListView()
CheckFirstRun()
Hotkey(F1Key, (*) => moveRobloxWindow())
Hotkey(F2Key, (*) => StartMacro())
Hotkey(F3Key, (*) => Reload())
Hotkey(F4Key, (*) => TogglePause())
Hotkey(";", (*) => TogglePause()) ; Second pause key

F5:: {
    SetRegion()
}

F6:: {

}

F7:: {
    CopyMouseCoords(true)
}

F8:: {
    Run (A_ScriptDir "\Lib\Tools\FindText.ahk")
}

F9:: {
    OpenDebugMenu()
}

StartMacro(*) {
    if (!ValidateMode()) {
        return
    }
    if (StartsInLobby(ModeDropdown.Text) || StartsInLobby(EventDropdown.Text)) {
        if (CheckForLobby()) {
            StartSelectedMode()
        } else {
            AddToLog("You need to be in the lobby to start " ModeDropdown.Text)
        }
    } else {
        StartSelectedMode()
    }
}

TogglePause(*) {
    Pause -1
    if (A_IsPaused) {
        StopMovement() ; Don't leave W/A/S/D held down if it was paused mid-walk
        AddToLog("Macro Paused")
        Sleep(1000)
    } else {
        AddToLog("Macro Resumed")
        Sleep(1000)
    }
}

CheckForXP(closeLeaderboard := false, shouldClick := true) {
    if (closeLeaderboard) {
        FixClick(564, 72)
        Sleep(1200)
    }
    ; Check for lobby text
    if (ok := FT(&X, &Y, 534, 126, 758, 158, 0, 0, XpText)) {
        if (shouldClick) {
            FixClick(325, 185)
            Loop 3 {
                FixClick(560, 560)
                Sleep(50)
            }
        }
        return true
    }
    return false
}

ChallengeMode() {
    AddToLog("Moving to Challenge mode")
    ChallengeMovement()

    while !(ok := FindText(&X, &Y, 325, 520, 489, 587, 0, 0, Story)) {
        ChallengeMovement()
    }

    RestartStage()
}

CustomMode() {
    AddToLog("Starting Custom Mode")
    RestartStage()
}

HandleEndScreen(isVictory := true) {
    ; Challenge mode exits to the lobby. Do not continue into the normal
    ; end-screen handlers after the lobby transition.
    if (inChallengeMode) {
        ClickReturnToLobby()
        CheckLobby()
        return
    }

    switch ModeDropdown.Text {
        case "Story":
            HandleStoryEnd()
        case "Portal":
            HandlePortalEnd()
        case "Custom":
            HandleCustomEnd()
        case "Contracts":
            HandleContractEnd()
        Default:
            HandleDefaultEnd(isVictory)
    }
}

HandleStoryEnd() {
    global lastResult
    if (NextLevelBox.Value && lastResult = "win") {
        AddToLog("[Game Over] Starting next level")
        ClickNextLevel()
        return RestartStage()
    }

    ; Same rules as the other modes: matchmaking or Return To Lobby go back to the lobby
    if ((MatchMaking.Value && HasMatchmaking("Story")) || ReturnLobbyBox.Value) {
        AddToLog("[Game Over] Returning to lobby")
        ClickReturnToLobby()
        CheckLobby()
        return StartSelectedMode()
    }

    AddToLog("[Game Over] Replaying stage")
    ClickReplay()
    return RestartStage()
}

HandleCustomEnd() {
    global lastResult
    if (NextLevelBox.Value) {
        if (lastResult = "win") {
            AddToLog("[Game Over] Starting next level")
            ClickNextLevel()
            return RestartStage()
        }
    } else {
        AddToLog("[Game Over] Replaying stage")
        ClickReplay()
        return RestartStage()
    }
}

HandleDefaultEnd(isVictory) {
    mode := ModeDropdown.Text = "Event" ? EventDropdown.Text : ModeDropdown.Text

    ; Infinity Castle advances to the next level instead of replaying
    if (mode = "Infinity Castle") {
        if (isVictory) {
            AddToLog("[Game Over] Infinity Castle, advancing to next room")
            ClickNextLevel()
        } else {
            AddToLog("[Game Over] Replaying stage")
            ClickReplay()
        }
        return RestartStage()
    }

    if (MatchMaking.Value && HasMatchmaking(mode)) {
        AddToLog("[Game Over] Matchmaking enabled, returning to lobby to matchmake")
        ClickReturnToLobby()
        CheckLobby()
        return StartSelectedMode()
    }

    if (!ReturnLobbyBox.Value) {
        AddToLog("[Game Over] Replaying stage")
        ClickReplay()
        return RestartStage()
    } else {
        AddToLog("[Game Over] Returning to lobby")
        ClickReturnToLobby()
        CheckLobby()
        return StartSelectedMode()
    }
}

MonitorStage() {
    global Wins, loss, mode, stageStartTime

    ; -------------------------------------------------
    ; 1. Setup: Timers, anti-AFK, timeouts
    ; -------------------------------------------------
    lastClickTime := A_TickCount
    FixClick(400, 500)  ; Initial anti-AFK
    stageTimeout := A_TickCount + 3600000  ; 1 hour

    ; -------------------------------------------------
    ; 2. Main monitoring loop
    ; -------------------------------------------------
    while (true) {
        Sleep(200)

        ; --- Anti-AFK (every 10s) ---
        if (A_TickCount - lastClickTime >= 10000) {
            FixClick(400, 500)
            lastClickTime := A_TickCount
        }

        ; --- Quick progression checks ---
        if (HasCards(ModeDropdown.Text) || HasCards(EventDropdown.Text)) {
            CheckForCardSelection()
        }

        ; --- Fallbacks (early exit if needed) ---
        Reconnect()

        ; --- Wait for XP screen (break IMMEDIATELY) ---
        if (CheckForXP()) {
            break
        }
    }

    CloseUnitOverview()
    Sleep(300)

    stageEndTime := A_TickCount
    stageLength := FormatStageTime(stageEndTime - stageStartTime)

    result := false

    ; Fast parallel checks
    victoryFound := (ok := FT(&X, &Y, 150, 180, 350, 260, 0, 0, VictoryText) or (ok := FT(&X, &Y, 319, 176, 492, 279, 0, 0, VictoryText2)) or (ok := FT(&X, &Y, 363, 193, 475, 274, 0, 0, VictoryTextApril)))
    defeatFound := (ok := FT(&X, &Y, 150, 180, 350, 260, 0, 0, DefeatText) or (ok := FT(&X, &Y, 319, 176, 492, 279, 0, 0, DefeatText2)))

    if (victoryFound) {
        result := true
    } else if (defeatFound) {
        result := false
    } else {
        AddToLog("⚠️ Warning: No clear win/loss detected - assuming defeat")
        result := false
    }

    outcome := result ? "Victory" : "Defeat"
    AddToLog(outcome " - Stage Length: " stageLength)
    if !WaitAndCheck(3000, NextText, 266, 376, 377, 413) {
        ClickUntilGone(0, 0, 266, 376, 377, 413, NextText)
        Sleep(1500)
    } else {
        FixClick(321, 387)
    }

    if (WebhookEnabled.Value) {
        try {
            SendWebhookWithTime(result, stageLength)
        } catch as err {
            AddToLog("Webhook failed: " err.Message)
        }
    } else {
        UpdateStreak(result)
    }

    HandleEndScreen(result)
}

ChallengeMovement() {
    FixClick(765, 475)
    Sleep (500)
    FixClick(300, 415)
    SendInput ("{a down}")
    sleep (7000)
    SendInput ("{a up}")
}

StartContent(mapName, actName, getMapFunc, getActFunc, mapScrollMousePos, actScrollMousePos) {
    Map := getMapFunc.Call(mapName)
    if !Map {
        AddToLog("Error: Map '" mapName "' not found.")
        return false
    }

    if (CheckForNotification()) {
        ClickUntilGone(0, 0, 748, 94, 778, 551, ExitNotification, -3)
        Sleep (1000)
    }

    if Map.scrolls > 0 {
        AddToLog(Format("Scrolling down {} times for {}", Map.scrolls, mapName))
        MouseMove(mapScrollMousePos.x, mapScrollMousePos.y)
        Sleep(50)
        Scroll(Map.scrolls, 'WheelDown', 250)
    }
    Sleep(1000)
    FixClick(Map.x, Map.y)
    Sleep(1000)
    Act := getActFunc.Call(actName)
    if !Act {
        AddToLog("ERROR: Act '" actName "' not found.")
        return false
    }
    if Act.scrolls > 0 {
        AddToLog(Format("Scrolling down {} times for {}", Act.scrolls, actName))
        MouseMove(actScrollMousePos.x, actScrollMousePos.y)
        Sleep(50)
        Scroll(Act.scrolls, 'WheelDown', 250)
    }
    Sleep(1000)
    FixClick(Act.x, Act.y)
    Sleep(1000)
    return true
}

PlayHere() {
    FixClick(400, 435)  ; Play Here or Find Match
    Sleep (500)
    FixClick(330, 325) ;Click Play here
    Sleep (1200)
    if (ModeDropdown.Text = "Legend Stages" && LegendDropDown.Text = "Magic Hills" && LegendActDropdown.Text = "Act 3") {
        Sleep (4000)
    }
    ClickStartStory()
    Sleep (500)
}

Zoom() {
    WinActivate(rblxID)
    Sleep 100

    MouseMove(400, 300)
    Sleep 100

    if (ZoomInOption.Value) {
        Scroll(20, "WheelUp", 50)
        ; Look down
        Click
        MouseMove(400, 400)  ; Move mouse down to angle camera down
    }

    ; Zoom back out smoothly
    Scroll(Integer(ZoomBox.Value), "WheelDown", 50)

    ; Move mouse back to center
    MouseMove(400, 300)
}

TeleportToSpawn() {
    FixClick(26, 570) ;click settings
    Sleep 300
    FixClick(400, 215)
    Sleep 300
    loop 6 {
        Sleep 150
        SendInput("{WheelDown 1}") ;scroll
    }
    Sleep 300
    if (ok := FT(&X, &Y, 215, 160, 596, 480, 0.20, 0.20, Spawn)) {
        AddToLog("Found Teleport to Spawn button")
        FixClick(X + 100, Y)
    } else {
        AddToLog("Could not find Teleport button")
    }
    Sleep 300
    FixClick(583, 147)
    Sleep 300
}

RestartMatch() {
    FixClick(233, 10) ;click settings
    Sleep 300
    FixClick(338, 253) ;click restart match
    Sleep 3500
}

CloseChat() {
    if (ok := FindText(&X, &Y, 123, 50, 156, 79, 0, 0, OpenChat)) {
        AddToLog "Closing Chat"
        FixClick(138, 30) ;close chat
    }
}

BasicSetup(usedButton := false) {
    global firstStartup, currentMap

    if (!WinActive(rblxID)) {
        WinActivate(rblxID)
    }

    if (ShouldUseRecording.Value) {
        if (!ShouldUseSetup.Value) {
            return
        }
    }

    if (!firstStartup) {
        if (!DoesntHaveSeamless(ModeDropdown.Text)) {
            return
        } else {

        }
    }

    ; Close various UI elements

    CloseChat()
    Sleep 250

    if (ModeDropdown.Text = "Custom" && !usedButton) {
        return
    }

    if (ZoomTech.Value) {
        Zoom()
    }

    if (ZoomTeleport.Value) {
        TeleportToSpawn()
    }

    CloseLeaderboard(false)
    Sleep 250

    if (!StartWalk(usedButton)) {
        HandleMapMovement(currentMap)
    }

    if (!usedButton) {
        firstStartup := false
    }
}

DoesntHaveSeamless(ModeName) {
    static modesWithoutSeamless := ["Boss Rush"]

    for mode in modesWithoutSeamless {
        if (mode = ModeName)
            return true
    }
    return true
}

DetectMap() {
    map := ""

    switch ModeDropdown.Text {
        case "Raid":
            map := RaidDropdown.Text
        case "Story":
            map := StoryDropdown.Text
        case "Portal":
            map := PortalDropdown.Text
            case "Legend Stages":
            map := LegendDropDown.Text
        case "Event":
            map := EventDropdown.Text
    }

    if (map != "")
        AddToLog("Map selected: " map)
    else
        AddToLog("No map selected.")

    return map
}

; Fool's Hunt is picked as Mode "Event" + Event "Fool's Hunt" - the Mode dropdown never says "Fool's Hunt"
; itself, so the map movements must check both
IsFoolsHunt() {
    return ModeDropdown.Text = "Event" && EventDropdown.Text = "Fool's Hunt"
}

HandleMapMovement(MapName) {
    AddToLog("Executing Movement for: " MapName)

    switch MapName {
        case "Planet Greenie":
            MoveForPlanetGreenie()
        case "Snowy Town":
            MoveForSnowyTown()
        case "Sand Village":
            MoveForSandVillage()
        case "Ant Kingdom":
            MoveForAntKingdom()
        case "Magic Town":
            MoveForMagicTown()
        case "Magic Hills":
            (IsFoolsHunt()) ? MoveForMagicHills() : MoveForMagicHill()
        case "Navy Bay":
            MoveForNavyBay()
        case "Alien Spaceship":
            MoveForAlienSpaceship()
        case "Fiend City":
            MoveForFiendCity()
        case "Spirit World":
            MoveForSpiritWorld()
        case "Haunted Academy":
            MoveForHauntedAcademy()
        case "Space Center":
            MoveForSpaceCenter()
        case "Mountain Temple":
            MoveForMountainTemple()
        case "Cursed Festival":
            MoveForCursedFestival()
        case "Nightmare Train":
            MoveForNightmareTrain()
        case "Air Craft":
            MoveForAirCraft()
        case "Hellish City":
            MoveForHellish()
        case "Contracts":
            MoveForContracts()
        case "Shibuya District":
            MoveForShibuya()
        case "Sacred Planet":
            MoveForSacredPlanet()
        case "Snowy Kingdom":
            MoveForSnowyKingdom()
        case "Future City":
            MoveForFutureCity()
        case "Fabled Kingdom":
            MoveForFabledKingdom()
        case "Puppet Island":
            MoveForPuppetIsland()
        case "Virtual Dungeon":
            MoveForVirtualDungeon()
        case "Dungeon Throne":
            MoveForDungeonThrone()
        case "Storm Hideout":
            MoveForStormHideout()
        case "Rain Village":
            MoveForRainVillage()
        case "Spirit Town":
            MoveForSpiritTown()
        case "Ruined City":
            MoveForRuinedCity()
        case "Strange Town":
            MoveForStrangeTown()
        case "Future City (Tyrant)":
            MoveForFutureCity()
    }
}

MoveForPlanetGreenie() {
    if !(IsFoolsHunt()) {
        SendInput ("{a down}")
        SendInput ("{w down}")
        Sleep (2200)
        SendInput ("{a up}")
        SendInput ("{w up}")
    }
}

MoveForAlienSpaceship() {
    if (ok := FT(&X, &Y, 0, 244, 48, 278, 0.15, 0.15, AlienSpaceshipAngle)) {
        if (IsFoolsHunt()) {
            SendInput ("{a down}")
            Sleep (700)
            SendInput ("{a up}")
            KeyWait "a"
            Sleep (1000)
            SendInput ("{w down}")
            Sleep (500)
            SendInput ("{w up}")
            KeyWait "w"
            Sleep (1000)
            SendInput ("{a down}")
            Sleep (1300)
            SendInput ("{a up}")
            KeyWait "a"
            Sleep (1000)
            SendInput ("{w down}")
            Sleep (1000)
            SendInput ("{w up}")
            KeyWait "w"
            Sleep (1000)
        } else {
            FixClick(73, 176, "Right")
            Sleep (2500)
        }
    } else {
        if (IsFoolsHunt()) {
            SendInput ("{w down}")
            Sleep (700)
            SendInput ("{w up}")
            KeyWait "w"
            Sleep (1000)
            SendInput ("{d down}")
            Sleep (700)
            SendInput ("{d up}")
            KeyWait "d"
            Sleep (1000)
            SendInput ("{w down}")
            Sleep (1500)
            SendInput ("{w up}")
            KeyWait "w"
            Sleep (1000)
            SendInput ("{d down}")
            Sleep (1600)
            SendInput ("{d up}")
            KeyWait "d"
            Sleep (1000)
        } else {
            FixClick(658, 61, "Right")
            Sleep (2500)
        }
    }
}

MoveForSnowyTown() {
    if (IsFoolsHunt()) {
        SendInput ("{d down}")
        Sleep (3000)
        SendInput ("{d up}")
        KeyWait("d")
        Sleep (1000)
        SendInput ("{w down}")
        Sleep (2400)
        SendInput ("{w up}")
        KeyWait("w")
        Sleep (1000)
        SendInput ("{d down}")
        Sleep (4300)
        SendInput ("{d up}")
        KeyWait("d")
        Sleep (1000)
        SendInput ("{s down}")
        Sleep (800)
        SendInput ("{s up}")
        KeyWait("s")
        Sleep (1000)
        SendInput ("{d down}")
        Sleep (1000)
        SendInput ("{d up}")
        KeyWait("d")
        Sleep (1000)
    } else {
        SendInput ("{d down}")
        Sleep (3000)
        SendInput ("{d up}")
        KeyWait("d")
        Sleep (1000)
        SendInput ("{w down}")
        Sleep (1000)
        SendInput ("{w up}")
        KeyWait("w")
        Sleep (1000)
    }
}

MoveForNavyBay() {
    if (IsFoolsHunt()) {
        SendInput ("{d down}")
        SendInput ("{w down}")
        Sleep (1000)
        SendInput ("{d up}")
        SendInput ("{w up}")
    } else {
        SendInput ("{a down}")
        SendInput ("{w down}")
        Sleep (1700)
        SendInput ("{a up}")
        SendInput ("{w up}")
    }
}

MoveForSandVillageOld() {
    Fixclick(777, 415, "Right")
    Sleep (3000)
    Fixclick(560, 555, "Right")
    Sleep (3000)
    Fixclick(125, 570, "Right")
    Sleep (3000)
    Fixclick(200, 540, "Right")
    Sleep (3000)
}

MoveForSandVillage() {
    SendInput ("{s down}")
    Sleep (700)
    SendInput ("{s up}")
    KeyWait("s")
    Sleep (1000)
    SendInput ("{d down}")
    Sleep (2700)
    SendInput ("{d up}")
    KeyWait("d")
    Sleep (1000)
    SendInput ("{s down}")
    Sleep (2400)
    SendInput ("{s up}")
    KeyWait("s")
    Sleep (1000)
    SendInput ("{a down}")
    Sleep (2400)
    SendInput ("{a up}")
    KeyWait("a")
    Sleep (1000)
    SendInput ("{s down}")
    Sleep (1800)
    SendInput ("{s up}")
    KeyWait("s")

}

MoveForFiendCity() {
    SendInput ("{s down}")
    Sleep (500)
    SendInput ("{s up}")
    Sleep (500)
    SendInput ("{a down}")
    Sleep (3800)
    SendInput ("{a up}")
    Sleep (500)
    SendInput ("{s down}")
    Sleep (2000)
    SendInput ("{s up}")
}

MoveForSpiritWorld() {
    SendInput ("{d down}")
    SendInput ("{w down}")
    Sleep(4000)
    SendInput ("{d up}")
    SendInput ("{w up}")
    KeyWait("d")
    KeyWait("w")
    Sleep(1000)
    SendInput ("{d down}")
    Sleep (1900)
    SendInput ("{d up}")
    KeyWait "d"
    Sleep (1000)
    SendInput ("{w down}")
    Sleep (2000)
    SendInput ("{w up}")
    KeyWait "w"
    Sleep (1000)
    if (IsFoolsHunt()) {
        SendInput ("{a down}")
        SendInput ("{w down}")
        Sleep(2500)
        SendInput ("{a up}")
        SendInput ("{w up}")
        KeyWait("a")
        KeyWait("w")
        Sleep(1000)
        SendInput ("{w down}")
        Sleep (500)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
    }
}

MoveForAntKingdom() {
    if (ok := FT(&X, &Y, 531, 205, 582, 251, 0.15, 0.15, AntKingdomAngle)) {
        SendInput ("{a down}") ; Move Towards Gate
        Sleep (1000)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
        SendInput ("{s down}")
        Sleep (500)
        SendInput ("{s up}")
        KeyWait "s"
        Sleep (1000)
        SendInput ("{a down}")
        Sleep (500)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
        SendInput ("{s down}")
        Sleep (500)
        SendInput ("{s up}")
        KeyWait "s"
        Sleep (1000)
        SendInput ("{a down}")
        Sleep (900)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)

        SendInput ("{s down}") ; Move Out Of Gate
        Sleep (300)
        SendInput ("{s up}")
        KeyWait "s"
        Sleep (1000)
        SendInput ("{a down}")
        Sleep (4000)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)

        SendInput ("{w down}") ; Move Towards Enemy Spawn
        Sleep (1000)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
        SendInput ("{a down}")
        Sleep (500)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
        SendInput ("{w down}")
        Sleep (3000)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
        if (IsFoolsHunt()) {
            SendInput ("{a down}")
            Sleep (1500)
            SendInput ("{a up}")
            KeyWait "a"
            Sleep (1000)
        }
    } else {
        SendInput ("{a down}")
        Sleep (500)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
        SendInput ("{s down}")
        Sleep (500)
        SendInput ("{s up}")
        KeyWait "s"
        Sleep (1000)
        SendInput ("{a down}")
        Sleep (500)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
        SendInput ("{s down}")
        Sleep (1400)
        SendInput ("{s up}")
        KeyWait "s"
        Sleep (1000)
        SendInput ("{a down}")
        Sleep (800)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
        SendInput ("{s down}")
        Sleep (3000)
        SendInput ("{s up}")
        KeyWait "s"
        Sleep (1000)
        SendInput ("{a down}")
        Sleep (2800)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
        SendInput ("{w down}")
        Sleep (1500)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
        SendInput ("{a down}")
        Sleep (1500)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
        SendInput ("{w down}")
        Sleep (2000)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
        SendInput ("{a down}")
        Sleep (500)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
        SendInput ("{w down}")
        Sleep (1000)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
        SendInput ("{a down}")
        Sleep (800)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
    }
}

MoveForMagicTown() {
    SendInput ("{d down}")
    Sleep (3000)
    SendInput ("{d up}")
    Sleep (1000)
    KeyWait("d")
    Sleep (1000)
    SendInput ("{s down}")
    Sleep (1200)
    SendInput ("{s up}")
    Sleep (1000)
    KeyWait("s")
    Sleep (1000)
    if (IsFoolsHunt()) {
        SendInput ("{d down}")
        Sleep (5800)
        SendInput ("{d up}")
        Sleep (1000)
        KeyWait("d")
        Sleep (1000)
        SendInput ("{s down}")
        Sleep (700)
        SendInput ("{s up}")
        Sleep (1000)
        KeyWait("s")
        /*SendInput ("{d down}") ;Garden
        Sleep (4700)
        SendInput ("{d up}")
        Sleep (1000)
        KeyWait("d")*/
    } else {
        SendInput ("{d down}")
        Sleep (3200)
        SendInput ("{d up}")
        Sleep (1000)
        KeyWait("d")
    }
}

MoveForMagicHill() {
    if (ok := FT(&X, &Y, 518, 334, 566, 404, 0.20, 0.20, MagicHillsBench) or (ok := FT(&X, &Y, 522, 339, 557, 402, 0.20,
        0.20, MagicHillLegendStageBench))) {
        SendInput ("{d down}")
        Sleep (500)
        SendInput ("{d up}")
        KeyWait "d"
        Sleep (1000)
        SendInput ("{w down}")
        Sleep (2600)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
        SendInput ("{d down}")
        Sleep (500)
        SendInput ("{d up}")
        KeyWait "d"
        Sleep (1000)
        SendInput ("{w down}")
        Sleep (4000)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
        SendInput ("{a down}")
        Sleep (1000)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
        SendInput ("{w down}")
        Sleep (4000)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
        SendInput ("{d down}")
        Sleep (2500)
        SendInput ("{d up}")
        KeyWait "d"
        Sleep (1000)
        SendInput ("{w down}")
        Sleep (2800)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
        SendInput ("{d down}")
        Sleep (1500)
        SendInput ("{d up}")
        KeyWait "d"
        Sleep (1000)
    } else {
        SendInput ("{w down}")
        Sleep (500)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
        SendInput ("{a down}")
        Sleep (7000)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
        SendInput ("{s down}")
        Sleep (1400)
        SendInput ("{s up}")
        KeyWait "s"
        Sleep (1000)
        SendInput ("{a down}")
        Sleep (3500)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
        SendInput ("{w down}")
        Sleep (2800)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
        SendInput ("{a down}")
        Sleep (3500)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
        SendInput ("{w down}")
        Sleep (1100)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
    }
}

MoveForMagicHills() {
    if (ok := FT(&X, &Y, 518, 334, 566, 404, 0.20, 0.20, MagicHillsBench) or (ok := FT(&X, &Y, 522, 339, 557, 402, 0.20,
        0.20, MagicHillLegendStageBench))) {
        SendInput ("{d down}")
        Sleep (500)
        SendInput ("{d up}")
        KeyWait "d"
        Sleep (1000)
        SendInput ("{w down}")
        Sleep (2600)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
        SendInput ("{d down}")
        Sleep (500)
        SendInput ("{d up}")
        KeyWait "d"
        Sleep (1000)
        SendInput ("{w down}")
        Sleep (4000)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
        SendInput ("{a down}")
        Sleep (1000)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
        SendInput ("{w down}")
        Sleep (4000)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
        SendInput ("{d down}")
        Sleep (2500)
        SendInput ("{d up}")
        KeyWait "d"
        Sleep (1000)
        SendInput ("{w down}")
        Sleep (2800)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
        SendInput ("{d down}")
        Sleep (1900)
        SendInput ("{d up}")
        KeyWait "d"
        Sleep (1000)
        SendInput ("{w down}")
        Sleep (2700)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
        SendInput ("{a down}")
        Sleep (1300)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
        SendInput ("{w down}")
        Sleep (1500)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
        SendInput ("{a down}")
        Sleep (1000)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
        SendInput ("{w down}")
        Sleep (700)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
        SendInput ("{a down}")
        Sleep (800)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
    } else {
        SendInput ("{w down}")
        Sleep (500)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
        SendInput ("{a down}")
        Sleep (7000)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
        SendInput ("{s down}")
        Sleep (1400)
        SendInput ("{s up}")
        KeyWait "s"
        Sleep (1000)
        SendInput ("{a down}")
        Sleep (3500)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
        SendInput ("{w down}")
        Sleep (2800)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
        SendInput ("{a down}")
        Sleep (3500)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
        SendInput ("{w down}")
        Sleep (1500)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
        SendInput ("{a down}")
        Sleep (2700)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
        SendInput ("{s down}")
        Sleep (1800)
        SendInput ("{s up}")
        KeyWait "s"
        Sleep (1000)
        SendInput ("{a down}")
        Sleep (1600)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
        SendInput ("{s down}")
        Sleep (1800)
        SendInput ("{s up}")
        KeyWait "s"
        Sleep (1000)
    }
}

MoveForHauntedAcademy() {
    SendInput ("{d down}")
    sleep 4700
    SendInput ("{d up}")
    KeyWait "d"
    /*if (ok := FT(&X, &Y, 173, 401, 224, 437, 0.15, 0.15, HauntedAcademyAngle)) {
        if (ModeDropdown.Text = "Story") {
            AddToLog("Angle 1")
            SendInput ("{d up}")
            Sleep 100
            SendInput ("{d down}")
            Sleep 3500
            SendInput ("{d up}")
            KeyWait "d"
        } else {
            SendInput ("{w up}")
            Sleep 100
            SendInput ("{w down}")
            Sleep 6500
            SendInput ("{w up}")
            KeyWait "w"
        }
    }
    if (ok := FT(&X, &Y, 720, 124, 766, 170, 0.15, 0.15, HauntedAcademyAngle2)) {
        if (ModeDropdown.Text = "Story") {
            SendInput ("{s up}")
            Sleep 100
            SendInput ("{s down}")
            Sleep 3500
            SendInput ("{s up}")
            KeyWait "s"
        } else {
            SendInput ("{d up}")
            Sleep 100
            SendInput ("{d down}")
            Sleep 6500
            SendInput ("{d up}")
            KeyWait "s"
        }
    }*/
}

MoveForSpaceCenter() {
    if (IsFoolsHunt()) {
        /* if (ok := FT(&X, &Y, 248, 402, 283, 438, 0.20, 0.20, SpaceCenterAngle)) {
           SendInput ("{a down}")
           Sleep (2000)
           SendInput ("{a up}")
           KeyWait "a"
           Sleep (1000)
           SendInput ("{w down}")
           Sleep (600)
           SendInput ("{w up}")
           KeyWait "w"
           Sleep (1000)
           SendInput ("{a down}")
           Sleep (900)
           SendInput ("{a up}")
           KeyWait "a"
           Sleep (1000)
           SendInput ("{s down}")
           Sleep (2800)
           SendInput ("{s up}")
           KeyWait "s"
           Sleep (1000)
           SendInput ("{d down}")
           Sleep (500)
           SendInput ("{d up}")
           KeyWait "d"
           Sleep (1000)
        */
        ;} else {
        SendInput ("{d down}")
        Sleep (2000)
        SendInput ("{d up}")
        KeyWait "d"
        Sleep (1000)
        SendInput ("{s down}")
        Sleep (600)
        SendInput ("{s up}")
        KeyWait "s"
        Sleep (1000)
        SendInput ("{d down}")
        Sleep (900)
        SendInput ("{d up}")
        KeyWait "d"
        Sleep (1000)
        SendInput ("{w down}")
        Sleep (2800)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
        SendInput ("{a down}")
        Sleep (500)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
    }
    else {
        /*if (ok := FT(&X, &Y, 248, 402, 283, 438, 0.20, 0.20, SpaceCenterAngle)) {
           SendInput ("{a down}")
           Sleep (2000)
           SendInput ("{a up}")
           KeyWait "a"
           Sleep (1000)
           SendInput ("{w down}")
           Sleep (600)
           SendInput ("{w up}")
           KeyWait "w"
        } else {*/
        SendInput ("{d down}")
        Sleep (2000)
        SendInput ("{d up}")
        KeyWait "d"
        Sleep (1000)
        SendInput ("{w down}")
        Sleep (1500)
        SendInput ("{w up}")
        KeyWait "s"
    }
}
;}

MoveForMountainTemple() {
    if (IsFoolsHunt()) {
        if (ok := FT(&X, &Y, 667, 185, 765, 244, 0.15, 0.15, MountainTempleAngle)) {
            SendInput ("{w down}")
            Sleep (2000)
            SendInput ("{w up}")
            KeyWait "w"
        } else {
            SendInput ("{s down}")
            Sleep (2000)
            SendInput ("{s up}")
            KeyWait "s"
        }
    } else {
        SendInput ("{w down}")
        SendInput ("{d down}")
        Sleep(2000)
        SendInput ("{w up}")
        SendInput ("{d up}")
        KeyWait("w")
        KeyWait("d")
        Sleep(1000)
        /* if (ok := FT(&X, &Y, 667, 185, 765, 244, 0.15, 0.15, MountainTempleAngle)) {
             SendInput ("{w down}")
             SendInput ("{d down}")
             Sleep(2000)
             SendInput ("{w up}")
             SendInput ("{d up}")
             KeyWait("w")
             KeyWait("d")
             Sleep(1000)
         } else {
             SendInput ("{a down}")
             SendInput ("{s down}")
             Sleep(2000)
             SendInput ("{a up}")
             SendInput ("{s up}")
             KeyWait("a")
             KeyWait("s")
             Sleep(1000)
        } */
    }
}

MoveForFabledKingdom() {
    if (IsFoolsHunt()) {
        if (ok := FT(&X, &Y, 506, 248, 564, 308, 0.15, 0.15, FabledKingdomAngle)) {
            SendInput ("{s down}")
            Sleep (6000)
            SendInput ("{s up}")
            KeyWait "s"
            Sleep (1000)
            SendInput ("{a down}")
            Sleep (400)
            SendInput ("{a up}")
            KeyWait "a"
        } else {
            SendInput ("{w down}")
            Sleep (6000)
            SendInput ("{w up}")
            KeyWait "w"
            Sleep (1000)
            SendInput ("{d down}")
            Sleep (400)
            SendInput ("{d up}")
            KeyWait "d"
        }
    }
}

MoveForFutureCity() {
    if (IsFoolsHunt()) {
        if (ok := FT(&X, &Y, 699, 526, 797, 574, 0.15, 0.15, FutureCityAngle)) {
            SendInput ("{s down}")
            Sleep (7300)
            SendInput ("{s up}")
            KeyWait "a"
            Sleep (1000)
        } else {
            SendInput ("{w down}")
            Sleep (7300)
            SendInput ("{w up}")
            KeyWait "w"
            Sleep (1000)
        }
    }
}

MoveForSnowyKingdom() {
    /*
    if (IsFoolsHunt()) {
        if (ok := FT(&X, &Y, 126, 420, 200, 452, 0.15, 0.15, SnowyKingdomAngle)) {
            SendInput ("{d down}")
            Sleep (300)
            SendInput ("{d up}")
            KeyWait "d"
            Sleep (1000)
            SendInput ("{w down}")
            Sleep (3000)
            SendInput ("{w up}")
            KeyWait "w"
            Sleep (1000)
            SendInput ("{d down}")
            Sleep (2800)
            SendInput ("{d up}")
            KeyWait "d"
            Sleep (1000)
            SendInput ("{w down}")
            Sleep (2500)
            SendInput ("{w up}")
            KeyWait "w"
            Sleep (1000)
            SendInput ("{d down}")
            Sleep (500)
            SendInput ("{d up}")
            KeyWait "d"
            Sleep (1000)
        } else {
            SendInput ("{a down}")
            Sleep (300)
            SendInput ("{a up}")
            KeyWait "a"
            Sleep (1000)
            SendInput ("{s down}")
            Sleep (3000)
            SendInput ("{s up}")
            KeyWait "s"
            Sleep (1000)
            SendInput ("{a down}")
            Sleep (2800)
            SendInput ("{a up}")
            KeyWait "a"
            Sleep (1000)
            SendInput ("{s down}")
            Sleep (2000)
            SendInput ("{s up}")
            KeyWait "s"
            Sleep (1000)
        }
    }
    */
}

MoveForPuppetIsland() {
    if (IsFoolsHunt()) {
        if (ok := FT(&X, &Y, 519, 484, 594, 559, 0.15, 0.15, PuppetIslandAngle)) {
            SendInput ("{w down}")
            Sleep (2800)
            SendInput ("{w up}")
            KeyWait "w"
            Sleep (1000)
            SendInput ("{a down}")
            Sleep (2000)
            SendInput ("{a up}")
            KeyWait "a"
            Sleep (1000)
        } else {
            SendInput ("{s down}")
            Sleep (2800)
            SendInput ("{s up}")
            KeyWait "s"
            Sleep (1000)
            SendInput ("{d down}")
            Sleep (2000)
            SendInput ("{d up}")
            KeyWait "d"
            Sleep (1000)
        }
    }
}

MoveForVirtualDungeon() {
    if (IsFoolsHunt()) {
        if (ok := FT(&X, &Y, 592, 505, 663, 571, 0.15, 0.15, VirtualDungeonAngle)) {
            SendInput ("{w down}")
            Sleep (1800)
            SendInput ("{w up}")
            KeyWait "w"
            Sleep (1000)
        } else if (ok := FT(&X, &Y, 160, 515, 228, 591, 0.15, 0.15, VirtualDungeonAngle2)) {
            SendInput ("{d down}")
            Sleep (1800)
            SendInput ("{d up}")
            KeyWait "d"
            Sleep (1000)
        } else {
            SendInput ("{a down}")
            Sleep (1800)
            SendInput ("{a up}")
            KeyWait "a"
            Sleep (1000)
        }
    }
}

MoveForStormHideout() {
    if (IsFoolsHunt()) {
        SendInput ("{a down}")
        Sleep (200)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
        SendInput ("{w down}")
        Sleep (5000)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
        SendInput ("{d down}")
        Sleep (1500)
        SendInput ("{d up}")
        KeyWait "d"
        Sleep (1000)
        SendInput ("{w down}")
        Sleep (200)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
    }
}

MoveForSpiritTown() {
    if (IsFoolsHunt()) { ; Old Spirit Town Angle 224, 354, 300, 419
        if (ok := FT(&X, &Y, 648, 284, 740, 336, 0.15, 0.15, SpiritTownAngle2)) {
            SendInput ("{w down}")
            Sleep (3000)
            SendInput ("{w up}")
            KeyWait "w"
            Sleep (1000)
            SendInput ("{d down}")
            Sleep (3700)
            SendInput ("{d up}")
            KeyWait "d"
            Sleep (1000)
            SendInput ("{w down}")
            Sleep (500)
            SendInput ("{w up}")
            KeyWait "w"
        } else {
            SendInput ("{s down}")
            Sleep (3000)
            SendInput ("{s up}")
            KeyWait "s"
            Sleep (1000)
            SendInput ("{a down}")
            Sleep (3700)
            SendInput ("{a up}")
            KeyWait "a"
            Sleep (1000)
            SendInput ("{s down}")
            Sleep (500)
            SendInput ("{s up}")
            KeyWait "s"
            Sleep (1000)
        }
    }
}

MoveForRuinedCity() {
    if (IsFoolsHunt()) {
        if (ok := FT(&X, &Y, 37, 515, 129, 588, 0.15, 0.15, RuinedCityAngle)) {
            SendInput ("{d down}")
            Sleep (500)
            SendInput ("{d up}")
            KeyWait "d"
            Sleep (1000)
            SendInput ("{w down}")
            Sleep (800)
            SendInput ("{w up}")
            KeyWait "w"
            Sleep (1000)
            SendInput ("{d down}")
            Sleep (4000)
            SendInput ("{d up}")
            KeyWait "d"
            Sleep (1000)
        } else {
            SendInput ("{a down}")
            Sleep (500)
            SendInput ("{a up}")
            KeyWait "a"
            Sleep (1000)
            SendInput ("{s down}")
            Sleep (800)
            SendInput ("{s up}")
            KeyWait "s"
            Sleep (1000)
            SendInput ("{a down}")
            Sleep (4000)
            SendInput ("{a up}")
            KeyWait "a"
            Sleep (1000)
        }
    }
}

MoveForRainVillage() {
    /* if (ok := FT(&X, &Y, 16, 369, 155, 470, 0.15, 0.15, RainVillageAngle)) {
         SendInput ("{w down}")
         Sleep (2000)
         SendInput ("{w up}")
         KeyWait "w"
         Sleep (1000)
         SendInput ("{a down}")
         Sleep (500)
         SendInput ("{a up}")
         KeyWait "a"
         Sleep (1000)
     } else {
         SendInput ("{a down}")
         Sleep (2000)
         SendInput ("{a up}")
         KeyWait "a"
         Sleep (1000)
         SendInput ("{s down}")
         Sleep (500)
         SendInput ("{s up}")
         KeyWait "s"
         Sleep (1000)
     }
    */
}

MoveForDungeonThrone() {
    if (IsFoolsHunt()) {
        if (ok := FT(&X, &Y, 15, 335, 80, 461, 0.15, 0.15, DungeonThroneAngle)) {
            SendInput ("{s down}")
            Sleep (4500)
            SendInput ("{s up}")
            KeyWait "s"
            Sleep (1000)
        } else {
            SendInput ("{w down}")
            Sleep (4500)
            SendInput ("{w up}")
            KeyWait "w"
            Sleep (1000)
        }
    }
}

MoveForStrangeTown() {
    if (IsFoolsHunt() or ModeDropdown.Text = "Raid") {
        if (ok := FT(&X, &Y, 34, 483, 82, 512, 0.15, 0.15, StrangeTownAngle)) {
            /*SendInput ("{a down}") ; Move To Center Garden
            Sleep (1600)
            SendInput ("{a up}")
            KeyWait "a"
            Sleep (1000)
            SendInput ("{w down}")
            Sleep (600)
            SendInput ("{w up}")
            KeyWait "w"
            Sleep (1000)*/
            SendInput ("{a down}")
            Sleep (2500)
            SendInput ("{a up}")
            KeyWait "a"
            Sleep (1000)
        } else {
            SendInput ("{d down}")
            Sleep (2500)
            SendInput ("{d up}")
            KeyWait "d"
            Sleep (1000)
        }
    }
}

MoveForCursedFestival() {
    if (IsFoolsHunt()) {
        if (ok := FT(&X, &Y, 47, 213, 107, 257, 0.15, 0.15, CursedFestivalAngle)) {
            SendInput ("{d down}")
            Sleep (1800)
            SendInput ("{d up}")
            KeyWait "d"
            Sleep (1000)
            SendInput ("{s down}")
            Sleep (800)
            SendInput ("{s up}")
            KeyWait "s"
            Sleep (1000)
        } else {
            SendInput ("{a down}")
            Sleep (1800)
            SendInput ("{a up}")
            KeyWait "a"
            Sleep (1000)
            SendInput ("{w down}")
            Sleep (800)
            SendInput ("{w up}")
            KeyWait "w"
            Sleep (1000)
        }
    } else {
        if (ok := FT(&X, &Y, 560, 285, 615, 350, 0.15, 0.15, FestivalAngle)) {
            SendInput ("{d down}")
            Sleep (1800)
            SendInput ("{d up}")
            KeyWait "d"
            Sleep (1000)
        } else {
            SendInput ("{a down}")
            Sleep (1800)
            SendInput ("{a up}")
            KeyWait "a"
            Sleep (1000)
        }
    }
}

MoveForNightmareTrain() {
    SendInput ("{a down}")
    sleep (1800)
    SendInput ("{a up}")
}

MoveForAirCraftOld() {
    SendInput ("{s down}")
    sleep (800)
    SendInput ("{s up}")
}

MoveForAirCraft() {
    if (ok := FT(&X, &Y, 535, 110, 620, 175, 0.15, 0.15, AirCraftAngle)) {
        SendInput ("{s down}")
        Sleep (800)
        SendInput ("{s up}")
        KeyWait "s"
        Sleep (1000)
        SendInput ("{d down}")
        Sleep (1000)
        SendInput ("{d up}")
        KeyWait "d"
        Sleep (1000)
        SendInput ("{s down}")
        Sleep (800)
        SendInput ("{s up}")
        KeyWait "s"
        Sleep (1000)
    } else {
        if (IsFoolsHunt()) {
            SendInput ("{w down}")
            Sleep (800)
            SendInput ("{w up}")
            KeyWait "w"
            Sleep (1000)
            SendInput ("{a down}")
            Sleep (1000)
            SendInput ("{a up}")
            KeyWait "a"
            Sleep (1000)
            SendInput ("{w down}")
            Sleep (800)
            SendInput ("{w up}")
            KeyWait "w"
            Sleep (1000)
        } else {
            SendInput ("{w down}")
            Sleep (1000)
            SendInput ("{w up}")
            KeyWait "w"
            Sleep (1000)
            SendInput ("{d down}")
            Sleep (1000)
            SendInput ("{d up}")
            KeyWait "d"
            Sleep (1000)
            SendInput ("{w down}")
            Sleep (400)
            SendInput ("{w up}")
            KeyWait "w"
            Sleep (1000)
            SendInput ("{d down}")
            Sleep (1000)
            SendInput ("{d up}")
            KeyWait "d"
            Sleep (1000)
        }
    }
}

MoveForHellishOlder() {
    Fixclick(600, 300, "Right")
    Sleep (7000)
}

MoveForHellish() {
    if (IsFoolsHunt()) {
        if (ok := FT(&X, &Y, 618, 519, 675, 573, 0.15, 0.15, HellishAngle)) {
            SendInput ("{a down}")
            Sleep (1250)
            SendInput ("{a up}")
            KeyWait "a"
            Sleep (1000)
            SendInput ("{w down}")
            Sleep (2300)
            SendInput ("{w up}")
            KeyWait "w"
            Sleep (1000)
            SendInput ("{a down}")
            Sleep (1000)
            SendInput ("{a up}")
            KeyWait "a"
            Sleep (1000)
            SendInput ("{w down}")
            Sleep (2000)
            SendInput ("{w up}")
            KeyWait "w"
            Sleep (1000)
            SendInput ("{d down}")
            Sleep (500)
            SendInput ("{d up}")
            KeyWait "d"
            Sleep (1000)
            SendInput ("{w down}")
            Sleep (1000)
            SendInput ("{w up}")
            KeyWait "w"
            Sleep (1000)
            SendInput ("{d down}")
            Sleep (500)
            SendInput ("{d up}")
            KeyWait "d"
            Sleep (1000)
        } else {
            SendInput("{d down}")
            Sleep(1250)
            SendInput("{d up}")
            KeyWait("d")
            Sleep(1000)

            SendInput("{s down}")
            Sleep(2300)
            SendInput("{s up}")
            KeyWait("s")
            Sleep(1000)

            SendInput("{d down}")
            Sleep(1000)
            SendInput("{d up}")
            KeyWait("d")
            Sleep(1000)

            SendInput("{s down}")
            Sleep(2000)
            SendInput("{s up}")
            KeyWait("s")
            Sleep(1000)

            SendInput("{a down}")
            Sleep(500)
            SendInput("{a up}")
            KeyWait("a")
            Sleep(1000)

            SendInput("{s down}")
            Sleep(1000)
            SendInput("{s up}")
            KeyWait("s")
            Sleep(1000)

            SendInput("{a down}")
            Sleep(500)
            SendInput("{a up}")
            KeyWait("a")
            Sleep(1000)
        }
    } else {
        if (ok := FT(&X, &Y, 370, 210, 465, 265, 0.15, 0.15, HellishAngle)) {
            SendInput ("{d down}")
            Sleep (1200)
            SendInput ("{d up}")
            KeyWait "d"
        } else {
            SendInput ("{a down}")
            Sleep (800)
            SendInput ("{a up}")
            KeyWait "a"
            sleep 500
            SendInput ("{w down}")
            Sleep (800)
            SendInput ("{w up}")
            keywait "w"
            sleep 500
            SendInput ("{d down}")
            Sleep (2400)
            SendInput ("{d up}")
            keywait "d"
            sleep 500
            SendInput ("{s down}")
            Sleep (600)
            SendInput ("{s up}")
            keywait "s"
        }
    }
}

MoveForContracts() {
    FixClick(590, 15) ; click on paths
    loop {
        if FindAndClickColor() {
            FixClick(590, 15) ; click on paths
            break
        }
        else {
            AddToLog("Color not found. Turning again.")
            SendInput ("{Left up}")
            Sleep 200
            SendInput ("{Left down}")
            Sleep 750
            SendInput ("{Left up}")
            KeyWait "Left" ; Wait for key to be fully processed
            Sleep 200
        }
    }
}

MoveForShibuya() {
    /*
    if (ok := FT(&X, &Y, 220, 190, 320, 250, 0.15, 0.15, ShibuyaAngle)) {
        SendInput ("{a down}")
        Sleep (600)
        SendInput ("{a up}")
        Sleep (500)
        SendInput ("{a down}")
        SendInput ("{w down}")
        Sleep (1500)
        SendInput ("{a up}")
        SendInput ("{w up}")
    } else {
        SendInput ("{d down}")
        Sleep(2000)
        SendInput ("{d up}")
    }
    */
    SendInput ("{a down}")
    Sleep (600)
    SendInput ("{a up}")
    Sleep (500)
    SendInput ("{a down}")
    SendInput ("{w down}")
    Sleep (1500)
    SendInput ("{a up}")
    SendInput ("{w up}")
}

MoveForSacredPlanet() {
    if (IsFoolsHunt() or ModeDropdown.Text = "Raid") {
        SendInput ("{w down}")
        Sleep (2400)
        SendInput ("{w up}")
        Sleep (1500)
        SendInput ("{a down}")
        Sleep (1000)
        SendInput ("{a up}")
        Sleep (1500)
        SendInput ("{w down}")
        Sleep (300)
        SendInput ("{w up}")
    }
}

RestartStage() {
    global currentMap
    if (TeleportFailsafe.Value) {
        TimerManager.Start("Teleport Failsafe", TeleportFailsafeTimer.Value * 1000)
    }

    if (ModeDropdown.Text = "Event" && EventDropdown.Text = "Fool's Hunt" && BringOwnTeam.Value) {
        TimerManager.Pause("Teleport Failsafe")
        CoordMode("Mouse", "Window")
        ClickAndHoldExit()
        CoordMode("Mouse", "Client")
        Sleep(1000)
        TimerManager.Resume("Teleport Failsafe")
    }

    currentMap := ""

    if (CheckNormalLoadingScreens
        || ModeDropdown.Text = "Event"
        || ModeDropdown.Text = "Infinity Castle") {

        currentMap := (ModeDropdown.Text = "Event" && EventDropdown.Text = "Fool's Hunt")
            ? DetectHuntMap()
            : DetectMapImageSearch()
    } else {
        currentMap := DetectMap()
    }

    ; Wait for loading
    CheckLoaded()

    BasicSetup()

    ; Wait for game to actually start
    StartedGame()

    if (ShouldUseRecording.Value) {
        PlayRecordedActions()
    } else {
        StartPlacingUnits(PlacementPatternDropdown.Text == "Custom" || PlacementPatternDropdown.Text = "Map Specific")
    }

    ; Monitor stage progress
    MonitorStage()
}

Reconnect(force := false) {
    if (FindText(&X, &Y, 202, 206, 601, 256, 0.10, 0.10, Disconnect) || force || TeleportFailsafe.Value && TimerManager
    .HasExpired("Teleport Failsafe")) {
        if (WinExist(rblxID)) {
            if (!WinActive(rblxID)) {
                WinActivate(rblxID)
            }
        }

        ; Wait until internet is available
        while !isConnectedToInternet() {
            AddToLog("❌ No internet connection. Waiting to reconnect...")
            Sleep(5000) ; wait 5 seconds before checking again
        }

        AddToLog("✅ Internet connection verified, attempting to reconnect...")
        sendDCWebhook()

        if (PrivateServerEnabled.Value) {
            psLink := PrivateServerURLBox.Value
            if (psLink != "") {
                serverCode := GetPrivateServerCode(psLink)
                deepLink := "roblox://experiences/start?placeId=8304191830&linkCode=" serverCode
                if (WinExist("ahk_exe RobloxPlayerBeta.exe")) {
                    WinClose("ahk_exe RobloxPlayerBeta.exe")
                    Sleep(3000)
                }
                AddToLog("Connecting to your private server...")
                Run(serverCode = "" ? psLink : deepLink)
                loop {
                    if WinWait("ahk_exe RobloxPlayerBeta.exe", , 15) {
                        AddToLog("New Roblox Window Found!")
                        break
                    } else {
                        AddToLog("Waiting for new Roblox Window...")
                        Sleep(1000)
                    }
                }
            }
        } else {
            Run("roblox://placeID=8304191830")
        }

        AddToLog("Reconnecting to " GameName "...")

        while (!isInLobby()) {
            if (WinExist(rblxID)) {
                WinActivate(rblxID)
                sizeDown()
            }
            Sleep(1250)
        }
        if (TeleportFailsafe.Value) {
            TimerManager.Clear("Teleport Failsafe")
        }
        Sleep(1000)
        AddToLog("Reconnected Successfully!")
        return true
    }

    return false
}

wiggle() {
    MouseMove(1, 1, 5, "R")
    Sleep(30)
    MouseMove(-1, -1, 5, "R")
}

CheckLobby() {
    ; This function only waits for the lobby. It must not start another mode
    ; from inside the previous run's call stack, or repeated runs can overlap.
    loop {
        Sleep(1000)

        if (CheckForLobby()) {
            AddToLog("Returned to lobby")
            return true
        }

        Reconnect()
    }
}

CheckForLobby() {
    return FT(&X, &Y, 742, 239, 789, 502, 0.10, 0.10, ProfileText)
}

CheckLoaded() {
    loop {
        Sleep(500)

        if (ok := FT(&X, &Y, 301, 64, 503, 154, 0, 0, VoteStart)
        or FT(&X, &Y, 301, 64, 503, 154, 0, 0, VoteStartLaptop)
        or FT(&X, &Y, 0, 0, 742, 287, 832, 377, 0.10, 0.10, Units)
        or FT(&X, &Y, 0, 0, 1080, 1080, 0, 0, UnitManager)
        or PixelGetColor(320, 60) = 0x00EE00) {

            AddToLog("Successfully Loaded In")

            if (TeleportFailsafe.Value) {
                TimerManager.Clear("Teleport Failsafe")
            }

            return true
        }

        Reconnect()
    }

    return false
}

StartedGame() {
    HandleStartButton()
    AddToLog("Game started")
}

StartSelectedMode() {

    if (StartsInLobby(ModeDropdown.Text) || StartsInLobby(EventDropdown.Text)) {
        CloseLobbyPopups()
    }

    switch (ModeDropdown.Text) {
        case "Legend Stages":
            StartLegendStage()
        case "Story":
            StartStoryMode()
        case "Raid":
            StartRaidStage()
        case "Custom":
            CustomMode()
        case "Portal":
            StartPortal()
        case "Event":
            StartEvent()
        case "Infinity Castle":
            StartInfinityCastle()
        case "Contracts":
            StartContracts()
    }
}

FormatStageTime(ms) {
    seconds := Floor(ms / 1000)
    minutes := Floor(seconds / 60)
    hours := Floor(minutes / 60)

    minutes := Mod(minutes, 60)
    seconds := Mod(seconds, 60)

    return Format("{:02}:{:02}:{:02}", hours, minutes, seconds)
}

ValidateMode() {
    if (ModeDropdown.Text = "") {
        AddToLog("Please select a gamemode before starting the macro!")
        return false
    }
    if (!confirmClicked) {
        AddToLog("Please click the confirm button before starting the macro!")
        return false
    }
    return true
}

GetNavKeys() {
    return StrSplit(FileExist("Settings\UINavigation.txt") ? FileRead("Settings\UINavigation.txt", "UTF-8") : "\,#,}",
    ",")
}

SetupForInfinite() {
    ChangeCameraMode("Follow")
    Sleep (1000)
    ZoomIn()
    Sleep (1000)
    ZoomOut()
    ChangeCameraMode("Default (Classic)")
    Sleep (1000)
    SendInput ("{a down}")
    Sleep 2000
    SendInput ("{a up}")
    KeyWait "a"
}

ChangeCameraMode(mode := "") {
    AddToLog("Changing camera mode to " mode)
    SendInput("{Escape}") ; Open Roblox Menu
    Sleep (1000)
    FixClick(205, 90) ; Click Settings
    Sleep (1000)
    loop 2 {
        FixClick(336, 209) ; Change Camera Mode
        Sleep (500)
    }
    SendInput("{Escape}") ; Open Roblox Menu
}

ZoomIn() {
    MouseMove 400, 300
    Sleep 100
    FixClick(400, 300)
    Sleep 100

    ; Zoom in smoothly
    loop 12 {
        Send "{WheelUp}"
        Sleep 50
    }

    ; Right-click and drag camera down
    Sleep 100
    MouseMove 400, 300  ; Ensure starting point
    Click "Right Down"
    Sleep 50
    MouseMove 400, 400, 20  ; Drag downward over 20ms
    Sleep 50
    Click "Right Up"
    Sleep 100
}

ZoomOut() {
    ; Zoom out smoothly
    loop 10 {
        Send "{WheelDown}"
        Sleep 50
    }

    ; Move mouse back to center
    MouseMove 400, 300
}

DetectAngle(mode := "Story") {
    switch mode {
        case "Story":
            angle := GetPixel(0xA77EFF, 319, 40, 2, 2, 10)
            if (angle) {
                return 1
            } else {
                return 2
            }

        case "Raid":
            angle := GetPixel(0x008BFF, 154, 192, 2, 2, 10)
            if (angle) {
                return 1
            } else {
                return 2
            }
    }
    return 0
}

HandleStageEnd(waveRestart := false) {
    AddToLog("Stage ended during upgrades, proceeding to results")
    ResetPlacementTracking()
    return MonitorStage()
}

CheckForStartButton() {
    return FindText(&X, &Y, 319, 536, 396, 558, 0.10, 0.10, StartButton)
}

HandleStartButton() {
    loop {
        Sleep(1000)
        if (ok := FT(&X, &Y, 352, 36, 450, 62, 0, 0, VoteStart) or (ok := FT(&X, &Y, 352, 36, 450, 62, 0, 0, VoteStartLaptop))) {
            FixClick(350, 103) ; click yes
            FixClick(350, 100)
            FixClick(350, 97)
            continue  ; Keep waiting if vote screen is still there
        }
        global stageStartTime := A_TickCount
        break
    }
}

StartsInLobby(ModeName) {
    ; Array of modes that usually start in lobby
    static modes := ["Story", "Raid", "Challenge", "Infinity Castle", "Portal", "Legend Stages", "Event"]

    ; Special case: If PortalLobby.Value is set, don't start in lobby for "Portal"
    if (ModeName = "Portal" && !PortalLobby.Value)
        return false

    ; Check if current mode is in the array
    for mode in modes {
        if (mode = ModeName)
            return true
    }
    return false
}

isMenuOpen(name := "") {
    static menuData := Map(
        "Unit Manager", [
            [700, 142, 789, 166, 0.20, 0.20, "UnitManager"],
            [679, 595, 782, 616, 0.20, 0.20, "UnitManagerDark"]
        ],
        "End Screen", [
            [225, 217, 356, 246, 0.20, 0.20, "Results"]
        ],
        "Unit Placement", [
            [23, 363, 12, 12, 25, "PixelCheck", 0x17D6FE] ; Same check as PlacementPanelOpen()
        ]
    )

    if !menuData.Has(name)
        return false

    for each, data in menuData[name] {
        if (data[6] = "PixelCheck") {
            if GetPixel(data[7], data[1], data[2], data[3], data[4], data[5])
                return true
        } else {
            ; FT, not FindText: the regions are Roblox client coordinates
            if FT(&X, &Y, data[1], data[2], data[3], data[4], data[5], data[6], %data[7]%)
                return true
        }
    }
    return false
}

; -------------------------------------------------
; 1. REGION CAPTURE – CLICK TWO CORNERS + COPY TO CLIPBOARD
; -------------------------------------------------

SetRegion(winTitle := "ahk_exe RobloxPlayerBeta.exe") {
    if !WinExist(winTitle) {
        MsgBox("Game window not found: " winTitle)
        return
    }

    ; Ensure mouse coordinates are relative to the Roblox client.
    CoordMode("Mouse", "Client")

    AddToLog("Click TOP-LEFT of wanted search area")

    ; First click
    while !GetKeyState("LButton", "P")
        Sleep(10)

    while GetKeyState("LButton", "P")
        Sleep(10)

    MouseGetPos(&x1, &y1)

    AddToLog("Click BOTTOM-RIGHT of wanted search area (top-left: " x1 "," y1 ")")

    ; Second click
    while !GetKeyState("LButton", "P")
        Sleep(10)

    while GetKeyState("LButton", "P")
        Sleep(10)

    MouseGetPos(&x2, &y2)

    ; Normalize coordinates.
    left := Min(x1, x2)
    top := Min(y1, y2)
    right := Max(x1, x2)
    bottom := Max(y1, y2)

    region := [left, top, right, bottom]

    A_Clipboard := Format("{1}, {2}, {3}, {4}",
        left, top, right, bottom)

    AddToLog("Region: " left ", " top ", " right ", " bottom)

    ; Show the selected region.
    ShowOCRRegions([region])

    return region
}