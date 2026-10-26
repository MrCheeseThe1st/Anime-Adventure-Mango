#Requires AutoHotkey v2.0

StartInfinityCastle() {
    ; Get current difficulty
    currentDifficulty := InfinityCastleDropdown.Text

    ; Execute the movement pattern
    AddToLog("Moving to position for Infinity Castle")
    InfCastleMovement()

    ; Start stage
    while !(ok := FT(&X, &Y, 344, 506, 458, 540, 0, 0, ModeCancel)) {
        Reconnect() ; Added Disconnect Check
        InfCastleMovement()
    }
    AddToLog("Starting Infinity Castle - " currentDifficulty)

    ; Select difficulty with direct clicks
    if (currentDifficulty = "Normal") {
        FixClick(418, 375)  ; Click Easy Mode
    } else {
        FixClick(485, 375)  ; Click Hard Mode
    }

    ;Start Inf Castle
    if (ok := FT(&X, &Y, 344, 506, 458, 540, 0, 0, ModeCancel)) {
        ClickUntilGone(0, 0, 344, 506, 458, 540, ModeCancel, -10, -80)
    }

    RestartStage()
}

InfCastleMovement() {
    FixClick(765, 475)
    Sleep (300)
    FixClick(370, 330)
    Sleep (500)
    SendInput ("{w down}")
    Sleep (500)
    SendInput ("{w up}")
    Sleep (500)
    SendInput ("{a down}")
    sleep (4000)
    SendInput ("{a up}")
    Sleep (500)
}