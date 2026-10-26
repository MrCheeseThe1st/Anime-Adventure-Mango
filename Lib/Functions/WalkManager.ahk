#Requires AutoHotkey v2.0

global movementKeys := ["w", "a", "s", "d"]
global activeHotkeys := []
global firstKeyPressed := false
global walkRecordStart := 0 ; When the current recording started - each key also stores its press time

Walk(direction, duration) {
    key := "{" . direction . " down}"
    SendInput(key)
    Sleep(duration)
    key := "{" . direction . " up}"
    SendInput(key)
    KeyWait direction
    Sleep(1000)  ; Optional pause after each movement
}

GetMapForMode(mode) {
    switch mode {
        case "Story":
            return currentMap != "" ? currentMap : StoryDropdown.Text
        case "Legend Stages":
            return currentMap != "" ? currentMap : LegendDropDown.Text
        case "Infinity Castle":
            return currentMap != "" ? currentMap : ""
        case "Raid":
            return currentMap != "" ? currentMap : RaidDropdown.Text
        case "Portal":
            return currentMap != "" ? currentMap : PortalDropdown.Text
        case "Event":
            return currentMap != "" ? currentMap : EventDropdown.Text
        case "Custom":
            return WalkMapDropdown.Text
    }
    return WalkMapDropdown.Text
}

; === Start of new walk functions ===

StartRecordingWalk(*) {
    global recording, allWalks, keyDownTimes, lastActionTime, activeHotkeys, movementKeys, firstKeyPressed

    mapName := WalkMapDropdown.Text

    if !allWalks.Has(mapName)
        allWalks[mapName] := []
    allWalks[mapName] := [] ; clear old recording
    recording := true
    keyDownTimes := Map()
    lastActionTime := A_TickCount
    global walkRecordStart := A_TickCount
    firstKeyPressed := false
    AddToLog("Starting map movement recording for: " mapName)
    AddToLog("Press LShift to stop recording")

    for key in movementKeys {
        downHK := Hotkey("~*" key, RecordKeyDown.Bind(key))
        upHK := Hotkey("~*" key " up", RecordKeyUp.Bind(key))
        activeHotkeys.Push(downHK)
        activeHotkeys.Push(upHK)
    }

    activeHotkeys.Push(Hotkey("~LShift", StopRecordingWalk))

    if (!WinActive(rblxID)) {
        WinActivate(rblxID)
    }
}

StopRecordingWalk(*) {
    global recording, activeHotkeys

    if !recording
        return

    recording := false
    AddToLog("Movement recording stopped, saving...")

    for hk in activeHotkeys {
        try hk.Delete
    }
    activeHotkeys := []  ; clear list
    SaveAllMovements()
    UpdateWalkListView()
}

RecordKeyDown(key, *) {
    global recording, keyDownTimes
    if !recording
        return
    if !keyDownTimes.Has(key)
        keyDownTimes[key] := A_TickCount
}

RecordKeyUp(key, *) {
    global recording, allWalks, keyDownTimes, lastActionTime, firstKeyPressed
    if !recording || !keyDownTimes.Has(key)
        return

    currentMap := WalkMapDropdown.Text
    now := A_TickCount
    pressStart := keyDownTimes[key]
    duration := now - pressStart

    if !firstKeyPressed {
        delay := 0
        firstKeyPressed := true
    } else {
        delay := pressStart - lastActionTime
    }

    lastActionTime := now
    keyDownTimes.Delete(key)
    ; `start` = when the key went down, from the start of the recording - lets keys held together
    ; (W+A) be played back together
    entry := { key: key, duration: duration, delay: delay, start: pressStart - walkRecordStart }
    allWalks[currentMap].Push(entry)
    AddToLog("Registered Key: " key " (" duration " ms, +" delay " ms delay)")
}

StartWalk(testing := false) {
    global allWalks

    currentMap := testing ? WalkMapDropdown.Text : GetMapForMode(ModeDropdown.Text)

    if !allWalks.Has(currentMap) || allWalks[currentMap].Length = 0 {
        if (debugMessages) {
            AddToLog("No recording for profile: " currentMap)
        }
        return false
    }

    if (!WinActive(rblxID)) {
        WinActivate(rblxID)
    }

    events := WalkEvents(allWalks[currentMap])
    AddToLog("[Walking] Playing " allWalks[currentMap].Length " recorded keys for " currentMap)

    ; Press and release every key at its recorded time, so keys held together overlap again.
    ; (No logging in here - AddToLog pauses briefly and would throw the timing off)
    start := A_TickCount
    for ev in events {
        wait := ev.t - (A_TickCount - start)
        if (wait > 0)
            Sleep(wait)
        Send("{" ev.key (ev.down ? " down" : " up") "}")
    }
    for ev in events
        KeyWait(ev.key)
    return true
}

; Turns a recording into press/release events in time order. Recordings with press times play keys
; exactly as recorded; older ones (and edited ones) play one key at a time with their delays
WalkEvents(data) {
    timeline := true
    for entry in data {
        if !(entry.HasOwnProp("start") && IsInteger(entry.start)) {
            timeline := false
            break
        }
    }

    events := []
    t := 0
    for entry in data {
        duration := Max(0, Integer(entry.duration))
        if timeline {
            t := Max(0, Integer(entry.start))
        } else {
            t += Max(0, Integer(entry.delay))
        }
        events.Push({ t: t, key: entry.key, down: true })
        events.Push({ t: t + duration, key: entry.key, down: false })
        if !timeline
            t += duration
    }

    ; Sort by time; at the same moment, release before pressing
    loop events.Length {
        loop events.Length - 1 {
            a := events[A_Index], b := events[A_Index + 1]
            if (a.t > b.t || (a.t = b.t && a.down && !b.down)) {
                events[A_Index] := b
                events[A_Index + 1] := a
            }
        }
    }
    return events
}

SaveAllMovements(*) {
    global allWalks
    try {
        folder := A_ScriptDir "\Settings"
        if !DirExist(folder)
            DirCreate(folder)

        file := FileOpen(folder "\CustomMovements.txt", "w", "UTF-8")
        for mapName, actions in allWalks {
            for entry in actions {
                line := Format("{},{},{},{}{}`n", mapName, entry.key, entry.duration, entry.delay, WalkStartField(entry))
                file.Write(line)
            }
        }
        file.Close()
    } catch Error {
        AddToLog("Error saving custom movements: " Error)
    }
}

LoadAllMovements(*) {
    global allWalks
    if !FileExist(A_ScriptDir "\Settings\CustomMovements.txt") {
        FileAppend("", A_ScriptDir "\Settings\CustomMovements.txt")
        return
    }

    allWalks := Map()
    for line in StrSplit(FileRead(A_ScriptDir "\Settings\CustomMovements.txt", "UTF-8"), "`n") {
        if (Trim(line) = "")
            continue
        parts := StrSplit(line, ",")
        if (parts.Length < 4)
            continue

        mapName := parts[1]
        key := parts[2]
        duration := parts[3]
        delay := parts[4]

        if !allWalks.Has(mapName)
            allWalks[mapName] := []

        allWalks[mapName].Push(WalkEntryFromParts(parts))
    }

    UpdateWalkListView()
}

ExportMovements(mapName := "") {
    global allWalks

    exportDir := A_ScriptDir "\Settings\Export"
    if !DirExist(exportDir)
        DirCreate(exportDir)

    ; Default: export all maps
    if (mapName = "") {
        filePath := exportDir "\Exported Movements - All.txt"
        AddToLog("Exporting all maps to " filePath)
        entries := allWalks
    } else if !allWalks.Has(mapName) {
        AddToLog("No recording found for map: " mapName)
        return
    } else {
        filePath := exportDir "\Exported Movements - " mapName ".txt"
        AddToLog("Exporting map '" mapName "' to " filePath)
        entries := Map()
        entries[mapName] := allWalks[mapName]
    }

    try {
        file := FileOpen(filePath, "w", "UTF-8")
        for mName, actions in entries {
            for entry in actions {
                line := Format("{},{},{},{}{}`n", mName, entry.key, entry.duration, entry.delay, WalkStartField(entry))
                file.Write(line)
            }
        }
        file.Close()
        AddToLog("✅ Export successful.")
    } catch Error {
        AddToLog("❌ Export failed: " Error)
    }
}

ImportMovements(*) {
    global allWalks

    ; Ensure allWalks exists
    if !IsObject(allWalks)
        allWalks := Map()

    MainUI.Opt("-AlwaysOnTop")
    Sleep(100)

    ; Prompt user to select file
    filePath := FileSelect("", A_ScriptDir "\Settings", "Select a movement file to import", "Text Files (*.txt)")

    MainUI.Opt("+AlwaysOnTop")

    if filePath = ""
        return

    if !FileExist(filePath) {
        return
    }

    try {
        content := FileRead(filePath, "UTF-8")
        lines := StrSplit(content, "`n")
        importedCount := 0
        replacedMaps := Map()  ; keep track of which maps are replaced

        for line in lines {
            line := Trim(line, "`r`n ") ; remove CRLF and spaces
            if (line = "")
                continue

            parts := StrSplit(line, ",")
            if (parts.Length < 4) {
                AddToLog("⚠ Skipping malformed line: " line)
                continue
            }

            mapName := parts[1]
            key := parts[2]
            duration := parts[3]
            delay := parts[4]

            ; If this is the first time we see this map in this import, clear old data
            if !replacedMaps.Has(mapName) {
                allWalks[mapName] := []  ; replace existing map
                replacedMaps[mapName] := true
            }

            allWalks[mapName].Push(WalkEntryFromParts(parts))
            importedCount++
        }

        AddToLog("✅ Imported " importedCount " movement(s)")
        SaveAllMovements()
    } catch Error {
        AddToLog("❌ Import failed")
    }
}

ClearMovement(*) {
    global allWalks
    mapName := WalkMapDropdown.Text

    if !allWalks.Has(mapName) {
        AddToLog("No recording found for map: " mapName)
        return
    }

    AddToLog("Clearing movements for map: " mapName)
    allWalks.Delete(mapName)
    SaveAllMovements()
    UpdateWalkListView()
}

UpdateWalkListView(*) {
    global allWalks, WalkMapDropdown, WalkListView

    WalkListView.Delete()          ; clear current rows

    mapName := WalkMapDropdown.Text
    if !allWalks.Has(mapName) || allWalks[mapName].Length = 0
        return

    directionMap := Map(
        "w", "Forward",
        "a", "Left",
        "s", "Backward",
        "d", "Right"
    )

    for i, entry in allWalks[mapName] {
        dir := directionMap.Has(entry.key) ? directionMap[entry.key] : entry.key
        WalkListView.Add(, i, dir, entry.duration " ms", entry.delay " ms")
    }

    ; Auto-size columns
    loop 4
        WalkListView.ModifyCol(A_Index, "AutoHdr")
}

RemoveSelectedMovement(*) {
    global allWalks, WalkMapDropdown, WalkListView

    row := WalkListView.GetNext()          ; get selected row number
    if !row
        return

    mapName := WalkMapDropdown.Text
    if !allWalks.Has(mapName)
        return

    ; Remove the selected entry (ListView rows are 1-based, array is 1-based too)
    allWalks[mapName].RemoveAt(row)

    SaveAllMovements()
    UpdateWalkListView()                   ; refresh the list
    AddToLog("Removed movement #" row " from " mapName)
}

EditSelectedMovement(*) {
    global allWalks, WalkMapDropdown, WalkListView

    row := WalkListView.GetNext()
    if !row
        return

    mapName := WalkMapDropdown.Text
    if !allWalks.Has(mapName) || row > allWalks[mapName].Length
        return

    entry := allWalks[mapName][row]

    ; Create a small edit popup
    editGui := Gui("+AlwaysOnTop -MinimizeBox", "Edit Movement #" row)
    editGui.SetFont("s10")

    editGui.Add("Text", "x20 y20", "Direction:")
    dirDDL := editGui.Add("DropDownList", "x100 y18 w120", ["Forward", "Left", "Backward", "Right"])

    ; Set current direction
    directionMap := Map("w", "Forward", "a", "Left", "s", "Backward", "d", "Right")
    reverseMap := Map("Forward", "w", "Left", "a", "Backward", "s", "Right", "d")
    currentDir := directionMap.Has(entry.key) ? directionMap[entry.key] : "Forward"
    dirDDL.Choose(currentDir)

    editGui.Add("Text", "x20 y55", "Duration (ms):")
    durEdit := editGui.Add("Edit", "x120 y53 w100 Number", entry.duration)

    editGui.Add("Text", "x20 y90", "Delay (ms):")
    delayEdit := editGui.Add("Edit", "x120 y88 w100 Number", entry.delay)

    saveBtn := editGui.Add("Button", "x40 y130 w80", "Save")
    cancelBtn := editGui.Add("Button", "x140 y130 w80", "Cancel")

    saveBtn.OnEvent("Click", (*) => SaveEditedMovement())
    cancelBtn.OnEvent("Click", (*) => editGui.Destroy())
    editGui.OnEvent("Close", (*) => editGui.Destroy())

    editGui.Show("w260 h180")

    SaveEditedMovement() {
        newDir := dirDDL.Text
        newDur := Integer(durEdit.Value)
        newDelay := Integer(delayEdit.Value)

        if (newDur < 0 || newDelay < 0) {
            MsgBox("Duration and Delay must be 0 or higher.")
            return
        }

        ; Update the actual data
        allWalks[mapName][row].key := reverseMap[newDir]
        allWalks[mapName][row].duration := newDur
        allWalks[mapName][row].delay := newDelay

        ; Recorded press times no longer match after an edit, so this map now plays one key at a time
        for entry in allWalks[mapName]
            entry.start := ""

        SaveAllMovements()
        UpdateWalkListView()
        editGui.Destroy()
        AddToLog("Updated movement #" row " on map: " mapName)
    }
}

; ",<press time>" for recordings that have one, "" for older ones
WalkStartField(entry) {
    return (entry.HasOwnProp("start") && IsInteger(entry.start)) ? "," entry.start : ""
}

; A walk entry from a saved line split on commas: map,key,duration,delay[,press time]
WalkEntryFromParts(parts) {
    entry := { key: Trim(parts[2]), duration: Trim(parts[3]), delay: Trim(parts[4], " `r`n") }
    if (parts.Length >= 5 && IsInteger(Trim(parts[5], " `r`n")))
        entry.start := Integer(Trim(parts[5], " `r`n"))
    return entry
}
