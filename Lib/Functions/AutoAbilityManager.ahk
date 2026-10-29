#Requires AutoHotkey v2.0

CheckAutoAbility() {
    ; This runs on a timer. Outside a match (results screen, lobby, matchmaking captcha) it must not
    ; click old unit spots or press keys - stop the timer instead
    global stageEnded
    if (stageEnded || CheckForLobby()) {
        SetTimer(CheckAutoAbility, 0)
        return
    }

    if (!HasUnitForAbilityCheck()) {
        return  ; No units to check
    }

    AddToLog("Checking auto abilities of placed units...")
    CloseUnitOverview() ; Map clicks can be blocked by the overview panel
    global successfulCoordinates, maxedCoordinates

    ; Process successfulCoordinates
    for index, coord in successfulCoordinates {
        if (!coord.hasAbility)
            continue

        if (ProcessAbility(coord)) {
            successfulCoordinates[index].hasAbility := false
        }
    }

    ; Process maxedCoordinates
    for index, coord in maxedCoordinates {
        if (!coord.hasAbility)
            continue

        if (ProcessAbility(coord)) {
            maxedCoordinates[index].hasAbility := false
        }
    }

    AddToLog("Finished looking for abilities")
    if (ShouldOpenUnitManager()) {
        OpenUnitOverview()
    }
}

HasUnitForAbilityCheck() {
    global successfulCoordinates, maxedCoordinates

    for coord in successfulCoordinates {
        if (coord.hasAbility)
            return true
    }

    for coord in maxedCoordinates {
        if (coord.hasAbility)
            return true
    }

    return false
}

ProcessAbility(coord) {

    slot := coord.slot

    if (CheckForXP(false, false)) {
        ; Leave the results screen to the main loop - starting MonitorStage from this timer would run a
        ; second copy of the end-of-game handling on top of the one already running
        AddToLog("Stopping auto ability check because the game ended")
        SetTimer(CheckAutoAbility, 0)
        return false
    }

    if (HasCards(ModeDropdown.Text) || HasCards(EventDropdown.Text)) {
        CheckForCardSelection()
    }

    if (OpenUnitAbility(coord.x, coord.y))
        return true

    ; Units without an ability toggle would otherwise be clicked every minute for the whole match
    coord.abilityTries := (coord.HasOwnProp("abilityTries") ? coord.abilityTries : 0) + 1
    if (coord.abilityTries >= 3) {
        AddToLog("Unit " slot " has no ability toggle that could be turned on - stopped trying")
        return true
    }
    return false
}

; Opens the unit's panel (clicks the unit when the game didn't auto-open it), turns the ability on
; and closes the panel with its X
OpenUnitAbility(x, y) {
    if (!UnitPanelOpen()) {
        FixClick(x, y)
        Sleep(500)
    }
    isOn := HandleAutoAbility()
    if (UnitPanelOpen()) {
        FixClick(330, 186) ; X of the unit panel - same spot for every unit
        Sleep(300)
    }
    return isOn
}

; The red X at the top right of the unit panel
UnitPanelOpen() => GetPixel(0xE40000, 315, 178, 30, 17, 30)

; The ability toggle sits right of the unit panel: green with the dark knob on the right when on
AbilityToggleOn() => GetPixel(0x00A653, 340, 220, 40, 25, 12) && GetPixel(0x191919, 378, 226, 25, 18, 6)
; Off: near-black green with the knob on the left
AbilityToggleOff() => GetPixel(0x191919, 340, 226, 22, 18, 6) && GetPixel(0x001A0D, 372, 224, 28, 20, 6)

GetAutoAbilityTimer() {
    seconds := 60
    return Round(seconds * 1000)
}

ActiveAbilityEnabled() {
    if (!autoAbilityDisabled) {
        return true
    }
    loop 6 {
        if (abilityEnabled%A_Index%.Value)
            return true
    }
    return false
}

HandleAutoAbility() {
    if (!ActiveAbilityEnabled()) {
        AddToLog("Auto Ability Disabled")
        return
    }

    ; Only click the toggle while a unit's panel is open, otherwise the click lands on the map
    if (!UnitPanelOpen())
        return false

    if (AbilityToggleOn())
        return true
    if (!AbilityToggleOff())
        return false ; No toggle showing for this unit

    FixClick(373, 236)  ; Turn ability on
    Sleep(400)
    if (AbilityToggleOn()) {
        AddToLog("Auto Ability Enabled")
        return true
    }
    return false
}

HandleAutoAbilityUnitManager() {
    wiggle()

    ; Grid configuration
    baseX := 675            ; Left column starting X
    xOffset := 95             ; Distance between columns
    baseY := 130            ; Top row starting Y
    yStep := 60             ; Vertical gap between rows
    numRows := 8              ; Total rows to scan
    numCols := 2              ; Columns per row
    color := 0xC22725       ; Target pixel color

    ; Scan grid
    loop numRows {
        rowIndex := A_Index - 1
        rowY := baseY + rowIndex * yStep

        loop numCols {
            colIndex := A_Index - 1
            colX := baseX + colIndex * xOffset

            if GetPixel(color, colX, rowY, 4, 4, 20) {
                FixClick(colX, rowY)
                Sleep(100)
            }
        }
    }
}