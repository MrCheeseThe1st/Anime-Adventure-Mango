#Requires AutoHotkey v2.0

StartCoordinateCapture(*) {
    global savedCoords, waitingForClick, activeHotkeys

    ; Make sure savedCoords exists
    if !IsSet(savedCoords) || !(savedCoords is Map)
        savedCoords := Map()

    mapName := GetPlacementsForMode(ModeDropdown.Text)
    if mapName != ""
        savedCoords[mapName] := []

    waitingForClick := true
    activeHotkeys := []  ; clear previous session

    ; Activate Roblox window
    if (!WinActivate(rblxID)) {
        WinActivate(rblxID)
    }

    AddToLog("📍 Coordinate capture started. Left-click to record, press LShift to stop.")
    SetTimer(UpdateTooltip, 50)

    ; --- Register temporary hotkeys dynamically ---
    activeHotkeys.Push(Hotkey("~LButton", HandleCoordinateClick))
    activeHotkeys.Push(Hotkey("~LShift", StopCoordinateCapture))
}

UseCustomPoints() {
    global savedCoords  ; Access the global saved coordinates
    points := []

    mapName := GetPlacementsForMode(ModeDropdown.Text)

    if (AlwaysUseCustomCheck.Value) {
        mapName := "Custom"
    }

    if (!savedCoords.Has(mapName) || savedCoords[mapName].Length = 0) {
        return
    }

    ; Use saved coordinates for the selected preset
    for coord in savedCoords[mapName] {
        points.Push({ x: coord.x, y: coord.y })
    }

    AddToLog("Points: " points.Length)

    return points
}

GetOrInitCustomCoords(mapName) {
    global savedCoords
    if !savedCoords.Has(mapName)
        savedCoords[mapName] := []
    return savedCoords[mapName]
}

SaveCustomPlacements() {
    global savedCoords

    filePath := A_ScriptDir "\Settings\CustomPlacements.txt"

    file := FileOpen(filePath, "w")  ; 'w' = write mode (clears file)
    if !IsObject(file) {
        AddToLog("❌ Failed to open file for writing: " filePath)
        return
    }

    for mapName, coords in savedCoords {
        for _, point in coords {
            line := mapName "," point.x "," point.y "`n"
            file.Write(line)
        }
    }

    file.Close()
}

LoadCustomPlacements() {
    global savedCoords
    savedCoords := Map()  ; clear before loading

    filePath := A_ScriptDir "\Settings\CustomPlacements.txt"

    if !FileExist(filePath) {
        AddToLog("❌ Save file not found: " filePath)
        return
    }

    file := FileOpen(filePath, "r")
    if !IsObject(file) {
        AddToLog("❌ Failed to open file: " filePath)
        return
    }

    merged := 0
    while !file.AtEOF {
        line := file.ReadLine()
        if (line = "")  ; skip blank lines
            continue

        parts := StrSplit(line, ",")
        if (parts.Length < 3)
            continue

        mapName := parts[1]
        x := parts[2] + 0
        y := parts[3] + 0

        if !savedCoords.Has(mapName)
            savedCoords[mapName] := []

        if SpotTooClose(savedCoords[mapName], x, y) {
            merged += 1
            continue
        }
        savedCoords[mapName].Push({ x: x, y: y, mapName: mapName })
    }
    file.Close()

    ; Spots closer than 15px to an earlier one were dropped - save the cleaned-up list
    if (merged > 0) {
        SaveCustomPlacements()
        AddToLog("Removed " merged " saved spots that were within " SpotMinDistance() " px of another")
    }
}

PrintSavedCoords() {
    global savedCoords
    for mapName, coords in savedCoords {
        AddToLog("Map: " mapName " has " coords.Length " coordinates saved.")
    }
}

DeleteCustomCoordsForPreset(mapName) {
    global savedCoords

    if !(savedCoords is Map)
        savedCoords := Map()

    ; If the map exists and has coords, remove it
    if savedCoords.Has(mapName) && savedCoords[mapName].Length > 0 {
        savedCoords.Delete(mapName)
        AddToLog("🗑️ Removed all custom placements for map: " mapName)
        SaveCustomPlacements()
    } else {
        AddToLog("⚠️ No custom placements to remove for map: " mapName)
    }
    UpdatePlacementListView()
}

GetPlacementsForMode(mode) {
    switch mode {
        case "Story":
            return currentMap != "" ? currentMap : StoryDropdown.Text
        case "Legend Stages":
            return currentMap != "" ? currentMap : LegendDropDown.Text
        case "Raid":
            return currentMap != "" ? currentMap : RaidDropdown.Text
        case "Portal":
            return currentMap != "" ? currentMap : PortalDropdown.Text
        case "Event":
            return currentMap != "" ? currentMap : EventDropdown.Text
        case "Infinity Castle", "Contracts":
            return currentMap != "" ? currentMap : CustomPlacementMapDropdown.Text
        case "Custom":
            return CustomPlacementMapDropdown.Text
    }
    return CustomPlacementMapDropdown.Text
}

ExportCustomCoords(mapName) {
    global savedCoords

    mapName := Trim(mapName)
    if mapName = "" || !savedCoords.Has(mapName) || savedCoords[mapName].Length = 0 {
        AddToLog("⚠️ No coordinates found for map: " mapName)
        return
    }

    exportDir := A_ScriptDir "\Settings\Export"
    exportFile := exportDir "\" mapName " Coords.txt"

    file := FileOpen(exportFile, "w")
    if !IsObject(file) {
        AddToLog("❌ Failed to export file for map: " mapName)
        return
    }

    for _, point in savedCoords[mapName] {
        line := mapName "," point.x "," point.y "`n"
        file.Write(line)
    }

    file.Close()
    AddToLog("📤 Exported " savedCoords[mapName].Length " coords to → Settings\Export\" mapName " Coords.txt")
}

ImportCustomCoords() {
    global savedCoords, MainUI

    ; Ensure savedCoords is initialized
    if !IsSet(savedCoords) || !(savedCoords is Map)
        savedCoords := Map()

    ; Temporarily disable AlwaysOnTop for file dialog
    MainUI.Opt("-AlwaysOnTop")
    Sleep(100)

    file := FileSelect("", A_ScriptDir "\Settings", "Select a placement file to import", "Text Files (*.txt)")
    MainUI.Opt("+AlwaysOnTop")

    if !file
        return

    content := FileRead(file)
    lines := StrSplit(content, "`n")

    importedMap := ""
    coordList := []

    for line in lines {
        line := Trim(line)
        if (line = "")
            continue

        parts := StrSplit(line, ",")
        if parts.Length < 3
            continue

        mapName := Trim(parts[1])
        x := parts[2] + 0
        y := parts[3] + 0

        if importedMap = ""
            importedMap := mapName  ; Use map from first line

        coordList.Push({ x: x, y: y, mapName: mapName })
    }

    if coordList.Length = 0 {
        AddToLog("⚠️ No valid coordinates found in the file.")
        return
    }

    savedCoords[importedMap] := coordList
    AddToLog("📥 Imported " coordList.Length " placements for map: " importedMap)

    ; Optional: Save after importing
    SaveCustomPlacements()
}

UpdatePlacementListView(*) {
    global savedCoords, CustomPlacementMapDropdown, PlacementListView

    PlacementListView.Delete()

    profileName := CustomPlacementMapDropdown.Text
    if !savedCoords.Has(profileName) || savedCoords[profileName].Length = 0
        return

    for i, entry in savedCoords[profileName]
        PlacementListView.Add(, i, entry.x, entry.y)

    loop 3
        PlacementListView.ModifyCol(A_Index, "AutoHdr")

    UpdatePlacementStatus()
}

UpdatePlacementStatus() {
    global savedCoords, CustomPlacementMapDropdown, PlacementStatusText
    profileName := CustomPlacementMapDropdown.Text
    count := savedCoords.Has(profileName) ? savedCoords[profileName].Length : 0
    PlacementStatusText.Value := count (count = 1 ? " placement" : " placements")
}

RemoveSelectedPlacement(*) {
    global savedCoords, CustomPlacementMapDropdown, PlacementListView

    row := PlacementListView.GetNext()
    if !row
        return

    profileName := CustomPlacementMapDropdown.Text
    if !savedCoords.Has(profileName) || row > savedCoords[profileName].Length
        return

    savedCoords[profileName].RemoveAt(row)

    SavePlacementProfiles()
    UpdatePlacementListView()
    AddToLog("Removed placement #" row " from " profileName)
}

EditSelectedPlacement(*) {
    global savedCoords, CustomPlacementMapDropdown, PlacementListView

    row := PlacementListView.GetNext()
    if !row
        return

    profileName := CustomPlacementMapDropdown.Text
    if !savedCoords.Has(profileName) || row > savedCoords[profileName].Length
        return

    entry := savedCoords[profileName][row]

    editGui := Gui("+AlwaysOnTop -MinimizeBox", "Edit Placement #" row)
    editGui.SetFont("s10")

    editGui.Add("Text", "x20 y20", "X:")
    xEdit := editGui.Add("Edit", "x60 y18 w100", entry.x)

    editGui.Add("Text", "x20 y55", "Y:")
    yEdit := editGui.Add("Edit", "x60 y53 w100", entry.y)

    saveBtn := editGui.Add("Button", "x30 y100 w80", "Save")
    cancelBtn := editGui.Add("Button", "x130 y100 w80", "Cancel")

    saveBtn.OnEvent("Click", (*) => SaveEditedPlacement())
    cancelBtn.OnEvent("Click", (*) => editGui.Destroy())
    editGui.OnEvent("Close", (*) => editGui.Destroy())

    editGui.Show("w240 h150")

    SaveEditedPlacement() {
        if (xEdit.Value = "" || yEdit.Value = "") {
            MsgBox("X and Y must both have a value.")
            return
        }

        savedCoords[profileName][row].x := Integer(xEdit.Value)
        savedCoords[profileName][row].y := Integer(yEdit.Value)

        SavePlacementProfiles()
        UpdatePlacementListView()
        editGui.Destroy()
        AddToLog("Updated placement #" row " on profile: " profileName)
    }
}

ShowPlacementDots(profileName := "", duration := 5000, winTitle := "ahk_exe RobloxPlayerBeta.exe") {
    global savedCoords, CustomPlacementMapDropdown

    if !WinExist(winTitle) {
        return
    }

    if (profileName = "")
        profileName := CustomPlacementMapDropdown.Text

    if !savedCoords.Has(profileName) || savedCoords[profileName].Length = 0 {
        AddToLog("No placements saved for: " profileName)
        return
    }

    AddToLog("Showing placements for: " profileName)

    ; Client area's top-left screen position (same approach as ShowOCRRegions).
    WinGetClientPos(&offX, &offY, , , winTitle)

    allGuis := []
    size := 14   ; dot diameter in pixels

    for entry in savedCoords[profileName] {
        ; Convert client-relative coords to screen coords, centered on the point.
        x := entry.x + offX - size // 2
        y := entry.y + offY - size // 2

        g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
        g.BackColor := "Red"
        g.Show("x" x " y" y " w" size " h" size " NoActivate")
        WinSetRegion("0-0 W" size " H" size " E", "ahk_id " g.Hwnd)   ; make it round
        allGuis.Push(g)
    }

    Cleanup(*) {
        for g in allGuis
            g.Destroy()
    }

    SetTimer(Cleanup, -duration)
}

; Add: click spots in the Roblox window to save them to the map selected in the dropdown, one after
; another, until Escape is pressed. The clicks themselves don't reach the game
AddManualPlacement(*) {
    global CustomPlacementMapDropdown
    static active := false

    profileName := CustomPlacementMapDropdown.Text
    if (profileName = "") {
        AddToLog("Select or create a profile first.")
        return
    }
    if active
        return
    if !WinExist(rblxID) {
        AddToLog("Roblox window not found.")
        return
    }

    active := true
    WinActivate(rblxID)
    added := 0
    AddToLog("📍 Click each spot for " profileName " - press Esc when done")
    SetTimer(FollowTip, 50)
    Hotkey("*LButton", OnClick, "On")
    Hotkey("*Esc", OnCancel, "On")

    FollowTip() {
        CoordMode("Mouse", "Screen")
        MouseGetPos(&mx, &my)
        CoordMode("Mouse", "Client")
        CoordMode("ToolTip", "Screen")
        ToolTip("Click to add spots to " profileName " (" added " added)`nEsc when done", mx + 15, my + 15)
        CoordMode("ToolTip", "Client")
    }

    OnClick(*) {
        ; Position relative to the Roblox client area - the same coordinates placement clicks use
        CoordMode("Mouse", "Screen")
        MouseGetPos(&mx, &my)
        CoordMode("Mouse", "Client")
        WinGetClientPos(&cx, &cy, &cw, &ch, rblxID)
        x := mx - cx, y := my - cy
        if (x < 0 || y < 0 || x >= cw || y >= ch) {
            AddToLog("⚠️ That's outside the Roblox window - click inside the game")
            return
        }
        if AddPlacementSpot(profileName, x, y)
            added += 1
    }

    OnCancel(*) {
        Finish()
        AddToLog("Done adding spots - " added " added to " profileName)
    }

    Finish() {
        Hotkey("*LButton", "Off")
        Hotkey("*Esc", "Off")
        SetTimer(FollowTip, 0)
        ToolTip()
        active := false
    }
}

; Returns false (and saves nothing) if the click is within 15px of a spot already saved for this map
AddPlacementSpot(profileName, x, y) {
    global savedCoords
    if !savedCoords.Has(profileName)
        savedCoords[profileName] := []
    if SpotTooClose(savedCoords[profileName], x, y) {
        AddToLog("Too close to a saved spot (within " SpotMinDistance() " px) - ignored")
        return false
    }
    savedCoords[profileName].Push({ x: x, y: y })

    SaveCustomPlacements()
    UpdatePlacementListView()
    AddToLog("Added placement (" x ", " y ") to " profileName " - " savedCoords[profileName].Length " spots")
    return true
}

; Saved spots closer than this (px) count as the same spot. A function rather than a global variable:
; saved spots are loaded while the GUI is built, before this file's top-level code has run
SpotMinDistance() => 15

SpotTooClose(coords, x, y) {
    minDist := SpotMinDistance()
    for c in coords {
        if ((c.x - x) ** 2 + (c.y - y) ** 2 < minDist ** 2)
            return true
    }
    return false
}
