#Requires AutoHotkey v2.0

FindMatch() {
    startTime := A_TickCount

    loop {
        FixClick(400, 435)  ; Play Here or Find Match
        Sleep(300)
        FixClick(460, 330)  ; Click Find Match
        Sleep(300)

        ; Try captcha
        if (!CaptchaDetect(252, 292, 300, 50, 400, 335)) {
            AddToLog("Captcha not detected, retrying...")
            FixClick(585, 190)  ; Click close
            Sleep(1000)
            continue
        }
        FixClick(300, 385)  ; Enter captcha
        Sleep(2000)
        while (A_TickCount - startTime < 60000) {  ; Check for 60 seconds
            /* if (ok := FT(&X, &Y, 243, 116, 381, 180, 0, 0, MatchMakingText)) {
                AddToLog("Matchmaking succesfull.")
                return true
            } */
           if (!CheckForLobby()) {
                AddToLog("Player is no longer detecting the lobby, matchmaking successful.")
                return true
           }
            Sleep(200)  ; Check every 200ms
        }
        AddToLog("Matchmaking timeout, restarting mode")
        FixClick(400, 520)
        return StartSelectedMode()
    }
}

HasMatchmaking(ModeName) {
    ; Portal and Infinity Castle do not use matchmaking
    if (ModeName = "Infinity Castle")
        return false

    if (ModeName = "Portal" && !PortalLobby.Value)
        return false

    return true
}