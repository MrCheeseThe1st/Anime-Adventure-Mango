#Requires AutoHotkey v2.0

; Unit Overview (opened with F) lists every placed unit newest first, 2 cards per row.
; Cards are found at runtime by their cyan "First" button, so nothing depends on window size.
; Each card's progress bar has one segment per upgrade level - lit segments are the current level.
; All offsets below were measured on a card whose "First" button is 70px wide, then scaled.

global overviewCards := []

; Scrolling: the script starts at the very bottom of the list, where the rows line up and the last
; row is known to be the last row of the list. After every wheel notch it re-detects the rows on screen
; and matches portraits against the previous view to see how many rows the list moved, so it never
; depends on rows landing on exact pixel positions. It never scrolls above the first row.
;   rows    - fully visible rows on screen, top to bottom; each is [left card or 0, right card or 0]
;   topRow  - which list row is the first fully visible row (1 = first row of the list)
;   look    - RowPortraits(rows), so the next step and a reopen don't have to read the cards again
global overviewScroll := { known: false, total: -1, rows: [], look: "", leftX: 0, rightX: 0, topRow: 1, totalRows: 0 }
global overviewError := "" ; Why the last scroll/lookup failed, shown by the debug test
global stageEnded := false   ; Set when the results screen shows up mid placing/upgrading
global lastFullStageCheck := 0
global lastUnitRecount := 0  ; When the overview was last recounted (ResyncUnitCount)

; verify = true checks the level actually went up, and returns "unaffordable" if it didn't
UpgradeViaOverview(coord, upgradeLimit := "", verify := false) {
    if !OpenUnitOverview()
        return "missing"

    card := GetOverviewCard(coord.placementIndex, TotalPlacedUnits())
    if !card
        return "missing"

    ; Check the button first - the bottom card's bar can be cut off by the list edge
    if IsOverviewCardMaxed(card)
        return "max"

    level := ReadOverviewLevel(card)
    if (level.total > 0 && level.lit = level.total)
        return "max"

    if (upgradeLimit != "") {
        if (level.total = 0) {
            AddToLog("Couldn't read the upgrade level of unit " coord.slot ", skipping the overview for it")
            return "missing" ; Don't risk going past the limit
        }
        if (level.lit >= upgradeLimit)
            return "limit"
    }

    FixClick(card.upgX, card.upgY)
    Sleep(150)
    if (!verify || level.total = 0) { ; Can't read the bar, so can't tell - assume it went through
        RefreshCardLook(card)
        return "upgraded"
    }

    ; Give the bar time to update - calling a slow update "unaffordable" would upgrade the unit twice
    loop 12 {
        Sleep(100)
        if (ReadOverviewLevel(card).lit > level.lit || IsOverviewCardMaxed(card)) {
            RefreshCardLook(card)
            return "upgraded"
        }
    }
    return "unaffordable"
}

; The card's level changed - update its saved look so scroll matching compares against what's on screen
RefreshCardLook(card) {
    global overviewScroll
    sc := overviewScroll
    if !IsObject(sc.look)
        return
    for i, row in sc.rows {
        loop 2 {
            if (row[A_Index] = card && i <= sc.look.Length) {
                sc.look[i][A_Index] := CardLook(card)
                return
            }
        }
    }
}

OpenUnitOverview() {
    global overviewScroll
    if (IsUnitOverviewOpen())
        return true

    loop 3 {
        if !IsUnitOverviewOpen() ; F toggles - don't close a panel that opened late
            Send("F")
        start := A_TickCount
        while (A_TickCount - start < 1000) {
            Sleep(100)
            if (IsUnitOverviewOpen()) {
                Sleep(300) ; Let the slide-in animation finish before trusting positions
                ScanOverviewCards()
                ; Closing doesn't scroll the list, so the last position is usually still right - check it
                ; instead of scrolling to the bottom and back up every time the overview reopens
                if overviewScroll.known
                    overviewScroll.known := OverviewStillWhereLeft()
                return true
            }
        }
    }
    AddToLog("Couldn't open the Unit Overview")
    return false
}

CloseUnitOverview() {
    global overviewScroll
    if !IsUnitOverviewOpen()
        return

    Send("F")
    Sleep(400)
    if IsUnitOverviewOpen() {
        ; Fall back to the red Return button under the card list
        WinGetClientPos(, , &w, &h, rblxID)
        if PixelSearch(&rx, &ry, Round(w * 0.72), Round(h * 0.86), Round(w * 0.95), Round(h * 0.95), 0xC00000, 0x40) {
            FixClick(rx + 10, ry + 10)
            Sleep(400)
        }
    }
    ; overviewScroll.known is kept - OpenUnitOverview checks the list is still where it was left
}

; After reopening: are the rows on screen the same ones that were showing when it closed? Compares the
; cards with the saved look, and with the look one row up/down - if the list could have moved one row
; without looking different (rows of identical units), it isn't trusted
OverviewStillWhereLeft() {
    global overviewScroll
    sc := overviewScroll
    if !IsObject(sc.look)
        return false
    WaitForOverviewSettle()
    rows := OverviewRows()
    if (rows = "" || rows.Length != sc.rows.Length || !RowsMatchList(rows, sc.topRow, sc.total))
        return false
    look := RowPortraits(rows)
    same := RowsDistance(look, sc.look, 0)
    up := RowsDistance(look, sc.look, -1), down := RowsDistance(look, sc.look, 1)
    if (same = "" || same > 15 || (up != "" && up <= same + 25) || (down != "" && down <= same + 25))
        return false
    sc.rows := rows, sc.look := look
    return true
}

; Open if any cards are showing, or - with no units placed yet - if the panel itself is showing
IsUnitOverviewOpen() {
    return ScanOverviewCards().Length > 0 || IsOverviewPanelOpen()
}

; The orange "Unit Overview" title and the red Return button only show while the panel is open.
; Counts matching pixels on a grid rather than trusting a single pixel
IsOverviewPanelOpen() {
    try WinGetClientPos(&cx, &cy, &w, &h, rblxID)
    catch
        return false
    return CountColorInBox(cx, cy, Round(w * 0.70), Round(h * 0.11), Round(w * 0.96), Round(h * 0.18), "orange") >= 40
        && CountColorInBox(cx, cy, Round(w * 0.75), Round(h * 0.86), Round(w * 0.90), Round(h * 0.95), "red") >= 60
}

CountColorInBox(cx, cy, x1, y1, x2, y2, kind) {
    FindText().ScreenShot(cx + x1, cy + y1, cx + x2, cy + y2)
    count := 0
    y := y1
    while (y <= y2) {
        x := x1
        while (x <= x2) {
            c := FindText().GetColor(cx + x, cy + y, 0)
            r := (c >> 16) & 0xFF, g := (c >> 8) & 0xFF, b := c & 0xFF
            if (kind = "orange" ? (r > 200 && g > 120 && g < 220 && b < 80) : (r > 150 && g < 50 && b < 50))
                count += 1
            x += 3
        }
        y += 3
    }
    return count
}

; Does the overview list exactly `total` units? Up to 6 units always fit on screen, so count them
; directly. A longer list may be scrolled, so check it from the bottom, where the layout only fits
; the right count (the last row has 1 card for an odd count, 2 for an even one)
OverviewHasUnits(total) {
    global overviewCards
    if !OpenUnitOverview()
        return false
    WaitForOverviewSettle()

    visible := 0
    for card in overviewCards
        visible += card.full ? 1 : 0
    if (visible <= 6 && visible = overviewCards.Length)
        return visible = total
    if (total <= 6)
        return false ; 7+ cards showing, but only `total` expected
    return HomeOverviewToBottom(total)
}

; How many units the overview lists, if that's at least `atLeast`; 0 if it lists fewer. More than
; expected means an earlier placement went through unnoticed.
; Only a list that fits on screen can be counted exactly. A longer one is checked from the bottom, which
; only shows whether the count is odd or even (last row 1 or 2 cards) - 8 and 10 units look the same
; there. So for long lists only the exact count `atLeast` is accepted: guessing a higher count could
; record units that don't exist and throw every unit's position in the overview off by one
OverviewUnitCount(atLeast, scroll := true) {
    global overviewCards
    if !OpenUnitOverview()
        return 0
    WaitForOverviewSettle()

    visible := 0
    for card in overviewCards
        visible += card.full ? 1 : 0
    if (visible <= 6 && visible = overviewCards.Length)
        return (visible >= atLeast) ? visible : 0

    if (atLeast <= 6)
        return 0 ; 7+ cards are showing, so it can't be this few
    return HomeOverviewToBottom(atLeast, scroll, true) ? atLeast : 0
}

TotalPlacedUnits() {
    global successfulCoordinates, maxedCoordinates
    total := 0
    for coord in successfulCoordinates
        total := Max(total, coord.placementIndex)
    for coord in maxedCoordinates
        total := Max(total, coord.placementIndex)
    return total
}

; Returns the card for the unit placed at position `placementIndex`, scrolling the list if needed.
; If it can't be found, the recorded unit count may be wrong - recount the overview, fix the records
; and try once more, so one miscount doesn't break upgrading for the rest of the match
GetOverviewCard(placementIndex, total) {
    card := FindOverviewCard(placementIndex, total)
    if (!card && ResyncUnitCount()) {
        total := TotalPlacedUnits()
        if (placementIndex > total)
            return false ; This unit was never really placed - it was just forgotten
        card := FindOverviewCard(placementIndex, total)
    }
    return card
}

FindOverviewCard(placementIndex, total) {
    global overviewScroll
    sc := overviewScroll

    ; The overview lists units newest first, so the first unit placed is the last card
    index := total - placementIndex + 1
    if (index < 1)
        return false

    if (!sc.known || sc.total != total) {
        if !HomeOverviewToBottom(total)
            return false
    }

    card := ScrollToOverviewCard(index)
    if (!card && HomeOverviewToBottom(total)) ; Lost track (dropped wheel input?) - start over from the bottom once
        card := ScrollToOverviewCard(index)
    return card
}

; Scrolls to the bottom, where the last row on screen is the last row of the list
HomeOverviewToBottom(total, scroll := true, quiet := false) {
    global overviewCards, overviewScroll, overviewError
    sc := overviewScroll
    sc.known := false

    if (overviewCards.Length = 0)
        return false

    ; The bottom is a hard stop, so send far more notches than the list has rows (covers dropped inputs)
    ; and then wait for the cards to stop moving
    if scroll {
        OverviewWheel("WheelDown", Ceil(total / 2) * 2 + 10)
        WaitForOverviewSettle()
    }

    ; Column x positions don't change when scrolling, so learn them once here
    leftX := "", rightX := ""
    for card in overviewCards {
        if card.full {
            leftX := (leftX = "") ? card.x1 : Min(leftX, card.x1)
            rightX := (rightX = "") ? card.x1 : Max(rightX, card.x1)
        }
    }
    if (leftX = "") {
        overviewError := "No fully visible cards at the bottom of the list"
        return false
    }
    sc.leftX := leftX, sc.rightX := rightX
    if (rightX - leftX < overviewCards[1].scale * 20)
        sc.rightX := leftX + overviewCards[1].scale * 178 ; Only one column on screen - estimate the other

    rows := OverviewRows()
    if (rows = "" || rows.Length = 0) {
        overviewError := "Couldn't sort the cards into rows. Cards seen: " OverviewYs()
        return false
    }

    totalRows := Ceil(total / 2)
    topRow := Max(1, totalRows - rows.Length + 1)
    if !RowsMatchList(rows, topRow, total) {
        overviewError := "At the bottom the cards on screen don't fit " total " units (" OverviewCardCount(rows)
            . " cards in " rows.Length " rows). Is the unit count right? Cards seen: " OverviewYs()
        if !quiet
            AddToLog("Unit Overview shows a different number of units than were placed - skipping it")
        return false
    }

    sc.rows := rows, sc.look := RowPortraits(rows), sc.topRow := topRow, sc.totalRows := totalRows
    sc.total := total
    sc.known := true
    return true
}

ScrollToOverviewCard(index) {
    global overviewScroll, overviewError
    sc := overviewScroll

    row := Ceil(index / 2)
    loop 2 * sc.totalRows + 4 {
        visRows := sc.rows.Length
        ; Away from the bottom of the list the rows don't line up, and the lowest visible row's level bar
        ; is cut off by the list edge. Only trust that row when scrolled all the way down
        atBottom := (sc.topRow + visRows - 1 >= sc.totalRows)
        usableRows := atBottom ? visRows : visRows - 1
        if (row >= sc.topRow && row <= sc.topRow + usableRows - 1)
            break
        dir := (row < sc.topRow) ? -1 : 1
        if (dir > 0 && sc.topRow + visRows - 1 >= sc.totalRows) {
            overviewError := "Card is below the bottom of the list"
            return false
        }
        if !OverviewStep(dir) {
            AddToLog("Unit Overview didn't scroll as expected (" overviewError ") - starting over from the bottom")
            sc.known := false
            return false
        }
    }

    i := row - sc.topRow + 1
    if (i < 1 || i > sc.rows.Length) {
        overviewError := "Couldn't bring row " row " on screen"
        return false
    }
    card := sc.rows[i][Mod(index - 1, 2) + 1]
    if !card {
        overviewError := "Row " row " is on screen but its " (Mod(index - 1, 2) ? "right" : "left") " card wasn't detected. Cards seen: " OverviewYs()
        return false
    }
    return card
}

; Scrolls one notch (dir -1 = up, 1 = down) and works out how many rows the list actually moved
OverviewStep(dir) {
    global overviewScroll, overviewError
    sc := overviewScroll

    before := sc.rows
    beforeLook := IsObject(sc.look) ? sc.look : RowPortraits(before)
    loop 3 { ; Retry dropped wheel inputs
        OverviewWheel(dir < 0 ? "WheelUp" : "WheelDown", 1)
        WaitForOverviewSettle()

        rows := OverviewRows()
        if (rows = "" || rows.Length = 0) {
            overviewError := "After scrolling " (dir < 0 ? "up" : "down") " the cards couldn't be sorted into rows. Cards seen: " OverviewYs()
            return false
        }
        look := RowPortraits(rows)

        ; New row i shows list row topRow + shift + i - 1. A notch moves the list exactly one row the way we
        ; scrolled, or not at all if the input was dropped. Keep the closer match; on a tie (rows of identical
        ; units at identical levels) prefer one row - those units are interchangeable anyway
        bestShift := "", bestScore := ""
        for shift in [dir, 0] {
            score := RowsDistance(look, beforeLook, shift)
            if (score != "" && (bestScore = "" || score < bestScore))
                bestShift := shift, bestScore := score
        }
        if (bestShift = "") {
            overviewError := "After scrolling, no rows overlapped with the previous view"
            return false
        }
        if (bestShift = 0) {
            before := rows, beforeLook := look ; Didn't move - send the notch again
            continue
        }

        newTop := sc.topRow + bestShift
        if (newTop < 1 || !RowsMatchList(rows, newTop, sc.total)) {
            overviewError := "After scrolling " (dir < 0 ? "up" : "down") " the list seemed to move " bestShift " rows, but the cards on screen ("
                . OverviewCardCount(rows) " in " rows.Length " rows) don't fit that. Cards seen: " OverviewYs()
            return false
        }
        sc.rows := rows, sc.look := look, sc.topRow := newTop
        return true
    }
    overviewError := "Scrolling " (dir < 0 ? "up" : "down") " didn't move the list (3 tries)"
    return false
}

; Groups the fully visible cards into rows (top to bottom), each [left card or 0, right card or 0].
; Returns "" if a card isn't in either column
OverviewRows() {
    global overviewCards, overviewScroll
    sc := overviewScroll
    ; Both columns on screen - take their positions from here (positions learned earlier can be stale)
    minX := "", maxX := ""
    for card in overviewCards {
        if card.full
            minX := (minX = "") ? card.x1 : Min(minX, card.x1), maxX := (maxX = "") ? card.x1 : Max(maxX, card.x1)
    }
    if (minX != "" && maxX - minX > overviewCards[1].scale * 100)
        sc.leftX := minX, sc.rightX := maxX
    rows := [], rowY := ""
    for card in overviewCards { ; Already in reading order
        if !card.full
            continue
        tolerance := card.scale * 15
        col := (Abs(card.x1 - sc.leftX) <= tolerance) ? 1 : (Abs(card.x1 - sc.rightX) <= tolerance) ? 2 : 0
        if !col
            return ""
        if (rowY = "" || Abs(card.y1 - rowY) > card.scale * 30) {
            rows.Push([0, 0])
            rowY := card.y1
        }
        rows[rows.Length][col] := card
    }
    return rows
}

; Do the rows on screen have the cards list rows topRow.. should have? Every row has 2 cards except
; the very last row of the list when the unit count is odd
RowsMatchList(rows, topRow, total) {
    totalRows := Ceil(total / 2)
    for i, row in rows {
        listRow := topRow + i - 1
        if (listRow > totalRows)
            return false
        lastOdd := (listRow = totalRows && Mod(total, 2) = 1)
        if (!row[1] || (lastOdd ? row[2] : !row[2]))
            return false
    }
    return true
}

OverviewCardCount(rows) {
    count := 0
    for row in rows
        count += (row[1] ? 1 : 0) + (row[2] ? 1 : 0)
    return count
}

; What each card in each row looks like: [left or 0, right or 0], each { colors, lit, total, maxed }
RowPortraits(rows) {
    look := []
    for row in rows
        look.Push([row[1] ? CardLook(row[1]) : 0, row[2] ? CardLook(row[2]) : 0])
    return look
}

CardLook(card) {
    level := ReadOverviewLevel(card)
    return { colors: PortraitSample(card), lit: level.lit, total: level.total, maxed: IsOverviewCardMaxed(card) }
}

; How different the cards look when new row i is compared with old row i + shift. "" if nothing overlaps
RowsDistance(look, beforeLook, shift) {
    total := 0, count := 0
    for i, row in look {
        j := i + shift
        if (j < 1 || j > beforeLook.Length)
            continue
        loop 2 {
            a := row[A_Index], b := beforeLook[j][A_Index]
            if (!a || !b)
                continue
            for k, c in a.colors {
                o := b.colors[k]
                total += Abs(((c >> 16) & 0xFF) - ((o >> 16) & 0xFF)) + Abs(((c >> 8) & 0xFF) - ((o >> 8) & 0xFF))
                    + Abs((c & 0xFF) - (o & 0xFF))
            }
            ; A different level or Max state counts like a clearly different colour sample
            total += 120 * (Abs(a.lit - b.lit) + Abs(a.total - b.total) + (a.maxed != b.maxed))
            count += a.colors.Length
        }
    }
    return count ? total / count : ""
}

; Counts the units in the Unit Overview without knowing how many there should be. Lists that fit on
; screen are counted directly. Longer ones: go to the bottom (all rows line up, the last row shows if the
; count is odd), then scroll up one notch at a time counting the rows that come into view, until the list
; stops moving. Returns -1 if it couldn't tell
CountOverviewUnits() {
    global overviewCards, overviewScroll
    sc := overviewScroll
    if !OpenUnitOverview()
        return -1
    WaitForOverviewSettle()
    if (overviewCards.Length = 0)
        return IsOverviewPanelOpen() ? 0 : -1

    visible := 0
    for card in overviewCards
        visible += card.full ? 1 : 0
    if (visible <= 6 && visible = overviewCards.Length)
        return visible

    loop 8
        OverviewWheel("WheelDown", 5)
    WaitForOverviewSettle()
    sc.known := false
    rows := OverviewRows()
    if (rows = "" || rows.Length = 0)
        return -1
    lastOdd := !rows[rows.Length][2]
    count := rows.Length
    look := RowPortraits(rows), tops := RowTops(rows)
    tolerance := overviewCards[1].scale * 10

    still := 0, foundTop := false
    loop 40 {
        OverviewWheel("WheelUp", 1)
        WaitForOverviewSettle()
        newRows := OverviewRows()
        if (newRows = "" || newRows.Length = 0)
            return -1
        newTops := RowTops(newRows)
        aligned := (newTops.Length = tops.Length)
        if aligned {
            for i, y in newTops {
                if (Abs(y - tops[i]) > tolerance)
                    aligned := false
            }
        }
        ; At the top the last notch only moves part of a row, so the rows stop lining up - that notch
        ; brought the first row into view
        if !aligned {
            count += 1, foundTop := true
            break
        }
        ; Lined up: moved one row (new row i looks like old row i - 1) or didn't move (looks like old row i).
        ; Rows of identical units look the same either way - count those as a move, since notches from the
        ; bottom almost always move
        newLook := RowPortraits(newRows)
        up := RowsDistance(newLook, look, -1), same := RowsDistance(newLook, look, 0)
        clearlyStill := (same != "" && same <= 8 && (up = "" || up > same + 25))
        look := newLook
        if !clearlyStill {
            count += 1, still := 0
            continue
        }
        still += 1
        if (still >= 3) { ; Didn't move for 3 notches in a row (one can be a dropped input) - at the top
            foundTop := true
            break
        }
    }
    sc.known := false
    if !foundTop ; 40 notches and never reached the top - the rows must all look alike, so it can't tell
        return -1
    return count * 2 - (lastOdd ? 1 : 0)
}

RowTops(rows) {
    tops := []
    for row in rows
        tops.Push(row[1] ? row[1].y1 : row[2].y1)
    return tops
}

; Recounts the Unit Overview and makes the script's records match it: units it didn't know about are
; added, recorded units that aren't there are forgotten (so they get placed again). Units the script gave
; up on reading get another chance. At most once every 20 seconds. Returns true if it recounted
ResyncUnitCount() {
    global lastUnitRecount
    if (A_TickCount - lastUnitRecount < 20000)
        return false
    lastUnitRecount := A_TickCount

    recorded := PlacedUnitCount()
    real := CountOverviewUnits()
    if (real < 0) {
        AddToLog("Couldn't recount the Unit Overview - carrying on")
        return false
    }
    ; Units don't vanish, so a much lower count means the cards were misread - don't throw records away
    if (real < recorded - 3 || real > recorded + 4) {
        AddToLog("Recounted " real " units in the Unit Overview but " recorded " were recorded - too far off to trust, carrying on")
        return false
    }
    if (real = recorded)
        AddToLog("Recounted the Unit Overview: " real " units, as recorded")
    else
        AdjustRecordedUnits(real)
    ResetOverviewSkips()
    return true
}

AdjustRecordedUnits(real) {
    global placedCounts, lastPlacementAttempt
    recorded := PlacedUnitCount()
    if (real > recorded) {
        ; Most likely the last placement that looked like it failed went through after all
        slot := IsObject(lastPlacementAttempt) ? lastPlacementAttempt.slot : NewestRecordedUnit().slot
        AddToLog("The Unit Overview has " real " units but " recorded " were recorded - counting the "
            . (real - recorded = 1 ? "extra one" : (real - recorded) " extra") " as Unit " slot)
        loop real - recorded
            AddUnrecordedUnit(slot)
    } else {
        AddToLog("The Unit Overview has " real " units but " recorded " were recorded - forgetting the newest "
            . (recorded - real) ", they'll be placed again")
        loop recorded - real
            ForgetNewestUnit()
    }
}

NewestRecordedUnit() {
    global successfulCoordinates, maxedCoordinates
    newest := { slot: 1, placementIndex: 0 }
    for list in [successfulCoordinates, maxedCoordinates] {
        for coord in list {
            if (coord.placementIndex > newest.placementIndex)
                newest := coord
        }
    }
    return newest
}

; Records a unit that's in the overview but was never recorded, as the newest unit
AddUnrecordedUnit(slot) {
    global successfulCoordinates, placedCounts, lastPlacementAttempt
    spot := IsObject(lastPlacementAttempt) ? lastPlacementAttempt : { x: 0, y: 0 }
    successfulCoordinates.Push({
        x: spot.x,
        y: spot.y,
        slot: slot,
        upgradePriority: GetUpgradePriority(slot),
        placementIndex: PlacedUnitCount() + 1,
        autoUpgrade: false,
        hasAbility: !autoAbilityDisabled && abilityEnabled%slot%.Value ; The ability timer turns it on later
    })
    if !placedCounts.Has(slot)
        placedCounts[slot] := 0
    placedCounts[slot] += 1
}

; Drops the newest recorded unit (it isn't really there) and lets its slot be placed again
ForgetNewestUnit() {
    global successfulCoordinates, maxedCoordinates, placedCounts, strategyCapped, placementCapped
    coord := NewestRecordedUnit()
    if (coord.placementIndex = 0)
        return
    for list in [successfulCoordinates, maxedCoordinates] {
        for i, c in list {
            if (c = coord) {
                list.RemoveAt(i)
                break
            }
        }
    }
    coord.removed := true, coord.strategyDone := true ; Anything still holding it skips it
    if (placedCounts.Has(coord.slot) && placedCounts[coord.slot] > 0)
        placedCounts[coord.slot] -= 1
    if (IsObject(strategyCapped) && strategyCapped.Has(coord.slot))
        strategyCapped.Delete(coord.slot)
    if (IsObject(placementCapped) && placementCapped.Has(coord.slot))
        placementCapped.Delete(coord.slot)
}

; Units skipped because their card couldn't be read get upgraded again
ResetOverviewSkips() {
    global successfulCoordinates, maxedCoordinates
    for list in [successfulCoordinates, maxedCoordinates] {
        for coord in list {
            coord.strategySkips := 0
            if (coord.HasOwnProp("skippedOut") && coord.skippedOut)
                coord.skippedOut := false, coord.strategyDone := false
        }
    }
}

; The list may glide into place after a wheel notch - rescan until card positions stop changing
WaitForOverviewSettle() {
    global overviewCards
    prev := OverviewYs(ScanOverviewCards())
    loop 10 {
        Sleep(120)
        now := OverviewYs(ScanOverviewCards())
        if (now = prev)
            return
        prev := now
    }
}

OverviewYs(cards := "") {
    global overviewCards
    if !IsObject(cards)
        cards := overviewCards
    ys := ""
    for card in cards
        ys .= card.x1 "," card.y1 (card.full ? "" : "p") " "
    return Trim(ys)
}

; 3x3 grid of colours from the unit's portrait (left of the buttons)
PortraitSample(card) {
    s := card.scale
    centerY := (card.y1 + card.y2) / 2
    x1 := card.x1 - 72 * s, x2 := card.x1 - 12 * s
    y1 := centerY - 25 * s, y2 := centerY + 15 * s
    colors := []
    try {
        WinGetClientPos(&cx, &cy, , , rblxID)
        FindText().ScreenShot(cx + Round(x1), cy + Round(y1), cx + Round(x2), cy + Round(y2))
    } catch {
        loop 9
            colors.Push(0)
        return colors
    }
    for fy in [0.25, 0.5, 0.75] {
        for fx in [0.25, 0.5, 0.75] {
            try c := FindText().GetColor(cx + Round(x1 + (x2 - x1) * fx), cy + Round(y1 + (y2 - y1) * fy), 0)
            catch
                c := 0
            colors.Push(Integer(c))
        }
    }
    return colors
}

OverviewWheel(direction, times) {
    global overviewCards
    if (overviewCards.Length = 0)
        return
    ; The wheel only scrolls the list while the mouse is over it
    first := overviewCards[1], last := overviewCards[overviewCards.Length]
    MouseMove(first.upgX, Round((first.y1 + last.y1) / 2))
    Sleep(50)
    Scroll(times, direction, 30)
    ; Park the mouse above the cards (on the panel title) so hover effects can't change what gets scanned
    MouseMove(first.upgX, Max(5, Round(first.y1 - 110 * first.scale)))
    Sleep(150)
}

ScanOverviewCards() {
    global overviewCards

    try WinGetClientPos(&cx, &cy, &w, &h, rblxID)
    catch {
        return overviewCards := []
    }

    x1 := Round(w * 0.45), y1 := Round(h * 0.17), x2 := w - 1, y2 := Round(h * 0.85)
    FindText().ScreenShot(cx + x1, cy + y1, cx + x2, cy + y2)

    ; Group cyan pixels into blobs
    step := 2, margin := 8
    blobs := []
    y := y1
    while (y <= y2) {
        x := x1
        while (x <= x2) {
            c := FindText().GetColor(cx + x, cy + y, 0)
            r := (c >> 16) & 0xFF, g := (c >> 8) & 0xFF, b := c & 0xFF
            if (r < 0x50 && g > 0xB0 && b > 0xE0) {
                added := false
                for blob in blobs {
                    if (x >= blob.x1 - margin && x <= blob.x2 + margin && y >= blob.y1 - margin && y <= blob.y2 + margin) {
                        blob.x1 := Min(blob.x1, x), blob.y1 := Min(blob.y1, y)
                        blob.x2 := Max(blob.x2, x), blob.y2 := Max(blob.y2, y)
                        added := true
                        break
                    }
                }
                if !added
                    blobs.Push({ x1: x, y1: y, x2: x, y2: y })
            }
            x += step
        }
        y += step
    }

    ; The white "First" text can split a button into pieces - merge overlapping blobs
    merged := true
    while (merged) {
        merged := false
        i := 1
        while (i <= blobs.Length) {
            j := i + 1
            while (j <= blobs.Length) {
                a := blobs[i], b := blobs[j]
                if (a.x1 - margin <= b.x2 && b.x1 - margin <= a.x2 && a.y1 - margin <= b.y2 && b.y1 - margin <= a.y2) {
                    a.x1 := Min(a.x1, b.x1), a.y1 := Min(a.y1, b.y1)
                    a.x2 := Max(a.x2, b.x2), a.y2 := Max(a.y2, b.y2)
                    blobs.RemoveAt(j)
                    merged := true
                } else {
                    j += 1
                }
            }
            i += 1
        }
    }

    ; Reference size from fully visible, button-shaped blobs only (~3.5:1), so stray cyan can't skew it
    maxW := 0, maxH := 0
    for blob in blobs {
        bw := blob.x2 - blob.x1, bh := blob.y2 - blob.y1
        if (bh >= 6 && bw >= bh * 2.5 && bw <= bh * 6)
            maxW := Max(maxW, bw), maxH := Max(maxH, bh)
    }
    if (maxW = 0)
        return overviewCards := []

    ; Keep only button-shaped blobs (all "First" buttons share the same width)
    cards := []
    scale := maxW / 70
    for blob in blobs {
        bw := blob.x2 - blob.x1, bh := blob.y2 - blob.y1
        if (bw < 20 || bw < maxW * 0.85 || bw > maxW * 1.15 || bw < bh * 2.5)
            continue
        centerY := (blob.y1 + blob.y2) / 2
        ; full = false when clipped at the list edge, so it isn't safe to click or read
        cards.Push({
            x1: blob.x1, y1: blob.y1, x2: blob.x2, y2: blob.y2,
            full: bh >= maxH * 0.8,
            scale: scale,
            upgX: Round(blob.x1 + 40 * scale),
            upgY: Round(centerY - 27 * scale),
            barX1: Round(blob.x1 - 76 * scale),
            barX2: Round(blob.x1 + 73 * scale),
            barY: Round(centerY + 31.5 * scale)
        })
    }

    ; Sort into reading order: row by row, left to right
    loop cards.Length {
        loop cards.Length - 1 {
            a := cards[A_Index], b := cards[A_Index + 1]
            sameRow := Abs(a.y1 - b.y1) <= maxH / 2
            if ((sameRow && a.x1 > b.x1) || (!sameRow && a.y1 > b.y1)) {
                cards[A_Index] := b
                cards[A_Index + 1] := a
            }
        }
    }

    return overviewCards := cards
}

; Counts lit / total segments in a card's progress bar. total = 0 means the bar couldn't be read
ReadOverviewLevel(card) {
    WinGetClientPos(&cx, &cy, &w, &h, rblxID)
    s := card.scale
    yRange := Max(2, Round(4 * s))
    minRun := Max(3, Round(6 * s))
    x1 := Max(0, card.barX1), x2 := Min(w - 1, card.barX2)

    FindText().ScreenShot(cx + x1, cy + card.barY - yRange, cx + x2, cy + card.barY + yRange)

    best := { colored: 0, lit: 0, total: 0 }
    y := card.barY - yRange
    while (y <= card.barY + yRange) {
        colored := 0, lit := 0, dim := 0
        runState := "", runLength := 0
        x := x1
        while (x <= x2 + 1) {
            if (x <= x2) {
                c := FindText().GetColor(cx + x, cy + y, 0)
                r := (c >> 16) & 0xFF, g := (c >> 8) & 0xFF, b := c & 0xFF
                hi := Max(r, g, b)
                ; Gray = gap between segments, bright = lit segment, dark color = unlit segment
                state := (hi - Min(r, g, b) < 0x30) ? "G" : (hi >= 0xA0 ? "L" : "D")
                colored += (state != "G")
            } else {
                state := "" ; Flush the last run
            }

            if (state = runState) {
                runLength += 1
            } else {
                if (runLength >= minRun) {
                    lit += (runState = "L")
                    dim += (runState = "D")
                }
                runState := state, runLength := 1
            }
            x += 1
        }
        if (colored > best.colored)
            best := { colored: colored, lit: lit, total: lit + dim }
        y += 1
    }
    return best
}

; Maxed units show "Max" instead of "Upg: 1234¥". Button colour can't tell them apart (an unaffordable
; upgrade is also dark green with grey text), but "Max" only spans ~43% of the button vs 70%+ for "Upg"
IsOverviewCardMaxed(card) {
    WinGetClientPos(&cx, &cy, , , rblxID)
    s := card.scale
    x1 := Round(card.x1 - 4 * s), x2 := Round(card.x2 + 4 * s)
    y1 := Round(card.upgY - 5 * s), y2 := Round(card.upgY + 5 * s)

    FindText().ScreenShot(cx + x1, cy + y1, cx + x2, cy + y2)

    left := x2, right := x1
    y := y1
    while (y <= y2) {
        x := x1
        while (x <= x2) {
            c := FindText().GetColor(cx + x, cy + y, 0)
            r := (c >> 16) & 0xFF, g := (c >> 8) & 0xFF, b := c & 0xFF
            hi := Max(r, g, b)
            if (hi - Min(r, g, b) < 0x30 && hi >= 0x60) { ; White or grey text
                left := Min(left, x), right := Max(right, x)
            }
            x += 1
        }
        y += 1
    }
    if (right <= left)
        return false
    return (right - left) / (x2 - x1) < 0.55
}

; Debug: describes every visible card. `total` = units placed (0 = assume all are on screen)
TestUnitOverview(total := 0) {
    global overviewCards
    if !OpenUnitOverview()
        return "Couldn't find the Unit Overview. Is it open (F) with at least one unit placed?"
    if (total <= 0)
        total := overviewCards.Length

    ; The overview lists units newest first, so walk it backwards to report in placement order
    report := "Found " overviewCards.Length " cards (Unit #1 = first unit placed):`n"
    allVisible := overviewCards.Length >= total
    loop overviewCards.Length {
        index := overviewCards.Length - A_Index + 1
        card := overviewCards[index]
        level := ReadOverviewLevel(card)
        label := allVisible ? "Unit #" (total - index + 1) : "Card " index
        report .= label ": level " (level.total ? level.lit "/" level.total : "unreadable")
            . (IsOverviewCardMaxed(card) ? "  MAX" : "") (card.full ? "" : "  (cut off)")
            . "  | Upg button at " card.upgX ", " card.upgY "`n"
    }
    if (overviewCards.Length < total)
        report .= "`nList is longer than the screen - use the scrolling test for placement numbers."
    return report
}

; Debug: scrolls to the bottom, then to every unit in a mixed order and checks each one is found
TestOverviewScrolling(total) {
    global overviewCards, overviewScroll, overviewError
    if !OpenUnitOverview()
        return "Couldn't find the Unit Overview. Is it open (F)?"

    if !HomeOverviewToBottom(total)
        return "Couldn't line up the list at the bottom.`nReason: " overviewError
    sc := overviewScroll
    report := "Bottom OK: " sc.rows.Length " rows visible, list has " sc.totalRows " rows`n"
        . "(Unit #1 = first unit placed, at the bottom of the list)`n`n"

    ; Visit units far apart from each other: first placed, newest, second, ...
    order := [], lo := 1, hi := total
    while (lo <= hi) {
        order.Push(lo)
        if (lo != hi)
            order.Push(hi)
        hi -= 1, lo += 1
    }
    found := 0
    lines := Map() ; Visited out of order, reported in placement order below
    for placed in order {
        card := GetOverviewCard(placed, total)
        if card {
            found += 1
            level := ReadOverviewLevel(card) ; Read before hovering, in case hovering changes the card
            MouseMove(card.upgX, card.upgY) ; Hover so you can watch it land on the right card
            Sleep(600)
            lines[placed] := "Unit #" placed ": found, level " (level.total ? level.lit "/" level.total : "unreadable")
                . (IsOverviewCardMaxed(card) ? " MAX" : "") "`n"
        } else {
            lines[placed] := "Unit #" placed ": NOT found - " overviewError "`n"
            overviewError := ""
        }
    }
    loop total
        report .= lines[A_Index] ; Map loops sort numeric keys, but be explicit about the order
    return report "`nFound " found "/" total ". Check the mouse hovered the right unit each time."
}

; Card pop-ups and the results screen, checked while placing and upgrading.
; The XP text on the results screen is searched for under where the Unit Overview sits, and the overview
; can block card clicks, so the overview is closed before anything is handled. A quick look (results
; header, "pick a card") runs every time; `full` also closes the overview just to look, in case something
; is hidden behind it. Returns true and sets stageEnded once the stage is over - callers then stop
CheckStageInterruptions(full := false) {
    global stageEnded, lastFullStageCheck
    if stageEnded
        return true

    seen := StageEndScreenShowing() || FT(&X, &Y, 270, 127, 532, 161, 0, 0, pick_card)
    if (!seen && !full)
        return false
    lastFullStageCheck := A_TickCount

    if IsOverviewPanelOpen()
        CloseUnitOverview()

    if (HasCards(ModeDropdown.Text) || HasCards(EventDropdown.Text))
        CheckForCardSelection()

    if (StageEndScreenShowing() || CheckForXP(false, false)) {
        AddToLog("Stage ended - stopping placement/upgrades")
        stageEnded := true
        return true
    }
    Reconnect()
    return false
}

; The win/lose panel on the left: VICTORY/DEFEAT title or the green Next button (same patterns and
; regions MonitorStage uses). Unlike the XP text, the overview doesn't cover these
StageEndScreenShowing() {
    return isMenuOpen("End Screen")
        || FT(&X, &Y, 319, 176, 492, 279, 0, 0, DefeatText2) || FT(&X, &Y, 150, 180, 350, 260, 0, 0, DefeatText)
        || FT(&X, &Y, 319, 176, 492, 279, 0, 0, VictoryText2) || FT(&X, &Y, 150, 180, 350, 260, 0, 0, VictoryText)
        || FT(&X, &Y, 363, 193, 475, 274, 0, 0, VictoryTextApril)
        || FT(&X, &Y, 266, 376, 377, 413, 0, 0, NextText)
}

; Full check if one hasn't run for `interval` ms
CheckStageInterruptionsEvery(interval := 15000) {
    global lastFullStageCheck
    return CheckStageInterruptions(A_TickCount - lastFullStageCheck >= interval)
}
