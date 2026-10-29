#Requires AutoHotkey v2.0

; Unit-type strategy: every slot is given a type (Farm, DPS, Support, Buff, Summon or None) and units are
; placed and upgraded in a fixed order. Within a type, the Priority column decides which unit goes first.
;   1. Top farm: place 1 copy in Story, 3 in other modes (never more than its Placements). No upgrades
;   2. Top DPS: place 1 copy, upgrade it to level 2
;   3. Place all remaining farm copies, then upgrade every farm to level 2 (evenly)
;   4. Top DPS: place a 2nd copy, upgrade it to level 2
;   5. Top support: place 1 copy, upgrade it to level 2
;   6. Top DPS, 1st copy: upgrade to level 3
;  6b. Place every remaining copy, DPS > Summon > Buff > Support > None. Money is spent as it goes:
;      after every placement, and every 3 failed tries, units are upgraded in priority order until
;      nothing more is affordable
;   7. Every farm to MAX, one level per farm per round
;   8. Every copy of the top DPS to level 4 (evenly)
;   9. Place anything step 6b couldn't (e.g. not enough money then), upgrading each new one once.
;      Spare money is spent as it goes: after every placement, and every 3 failed tries while a placement
;      keeps failing, units are upgraded in priority order until nothing more is affordable
;  10. Until everything is maxed or at its limit: go down the step 9 order giving each unit up to 2
;      upgrades it can afford right now - a unit that's too expensive is skipped until the next pass.
;      If a recount of the Unit Overview shows a unit is missing (farms included), it's placed again first
; "Level N" = N lit segments on the Unit Overview bar. A unit's Upgrade Limit always wins over a step's
; target. If a unit can't be afforded, the script waits for it. Cards and the end screen are handled
; between every action (CheckStageInterruptions)

global strategyCapped := Map()  ; slot -> true once the game won't take more copies
global strategyPlaceArgs := ""   ; Placement points and retry settings from StartPlacingUnits

global StrategyTypes := ["None", "Farm", "DPS", "Support", "Buff", "Summon"]
global StrategyLaterOrder := ["DPS", "Summon", "Buff", "Support", "None"] ; Steps 9 and 10

RunTypeStrategy(placementPoints, untilSuccessful, maxAttemptsPerSpot, maxFailedSpots) {
    global placedCounts, strategyCapped, strategyPlaceArgs, StrategyLaterOrder
    strategyCapped := Map()
    strategyPlaceArgs := { points: placementPoints, untilSuccessful: untilSuccessful
        , maxAttempts: maxAttemptsPerSpot, maxFailed: maxFailedSpots }
    loop 6
        placedCounts[A_Index] := 0

    if !UnitManagerUpgradeSystem.Value {
        AddToLog("Unit-type strategy needs the Unit Overview - turning it on")
        UnitManagerUpgradeSystem.Value := 1
    }
    AddToLog("Using the unit-type strategy")
    ClickVoteStartIfShown()

    farms := SlotsOfType("Farm")
    supports := SlotsOfType("Support")
    dps := SlotsOfType("DPS")
    topDps := dps.Length ? dps[1] : 0

    ; 1. Top farm
    if farms.Length {
        StrategyStep(1, "placing the top farm unit")
        if !StrategyPlace(farms[1], ModeDropdown.Text = "Story" ? 1 : 3)
            return
    }

    ; 2. Top DPS, first copy to level 2
    if topDps {
        StrategyStep(2, "placing the top DPS and upgrading it to level 2")
        if !StrategyPlace(topDps, 1) || !UpgradeCopiesTo(FirstCopies(topDps, 1), 2)
            return
    }

    ; 3. Every farm copy, then every farm to level 2
    if farms.Length {
        StrategyStep(3, "placing all farm units and upgrading them to level 2")
        for slot in farms {
            if !StrategyPlace(slot, SlotPlacements(slot))
                return
        }
        if !UpgradeCopiesTo(CopiesOfSlots(farms), 2)
            return
    }

    ; 4. Second copy of the top DPS to level 2
    if topDps {
        StrategyStep(4, "placing a 2nd copy of the top DPS and upgrading it to level 2")
        if !StrategyPlace(topDps, 2)
            return
        copies := CopiesOfSlots([topDps])
        if (copies.Length >= 2 && !UpgradeCopiesTo([copies[2]], 2))
            return
    }

    ; 5. Top support to level 2
    if supports.Length {
        StrategyStep(5, "placing the top support and upgrading it to level 2")
        if !StrategyPlace(supports[1], 1) || !UpgradeCopiesTo(FirstCopies(supports[1], 1), 2)
            return
    }

    ; 6. First copy of the top DPS to level 3
    if topDps {
        StrategyStep(6, "upgrading the first top DPS to level 3")
        if !UpgradeCopiesTo(FirstCopies(topDps, 1), 3)
            return
    }

    ; 6b. Every remaining unit goes down before the farms are maxed, spending spare money on upgrades
    ; after each placement (and every 3 failed tries) so none is left sitting unused
    later := []
    for type in StrategyLaterOrder {
        for slot in SlotsOfType(type)
            later.Push(slot)
    }
    StrategyStep("6b", "placing all remaining units, spending spare money on upgrades")
    for slot in later {
        while (placedCounts[slot] < SlotPlacements(slot) && !strategyCapped.Has(slot)) {
            before := placedCounts[slot]
            if !StrategyPlace(slot, before + 1, true) ; true = spend money every 3 failed tries
                return
            if (placedCounts[slot] > before && !StrategySpendMoney())
                return
        }
    }

    ; 7. Every farm to MAX, evenly
    if farms.Length {
        StrategyStep(7, "upgrading all farm units to MAX")
        if !UpgradeCopiesTo(CopiesOfSlots(farms), "MAX")
            return
    }

    ; 8. Every copy of the top DPS to level 4
    if topDps {
        StrategyStep(8, "upgrading the top DPS to level 4")
        if !UpgradeCopiesTo(CopiesOfSlots([topDps]), 4)
            return
    }

    ; 9. Anything step 6b couldn't place, one upgrade after each placement. From here on farms count too -
    ; a recount of the Unit Overview can find any unit missing
    everyone := later.Clone()
    for slot in farms
        everyone.Push(slot)
    if !StrategyPlaceMissing(everyone)
        return

    ; 10. Upgrade whatever can be afforded, in priority order: each pass goes down the step 9 order and
    ; gives every unit up to 2 upgrades it can pay for right now. A unit that's too expensive is skipped
    ; for this pass instead of waited on, so cheaper units further down still get upgraded
    StrategyStep(10, "upgrading every unit to MAX or its limit, whatever is affordable in priority order")
    loggedWait := false
    loop {
        if !StrategyPlaceMissing(everyone)
            return
        anyLeft := false, anyUpgraded := false
        for coord in CopiesOfSlots(everyone) {
            loop 2 {
                result := UpgradeOnce(coord, "MAX", false)
                if (result = "ended")
                    return
                if (result != "upgraded")
                    break ; Done, or can't afford it yet - move on to the next unit
                anyUpgraded := true
            }
            if !IsStrategyDone(coord)
                anyLeft := true
        }
        if !anyLeft
            break
        if anyUpgraded {
            loggedWait := false
            continue
        }
        ; Nothing was affordable this pass - wait a moment for money, then go down the list again
        if !loggedWait {
            AddToLog("Waiting for money - nothing affordable right now")
            loggedWait := true
        }
        if CheckStageInterruptionsEvery()
            return
        Sleep(1000)
    }
    AddToLog("Unit-type strategy finished - every unit is maxed or at its limit")
}

; Places every copy of `slots` that's still missing, upgrading each new one once and spending spare
; money after it. Returns false once the stage has ended
StrategyPlaceMissing(slots) {
    global placedCounts, strategyCapped
    announced := false
    for slot in slots {
        while (placedCounts[slot] < SlotPlacements(slot) && !strategyCapped.Has(slot)) {
            if !announced {
                StrategyStep(9, "placing the units still missing")
                announced := true
            }
            before := placedCounts[slot]
            if !StrategyPlace(slot, before + 1, true)
                return false
            if (placedCounts[slot] > before) {
                copies := CopiesOfSlots([slot])
                if (UpgradeOnce(copies[copies.Length]) = "ended")
                    return false
                if !StrategySpendMoney()
                    return false
            }
        }
    }
    return true
}

StrategyStep(number, text) {
    AddToLog("Strategy step " number ": " text)
}

; Places copies of `slot` until it has `count` (never more than its Placements setting). With
; `upgradeWhileWaiting`, every 5 failed tries all placed units get one upgrade each if affordable.
; Returns false once the stage has ended
StrategyPlace(slot, count, upgradeWhileWaiting := false) {
    global placedCounts, strategyCapped, strategyPlaceArgs, stageEnded
    a := strategyPlaceArgs
    count := Min(count, SlotPlacements(slot))

    ; PlaceOneUnit already cycles through the spots for a while before giving up - give it a couple
    ; more goes, so a long wait for money isn't mistaken for the game's placement cap
    passes := 3
    while (placedCounts[slot] < count && !strategyCapped.Has(slot)) {
        if CheckStageInterruptions()
            return false
        result := "gaveup"
        loop passes {
            result := PlaceOneUnit(slot, a.points, a.untilSuccessful, a.maxAttempts, a.maxFailed
                , upgradeWhileWaiting ? StrategySpendMoney : "")
            if (result != "gaveup" || stageEnded)
                break
            Sleep(2000)
        }
        if (result = "ended" || stageEnded)
            return false
        if (result = "gaveup") {
            AddToLog("Unit " slot " couldn't be placed (" placedCounts[slot] "/" count "), max placement likely reached - skipping its remaining copies")
            strategyCapped[slot] := true
        }
    }
    return true
}

; Spends the money on hand: goes down the step 9/10 order (farms last) upgrading every unit it can
; afford, and repeats until a whole pass upgrades nothing (nothing affordable, or everything maxed).
; Nobody waits for money. Returns false if the stage ended
StrategySpendMoney() {
    global StrategyLaterOrder, stageEnded
    order := []
    for type in StrategyLaterOrder {
        for slot in SlotsOfType(type)
            order.Push(slot)
    }
    for slot in SlotsOfType("Farm")
        order.Push(slot)

    total := 0
    loop {
        upgraded := 0
        for coord in CopiesOfSlots(order) {
            result := UpgradeOnce(coord, "MAX", false)
            if (result = "ended" || stageEnded)
                return false
            if (result = "upgraded")
                upgraded += 1
        }
        total += upgraded
    } until (upgraded = 0)
    if (total > 0)
        AddToLog("Spent spare money - " total " upgrade" (total = 1 ? "" : "s"))
    return true
}

; Upgrades every coord in `copies` to `target` (a level or "MAX"), one level per unit per round so the
; upgrades are spread evenly. Returns false once the stage has ended
UpgradeCopiesTo(copies, target) {
    reached := Map()
    while (reached.Count < copies.Length) {
        for coord in copies {
            if reached.Has(coord)
                continue
            result := UpgradeOnce(coord, target)
            if (result = "ended")
                return false
            if (result = "done")
                reached[coord] := true
        }
    }
    return true
}

; One upgrade for `coord`. Returns "upgraded", "done" (already at `target`, maxed or at its Upgrade
; Limit), "ended" (stage over) or - only with wait = false - "unaffordable" instead of waiting for money
UpgradeOnce(coord, target := "MAX", wait := true) {
    global stageEnded
    if IsStrategyDone(coord)
        return "done"

    ; Stop at whichever comes first: this step's target or the unit's Upgrade Limit
    stopAt := (target = "MAX") ? 99 : target
    fromLimit := false
    if IsLimitActive(coord.slot) {
        limit := GetUpgradeLimit(coord.slot)
        if (limit <= stopAt)
            stopAt := limit, fromLimit := true
    }

    loggedWait := false, misses := 0
    loop {
        if CheckStageInterruptionsEvery()
            return "ended"

        result := UpgradeViaOverview(coord, stopAt, true)
        switch result {
            case "upgraded":
                return "upgraded"
            case "max":
                coord.strategyDone := true
                AddToLog("Unit " coord.slot " is maxed")
                return "done"
            case "limit":
                if fromLimit {
                    coord.strategyDone := true
                    AddToLog("Upgrade limit reached for Unit " coord.slot)
                }
                return "done"
            case "unaffordable":
                if !wait
                    return "unaffordable"
                if !loggedWait {
                    AddToLog("Waiting for money to upgrade Unit " coord.slot)
                    loggedWait := true
                }
                PostUpgradeChecks(coord)
                if stageEnded
                    return "ended"
                Sleep(1000)
            default: ; "missing" - card not found or level unreadable
                misses += 1
                ; Each miss already includes a full retry from the bottom of the list, so 2 is plenty
                if (misses >= 2) {
                    ; Give up on it for this match after 3 skips, so it doesn't hold up every round
                    coord.strategySkips := (coord.HasOwnProp("strategySkips") ? coord.strategySkips : 0) + 1
                    if (coord.strategySkips >= 3) {
                        coord.strategyDone := true, coord.skippedOut := true ; A recount gives it another chance
                        AddToLog("Couldn't read Unit " coord.slot " in the Unit Overview 3 times - leaving it as it is")
                    } else {
                        AddToLog("Couldn't find Unit " coord.slot " in the Unit Overview - skipping it for now")
                    }
                    return "done"
                }
                if stageEnded
                    return "ended"
                Sleep(500)
        }
    }
}

IsStrategyDone(coord) {
    return coord.HasOwnProp("strategyDone") && coord.strategyDone
}

UnitTypeOf(slot) {
    ctrl := "unitType" slot
    return %ctrl%.Text
}

; Enabled slots of a type with at least one placement, highest priority (lowest number) first
SlotsOfType(type) {
    slots := []
    loop 6 {
        enabled := "enabled" A_Index
        if (%enabled%.Value && SlotPlacements(A_Index) > 0 && UnitTypeOf(A_Index) = type)
            slots.Push(A_Index)
    }
    loop slots.Length {
        loop slots.Length - 1 {
            if (SlotPriority(slots[A_Index]) > SlotPriority(slots[A_Index + 1])) {
                temp := slots[A_Index]
                slots[A_Index] := slots[A_Index + 1]
                slots[A_Index + 1] := temp
            }
        }
    }
    return slots
}

SlotPriority(slot) {
    ctrl := "priority" slot
    return %ctrl%.Value
}

; Placed copies of the given slots, in slot order then placement order
CopiesOfSlots(slots) {
    global successfulCoordinates, maxedCoordinates
    copies := []
    for slot in slots {
        for list in [successfulCoordinates, maxedCoordinates] {
            for coord in list {
                if (coord.slot = slot)
                    copies.Push(coord)
            }
        }
    }
    ; Placement order within each slot (stable bubble sort keeps the slot grouping)
    loop copies.Length {
        loop copies.Length - 1 {
            a := copies[A_Index], b := copies[A_Index + 1]
            if (a.slot = b.slot && a.placementIndex > b.placementIndex) {
                copies[A_Index] := b
                copies[A_Index + 1] := a
            }
        }
    }
    return copies
}

FirstCopies(slot, count) {
    copies := CopiesOfSlots([slot])
    while (copies.Length > count)
        copies.Pop()
    return copies
}
