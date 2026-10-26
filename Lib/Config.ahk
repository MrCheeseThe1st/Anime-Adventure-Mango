#Include %A_ScriptDir%\Lib\GUI.ahk

SaveSettingsForMode(toExport := false, sendMessage := true) {
    try {
        ; Determine mode name
        gameMode := (ModeConfigurations.Value ? ModeDropdown.Text : "Default")
        if !gameMode
            gameMode := "Default"

        safeMode := RegExReplace(gameMode, '[\\/:*?"<>|]', "_")

        if (toExport) {
            file := A_ScriptDir "\Settings\Export\" safeMode "_Configuration.json"
        } else {
            file := A_ScriptDir "\Settings\Modes\" safeMode "_Configuration.json"
        }

        ; Build JSON data map
        data := {
            Unit_Settings: {
                Slot_1_Enabled: Enabled1.Value, Slot_2_Enabled: Enabled2.Value, Slot_3_Enabled: Enabled3.Value,
                Slot_4_Enabled: Enabled4.Value, Slot_5_Enabled: Enabled5.Value, Slot_6_Enabled: Enabled6.Value,
                Slot_1_Placements: Placement1.Value, Slot_2_Placements: Placement2.Value, 
                Slot_3_Placements: Placement3.Value, Slot_4_Placements: Placement4.Value, 
                Slot_5_Placements: Placement5.Value, Slot_6_Placements: Placement6.Value,
                Slot_1_Priority: Priority1.Value, Slot_2_Priority: Priority2.Value, 
                Slot_3_Priority: Priority3.Value, Slot_4_Priority: Priority4.Value, 
                Slot_5_Priority: Priority5.Value, Slot_6_Priority: Priority6.Value,
                Slot_1_Upgrade_Priority: UpgradePriority1.Text, Slot_2_Upgrade_Priority: UpgradePriority2.Text,
                Slot_3_Upgrade_Priority: UpgradePriority3.Text, Slot_4_Upgrade_Priority: UpgradePriority4.Text, 
                Slot_5_Upgrade_Priority: UpgradePriority5.Text, Slot_6_Upgrade_Priority: UpgradePriority6.Text,
                Slot_1_Upgrade_Enabled: UpgradeEnabled1.Value, Slot_2_Upgrade_Enabled: UpgradeEnabled2.Value,
                Slot_3_Upgrade_Enabled: UpgradeEnabled3.Value, Slot_4_Upgrade_Enabled: UpgradeEnabled4.Value, 
                Slot_5_Upgrade_Enabled: UpgradeEnabled5.Value, Slot_6_Upgrade_Enabled: UpgradeEnabled6.Value,
                Slot_1_Ability_Enabled: AbilityEnabled1.Value, Slot_2_Ability_Enabled: AbilityEnabled2.Value,
                Slot_3_Ability_Enabled: AbilityEnabled3.Value, Slot_4_Ability_Enabled: AbilityEnabled4.Value, 
                Slot_5_Ability_Enabled: AbilityEnabled5.Value, Slot_6_Ability_Enabled: AbilityEnabled6.Value,
                Slot_1_Upgrade_Limit: UpgradeLimit1.Text, Slot_2_Upgrade_Limit: UpgradeLimit2.Text,
                Slot_3_Upgrade_Limit: UpgradeLimit3.Text, Slot_4_Upgrade_Limit: UpgradeLimit4.Text,
                Slot_5_Upgrade_Limit: UpgradeLimit5.Text, Slot_6_Upgrade_Limit: UpgradeLimit6.Text,
                Slot_1_Upgrade_Limit_Enabled: UpgradeLimitEnabled1.Value, Slot_2_Upgrade_Limit_Enabled: UpgradeLimitEnabled2.Value,
                Slot_3_Upgrade_Limit_Enabled: UpgradeLimitEnabled3.Value, Slot_4_Upgrade_Limit_Enabled: UpgradeLimitEnabled4.Value,
                Slot_5_Upgrade_Limit_Enabled: UpgradeLimitEnabled5.Value, Slot_6_Upgrade_Limit_Enabled: UpgradeLimitEnabled6.Value,
                Slot_1_Type: unitType1.Text, Slot_2_Type: unitType2.Text, Slot_3_Type: unitType3.Text,
                Slot_4_Type: unitType4.Text, Slot_5_Type: unitType5.Text, Slot_6_Type: unitType6.Text
            },
            Zoom_Settings: {
                Level: ZoomBox.Value,
                Enabled: ZoomTech.Value,
                Zoom_In: ZoomInOption.Value,
                Teleport: ZoomTeleport.Value
            },
            Upgrading: {
                Enabled: EnableUpgrading.Value,
                Use_Unit_Manager: UnitManagerUpgradeSystem.Value,
                Use_Unit_Priority: PriorityUpgrade.Value,
                Even_Upgrade: EvenUpgrade.Value
            },
            Custom_Recordings: {
                Use: ShouldUseRecording.Value,
                Setup: ShouldUseSetup.Value,
                Loop: ShouldLoopRecording.Value,
                HandleEnd: ShouldHandleGameEnd.Value
            },
            Custom_Placements: {
                Use: AlwaysUseCustomCheck.Value,
            },
            Debug : {
                Enabled: CheckNormalLoadingScreens.Value
            },
            Modes: {
                Portals: {

                },
                Events: {
                    Fools_Hunt: {
                        Bring_Own_Team: BringOwnTeam.Value,
                    }
                }
            },
            Failsafe_Settings: {
                Teleport_Failsafe: {
                    Enabled: TeleportFailsafe.Value,
                    Timer: TeleportFailsafeTimer.Value
                }
            },
            Update_Checker: {
                Enabled: UpdateChecker.Value
            }
        }

        ; Convert to JSON
        json := jsongo.Stringify(data, "", "    ")

        ; Save to file
        if FileExist(file)
            FileDelete(file)
        FileAppend(json, file, "UTF-8")

        if (toExport) {
            AddToLog("✅ Successfully exported settings for mode: " gameMode)
            return
        }

        if (sendMessage) {
            AddToLog("✅ Saved settings for mode: " gameMode)
        }

        ; Save related components
        SaveCustomPlacements()
        SaveAllMovements()
        SaveAllRecordings()
        SaveUniversalSettings()
        SaveAllCardConfigs()
    }
    catch {
        AddToLog("Error saving mode settings")
    }
}

LoadUnitSettingsByMode(fromFile := false) {

    mode := ModeDropdown.Text

    if !mode || !ModeConfigurations.Value
        mode := "Default"

    safeMode := RegExReplace(mode, '[\\/:*?"<>|]', "_")

    if (fromFile) {
        MainUI.Opt("-AlwaysOnTop")
        Sleep(100)

        file := FileSelect("", A_ScriptDir "\Settings", "Select a configuration file to import", "JSON Files (*.json)")

        MainUI.Opt("+AlwaysOnTop")

        if !file
            return
    } else {
        file := A_ScriptDir "\Settings\Modes\" safeMode "_Configuration.json"
    }

    if !FileExist(file) {
        AddToLog("⚠️ No configuration found for mode: " mode ", using default settings...")
        SaveSettingsForMode(false, false)
        file := A_ScriptDir "\Settings\Modes\" safeMode "_Configuration.json"
    }

    json := FileRead(file, "UTF-8")

    js := jsongo
    js.silent_error := true
    js.extract_objects := true

    data := js.Parse(json)

    if (data = "" || !IsObject(data)) {
        AddToLog("⚠️ Failed to parse JSON, using empty config.")
        data := {} ; fallback object
    }

    Enabled1.Value := GetValue(data, ["Unit_Settings", "Slot_1_Enabled"], 0)
    Enabled2.Value := GetValue(data, ["Unit_Settings", "Slot_2_Enabled"], 0)
    Enabled3.Value := GetValue(data, ["Unit_Settings", "Slot_3_Enabled"], 0)
    Enabled4.Value := GetValue(data, ["Unit_Settings", "Slot_4_Enabled"], 0)
    Enabled5.Value := GetValue(data, ["Unit_Settings", "Slot_5_Enabled"], 0)
    Enabled6.Value := GetValue(data, ["Unit_Settings", "Slot_6_Enabled"], 0)

    Placement1.Value := GetValue(data, ["Unit_Settings", "Slot_1_Placements"], 1)
    Placement2.Value := GetValue(data, ["Unit_Settings", "Slot_2_Placements"], 1)
    Placement3.Value := GetValue(data, ["Unit_Settings", "Slot_3_Placements"], 1)
    Placement4.Value := GetValue(data, ["Unit_Settings", "Slot_4_Placements"], 1)
    Placement5.Value := GetValue(data, ["Unit_Settings", "Slot_5_Placements"], 1)
    Placement6.Value := GetValue(data, ["Unit_Settings", "Slot_6_Placements"], 1)

    Priority1.Value := GetValue(data, ["Unit_Settings", "Slot_1_Priority"], 0)
    Priority2.Value := GetValue(data, ["Unit_Settings", "Slot_2_Priority"], 0)
    Priority3.Value := GetValue(data, ["Unit_Settings", "Slot_3_Priority"], 0)
    Priority4.Value := GetValue(data, ["Unit_Settings", "Slot_4_Priority"], 0)
    Priority5.Value := GetValue(data, ["Unit_Settings", "Slot_5_Priority"], 0)
    Priority6.Value := GetValue(data, ["Unit_Settings", "Slot_6_Priority"], 0)

    UpgradePriority1.Value := DropdownIndexFromText(UpgradePriority1, GetValue(data, ["Unit_Settings", "Slot_1_Upgrade_Priority"], "1"), 1)
    UpgradePriority2.Value := DropdownIndexFromText(UpgradePriority2, GetValue(data, ["Unit_Settings", "Slot_2_Upgrade_Priority"], "2"), 2)
    UpgradePriority3.Value := DropdownIndexFromText(UpgradePriority3, GetValue(data, ["Unit_Settings", "Slot_3_Upgrade_Priority"], "3"), 3)
    UpgradePriority4.Value := DropdownIndexFromText(UpgradePriority4, GetValue(data, ["Unit_Settings", "Slot_4_Upgrade_Priority"], "4"), 4)
    UpgradePriority5.Value := DropdownIndexFromText(UpgradePriority5, GetValue(data, ["Unit_Settings", "Slot_5_Upgrade_Priority"], "5"), 5)
    UpgradePriority6.Value := DropdownIndexFromText(UpgradePriority6, GetValue(data, ["Unit_Settings", "Slot_6_Upgrade_Priority"], "6"), 6)

    UpgradeEnabled1.Value := GetValue(data, ["Unit_Settings", "Slot_1_Upgrade_Enabled"], 0)
    UpgradeEnabled2.Value := GetValue(data, ["Unit_Settings", "Slot_2_Upgrade_Enabled"], 0)
    UpgradeEnabled3.Value := GetValue(data, ["Unit_Settings", "Slot_3_Upgrade_Enabled"], 0)
    UpgradeEnabled4.Value := GetValue(data, ["Unit_Settings", "Slot_4_Upgrade_Enabled"], 0)
    UpgradeEnabled5.Value := GetValue(data, ["Unit_Settings", "Slot_5_Upgrade_Enabled"], 0)
    UpgradeEnabled6.Value := GetValue(data, ["Unit_Settings", "Slot_6_Upgrade_Enabled"], 0)

    AbilityEnabled1.Value := GetValue(data, ["Unit_Settings", "Slot_1_Ability_Enabled"], 0)
    AbilityEnabled2.Value := GetValue(data, ["Unit_Settings", "Slot_2_Ability_Enabled"], 0)
    AbilityEnabled3.Value := GetValue(data, ["Unit_Settings", "Slot_3_Ability_Enabled"], 0)
    AbilityEnabled4.Value := GetValue(data, ["Unit_Settings", "Slot_4_Ability_Enabled"], 0)
    AbilityEnabled5.Value := GetValue(data, ["Unit_Settings", "Slot_5_Ability_Enabled"], 0)
    AbilityEnabled6.Value := GetValue(data, ["Unit_Settings", "Slot_6_Ability_Enabled"], 0)

    UpgradeLimit1.Value := DropdownIndexFromText(UpgradeLimit1, GetValue(data, ["Unit_Settings", "Slot_1_Upgrade_Limit"], "0"))
    UpgradeLimit2.Value := DropdownIndexFromText(UpgradeLimit2, GetValue(data, ["Unit_Settings", "Slot_2_Upgrade_Limit"], "0"))
    UpgradeLimit3.Value := DropdownIndexFromText(UpgradeLimit3, GetValue(data, ["Unit_Settings", "Slot_3_Upgrade_Limit"], "0"))
    UpgradeLimit4.Value := DropdownIndexFromText(UpgradeLimit4, GetValue(data, ["Unit_Settings", "Slot_4_Upgrade_Limit"], "0"))
    UpgradeLimit5.Value := DropdownIndexFromText(UpgradeLimit5, GetValue(data, ["Unit_Settings", "Slot_5_Upgrade_Limit"], "0"))
    UpgradeLimit6.Value := DropdownIndexFromText(UpgradeLimit6, GetValue(data, ["Unit_Settings", "Slot_6_Upgrade_Limit"], "0"))

    UpgradeLimitEnabled1.Value := GetValue(data, ["Unit_Settings", "Slot_1_Upgrade_Limit_Enabled"], 0)
    UpgradeLimitEnabled2.Value := GetValue(data, ["Unit_Settings", "Slot_2_Upgrade_Limit_Enabled"], 0)
    UpgradeLimitEnabled3.Value := GetValue(data, ["Unit_Settings", "Slot_3_Upgrade_Limit_Enabled"], 0)
    UpgradeLimitEnabled4.Value := GetValue(data, ["Unit_Settings", "Slot_4_Upgrade_Limit_Enabled"], 0)
    UpgradeLimitEnabled5.Value := GetValue(data, ["Unit_Settings", "Slot_5_Upgrade_Limit_Enabled"], 0)
    UpgradeLimitEnabled6.Value := GetValue(data, ["Unit_Settings", "Slot_6_Upgrade_Limit_Enabled"], 0)

    loop 6 {
        ctrl := "unitType" A_Index
        %ctrl%.Value := DropdownIndexFromText(%ctrl%, GetValue(data, ["Unit_Settings", "Slot_" A_Index "_Type"], "None"))
    }

    ZoomBox.Value := GetValue(data, ["Zoom_Settings", "Level"], 20)
    ZoomTech.Value := GetValue(data, ["Zoom_Settings", "Enabled"], 1)
    ZoomInOption.Value := GetValue(data, ["Zoom_Settings", "Zoom_In"], 1)
    ZoomTeleport.Value := GetValue(data, ["Zoom_Settings", "Teleport"], 1)

    EnableUpgrading.Value := GetValue(data, ["Upgrading", "Enabled"], 0)
    UnitManagerUpgradeSystem.Value := GetValue(data, ["Upgrading", "Use_Unit_Manager"], 0)
    PriorityUpgrade.Value := GetValue(data, ["Upgrading", "Use_Unit_Priority"], 1)
    EvenUpgrade.Value := GetValue(data, ["Upgrading", "Even_Upgrade"], 0)

    ShouldUseRecording.Value := GetValue(data, ["Custom_Recordings", "Use"], 0)
    ShouldUseSetup.Value := GetValue(data, ["Custom_Recordings", "Setup"], 0)
    ShouldLoopRecording.Value := GetValue(data, ["Custom_Recordings", "Loop"], 0)
    ShouldHandleGameEnd.Value := GetValue(data, ["Custom_Recordings", "HandleEnd"], 0)

    AlwaysUseCustomCheck.Value := GetValue(data, ["Custom_Placements", "Use"], 0)
    CheckNormalLoadingScreens.Value := GetValue(data, ["Debug", "Enabled"], 0)

    TeamSwap.Value := GetValue(data, ["Contracts", "Enabled"], 0)
    physicalTeam.Value := GetValue(data, ["Contracts", "Physical_Team"], 1)
    magicTeam.Value := GetValue(data, ["Contracts", "Magic_Team"], 2)

    BringOwnTeam.Value := GetValue(data, ["Modes", "Events", "Fools_Hunt", "Bring_Own_Team"], 0)

    TeleportFailsafe.Value := GetValue(data, ["Failsafe_Settings", "Teleport_Failsafe", "Enabled"], 0)
    TeleportFailsafeTimer.Value := GetValue(data, ["Failsafe_Settings", "Teleport_Failsafe", "Timer"], 120)

    UpdateChecker.Value := GetValue(data, ["Update_Checker", "Enabled"], true)

    LoadCustomPlacements()
    InitControlGroups()
    LoadUniversalSettings()
    LoadAllMovements()
    LoadAllRecordings()
    SetupCardManager()
    LoadAllProfiles()

    AddToLog("✅ Settings successfully loaded for mode: " mode)
}

LoadUniversalSettings() {
    file := A_ScriptDir "\Settings\Modes\Universal_Configuration.json"

    if !FileExist(file) {
        AddToLog("⚠️ No universal settings file found. Creating default JSON...")
        SaveUniversalSettings()
        return
    }

    json := FileRead(file, "UTF-8")
    data := jsongo.Parse(json)

    NextLevelBox.Value := GetValue(data, ["Universal", "NextLevel"], 0)
    ReturnLobbyBox.Value := GetValue(data, ["Universal", "ReturnToLobby"], 0)
    MatchMaking.Value := GetValue(data, ["Universal", "Matchmaking"], 1)
    ModeConfigurations.Value := GetValue(data, ["Universal", "UsingModeConfigurations"], 0)

    WebhookEnabled.Value := GetValue(data, ["Webhook", "Enabled"], 0)
    WebhookURLBox.Text := GetValue(data, ["Webhook", "URL"], "")
    WebhookLogsEnabled.Value := GetValue(data, ["Webhook", "LogsEnabled"], 0)

    PrivateServerEnabled.Value := GetValue(data, ["PrivateServer", "Enabled"], 0)
    PrivateServerURLBox.Text := GetValue(data, ["PrivateServer", "URL"], "")

    PlacementPatternDropdown.Value := GetValue(data, ["Placement", "Pattern"], 1)
    PlacementSelection.Value := GetValue(data, ["Placement", "Order"], 1)
    TypeStrategyBox.Value := GetValue(data, ["Placement", "Unit_Type_Strategy"], 0)
    PlaceSpeed.Value := GetValue(data, ["Placement", "Speed"], 2)
}

SaveUniversalSettings() {
    data := {
        Universal: {
            NextLevel: NextLevelBox.Value,
            ReturnToLobby: ReturnLobbyBox.Value,
            Matchmaking: MatchMaking.Value,
            UsingModeConfigurations: ModeConfigurations.Value,
        },
        Webhook: {
            Enabled: WebhookEnabled.Value,
            URL: WebhookURLBox.Text,
            LogsEnabled: WebhookLogsEnabled.Value
        },
        PrivateServer: {
            Enabled: PrivateServerEnabled.Value,
            URL: PrivateServerURLBox.Text
        },
        Placement: {
            Pattern: PlacementPatternDropdown.Value,
            Order: PlacementSelection.Value,
            Unit_Type_Strategy: TypeStrategyBox.Value,
            Speed: PlaceSpeed.Value
        }
    }

    file := A_ScriptDir "\Settings\Modes\Universal_Configuration.json"
    json := jsongo.Stringify(data, "", "    ")

    if FileExist(file)
        FileDelete(file)

    FileAppend(json, file, "UTF-8")
}

ExportCoordinatesPreset(presetIndex) {
    global savedCoords

    if !IsSet(savedCoords) || savedCoords.Length < presetIndex || savedCoords[presetIndex].Length = 0 {
        AddToLog("⚠️ No coordinates saved for Preset " presetIndex)
        return
    }

    ; Ensure export directory
    exportDir := A_ScriptDir "\Settings\Export"
    if !DirExist(exportDir)
        DirCreate(exportDir)

    file := exportDir "\Preset" presetIndex ".txt"

    exportData := Format("[Preset {1}]`n", presetIndex)
    for coord in savedCoords[presetIndex] {
        exportData .= Format("X={1}, Y={2}`n", coord.x, coord.y)
    }

    try {
        if FileExist(file)
            FileDelete(file)
        FileAppend(exportData, file)
    } catch {
        AddToLog "❌ Failed to save preset"
        return
    }

    AddToLog("✅ Preset " presetIndex " exported to: Settings\Export\Preset" presetIndex ".txt")
}

ImportCoordinatesPreset() {
    global savedCoords, MainUI

    ; Allow file dialog to appear
    MainUI.Opt("-AlwaysOnTop")
    Sleep(100)

    file := FileSelect("", A_ScriptDir "\Settings", "Select a placement file to import", "Text Files (*.txt)")

    if !file
        return

    content := FileRead(file)
    lines := StrSplit(content, "`n")

    newPresetCoords := []

    for line in lines {
        line := Trim(line)
        if (line = "" || InStr(line, "[Preset"))
            continue

        if (line = "NoCoordinatesSaved") {
            break
        }

        coordParts := StrSplit(line, ", ")
        if coordParts.Length < 2
            continue

        x := StrReplace(coordParts[1], "X=")
        y := StrReplace(coordParts[2], "Y=")
        newPresetCoords.Push({ x: x + 0, y: y + 0 })  ; Convert to numbers
    }

    if newPresetCoords.Length = 0 {
        MsgBox "❌ No coordinates found in file."
        return
    }

    ; Prompt user for target slot using AHK v2 InputBox
    result := InputBox("Enter preset slot (1–10) to import into:", "Import Custom Placements", "h95 w250")

    MainUI.Opt("+AlwaysOnTop")

    if result.Result = "Cancel" {
        AddToLog("❌ Import canceled.")
        return
    }

    targetSlot := Trim(result.Value)

    if !RegExMatch(targetSlot, "^\d+$") || targetSlot < 1 || targetSlot > 10 {
        MsgBox "❌ Invalid input. Please enter a number between 1 and 10."
        return
    }

    targetSlot := targetSlot + 0

    ; Ensure array is large enough
    while (savedCoords.Length < targetSlot)
        savedCoords.Push([])

    savedCoords[targetSlot] := newPresetCoords

    AddToLog("✅ Imported preset into slot " targetSlot "!")
}

SaveKeybindSettings(*) {
    AddToLog("Saving Keybind Configuration")

    if FileExist("Settings\Keybinds.txt")
        FileDelete("Settings\Keybinds.txt")

    FileAppend(Format("F1={}`nF2={}`nF3={}`nF4={}", F1Box.Value, F2Box.Value, F3Box.Value, F4Box.Value), "Settings\Keybinds.txt", "UTF-8")

    ; Update globals
    global F1Key := F1Box.Value
    global F2Key := F2Box.Value
    global F3Key := F3Box.Value
    global F4Key := F4Box.Value

    ; Update hotkeys
    Hotkey(F1Key, (*) => moveRobloxWindow())
    Hotkey(F2Key, (*) => StartMacro())
    Hotkey(F3Key, (*) => Reload())
    Hotkey(F4Key, (*) => TogglePause())
}

LoadKeybindSettings() {
    if FileExist("Settings\Keybinds.txt") {
        fileContent := FileRead("Settings\Keybinds.txt", "UTF-8")
        loop parse, fileContent, "`n" {
            parts := StrSplit(A_LoopField, "=")
            if (parts[1] = "F1")
                global F1Key := parts[2]
            else if (parts[1] = "F2")
                global F2Key := parts[2]
            else if (parts[1] = "F3")
                global F3Key := parts[2]
            else if (parts[1] = "F4")
                global F4Key := parts[2]
        }
    }
}

HasKey(obj, key) {
    return (obj is Map) ? obj.Has(key) : obj.HasOwnProp(key)
}

GetSection(obj, key) {
    return (IsObject(obj) && HasKey(obj, key)) ? obj[key] : {}
}

; Traverse nested objects safely and return a value or fallback
GetValue(obj, keys, fallback := "") {
    current := obj
    for key in keys {
        if !(IsObject(current) && current.Has(key))
            return fallback
        current := current[key]
    }
    return current
}
; Some dropdowns are saved by their text (e.g. upgrade limit "0"-"6"), so map the text back to its item index
DropdownIndexFromText(ctrl, text, fallbackIndex := 1) {
    for index, item in ControlGetItems(ctrl) {
        if (item = String(text))
            return index
    }
    return fallbackIndex
}
