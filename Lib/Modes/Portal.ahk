#Requires AutoHotkey v2.0

GetMapForFarming(name) {
    farmMap := Map(
        "Eclipse Portal", "Snowy Kingdom",
        "Snowy Kingdom", "Eclipse Portal",
        "Demon Leader's Portal", "Fabled Kingdom",
        "Fabled Kingdom", "Demon Leader's Portal",
        "Noble Portal", "Mountain Temple",
        "Mountain Temple", "Noble Portal",
        "Puppet Portal", "Puppet Island",
        "Puppet Island", "Puppet Portal",
        "Shibuya Portal", "Shibuya District",
        "Shibuya District", "Shibuya Portal"
    )
    if (farmMap.Has(name)) {
        return farmMap[name]
    } else {
        return "no map found"
    }
}

SetMapForPortalFarm(name) {
    return StoryDropdown.Text := name
}

StartPortal() {
    HandlePortalJoin()
    Sleep(2500)
    RestartStage()
}

SwitchActiveFarm() {
    global mode
    if (ModeDropdown.Text = "Story") {
        newMap := GetMapForFarming(StoryDropdown.Text)
        if (newMap != "no map found") {
            ModeDropdown.Text := "Portal"
            PortalDropdown.Text := newMap
            PortalRoleDropdown.Text := "Solo"
            mode := "Portal"
            AddToLog("Switched to " newMap)
            if (debugMessages) {
                AddToLog("Mode: " ModeDropdown.Text)
                AddToLog("Portal: " PortalDropdown.Text)
                AddToLog("Role: " PortalRoleDropdown.Text)
            }
        } else {
            if (debugMessages) {
                AddToLog("No valid portal mapping found for " StoryDropdown.Text)
            }
        }
    } else {
        newMap := GetMapForFarming(PortalDropdown.Text)
        if (newMap != "no map found") {
            ModeDropdown.Text := "Story"
            StoryActDropdown.Text := "Infinity"
            StoryDropdown.Text := newMap
            mode := "Story"
            AddToLog("Switched to " newMap " for farming portals")
            if (debugMessages) {
                AddToLog("Mode: " ModeDropdown.Text)
                AddToLog("Story Act: " StoryActDropdown.Text)
                AddToLog("Story: " StoryDropdown.Text)
            }
        } else {
            if (debugMessages) {
                AddToLog("No valid story mapping found for " PortalDropdown.Text)
            }
        }
    }
}

HandlePortalJoin() {
    switch PortalDropdown.text {
        case "Deception Portal":
            selectedPortal := "Deception"
        case "Demon Leader's Portal":
            selectedPortal := "Demon"
        case "Puppet Portal":
            selectedPortal := "P"
        case "Alien Portal":
            selectedPortal := "A"
        case "Noble Portal":
            selectedPortal := "N"
        case "Shibuya Portal":
            selectedPortal := "S"
        case "Eclipse Portal":
            selectedPortal := "E"
    }
    joinType := PortalRoleDropdown.Text

    FixClick(640, 70) ; Closes Player leaderboard
    Sleep(500)

    ; Click items and portals tab
    ClickItemsAndPortalsTab()

    ; Click search and type portal name
    ClickSearchAndTypePortal(selectedPortal)

    if (joinType = "Solo") {
        AddToLog("Soloing " PortalDropdown.text)
        HandlePortalSelection()
        FixClick(400, 460)  ; Start portal
    } else if (joinType = "Creating") {
        AddToLog("Creating " PortalDropdown.text)
        HandlePortalSelection()
        AddToLog("Waiting 15 seconds for others to join")
        Sleep(15000)
        FixClick(400, 460)  ; Start portal
    } else {
        AddToLog("Please join " PortalDropdown.text " manually")
        Sleep(5000)
    }
}

HandlePortalSelection() {
    sleep 200
    FixClick(211, 289)  ; Click On Portal
    Sleep(1500)
    CheckForPortal(true)
    Sleep(1500)
    FixClick(250, 350) ; Click Open
    Sleep(1500)
}

ClickItemsAndPortalsTab() {
    FixClick(33, 300) ; Click items
    Sleep(1500)
    FixClick(435, 230) ; Click portals tab
    Sleep(1500)
}

ClickSearchAndTypePortal(selectedPortal) {
    FixClick(510, 190) ; Click search
    Sleep(1500)
    ; Loops through every character in selectedPortal one by one
    loop parse, selectedPortal {
        SendInput(A_LoopField)
        Sleep(200) ; Adjust this number to change the delay in milliseconds
    }
    Sleep(200)
}

CheckForPortal(lobby := false) {
    x1 := lobby ? 211 : 255
    y1 := lobby ? 341 : 402
    x2 := lobby ? 401 : 552
    y2 := lobby ? 504 : 455
    portalText := lobby ? UsePortal : SelectPortal
    action := lobby ? "starting portal" : "restarting portal"

    if TryHandlePortal(x1, y1, x2, y2, portalText, action) {
        return
    }
    HandlePortalFallback(lobby)
}

TryHandlePortal(x1, y1, x2, y2, portalText, action) {
    if (ok := FT(&portalX, &portalY, x1, y1, x2, y2, 0, 0, portalText)) {
        AddToLog("Portal detected, " action "...")
        (portalText = SelectPortal) ? ClickSelectPortal() : ClickUsePortal()
            return true
    }
    return false
}

HandlePortalFallback(lobby := false) {
    FixClick(660, 187) ; Close Portal Interface
    SwitchActiveFarm()
    Sleep(1500)
    if (!lobby) {
        ClickReturnToLobby()
    }
    return CheckLobby()
}

HandlePortalEnd() {
    global inChallengeMode

    switch PortalDropdown.Text {
        case "Demon Leader's Portal":
            selectedPortal := "De"
        case "Puppet Portal":
            selectedPortal := "P"
        case "Alien Portal":
            selectedPortal := "A"
        case "Noble Portal":
            selectedPortal := "N"
        case "Shibuya Portal":
            selectedPortal := "S"
        case "Eclipse Portal":
            selectedPortal := "E"
        default:
            AddToLog("Unknown portal selected.")
            return
    }

    loop {
        ; Check whether the lobby has appeared
        if (FT(&X, &Y, 80, 85, 739, 224, 0, 0, LobbyText)
        || FT(&X, &Y, 80, 85, 739, 224, 0, 0, LobbyText2)) {

            if (inChallengeMode) {
                CompleteChallenge()
                return
            }

            AddToLog("Found lobby text - creating/joining new portal")
            Sleep(2000)

            CreateOrJoinPortal(selectedPortal)

            if (PortalRoleDropdown.Text = "Solo") {
                Sleep(1000)
                FixClick(400, 460) ; Start portal
            } else if (PortalRoleDropdown.Text = "Creating") {
                Sleep(5000)
            } else {
                AddToLog("Waiting for next portal")
                Sleep(5000)
            }

            return RestartStage()
        }

        ; Close Unit Placement UI if open
        if (isMenuOpen("Unit Placement")) {
            FixClick(329, 184)
            Sleep(500)
        }

        ; Click to progress through the end screen
        FixClick(560, 560)

        ; Handle the Next button
        if !WaitAndCheck(3000, NextText, 266, 376, 377, 413) {
            ClickUntilGone(0, 0, 266, 376, 377, 413, NextText)
            Sleep(1500)
        }

        Reconnect()

        Sleep(1000)
    }
}

HandleTextFind(x1, y1, x2, y2, text, offsetX, offsetY) {
    if (ok := FT(&X, &Y, x1, y1, x2, y2, 0, 0, text)) {
        ClickUntilGone(0, 0, x1, y1, x2, y2, text, offsetX, offsetY)
    }
}

CompleteChallenge() {
    global inChallengeMode, challengeStartTime
    AddToLog("Challenge completed - returning to selected mode")
    inChallengeMode := false
    challengeStartTime := A_TickCount
    Sleep(1500)
    ClickReturnToLobby()
    CheckLobby()
}

CreateOrJoinPortal(selectedPortal) {
    FixClick(485, 120) ; Select New Portal
    Sleep(1500)
    FixClick(510, 190) ; Click search
    Sleep(1500)
    SendInput(selectedPortal)
    Sleep(1500)
    FixClick(215, 285) ; Click On Portal
    Sleep(1500)
    CheckForPortal(false)
    Sleep(5000)
}

ClickSelectPortal() {
    ClickUntilGone(0, 0, 255, 402, 552, 455, SelectPortal)
}

ClickUsePortal() {
    ClickUntilGone(0, 0, 211, 341, 401, 504, UsePortal)
}

HandlePortalReJoin() {
    switch PortalDropdown.text {
        case "Demon Leader's Portal":
            selectedPortal := "De"
        case "Puppet Portal":
            selectedPortal := "P"
        case "Alien Portal":
            selectedPortal := "A"
        case "Noble Portal":
            selectedPortal := "N"
        case "Shibuya Portal":
            selectedPortal := "S"
        case "Eclipse Portal":
            selectedPortal := "E"
    }

    joinType := PortalRoleDropdown.Text

    loop {
        Sleep(3000)
        FixClick(560, 560)

        HandleTextFind(300, 190, 360, 250, UnitExit, -4, -35)
        Sleep(1500)

        HandleTextFind(201, 196, 633, 508, NextText, -4, -35)

        HandleTextFind(80, 85, 739, 224, LobbyText, -4, -35)

        if (ok := FT(&X, &Y, 746, 514, 789, 530, 0, 0, AreaText)) {
            if (!inChallengeMode && IsChallengeReady()) {
                AddToLog("Schedule: next step")
                return StartSelectedMode()
            }

            if (inChallengeMode) {
                CompleteChallenge()
                return
            }

            AddToLog("Found Lobby Text - creating/joining new portal")
            Sleep(2000)

            FixClick(640, 70) ; Closes Player leaderboard
            Sleep(500)

            ; Click items and portals tab
            ClickItemsAndPortalsTab()

            ; Click search and type portal name
            ClickSearchAndTypePortal(selectedPortal)

            if (joinType = "Solo") {
                AddToLog("Soloing " selectedPortal)
                HandlePortalSelection()
                FixClick(400, 460)  ; Start portal
                return RestartStage()
            } else if (joinType = "Creating") {
                AddToLog("Creating " selectedPortal)
                HandlePortalSelection()
                AddToLog("Waiting 15 seconds for others to join")
                Sleep(15000)
                FixClick(400, 460)  ; Start portal
                return RestartStage()
            } else {
                AddToLog("Please join " selectedPortal " manually")
                Sleep(5000)
            }
        }
    }
}