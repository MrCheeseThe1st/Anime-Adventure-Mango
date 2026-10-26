#Requires AutoHotkey v2.0

global inChallengeMode := false

StartChallengeCooldown() {
    TimerManager.Start("HourlyChallenge", 3600000)
}

IsChallengeReady() {
    return !TimerManager.timers.Has("HourlyChallenge") || TimerManager.HasExpired("HourlyChallenge")
}

HandleChallengeEnd() {
    StartChallengeCooldown()
    ClickReturnToLobby()
    CheckLobby()
}