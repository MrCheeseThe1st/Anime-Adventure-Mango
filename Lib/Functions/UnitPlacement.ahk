#Requires AutoHotkey v2.0

global lastSpotOccupied := false ; Set by PlaceUnit when another unit already stands on the spot
global lastPlacementUnconfirmed := false
global lastSpotRed := false        ; The last spot showed a red bubble, so nothing was clicked
global redSpots := Map()           ; "x,y" -> true for spots that showed a red bubble this match
global bubbleCheckOff := false     ; Turned off for the match if it marked every spot red (fooled by the map) ; The last placement attempt wasn't confirmed by the Unit Overview

StartPlacingUnits(untilSuccessful := true) {
    global successfulCoordinates, maxedCoordinates
    successfulCoordinates := []
    maxedCoordinates := []
    global placedCounts := Map()
    global redSpots := Map()
    global bubbleCheckOff := false
    global stageEnded := false

    maxAttemptsPerSpot := 20 ; Failed tries at one spot before moving to the next
    maxFailedSpots := 3      ; Spots in a row that fail before giving up on the unit

    ; --- Check if any slot is enabled ---
    anyEnabled := false
    for slotNum in [1, 2, 3, 4, 5, 6] {
        enabled := "enabled" slotNum
        enabled := %enabled%
        enabled := enabled.Value
        if (enabled) {
            anyEnabled := true
            break
        }
    }

    if (!anyEnabled) {
        AddToLog("No units enabled - skipping to monitoring")
        return MonitorStage()
    }

    if (ActiveAbilityEnabled()) {
        SetTimer(CheckAutoAbility, GetAutoAbilityTimer())
    }

    ; --- Placement Order Logic ---
    if (PlacementSelection.Text = "By Priority" || PlacementSelection.Text = "Evenly") {
        global slotPriorityList := []

        ; Build list of enabled slots and their priorities
        for slotNum in [1, 2, 3, 4, 5, 6] {
            priorityVar := "priority" slotNum
            enabledVar := "enabled" slotNum

            priority := %priorityVar%
            enabled := %enabledVar%

            if (enabled.Value) {
                slotPriorityList.Push({ slot: slotNum, priority: priority.Value })
            }
        }

        ; Manually sort the list by priority (ascending)
        loop slotPriorityList.Length {
            for i, item in slotPriorityList {
                if (i = slotPriorityList.Length)
                    continue
                if (slotPriorityList[i].priority > slotPriorityList[i + 1].priority) {
                    temp := slotPriorityList[i]
                    slotPriorityList[i] := slotPriorityList[i + 1]
                    slotPriorityList[i + 1] := temp
                }
            }
        }

        ; Extract sorted slot numbers into placementOrder
        placementOrder := []

        for item in slotPriorityList {
            placementOrder.Push(item.slot)
        }
    } else {
        placementOrder := [1, 2, 3, 4, 5, 6]
    }

    placementStrategies := Map(
        "Custom", UseCustomPoints,
        "Circle", GenerateCirclePoints,
        "Grid", GenerateGridPoints,
        "Spiral", GenerateSpiralPoints,
        "Up and Down", GenerateUpandDownPoints,
        "Path", GeneratePathPoints
    )

    ; Get the selected text
    selection := PlacementPatternDropdown.Text

    ; Call mapped function if it exists, else use fallback
    if placementStrategies.Has(selection)
        placementPoints := placementStrategies[selection].Call()
    else
        placementPoints := GenerateRandomPoints()

    ; Custom with no spots saved for this map (e.g. a new map in the event rotation): find the path instead
    ; of skipping placement - GeneratePathPoints does exactly that when there are no saved spots
    if (selection = "Custom" && (!IsObject(placementPoints) || placementPoints.Length = 0)) {
        AddToLog("No custom spots saved for " GetPlacementsForMode(ModeDropdown.Text) " - placing around the path instead")
        placementPoints := GeneratePathPoints()
    }

    if (!placementPoints) {
        AddToLog("No placement points - skipping to monitoring")
        return MonitorStage()
    }

    if (TypeStrategyBox.Value) {
        ; The strategy places and upgrades everything itself
        RunTypeStrategy(placementPoints, untilSuccessful, maxAttemptsPerSpot, maxFailedSpots)
        CloseUnitOverview()
        return stageEnded ? HandleStageEnd() : MonitorStage()
    }

    if (PlacementSelection.Text = "Evenly") {
        if (PlaceUnitsEvenly(placementOrder, placementPoints, untilSuccessful, maxAttemptsPerSpot, maxFailedSpots) = "ended")
            return HandleStageEnd()
    } else {
        ; Use user-defined placement order to iterate through slots
        for slotNum in placementOrder {
            enabled := "enabled" slotNum
            enabled := %enabled%
            enabled := enabled.Value

            ; Get number of placements wanted for this slot
            placements := "placement" slotNum
            placements := %placements%
            placements := IsInteger(placements.Text) ? Integer(placements.Text) : 0

            ; Get upgradeEnabled value for this slot
            upgradeEnabled := "upgradeEnabled" slotNum
            upgradeEnabled := %upgradeEnabled%
            upgradeEnabled := upgradeEnabled.Value

            abilityEnabled := "abilityEnabled" slotNum
            abilityEnabled := %abilityEnabled%
            abilityEnabled := abilityEnabled.Value

            ; Initialize count if not exists
            if !placedCounts.Has(slotNum)
                placedCounts[slotNum] := 0

            ; If enabled, place all units for this slot - each copy on a random free spot
            if (enabled && placements > 0) {
                HandleStartButton() ; Check for start button if placement failed
                AddToLog("Placing Unit " slotNum " (0/" placements ")")

                while (placedCounts[slotNum] < placements) {
                    result := PlaceOneUnit(slotNum, placementPoints, untilSuccessful, maxAttemptsPerSpot, maxFailedSpots)
                    if (result = "ended" || stageEnded)
                        return HandleStageEnd()
                    if (result = "gaveup") {
                        AddToLog("Unit " slotNum " couldn't be placed (" placedCounts[slotNum] "/" placements "), max placement likely reached - moving on")
                        break
                    }
                }
            }
        }
    }

    AddToLog("All units placed to requested amounts")
    if (EnableUpgrading.Value) {
        UpgradeUnits()
    } else {
        AddToLog("Upgrading is disabled, proceeding to monitoring stage...")
    }

}

; One copy of each unit per round, in placement priority order, until every unit reaches its
; Placements amount. If it's a unit's turn and it can't be placed yet (e.g. not enough money), wait
; for it - skipping ahead would let cheaper units take all the early spots
PlaceUnitsEvenly(placementOrder, placementPoints, untilSuccessful, maxAttemptsPerSpot, maxFailedSpots) {
    global placedCounts
    AddToLog("Placing units evenly in priority order")
    HandleStartButton()

    active := []
    for slotNum in placementOrder {
        enabled := "enabled" slotNum
        if (%enabled%.Value && SlotPlacements(slotNum) > 0) {
            active.Push(slotNum)
            placedCounts[slotNum] := 0
        }
    }

    while (active.Length > 0) {
        for slotNum in active.Clone() {
            result := PlaceOneUnit(slotNum, placementPoints, untilSuccessful, maxAttemptsPerSpot, maxFailedSpots)
            if (result = "ended")
                return "ended"
            if (result = "gaveup")
                AddToLog("Unit " slotNum " couldn't be placed (" placedCounts[slotNum] "/" SlotPlacements(slotNum) "), max placement likely reached - moving on")
            if (result = "gaveup" || placedCounts[slotNum] >= SlotPlacements(slotNum)) {
                for i, s in active {
                    if (s = slotNum) {
                        active.RemoveAt(i)
                        break
                    }
                }
            }
        }
    }
    return "done"
}

; Places one copy of a unit at the first free spot that works.
; Returns "placed", "gaveup" (likely at the game's placement cap) or "ended" (stage ended)
; `onFailedTries` (optional) is called after every 3rd failed try - return false from it to stop
PlaceOneUnit(slotNum, placementPoints, untilSuccessful, maxAttemptsPerSpot, maxFailedSpots, onFailedTries := "") {
    ; Free spots in a random order, one try each, round and round until the unit is placed. A failed spot
    ; just moves on to another one instead of being retried straight away. The total number of tries is the
    ; same as before (tries per spot x failed spots, 60 by default) - running out means the game most
    ; likely won't take more of this unit
    budget := Max(1, maxAttemptsPerSpot * maxFailedSpots)
    tries := 0
    while (tries < budget) {
        free := FreeSpotsShuffled(placementPoints)
        if (free.Length = 0) {
            AddToLog("No free placement spots left for Unit " slotNum)
            return "gaveup"
        }
        for point in free {
            if PlaceUnit(point.x, point.y, slotNum) {
                RecordPlacedUnit(point, slotNum)
                return "placed"
            }
            if stageEnded
                return "ended"
            PostPlacementChecks()
            if (stageEnded || isMenuOpen("End Screen"))
                return "ended"
            tries += 1
            if (IsObject(onFailedTries) && Mod(tries, 3) = 0 && !onFailedTries.Call())
                return "ended"
            if (tries >= budget)
                break
            Sleep(300) ; Prevents spamming clicks too fast
        }
    }
    AddToLog("Unit " slotNum " couldn't be placed after " tries " tries")
    return "gaveup"
}

; Placement spots nobody is standing on yet, in a random order
FreeSpotsShuffled(placementPoints) {
    global redSpots, bubbleCheckOff
    free := [], skippedRed := 0
    for point in placementPoints {
        if PointAlreadyUsed(point)
            continue
        if redSpots.Has(point.x "," point.y) {
            skippedRed += 1
            continue
        }
        free.Push(point)
    }
    ; Every free spot read as red - more likely the map's red hill shading is fooling the check than every
    ; spot being blocked. Stop trusting it this match and try those spots by clicking
    if (free.Length = 0 && skippedRed > 0) {
        AddToLog("Every free spot read as a red bubble - ignoring the bubble check for the rest of this match")
        bubbleCheckOff := true
        redSpots := Map()
        for point in placementPoints {
            if !PointAlreadyUsed(point)
                free.Push(point)
        }
    }
    i := free.Length
    while (i > 1) {
        j := Random(1, i)
        temp := free[i], free[i] := free[j], free[j] := temp
        i -= 1
    }
    return free
}

PointAlreadyUsed(point) {
    global successfulCoordinates, maxedCoordinates
    for coord in successfulCoordinates {
        if (coord.x = point.x && coord.y = point.y)
            return true
    }
    for coord in maxedCoordinates {
        if (coord.x = point.x && coord.y = point.y)
            return true
    }
    return false
}

; Same bookkeeping as the regular placement loop after a successful placement
RecordPlacedUnit(point, slotNum) {
    global successfulCoordinates, placedCounts
    upgradeEnabled := "upgradeEnabled" slotNum
    upgradeEnabled := %upgradeEnabled%.Value
    abilityEnabled := "abilityEnabled" slotNum
    abilityEnabled := %abilityEnabled%.Value

    successfulCoordinates.Push({
        x: point.x,
        y: point.y,
        slot: slotNum,
        upgradePriority: GetUpgradePriority(slotNum),
        placementIndex: PlacedUnitCount() + 1, ; Maxed units move out of successfulCoordinates but stay on the map
        autoUpgrade: upgradeEnabled,
        hasAbility: abilityEnabled
    })
    placedCounts[slotNum] += 1
    AddToLog("Placed Unit " slotNum " (" placedCounts[slotNum] "/" SlotPlacements(slotNum) ")")
    if (upgradeEnabled) {
        EnableAutoUpgrade(successfulCoordinates[successfulCoordinates.Length].placementIndex)
    }
    if (abilityEnabled) {
        if HandleAutoAbility()
            successfulCoordinates[successfulCoordinates.Length].hasAbility := false
    }
    SendInput("Q")
}

SlotPlacements(slotNum) {
    placements := "placement" slotNum
    placements := %placements%.Text
    return IsInteger(placements) ? Integer(placements) : 0
}

PlaceUnit(x, y, slot := 1) {
    if (ModeDropdown.Text = "Event" && EventDropdown.Text = "Fool's Hunt") {
        CheckForCardSelection()
    }

    ; A panel left open from the last unit would make this placement look successful - close it first
    if PlacementPanelOpen() {
        SendInput("q")
        start := A_TickCount
        while (PlacementPanelOpen() && A_TickCount - start < 1000)
            Sleep(50)
        if PlacementPanelOpen()
            AddToLog("Unit panel didn't close before placing - placement check may be wrong")
    }

    ; The occupied-spot check needs the name-label check, which is paused (see "Saved attempts")
    global lastSpotOccupied := false

    ; The overview covers the right side of the map, so it must be closed before clicking
    CloseUnitOverview()
    if CheckStageInterruptions(true)
        return false

    ; The last placement wasn't confirmed, but its card may just have shown up late. If it's there now,
    ; that unit counts and nothing new is placed - otherwise every retry would add another unit
    global lastPlacementUnconfirmed
    if lastPlacementUnconfirmed {
        lastPlacementUnconfirmed := false
        expected := PlacedUnitCount() + 1
        found := OverviewUnitCount(expected)
        CloseUnitOverview()
        if found {
            AddToLog("The last placement did go through (" found " units in the Unit Overview)")
            RecordMissedUnits(found - expected, x, y, slot)
            return true
        }
    }

    Sleep 50
    SendInput(slot)

    ; Holding a unit shows a bubble at the mouse: blue = can place, red = can't (hill, rock, other unit).
    ; Check it before clicking - a red spot is skipped without paying for a failed placement
    global lastSpotRed := false
    global bubbleCheckOff
    if (!bubbleCheckOff && PlacementBubbleIsRed(x, y)) {
        SendInput("q") ; Put the unit away
        global redSpots
        redSpots[x "," y] := true
        lastSpotRed := true
        AddToLog("Spot " x ", " y " shows a red bubble - skipping it")
        return false
    }

    FixClick(x, y)
    Sleep 50
    SendInput("q")

    expected := PlacedUnitCount() + 1
    found := UnitPlaced(expected)
    if found {
        RecordMissedUnits(found - expected, x, y, slot)
        Sleep 15
        return true
    }
    lastPlacementUnconfirmed := true
    return false
}

; Checks the placement worked by opening the Unit Overview (F) and checking it lists at least
; `expected` units. Returns the number listed, or 0. Keeps checking for the Placement Speed time (at
; least 3 seconds), then closes the overview so the next placement click isn't blocked
UnitPlaced(expected) {
    start := A_TickCount
    timeout := Max(GetPlacementSpeed(), 3000) ; The card can take a moment to appear
    found := 0
    loop {
        found := OverviewUnitCount(expected)
        if found
            break
        if CheckStageInterruptions()
            break
        Sleep(200)
    } until (A_TickCount - start >= timeout)
    CloseUnitOverview()

    if found
        AddToLog("Unit Placed Successfully (" found " units in the Unit Overview)")
    return found
}

; A placement that went through without being confirmed leaves a unit the script doesn't know about,
; which would shift the overview's unit order. Record it as this slot, at this spot
RecordMissedUnits(extra, x, y, slot) {
    global placedCounts
    loop extra {
        AddToLog("The Unit Overview has a unit that wasn't recorded - counting it as Unit " slot)
        if !placedCounts.Has(slot)
            placedCounts[slot] := 0
        RecordPlacedUnit({ x: x, y: y }, slot)
    }
}

; Units placed so far this match (maxed units are still on the map)
PlacedUnitCount() {
    global successfulCoordinates, maxedCoordinates
    return successfulCoordinates.Length + maxedCoordinates.Length
}

; ---- Paused: name-label placement check (unused, see "Saved attempts\label-placement-check") ----

; Rests the mouse on (x, y) and looks for the name label above that spot. Units placed close to the
; player sometimes don't show the label until the mouse leaves the unit's hover area entirely and comes
; back, so halfway through, move well away (150px, towards the middle of the screen) and return once
HoverForUnitLabel(x, y, timeout := 300) {
    MouseMove(x, y)
    if WaitForUnitLabel(x, y, timeout // 2)
        return true

    WinGetClientPos(, , &w, , rblxID)
    MouseMove((x < w // 2) ? x + 150 : x - 150, y)
    Sleep(80)
    MouseMove(x, y)
    return WaitForUnitLabel(x, y, timeout - timeout // 2)
}

WaitForUnitLabel(x, y, timeout) {
    start := A_TickCount
    loop {
        Sleep(40)
        if UnitLabelNear(x, y)
            return true
    } until (A_TickCount - start >= timeout)
    return false
}

; The label sits centred above the unit. Its height above the click spot depends on the unit, and its size
; on how far the unit is from the camera, so search a wide box and try the pattern at a few sizes
UnitLabelNear(x, y) {
    x1 := Max(0, x - 150), y1 := Max(0, y - 160), x2 := x + 150, y2 := y + 40
    for zoom in [1, 0.85, 1.2, 0.7, 1.4] {
        ; FT args after the pattern: ScreenShot, FindAll, JoinText, offsetX, offsetY, dir, zoomW, zoomH
        if FT(&X, &Y, x1, y1, x2, y2, 0.25, 0.25, PlacedUnitLabel, A_Index = 1, 1, 0, 20, 10, 1, zoom, zoom)
            return true
    }
    return false
}

; Saves what the label search looked at, so a failed check can be inspected (Logs\placement_fail.bmp)
SaveUnitLabelArea(x, y) {
    try {
        WinGetClientPos(&cx, &cy, , , rblxID)
        FindText().SavePic(A_ScriptDir "\Logs\placement_fail.bmp"
            , cx + Max(0, x - 150), cy + Max(0, y - 160), cx + x + 150, cy + y + 40)
    }
}

GetPlacementSpeed() {
    speeds := [1000, 1500, 2000, 2500, 3000, 4000]  ; Array of sleep values
    speedIndex := PlaceSpeed.Value  ; Get the selected speed value

    if speedIndex is number  ; Ensure it's a number
        return speeds[speedIndex]  ; Use the value directly from the array
}

PostPlacementChecks() {
    HandleStartButton()

    if (ModeDropdown.Text = "Event" && EventDropdown.Text = "Fool's Hunt") {
        CheckForFoolBuffs()
    }

    if (CheckForLobby()) {
        AddToLog("Found in lobby, restarting mode if possible")
        return CheckLobby()
    }

    CheckStageInterruptions(true) ; Cards, results screen, reconnect
}

ResetPlacementTracking() {
    global successfulCoordinates, maxedCoordinates
    successfulCoordinates := []
    maxedCoordinates := []
}

EnableAutoUpgrade(slotNum) {
    global successfulCoordinates
    slotNum := successfulCoordinates[successfulCoordinates.Length].placementIndex
    OpenMenu("Unit Manager")
    Sleep(150)
    SetAutoUpgradeForSingleUnit(slotNum)
    CloseMenu("Unit Manager")
}

; Is the placement bubble at (x, y) red? Must be called while holding a unit; leaves the mouse on (x, y).
; One picture is taken with the mouse parked far away and one with it on the spot, a moment apart. The
; ground, the red path and hill shading look the same in both, so only the bubble's tint differs: around
; the spot it turns bluer (can place) or redder (can't). Samples run from 25px (past the unit model) to
; 100px (inside even small bubbles). `score` = median change in (blue - red) across the samples, `share`
; = % of samples that clearly turned redder. Only a clear red result counts - anything else is placed
PlacementBubbleIsRed(x, y, &score := 0, &share := 0) {
    score := 0, share := 0
    try WinGetClientPos(&cx, &cy, &w, &h, rblxID)
    catch
        return false

    ; Sample points around the spot that are inside the game area (not the top bar or hotbar)
    points := []
    for r in [25, 40, 55, 70, 85, 100] {
        angle := 0
        while (angle < 360) {
            px := Round(x + r * Cos(angle * 0.0174533)), py := Round(y + r * Sin(angle * 0.0174533))
            if (px >= 0 && px < w && py >= 40 && py < h * 0.86)
                points.Push([px, py])
            angle += 15
        }
    }
    if (points.Length < 40)
        return false

    ; Park the mouse in the corner of the play area furthest from the spot, so its bubble is elsewhere
    best := 0
    for corner in [[0.08, 0.25], [0.92, 0.25], [0.08, 0.80], [0.92, 0.80]] {
        dx := w * corner[1] - x, dy := h * corner[2] - y
        if (dx * dx + dy * dy > best)
            best := dx * dx + dy * dy, parkX := Round(w * corner[1]), parkY := Round(h * corner[2])
    }
    MouseMove(parkX, parkY)
    Sleep(200)
    before := BubbleTints(points, cx, cy, w, h)
    MouseMove(x, y)
    Sleep(250) ; Let the bubble follow the mouse
    after := BubbleTints(points, cx, cy, w, h)

    changes := [], redder := 0
    for i, t in after {
        d := t - before[i]
        changes.Push(d)
        if (d <= -15)
            redder += 1
    }
    SortNumbers(changes)
    score := changes[changes.Length // 2 + 1]
    share := Round(100 * redder / changes.Length)
    return score <= -12 && share >= 55
}

; (blue - red) at each point
BubbleTints(points, cx, cy, w, h) {
    FindText().ScreenShot(cx, cy, cx + w - 1, cy + h - 1)
    tints := []
    for p in points {
        c := FindText().GetColor(cx + p[1], cy + p[2], 0)
        tints.Push((c & 0xFF) - ((c >> 16) & 0xFF))
    }
    return tints
}

SortNumbers(arr) {
    ; Insertion sort - lists here are ~150 numbers
    i := 2
    while (i <= arr.Length) {
        v := arr[i], j := i - 1
        while (j >= 1 && arr[j] > v) {
            arr[j + 1] := arr[j]
            j -= 1
        }
        arr[j + 1] := v
        i += 1
    }
    return arr
}
