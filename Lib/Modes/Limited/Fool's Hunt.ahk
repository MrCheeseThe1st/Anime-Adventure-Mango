#Requires AutoHotkey v2.0

ClickAndHoldExit() {

    if WinExist(rblxID) {
        WinActivate(rblxID)
    } else {
        return
    }

    AddToLog("Freezing client to bring your own units...")

    ; Make the AHK GUI click-through
    SetClickThrough(true)

    try {
        FreezeClient()
    } finally {
        SetClickThrough(false)
    }

    if WinExist(rblxID) {
        if (!WinActive(rblxID)) {
            WinActivate(rblxID)
        }
    }

    AddToLog("Client should be frozen now, continuing...")
    Sleep 1000
}

GetMinimizeBtnPos(hwnd, &x, &y) {
    rect := Buffer(16)
    ; DWMWA_CAPTION_BUTTON_BOUNDS = 5 (min+max+close area, window-relative)
    if DllCall("dwmapi\DwmGetWindowAttribute", "ptr", hwnd, "uint", 5, "ptr", rect, "uint", 16)
        return false
    l := NumGet(rect, 0, "int"), t := NumGet(rect, 4, "int")
    r := NumGet(rect, 8, "int"), b := NumGet(rect, 12, "int")
    x := Round(l + (r - l) / 6)   ; center of the first of 3 buttons = minimize
    y := Round((t + b) / 2)
    return true
}

FreezeClient(x := 692, y := 20, holdTime := 110000, detectFn := "", &detected := "") {
    global rblxID
    detected := ""
    hwnd := WinExist(rblxID)
    if !hwnd
        return false
    WinActivate(hwnd)
    if !WinWaitActive(hwnd, , 3)
        return false
    if GetMinimizeBtnPos(hwnd, &nx, &ny)
        x := nx, y := ny

    CoordMode("Mouse", "Window")
    MouseMove(x, y)
    Sleep(150)
    SendEvent("{RButton down}")

    try {
        start := A_TickCount
        while (A_TickCount - start < holdTime) {
            if (detectFn && detected = "") {
                result := detectFn()
                if (result != "") {
                    detected := result
                    AddToLog("Loading screen detected while frozen: " result)
                    ; keep holding; remove this line if you'd rather release early
                }
            }
            Sleep(100)
        }
    } finally {
        MouseMove(0, 125, 2, "R")
        SendEvent("{RButton up}")
    }

    Sleep(50)
    CoordMode("Mouse", "Client")
    return true
}

StartFoolsHunt() {
    ; Execute the movement pattern
    AddToLog("Moving to position for Fool's Hunt")
    EventMovement()

    ; Start stage
    while !(ok := CheckForMatchmakingPrompt()) {
        Reconnect() ; Added Disconnect Check
        EventMovement()
    }

    ; Handle play mode selection
    if (MatchMaking.Value) {
        FindMatch()
    } else {
        PlayHere()
    }

    while (ok := FT(&X, &Y, 3, 548, 56, 594, 0, 0, LobbySettings)) {
        Sleep(500)
    }

    AddToLog("Starting Fool's Hunt")
    RestartStage()
}

EventMovement() {
    FixClick(592, 204) ; Close Matchmaking UI (Just in case)
    Sleep (200)
    FixClick(85, 295) ; Click Play
    sleep (1000)
    SendInput ("{a up}")
    Sleep 100
    SendInput ("{a down}")
    Sleep 6000
    SendInput ("{a up}")
    KeyWait "a" ; Wait for "d" to be fully processed
    Sleep 1200
}

CheckForFoolBuffs() {
    CheckForRandomBuff()
    CheckForAstralGate()
    CheckForAstralSummon()
    CheckForClone()
    CheckForMerge()
    CheckForRefund()
}

CheckForRandomBuff() {
    global successfulCoordinates, maxedCoordinates
    if (ok := FT(&X, &Y, 255, 561, 551, 605, 0.35, 0.35, RandomBuff)) {
        ; Prefer maxedCoordinates
        if maxedCoordinates.Length > 0 {
            randomIndex := Random(1, maxedCoordinates.Length)
            coord := maxedCoordinates[randomIndex]

            AddToLog("Found random buff, applying to maxed unit at X" coord.x " Y" coord.y)
            FixClick(X, Y - 20)
            Sleep(500)
            FixClick(coord.x, coord.y)
            Sleep(250)
            return true
        }

        ; Otherwise use successfulCoordinates
        else if successfulCoordinates.Length > 0 {
            randomIndex := Random(1, successfulCoordinates.Length)
            coord := successfulCoordinates[randomIndex]

            AddToLog("Found random buff, applying to random unit at X" coord.x " Y" coord.y)
            FixClick(X, Y - 20)
            Sleep(500)
            FixClick(coord.x, coord.y)
            Sleep(250)
            return true
        }
    }
    return false
}

CheckForClone() {
    global successfulCoordinates, maxedCoordinates
    if (ok := FT(&X, &Y, 255, 561, 551, 605, 0.25, 0.25, Clone)) {
        ; Prefer maxedCoordinates
        if maxedCoordinates.Length > 0 {
            randomIndex := Random(1, maxedCoordinates.Length)
            coord := maxedCoordinates[randomIndex]

            AddToLog("Found clone, applying to maxed unit at X" coord.x " Y" coord.y)
            FixClick(X, Y - 20)
            Sleep(500)
            FixClick(coord.x, coord.y)
            Sleep(250)
            return true
        }
        ; Otherwise use successfulCoordinates
        else if successfulCoordinates.Length > 0 {
            randomIndex := Random(1, successfulCoordinates.Length)
            coord := successfulCoordinates[randomIndex]

            AddToLog("Found clone, applying to random unit at X" coord.x " Y" coord.y)
            FixClick(X, Y - 20)
            Sleep(500)
            FixClick(coord.x, coord.y)
            Sleep(250)
            return true
        }
    }
    return false
}

CheckForMerge() {
    if (ok := FT(&X, &Y, 255, 561, 551, 605, 0.25, 0.25, Merge)) {
        AddToLog("Found merge, deleting buff...")
        FixClick(X + 15, Y - 45)
        Sleep(500)
        Sleep(250)
        return true
    }
    return false
}

CheckForRefund() {
    if (ok := FT(&X, &Y, 255, 561, 551, 605, 0.25, 0.25, Refund)) {
        AddToLog("Found refund, deleting buff...")
        FixClick(X + 15, Y - 45)
        Sleep(500)
        return true
    }
    return false
}

CheckForAstralGate() {
    if (ok := FT(&X, &Y, 255, 561, 551, 605, 0.35, 0.35, AstralGate)) {
        AddToLog("Found astral gate, attempting to use...")
        FixClick(X, Y)
        Sleep(500)
        return true
    }
    return false
}

CheckForAstralSummon() {
    if (ok := FT(&X, &Y, 255, 561, 551, 605, 0.30, 0.30, AstralSummon)) {
        AddToLog("Found astral summon, attempting to use...")
        FixClick(X, Y)
        Sleep(500)
        return true
    }
    return false
}
