#Requires AutoHotkey v2.0

; =============================================================================
; CardManager.ahk  -  universal image-search (FT) card picker + priority GUI
;
; OpenCardPriorityPicker()           ; show the GUI for the current mode
; SwitchCardMode("Halloween", true)  ; change mode and show its GUI
; HandleCards()                      ; pick a card for the current mode
; HandleCards("Halloween")           ; pick a card for a specific mode
; =============================================================================
global CardGUI := ""      ; priority picker GUI
global dropDowns := []      ; dropdown controls, index = priority slot
global priorityOrder := []      ; mirror of the active mode's order (GUI bookkeeping)
global cardDebug := true   ; extra logging

; Tier images per card, highest tier first. Names are variable NAMES (strings),
global cardTierVars := Map(
    "shield", ["shield"],
    "speed", ["speed"],
    "health", ["health"],
    "regen", ["regen"],
    "yen", ["yen"],
    "range", ["range3", "range2", "range1"],
    "cooldown", ["cooldown3", "cooldown2", "cooldown1"],
    "attack", ["attack3", "attack2", "attack1"],
    "explosive", ["explosive_death21", "explosive_death3"],
    "resistant", ["resistant"],
    "spellproof", ["spellproof"]
)

; =============================================================================
; Mode registration / startup
; =============================================================================

; options : array of card keys in default priority order (keys must exist in textCards)
; extra   : optional Map of overrides:
;             "region"    [x1, y1, x2, y2] search area      (default [209,203,652,404])
;             "pickDelay" ms to wait after picking          (default 5000)
;             "tiers"     Map card -> array of tier var names
RegisterCardMode(modeName, options, extra := "") {
    key := RegExReplace(modeName, "[^\w]", "")

    cfg := Map(
        "title", modeName " Cards",
        "modeName", modeName,   ; must equal the key used in CardModeConfigs
        "filePath", A_ScriptDir "\Settings\" key "CardPriority.txt",
        "defaults", options.Clone(),
        "options", options.Clone()
    )

    if IsObject(extra) {
        for k, v in extra
            cfg[k] := v
    }

    CardModeConfigs[modeName] := cfg
}

InitCardManager(defaultMode := "") {
    LoadAllCardConfigs()

    if (defaultMode = "") {
        for name in CardModeConfigs {
            defaultMode := name
            break
        }
    }

    if (defaultMode != "")
        SwitchCardMode(defaultMode, false)
}

HasCards(modeName) {
    return FindCardMode(modeName) != ""
}

SwitchCardMode(newMode, showGui := false) {
    global currentCardMode, currentConfig, priorityOrder

    found := FindCardMode(newMode)
    if (found = "") {
        AddToLog("Unknown card mode: " newMode)
        return false
    }
    newMode := found

    currentCardMode := newMode
    currentConfig := CardModeConfigs[newMode]
    LoadCardConfig(newMode)
    priorityOrder := currentConfig["options"].Clone()

    if (showGui) {
        CreateCardPriorityGui(currentConfig)
        CardGUI.Show()
    }
    return true
}

OpenCardPriorityPicker(modeName := "") {
    if (modeName = "")
        modeName := currentCardMode

    if (modeName = "") {
        AddToLog("No card mode selected.")
        return
    }
    SwitchCardMode(modeName, true)
}

; =============================================================================
; The card picker
; =============================================================================

SelectCardsByMode() {
    if (currentCardMode != ModeDropdown.Text && ModeDropdown.Text != "") {
        SwitchCardMode(ModeDropdown.Text)
    }
    HandleCards(currentCardMode)
}

HandleCards(modeName := "") {
    if (modeName = "")
        modeName := currentCardMode

    found := FindCardMode(modeName)
    if (found = "") {
        keys := ""
        for k in CardModeConfigs
            keys .= "[" k "] "
        AddToLog("No card config for [" modeName "] (len " StrLen(modeName) "). Registered: " (keys = "" ? "none" : keys))
        return false
    }
    modeName := found
    config := CardModeConfigs[modeName]
    order := config["options"]
    region := config.Has("region") ? config["region"] : [209, 203, 652, 404]
    delay := config.Has("pickDelay") ? config["pickDelay"] : 6500
    tiers := config.Has("tiers") ? config["tiers"] : cardTierVars
    x1 := region[1], y1 := region[2], x2 := region[3], y2 := region[4]

    AddToLog("Picking card in priority order (" modeName ")")

    if (isMenuOpen("Unit Placement")) {
        FixClick(329, 184) ; close upg menu
        Sleep(500)
    }
    FixClick(59, 572) ; untarget mouse
    Sleep(100)

    for index, card in order {
        if (card = "" || !textCards.Has(card))
            continue

        if !FT(&cardX, &cardY, x1, y1, x2, y2, 0.20, 0.20, textCards.Get(card))
            continue

        ; Refine to the highest available tier
        if tiers.Has(card) {
            for tierVar in tiers[card] {
                img := ResolveGlobal(tierVar)
                if (img != "" && FT(&cardX, &cardY, x1, y1, x2, y2, 0, 0, img)) {
                    tierText := RegExMatch(tierVar, "(\d+)$", &m) ? m[1] : tierVar
                    break
                }
            }
        }

        FTClick(cardX, cardY, 0)
        MouseMove(0, 5, 2, "R")
        Click(2)
        Sleep(1000)
        MouseMove(0, 150, 2, "R")
        Click(2)

        msg := "Picked card: " card " (priority " index " of " order.Length ")"
        AddToLog(msg)
        ;Sleep(delay)
        while (FT(&cardX, &cardY, 270, 127, 532, 161, 0, 0, pick_card)) {
            Sleep(500)
        }
        return true
    }

    AddToLog("Failed to pick a card")
    return false
}

; =============================================================================
; GUI
; =============================================================================

CreateCardPriorityGui(config) {
    global CardGUI, dropDowns

    if IsObject(CardGUI) {
        try CardGUI.Destroy()
    }

    CardGUI := Gui("+AlwaysOnTop")
    CardGUI.SetFont("s10 bold", "Segoe UI")
    CardGUI.BackColor := "0c000a"
    CardGUI.MarginX := 25
    CardGUI.MarginY := 20
    CardGUI.Title := config["title"]
    ; Hide instead of destroy so Show() keeps working
    CardGUI.OnEvent("Close", (*) => (CardGUI.Hide(), 1))

    dropDowns := []
    modeName := config["modeName"]
    options := config["options"]

    yStart := 50
    ySpacing := 28

    loop options.Length {
        yPos := yStart + ((A_Index - 1) * ySpacing)
        CardGUI.Add("Text", Format("x38 y{} w30 h17 +0x200 cWhite", yPos + 3), A_Index)
        dd := CardGUI.Add("DropDownList", Format("x60 y{} w135 Choose{}", yPos, A_Index), options)
        dd.OnEvent("Change", OnCardDropDownChange.Bind(A_Index))
        dropDowns.Push(dd)
    }

    groupBoxHeight := yStart + (options.Length * ySpacing) - 15
    CardGUI.Add("GroupBox", Format("x30 y25 w190 h{} cWhite +Center", groupBoxHeight), "Card Priority Order")

    imgY := groupBoxHeight + 40
    if (IsSet(Import) && IsSet(Export)) {
        importBtn := CardGUI.Add("Picture", Format("x85 y{} w27 h27", imgY), Import)
        exportBtn := CardGUI.Add("Picture", Format("x135 y{} w27 h27", imgY), Export)
    } else {
        importBtn := CardGUI.Add("Button", Format("x45 y{} w80 h27", imgY), "Import")
        exportBtn := CardGUI.Add("Button", Format("x135 y{} w80 h27", imgY), "Export")
    }
    importBtn.OnEvent("Click", (*) => ImportCardConfig(modeName))
    exportBtn.OnEvent("Click", (*) => ExportCardConfig(modeName))

    return CardGUI
}

; Bound as OnCardDropDownChange.Bind(index), so the event supplies (ctrl, info)
OnCardDropDownChange(index, ctrl, *) {
    global priorityOrder

    if (!IsObject(currentConfig) || index > dropDowns.Length || index > priorityOrder.Length)
        return

    newValue := ctrl.Text
    oldValue := priorityOrder[index]
    if (newValue = "" || newValue = oldValue)
        return

    ; If another slot already holds this card, swap it into our old slot
    for i, dd in dropDowns {
        if (i != index && dd.Text = newValue) {
            dd.Text := oldValue
            priorityOrder[i] := oldValue
        }
    }
    priorityOrder[index] := newValue

    currentConfig["options"] := priorityOrder.Clone()
    SaveCardConfig(currentConfig["modeName"])
    AddToLog(Format("Priority {} set to {}", index, newValue))
}

; Push the active mode's options into the dropdowns (after import/load)
SyncCardGuiFromConfig() {
    global priorityOrder
    if (!IsObject(CardGUI) || !IsObject(currentConfig))
        return

    options := currentConfig["options"]
    priorityOrder := options.Clone()
    for i, dd in dropDowns {
        if (i <= options.Length)
            dd.Text := options[i]
    }
}

; =============================================================================
; Config files:  Settings\<Mode>CardPriority.txt   ([CardPriority] / card=slot)
; =============================================================================

RegisterAllCardModes() {
    tiers := Map(
        "shield", ["shield"],
        "speed", ["speed"],
        "health", ["health1", "health"],
        "regen", ["regen"],
        "range", ["range3", "range2", "range1"],
        "cooldown", ["cooldown3", "cooldown2", "cooldown1"],
        "attack", ["attack3", "attack2", "attack1"],
        "yen", ["yen"],
        "explosive", ["explosive_death21", "explosive_death3"],
        "resistant", ["resistant"],
        "spellproof", ["spellproof"],
        "plated", ["plated"]
    )

    RegisterCardMode("Default", ["shield", "regen", "health", "speed", "yen", "range", "cooldown", "attack", "explosive", "resistant", "spellproof"])
    RegisterCardMode("Fool's Hunt", ["shield", "regen", "health", "speed", "yen", "range", "cooldown", "attack", "explosive", "resistant", "spellproof", "plated"], Map("tiers", tiers))
}

LoadAllCardConfigs() {
    for modeName, config in CardModeConfigs {
        if (config.Has("loaded") && config["loaded"])
            continue

        if LoadCardConfig(modeName) {
        } else {
            SaveCardConfig(modeName)
        }
        config["loaded"] := true
    }
}

SaveAllCardConfigs() {
    for modeName in CardModeConfigs
        SaveCardConfig(modeName)
}

LoadCardConfig(modeName) {
    config := CardModeConfigs[modeName]
    path := config["filePath"]

    if !FileExist(path)
        return false

    loaded := ReadCardFile(path)
    if (loaded.Length = 0)
        return false

    config["options"] := NormalizeOrder(loaded, config["defaults"])
    return true
}

SaveCardConfig(modeName) {
    config := CardModeConfigs[modeName]
    ok := WriteCardFile(config["filePath"], config["options"])
    return ok
}

ExportCardConfig(modeName) {
    config := CardModeConfigs[modeName]
    exportDir := A_ScriptDir "\Settings\Export"
    fileName := RegExReplace(config["title"], "[^\w]", "")
    filePath := exportDir "\" fileName ".txt"

    if WriteCardFile(filePath, config["options"])
        AddToLog("Card config exported: " filePath)
    else
        AddToLog("Failed to export card config")
}

ExportAllCardConfigs() {
    for modeName in CardModeConfigs
        ExportCardConfig(modeName)
}

ImportCardConfig(modeName) {
    config := CardModeConfigs[modeName]

    if IsObject(CardGUI)
        CardGUI.Opt("-AlwaysOnTop")
    Sleep(100)
    selected := FileSelect(3, A_ScriptDir "\Settings\Export", "Select a card config file to import", "Text Documents (*.txt)")
    if IsObject(CardGUI)
        CardGUI.Opt("+AlwaysOnTop")

    if (selected = "") {
        AddToLog("Import cancelled.")
        return false
    }

    loaded := ReadCardFile(selected)
    if (loaded.Length = 0) {
        AddToLog("No valid card data found in file.")
        return false
    }

    config["options"] := NormalizeOrder(loaded, config["defaults"])
    SaveCardConfig(modeName)

    if (modeName = currentCardMode)
        SyncCardGuiFromConfig()

    AddToLog("Imported card config for mode: " modeName)
    return true
}

; Returns an array of card names ordered by their saved slot number
ReadCardFile(path) {
    entries := []

    try {
        content := FileRead(path, "UTF-8")
    } catch {
        return []
    }

    section := ""
    for line in StrSplit(content, "`n", "`r") {
        line := Trim(line)
        if (line = "" || SubStr(line, 1, 1) = ";")
            continue

        if RegExMatch(line, "^\[(.*)\]$", &m) {
            section := m[1]
            continue
        }

        if (section = "CardPriority" && RegExMatch(line, "^(.+?)\s*=\s*(\d+)$", &m2))
            entries.Push({ name: Trim(m2[1]), priority: Integer(m2[2]) })
    }

    SortByPriority(entries)

    names := []
    for e in entries
        names.Push(e.name)
    return names
}

WriteCardFile(path, options) {
    try {
        SplitPath(path, , &dir)
        if !DirExist(dir)
            DirCreate(dir)

        f := FileOpen(path, "w", "UTF-8-RAW")
        f.WriteLine("[CardPriority]")
        for index, name in options
            f.WriteLine(name "=" index)
        f.Close()
        return true
    } catch as err {
        AddToLog("Card config write failed: " err.Message)
        return false
    }
}

NormalizeOrder(loaded, defaults) {
    result := []

    for name in loaded {
        for def in defaults {
            if (def = name && !ArrayHasValue(result, def)) {
                result.Push(def)
                break
            }
        }
    }

    for def in defaults {
        if !ArrayHasValue(result, def)
            result.Push(def)
    }
    return result
}

; =============================================================================
; Helpers
; =============================================================================

SortByPriority(entries) {
    n := entries.Length
    loop n - 1 {
        i := A_Index
        loop n - i {
            j := A_Index
            if (entries[j].priority > entries[j + 1].priority) {
                tmp := entries[j]
                entries[j] := entries[j + 1]
                entries[j + 1] := tmp
            }
        }
    }
}

ArrayHasValue(arr, val) {
    for index, item in arr {
        if (item = val)
            return true
    }
    return false
}

; Read a global variable by name; "" if it doesn't exist / isn't set
ResolveGlobal(varName) {
    try {
        return %varName%
    }
    return ""
}

LogPriorityOrder() {
    if !IsObject(currentConfig)
        return
    text := ""
    for index, card in currentConfig["options"]
        text .= (index = 1 ? "" : ", ") card
    AddToLog("Current Priority Order (" currentCardMode "): " text)
}

ShowOCRRegions(regions := 0, duration := 5000, winTitle := "ahk_exe RobloxPlayerBeta.exe") {

    if !WinExist(winTitle) {
        return
    }

    ; Get the client area's top-left screen position.
    WinGetClientPos(&offX, &offY, , , winTitle)

    ; If no custom regions were supplied, use the default OCR regions.
    if !regions {
        regions := [
           ; [191, 227, 318, 258],
           ; [336, 230, 463, 258],
           ; [481, 229, 609, 255],
           ; [226, 97, 577, 148],
            ;[80, 85, 739, 224]
            ;[741, 501, 792, 594]
            [178, 309, 305, 336],
            [192, 244, 237, 400],
            [192, 244, 237, 400]
        ]
    }

    allGuis := []
    thick := 2

    for r in regions {
        ; Convert client-relative coordinates to screen coordinates.
        x1 := r[1] + offX
        y1 := r[2] + offY
        x2 := r[3] + offX
        y2 := r[4] + offY

        width := x2 - x1
        height := y2 - y1

        if width <= 0 || height <= 0
            continue

        ; Rectangle edges: top, bottom, left, right.
        edges := [
            [x1, y1, width, thick],
            [x1, y2 - thick, width, thick],
            [x1, y1, thick, height],
            [x2 - thick, y1, thick, height]
        ]

        for e in edges {
            g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
            g.BackColor := "Red"
            g.Show("x" e[1] " y" e[2] " w" e[3] " h" e[4] " NoActivate")
            allGuis.Push(g)
        }
    }

    ; Remove all preview borders after the requested duration.
    Cleanup(*) {
        for g in allGuis
            g.Destroy()
    }

    cleanupTimer := SetTimer(Cleanup, -duration)
}

NormalizeModeName(name) {
    return StrLower(RegExReplace(name, "[^\w]", ""))
}

; Returns the registered key matching name (ignoring case, spaces, punctuation), or ""
FindCardMode(name) {
    if CardModeConfigs.Has(name)
        return name
    wanted := NormalizeModeName(name)
    for key in CardModeConfigs {
        if (NormalizeModeName(key) = wanted)
            return key
    }
    return ""
}

SetupCardManager() {
    RegisterAllCardModes()          ; the function from my last message
    InitCardManager("Default")  ; loads saved files, sets the active mode
    LoadAllCardConfigs()          ; ensure all modes have a config file
}

; Detects which cards are on screen without picking anything.
;   modeName : mode to check (default: active mode)
;   report   : ByRef, filled with one line per card
;   scanAll  : true = test EVERY key in textCards, not just this mode's cards
; Returns the number of cards found.
CheckForActiveCards(modeName := "", &report := "", scanAll := false) {
    report := ""
    if (modeName = "")
        modeName := currentCardMode

    found := FindCardMode(modeName)
    if (found = "") {
        report := "Unknown card mode: [" modeName "]`n"
        return 0
    }
    modeName := found
    config := CardModeConfigs[modeName]

    region := config.Has("region") ? config["region"] : [209, 203, 652, 404]
    tiers := config.Has("tiers") ? config["tiers"] : cardTierVars
    images := config.Has("images") ? config["images"] : textCards
    x1 := region[1], y1 := region[2], x2 := region[3], y2 := region[4]

    ; Which cards to test
    cards := []
    if (scanAll) {
        for key in images
            cards.Push(key)
    } else {
        cards := config["options"]
    }

    report .= "Mode: " modeName " (" (scanAll ? "all cards" : "priority list") ")`n"

    activeCount := 0
    for index, card in cards {
        if (card = "")
            continue
        label := scanAll ? card : "[" index "] " card

        if !images.Has(card) {
            report .= "  " label ": NO IMAGE (missing from textCards)`n"
            continue
        }

        if !FT(&cx, &cy, x1, y1, x2, y2, 0.20, 0.20, images.Get(card)) {
            if (!scanAll)
                report .= "  " label ": not on screen`n"
            continue
        }

        activeCount++
        tierText := DetectCardTier(card, tiers, x1, y1, x2, y2)
        report .= "  " label ": FOUND at " cx "," cy (tierText != "" ? " (tier " tierText ")" : "") "`n"
    }

    report .= activeCount " card(s) detected`n"
    return activeCount
}

DetectCardTier(card, tiers, x1, y1, x2, y2) {
    if !tiers.Has(card)
        return ""

    for tierVar in tiers[card] {
        img := ResolveGlobal(tierVar)
        if (img != "" && FT(&tx, &ty, x1, y1, x2, y2, 0, 0, img))
            return RegExMatch(tierVar, "(\d+)$", &m) ? m[1] : tierVar
    }
    return "not detected"
}