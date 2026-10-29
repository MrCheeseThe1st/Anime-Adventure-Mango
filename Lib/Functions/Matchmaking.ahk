#Requires AutoHotkey v2.0

global matchmakingSince := 0

; True once matchmaking has been failing for a minute. The minute counts across retries and
; mode restarts, and only resets when a match is found or the macro rejoins
MatchmakingTimedOut() {
    global matchmakingSince
    if (!matchmakingSince)
        matchmakingSince := A_TickCount
    return A_TickCount - matchmakingSince >= 60000
}

; Gives up on matchmaking: rejoins the private server (when set up) and starts the mode again from the lobby
RejoinAfterMatchmaking() {
    global matchmakingSince
    matchmakingSince := 0
    if (PrivateServerEnabled.Value && PrivateServerURLBox.Value != "") {
        AddToLog("Couldn't matchmake for a minute, reconnecting to your private server")
        return Reconnect(true) ; Reconnect starts the selected mode once it's back in the lobby
    }
    AddToLog("Couldn't matchmake for a minute, restarting mode (turn on Reconnect to Private Server to rejoin instead)")
    FixClick(585, 190)  ; Close the matchmaking UI
    Sleep(500)
    FixClick(400, 520)
    Sleep(1000)
    return StartSelectedMode()
}

FindMatch() {
    global ModeDropdown, matchmakingSince

    ; Modes allowed to use walking recovery
    walkModes := [
        "Event",
        "Infinity Castle"
    ]

    canWalk := false
    for mode in walkModes {
        if (ModeDropdown.Text = mode) {
            canWalk := true
            break
        }
    }

    loop {
        if (MatchmakingTimedOut())
            return RejoinAfterMatchmaking()

        ; Wait for the matchmaking prompt - after a few lobby returns the player can spawn away from
        ; the matchmaking spot, and reading the captcha without the prompt open never succeeds
        promptStart := A_TickCount
        promptFound := false
        while (A_TickCount - promptStart < 10000) {
            if (CheckForMatchmakingPrompt()) {
                promptFound := true
                break
            }

            FixClick(400, 435)  ; Play Here or Find Match

            Sleep(250)
        }

        if (!promptFound) {
            AddToLog("Matchmaking prompt not detected.")
            FixClick(585, 190)  ; Close UI

            if (canWalk) {
                AddToLog("Walking recovery: moving right, then left...")
                Walk("D", 500)
                Walk("A", 1500)
                continue
            }

            AddToLog("Walking recovery disabled for this mode. Restarting mode...")
            return StartSelectedMode()
        }

        FixClick(400, 435)  ; Play Here or Find Match
        Sleep(300)
        FixClick(460, 330)  ; Click Find Match
        Sleep(300)

        ; Read, type and submit the captcha - only carries on once the game has accepted it
        if (!SolveCaptcha()) {
            AddToLog("Captcha not solved, retrying...")
            FixClick(585, 190)  ; Close UI
            Sleep(1000)
            continue
        }
        Sleep(1000)

        ; Wait for matchmaking success - leaving the lobby means a match was found
        while (!MatchmakingTimedOut()) {
            if (!CheckForLobbySettings()) {
                AddToLog("Matchmaking successful.")
                matchmakingSince := 0
                return true
            }
            Sleep(200)
        }
    }
}

HasMatchmaking(ModeName) {
    if (ModeName = "Portal" && !PortalLobby.Value)
        return false

    return true
}

CheckForMatchmakingPrompt() {
    return FT(&X, &Y, 230, 219, 562, 267, 0, 0, JoinMatchmaking)
}

WaitUntilNotInLobby() {
    startTime := A_TickCount

    while (ok := FT(&X, &Y, 11, 557, 45, 591, 0, 0, LobbySettings)) {
        if (A_TickCount - startTime >= 120000) {
            AddToLog("Still in lobby after 2 minutes, restarting mode...")
            return StartSelectedMode()
        }
        Sleep(500)
    }
    return true
}

CheckForLobbySettings() {
    return FT(&X, &Y, 11, 557, 45, 591, 0.10, 0.10, LobbySettings)
}
