#Requires AutoHotkey v2.0

UpgradeUnits() {

    SetTotalUnits()

    if (ShouldOpenUnitManager()) {
        OpenUnitOverview()
    }

    if (EvenUpgrade.Value) {
        UpgradeEvenly()
    } else if (PriorityUpgrade.Value) {
        UpgradeWithPriority()
    } else {
        UpgradeWithoutPriority()
    }

    if stageEnded
        return HandleStageEnd()
    return MonitorStage()
}

UpgradeWithoutPriority() {
    global successfulCoordinates

    slotOrder := [1, 2, 3, 4, 5, 6] ; or however many slots you have

    for slot in slotOrder {
        if (HasUnitsInSlot(slot, "", successfulCoordinates)) {
            ProcessUpgrades(slot, "")
            upgraded := true
        }
    }

    AddToLog("All units maxed, proceeding to monitor stage")
    CloseUnitOverview()
}

UpgradeWithPriority() {
    global successfulCoordinates
    AddToLog("Using priority upgrade system")
    slotOrder := [1, 2, 3, 4, 5, 6]
    priorityOrder := [1, 2, 3, 4, 5, 6]

    for priorityNum in priorityOrder {
        for slot in slotOrder {
            if (HasUnitsInSlot(slot, priorityNum, successfulCoordinates)) {
                AddToLog("Starting upgrades for priority " priorityNum " (slot " slot ")")
                ProcessUpgrades(slot, priorityNum)
            }
        }
    }

    AddToLog("All units maxed, proceeding to monitor stage")
    if (ActiveAbilityEnabled()) {
        SetTimer(CheckAutoAbility, GetAutoAbilityTimer())
    }
    CloseUnitOverview()
}

; One level per unit in upgrade priority order (ties in placement order), then back to the start,
; until every unit is maxed or at its limit. If the next unit can't be afforded yet, wait for it -
; skipping it would let cheaper units pull ahead
UpgradeEvenly() {
    AddToLog("Upgrading evenly in priority order")

    loop {
        if !RefillMissingUnits()
            return
        queue := EvenUpgradeQueue()
        if (queue.Length = 0)
            break

        for coord in queue {
            loggedWait := false
            loop {
                if (CheckStageInterruptionsEvery())
                    return

                result := UpgradeOneLevel(coord)
                if (result != "waiting")
                    break

                if !loggedWait {
                    AddToLog("Waiting for money to upgrade Unit " coord.slot)
                    loggedWait := true
                }
                PostUpgradeChecks(coord)
                if stageEnded
                    return
                Sleep(1000)
            }
            PostUpgradeChecks(coord)
            if stageEnded
                return
        }
    }

    AddToLog("All units maxed, proceeding to monitor stage")
    if (ActiveAbilityEnabled()) {
        SetTimer(CheckAutoAbility, GetAutoAbilityTimer())
    }
    CloseUnitOverview()
}

; Units still being upgraded, sorted by upgrade priority, then placement order.
; Units with a blank priority are left alone, same as the priority mode
EvenUpgradeQueue() {
    global successfulCoordinates
    queue := []
    for coord in successfulCoordinates {
        if (!coord.autoUpgrade && coord.upgradePriority >= 1 && coord.upgradePriority <= 6)
            queue.Push(coord)
    }
    loop queue.Length {
        loop queue.Length - 1 {
            a := queue[A_Index], b := queue[A_Index + 1]
            if (a.upgradePriority > b.upgradePriority
                || (a.upgradePriority = b.upgradePriority && a.placementIndex > b.placementIndex)) {
                queue[A_Index] := b
                queue[A_Index + 1] := a
            }
        }
    }
    return queue
}

; Tries to upgrade a unit by one level. Returns "upgraded", "done" (maxed or at its limit, removed from
; the upgrade list) or "waiting" (couldn't afford it)
UpgradeOneLevel(coord) {
    slot := coord.slot
    limit := IsLimitActive(slot) ? GetUpgradeLimit(slot) : ""

    if ShouldOpenUnitManager() {
        result := UpgradeViaOverview(coord, limit, true)
        if (result = "limit") {
            AddToLog("Upgrade limit reached for Unit: " slot)
            HandleMaxUpgrade(coord)
            return "done"
        }
        if (result = "max") {
            HandleMaxUpgrade(coord)
            return "done"
        }
        if (result = "unaffordable")
            return "waiting"
        if (result = "upgraded")
            return "upgraded"

        ; Card not visible in the overview - fall back to clicking the unit on the map
        CloseUnitOverview()
    }

    ; On the map there's no reliable way to tell whether the upgrade went through, so press once and move on
    if (limit != "") {
        if UpgradeUnitLimit(coord, 0, limit)
            return "done"
    } else {
        UpgradeUnit(coord.x, coord.y)
    }
    if MaxUpgrade() {
        HandleMaxUpgrade(coord)
        return "done"
    }
    return "upgraded"
}

SetAutoUpgradeForAllUnits() {
    global successfulCoordinates

    ; Sort by placementIndex to get visual order
    sorted := successfulCoordinates.Clone()

    ; Simple bubble sort by placementIndex
    Loop sorted.Length {
        for i, val in sorted {
            if (i = sorted.Length)
                continue
            if (sorted[i].placementIndex > sorted[i + 1].placementIndex) {
                temp := sorted[i]
                sorted[i] := sorted[i + 1]
                sorted[i + 1] := temp
            }
        }
    }

    ; GUI positioning constants
    baseX := 610
    baseY := 215
    colSpacing := 80
    rowSpacing := 115
    maxCols := 3
    totalCount := sorted.Length

    fullRows := Floor(totalCount / maxCols)
    lastRowUnits := Mod(totalCount, maxCols)

    ; Loop through units in visual order
    for index, unit in sorted {
        slot := unit.slot
        priority := unit.upgradePriority

        ; Calculate click position based on visual index
        placementIndex := index - 1 ; zero-based
        row := Floor(placementIndex / maxCols)
        colInRow := Mod(placementIndex, maxCols)
        isLastRow := (row = fullRows)

        if (lastRowUnits != 0 && isLastRow) {
            rowStartX := baseX + ((maxCols - lastRowUnits) * colSpacing / 2)
            clickX := rowStartX + (colInRow * colSpacing)
        } else {
            clickX := baseX + (colInRow * colSpacing)
        }

        clickY := baseY + (row * rowSpacing)

        if (priority > 4 && priority != 7) {
            priority := 4
        }

        if (priority == 7) {
            priority := 0
        }

        AddToLog("Set slot: " slot " priority to " priority)

        Loop priority {
            FixClick(clickX, clickY)
            Sleep(150)
        }
    }
}

UpgradeAllUnits() {
    FixClick(648, 123) ; Clicks upgrade all
    Sleep(1000)
}

HandleUnitManager(msg) {
    AddToLog(msg)
    CloseMenu("Unit Manager")
    return MonitorStage()
}

GetUpgradePriority(slotNum) {
    global
    priorityVar := "upgradePriority" slotNum
    return %priorityVar%.Value
}

UnitManagerUpgrade(slot) {
    if !(GetPixel(0x1643C5, 77, 357, 4, 4, 2)) {
        ClickUnit(slot)
        Sleep(500)
    }
    SendInput("R")
}

UnitManagerUpgradeWithLimit(coord, index, upgradeLimit) {
    if !(GetPixel(0x1643C5, 77, 357, 4, 4, 2)) {
        ClickUnit(coord.placementIndex)
        Sleep(500)
    }
    if (WaitForUpgradeLimitText(upgradeLimit + 1, 750)) {
        HandleMaxUpgrade(coord, index)
        return true
    }
    SendInput("R")
    return false
}

ProcessUpgrades(slot := false, priorityNum := false) {
    global successfulCoordinates

    ; Full upgrade loop
    while (true) {
        if (stageEnded || !RefillMissingUnits())
            return
        slotDone := true

        ; Iterate a snapshot - maxed units get removed from successfulCoordinates mid-loop
        for index, coord in successfulCoordinates.Clone() {

            if (coord.autoUpgrade) {
                continue
            }

            if ((!slot || coord.slot = slot) && (!priorityNum || coord.upgradePriority = priorityNum)) {
                slotDone := false  ; Found unit to upgrade => not done yet

                if (UpgradeUnitWithLimit(coord, index)) {
                    continue ; Upgrade limit reached, don't press R again
                }

                PostUpgradeChecks(coord)
                if stageEnded
                    return

                ; The overview path detects max from the card's progress bar instead
                if (!ShouldOpenUnitManager() && MaxUpgrade()) {
                    HandleMaxUpgrade(coord, index)
                    SendInput("R")
                    continue
                }

                PostUpgradeChecks(coord)
                if stageEnded
                    return
            }
        }

        if ((slot || priorityNum) && (slotDone || successfulCoordinates.Length = 0)) {
            AddToLog("Finished upgrades for priority " priorityNum)
            break
        }

        if (!slot && !priorityNum)
            break
    }
}

; The unit panel that opens after placing (or clicking) a unit has a cyan button at about (29, 369).
; Loose colour match over a small area - Roblox's lighting and anti-aliasing shift the exact colour and
; position slightly, which made the old exact 4x4 check miss real placements
PlacementPanelOpen() {
    return GetPixel(0x17D6FE, 20, 360, 30, 25, 15) ; Ryn v0.3.6 region: wider area, tighter colour
}

WaitForUpgradeText(timeout := 4500) {
    startTime := A_TickCount
    while (A_TickCount - startTime < timeout) {
        if (PlacementPanelOpen()) {
            if (CheckForElyssiaSummon())
                return false
            if (debugMessages)
                AddToLog("Upgrade text found in " (A_TickCount - startTime) " ms")
            return true
        }
        Sleep 50
    }
    if (debugMessages)
        AddToLog("Timed out, no upgrade text. Timeout: " timeout " ms")
    return false
}

WaitForUpgradeLimitText(upgradeCap, timeout := 4500) {
    upgradeTexts := [
        [Upgrade0],
        [Upgrade1],
        [Upgrade2],
        [Upgrade3],
        [Upgrade4],
        [Upgrade5],
        [Upgrade6],
        [Upgrade7],
        [Upgrade8],
        [Upgrade9]
    ]

    if (upgradeCap < 1 || upgradeCap > upgradeTexts.Length)
        return false

    targetTexts := upgradeTexts[upgradeCap]

    if (!IsObject(targetTexts) || targetTexts.Length = 0)
        return false

    startTime := A_TickCount

    while (A_TickCount - startTime < timeout) {
        for _, targetText in targetTexts {
            if (Trim(targetText) = "")
                continue

            if (FT(&X, &Y, 186, 351, 317, 387, 0, 0, MaxText) or (ok := FT(&X, &Y, 161, 194, 318, 225, 0, 0, MaxTextNew))) {
                AddToLog("Found Max Text " MaxText)
                return true
            }

            if (FT(&X, &Y, 166, 195, 316, 223, 0, 0, targetText)) {
                AddToLog("Found Upgrade Cap " upgradeCap)
                return true
            }
        }

        Sleep(100)
    }

    return false
}

TestUpgradeLimitTexts(resultEdit := true) {

    upgradeTexts := [
        [Upgrade0],
        [Upgrade1],
        [Upgrade2],
        [Upgrade3],
        [Upgrade4],
        [Upgrade5],
        [Upgrade6],
        [Upgrade7],
        [Upgrade8],
        [Upgrade9]
    ]

    ResultEdit.Value .= "Testing all upgrade limit texts...`n"

    foundCount := 0
    upgradeFound := false

    ; Check upgrade texts first
    for level, targetTexts in upgradeTexts {
        for variant, targetText in targetTexts {
            if (Trim(targetText) = "")
                continue

            if (FT(&X, &Y, 166, 195, 316, 223, 0, 0, targetText)) {
                ResultEdit.Value .= "Found Upgrade" (level - 1) " variant " variant " at X: " X ", Y: " Y "`n"

                foundCount++
                upgradeFound := true
            }
        }
    }

    ; Only check MaxText if no upgrade text was found
    if (!upgradeFound) {
        if (FT(&X, &Y, 186, 351, 317, 387, 0, 0, MaxText)
        || FT(&X, &Y, 161, 194, 318, 225, 0, 0, MaxTextNew)) {

            ResultEdit.Value .= "Found Max Text (upgrade limit detected).`n"
            foundCount++
        }
    }

    ResultEdit.Value .= "Found " foundCount " matching pattern(s).`n`n"
}

UpgradeUnitWithLimit(coord, index) {
    slot := coord.slot
    placementIndex := coord.placementIndex
    x := coord.x
    y := coord.y

    ; Returns true when the unit is done (max or limit reached) and was removed from the upgrade list
    if ShouldOpenUnitManager() {
        result := UpgradeViaOverview(coord, IsLimitActive(slot) ? GetUpgradeLimit(slot) : "")
        if (result = "limit") {
            AddToLog("Upgrade limit reached for Unit: " slot)
            HandleMaxUpgrade(coord, index)
            return true
        }
        if (result = "max") {
            HandleMaxUpgrade(coord, index)
            return true
        }
        if (result = "upgraded")
            return false

        ; Card not visible in the overview - fall back to clicking the unit on the map
        CloseUnitOverview()
    }

    if !IsLimitActive(slot) {
        UpgradeUnit(x, y)
        return false
    }
    return UpgradeUnitLimit(coord, index, GetUpgradeLimit(slot))
}

UpgradeUnitLimit(coord, index, upgradeLimit) {
    FixClick(coord.x, coord.y)
    if (WaitForUpgradeLimitText(upgradeLimit + 1, 1500)) {
        HandleMaxUpgrade(coord, index)
        return true
    }
    SendInput("R")
    return false
}

IsUpgradeLimitEnabled(slotNum) {
    setting := "upgradeLimitEnabled" slotNum
    return %setting%.Value
}

; "MAX" means no limit - upgrade until the unit is maxed
IsLimitActive(slotNum) {
    return IsUpgradeLimitEnabled(slotNum) && !unitUpgradeLimitDisabled && GetUpgradeLimit(slotNum) != "MAX"
}

GetUpgradeLimit(slotNum) {
    setting := "upgradeLimit" slotNum
    limit := %setting%.Text
    if (limit = "MAX")
        return "MAX"
    return IsInteger(limit) ? Integer(limit) : 0
}

HandleMaxUpgrade(coord, index := 0) {
    global successfulCoordinates, maxedCoordinates

    AddToLog("Max upgrade reached for Unit: " coord.slot)
    maxedCoordinates.Push(coord)

    ; Remove by identity - the index can be stale once earlier units were removed
    for i, c in successfulCoordinates {
        if (c = coord) {
            successfulCoordinates.RemoveAt(i)
            break
        }
    }
}

PostUpgradeChecks(coord) {
    ; Cards, results screen and reconnect. Quick look every time, full look every 15 seconds
    if CheckStageInterruptionsEvery()
        return

    if (coord.hasAbility) {
        HandleAutoAbility()
    }
}

StageEndedDuringUpgrades() {
    if (CheckForXP())
        return true

    if (EndButtonsVisible()) {
        return true
    }
    return false
}

IsUpgradeEnabled(slotNum) {
    setting := "upgradeEnabled" slotNum
    return %setting%.Value
}

TestAllUpgradeFindTexts() {
    foundCount := 0
    notFoundCount := 0

    Loop 15 {
        upgradeCap := A_Index  ; Now 1–15, aligns with AHK v2 arrays
        result := WaitForUpgradeLimitText(upgradeCap, 500)

        if (result) {
            AddToLog("Found Upgrade Level: " upgradeCap - 1)
            foundCount++
        } else {
            AddToLog("Did NOT Find Upgrade Level: " upgradeCap - 1)
            notFoundCount++
        }
    }

    AddToLog("Found: " foundCount " | Not Found: " notFoundCount)
}

ShouldOpenUnitManager() {
    if (UnitManagerUpgradeSystem.Value && !unitManagerDisabled) {
        return true
    }
}

HasUnitsInSlot(slot, priorityNum, coordinates) {
    for coord in coordinates {
        if (coord.slot = slot && !coord.autoUpgrade) {
            if (priorityNum = false || priorityNum = "") {
                return true   ; ignore priority requirement
            }
            if (coord.upgradePriority = priorityNum) {
                return true
            }
        }
    }
    return false
}

SetAutoUpgradeForSingleUnit(unitIndex := 1) {
    global successfulCoordinates

    ; Clone and sort by placementIndex
    sorted := successfulCoordinates.Clone()
    loop sorted.Length {
        for i, val in sorted {
            if (i = sorted.Length)
                continue
            if (sorted[i].placementIndex > sorted[i + 1].placementIndex) {
                temp := sorted[i]
                sorted[i] := sorted[i + 1]
                sorted[i + 1] := temp
            }
        }
    }

    ; GUI positioning constants
    baseX := 610
    baseY := 225
    colSpacing := 80
    rowSpacing := 115
    maxCols := 3
    totalCount := sorted.Length

    if (unitIndex < 1 || unitIndex > totalCount) {
        return
    }

    fullRows := Floor(totalCount / maxCols)
    lastRowUnits := Mod(totalCount, maxCols)

    unit := sorted[unitIndex]
    slot := unit.slot
    priority := unit.upgradePriority

    placementIndex := unitIndex - 1
    row := Floor(placementIndex / maxCols)
    colInRow := Mod(placementIndex, maxCols)
    isLastRow := (row = fullRows)

    if (lastRowUnits != 0 && isLastRow) {
        rowStartX := baseX + ((maxCols - lastRowUnits) * colSpacing / 2)
        clickX := rowStartX + (colInRow * colSpacing)
    } else {
        clickX := baseX + (colInRow * colSpacing)
    }

    clickY := baseY + (row * rowSpacing)

    ; Normalize priority values
    if (priority > 4 && priority != 7)
        priority := 4
    if (priority == 7)
        priority := 0

    if (priority = 0) {
        return
    }

    ; Perform upgrade clicks
    loop priority {
        FixClick(clickX, clickY)
        Sleep(150)
    }
}

SetTotalUnits() {
    global totalUnits, successfulCoordinates

    totalUnits := Map() ; Reset so counts from previous matches don't pile up
    for coord in successfulCoordinates {
        totalUnits[coord.slot] := (totalUnits.Has(coord.slot) ? totalUnits[coord.slot] + 1 : 1)
    }
}

MaxUpgrade() {
    Sleep 500
    ; Check for max text
    if (ok := FT(&X, &Y, 188, 350, 310, 387, 0, 0, MaxText) or (ok := FT(&X, &Y, 161, 194, 318, 225, 0, 0, MaxTextNew))) {
        if (CheckForElyssiaSummon()) {
            return false
        }
        CheckAutoAbility()
        return true
    }
    return false
}

CheckForElyssiaSummon() {
    if FT(&X, &Y, 16, 195, 131, 216, 0, 0, ElyssiaSummons) {
        AddToLog("Clicked on Elyssia Eel, ignoring...")
        return true
    }
}

UpgradeUnit(x, y) {
    FixClick(x, y)
    SendInput("{R}")
}

TestUpgrade(index) {
    global successfulCoordinates

    ; --- Create dummy test data so the main function works ---
    successfulCoordinates := [{ placementIndex: 1, slot: 1, upgradePriority: 1 }, { placementIndex: 2, slot: 2,
        upgradePriority: 2 }, { placementIndex: 3, slot: 3, upgradePriority: 3 }, { placementIndex: 4, slot: 4,
            upgradePriority: 4 }, { placementIndex: 5, slot: 5, upgradePriority: 1 }, { placementIndex: 6, slot: 6,
                upgradePriority: 2 }
    ]

    AddToLog("Testing upgrade on index: " index)

    ; --- Call your real method using the number you want ---
    SetAutoUpgradeForSingleUnit(index)
}
