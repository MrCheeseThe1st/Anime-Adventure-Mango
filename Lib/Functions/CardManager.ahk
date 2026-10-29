#Requires AutoHotkey v2.0

; =============================================================================
; CardManager.ahk  -  OCR card picker + priority GUI
;
; OpenCardPriorityPicker()           ; show the GUI for the current mode
; SwitchCardMode("Halloween", true)  ; change mode and show its GUI
; HandleCards()                      ; pick a card for the current mode
; HandleCards("Halloween")           ; pick a card for a specific mode
; CheckForActiveCards()              ; OCR the card slots and report what was read
;
; How it works: each card name sits in a fixed slot on screen. Every slot is
; read once with OCR, then the priority list is walked top to bottom and the
; first card whose pattern matches a slot is clicked. For tiered cards
; ("Range III") the tier is parsed from the end of the OCR text, and the
; highest tier wins if the same card shows up twice.
; =============================================================================
global CardGUI := ""      ; priority picker GUI
global cardRows := []      ; GUI row controls, index = priority slot
global priorityOrder := []      ; mirror of the active mode's order (GUI bookkeeping)
global cardDebug := false  ; true = log the raw OCR text of every slot (for tuning patterns)

; Window the client coordinates below are relative to
global robloxWin := "ahk_exe RobloxPlayerBeta.exe"

; OCR upscale factor. Windows OCR does much better on small text when enlarged.
global ocrScale := 3

; Card name slots [x1, y1, x2, y2], client coordinates, one per card on screen.
; Check them with ShowOCRRegions(cardSlots)
global cardSlots := [
    [191, 227, 318, 258],
    [336, 230, 463, 258],
    [481, 229, 609, 255]
]

; Regex per card, matched against the OCR text of a slot. Loose on purpose,
; because OCR often drops or swaps a letter. Whatever follows the match is
; used to read the tier.
global cardPatterns := Map(
    "shield", "i)shie",
    "speed", "i)spee",
    "health", "i)heal",
    "regen", "i)reg[ec]n",
    "range", "i)rang",
    "cooldown", "i)cool\s*down",
    "attack", "i)attac",
    "yen", "i)\byen",
    "explosive", "i)explo\w*(\s*death)?",
    "resistant", "i)resist",
    "spellproof", "i)spell\s*proof|spel|proof",
    "plated", "i)plat"
)

; Card type labels. Anything not listed here is a Buff.
;   "Buff"     stat boosts
;   "Money"    in-game money (yen)
;   "Currency" reward currency (candy, gems, event tokens, ...)
; Add cards here (or per mode via the "types" extra, see RegisterCardMode).
global cardTypes := Map(
    "shield", "Currency",
    "speed", "Currency",
    "health", "Currency",
    "regen", "Currency",
    "range", "Buff",
    "cooldown", "Buff",
    "attack", "Buff",
    "explosive", "Currency",
    "resistant", "Currency",
    "spellproof", "Currency",
    "plated", "Currency",
    "yen", "Money"
)

; Per-mode override first (extra Map "types"), then the global map, else "Buff"
CardType(card, config := "") {
    if (IsObject(config) && config.Has("types") && config["types"].Has(card))
        return config["types"][card]
    return cardTypes.Has(card) ? cardTypes[card] : "Buff"
}

; "yen" -> "yen (+Money)", "shield" -> "shield (+Buff)"
CardLabel(card, config := "") {
    return card " (+" CardType(card, config) ")"
}

; =============================================================================
; Mode registration / startup
; =============================================================================

; options : array of card keys in default priority order (keys must exist in cardPatterns,
;           or in the mode's own "patterns" extra)
; extra   : optional Map of overrides:
;             "slots"     array of [x1, y1, x2, y2] card name slots   (default cardSlots)
;             "patterns"  Map card -> regex, replaces cardPatterns for this mode
;             "pickDelay" ms to wait after picking                    (default 6500)
;             "types"     Map card -> "Buff" / "Money" / "Currency" (overrides cardTypes for this mode)
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
; OCR helpers
;
; Everything OCR-specific lives in OCRReadText(). To move to RapidOCR later,
; that is the only function that has to change.
; =============================================================================

; Top-left of the game window's client area in screen coordinates, or 0 if the window is gone
ClientOrigin() {
    global robloxWin
    if !WinExist(robloxWin)
        return 0
    WinGetClientPos(&ox, &oy, , , robloxWin)
    return [ox, oy]
}

; OCR a client-coordinate rectangle and return its text on a single line ("" on failure)
OCRReadText(x1, y1, x2, y2) {
    global ocrScale

    org := ClientOrigin()
    if !org {
        AddToLog("OCR: game window not found")
        return ""
    }

    try {
        res := OCR.FromRect(org[1] + x1, org[2] + y1, x2 - x1, y2 - y1, { scale: ocrScale })
        return Trim(RegExReplace(res.Text, "\s+", " "))
    } catch as err {
        AddToLog("OCR failed: " err.Message)
        return ""
    }
}

; Reads every slot. Returns an array of {slot, text, x, y} where x/y is the slot centre (client coords).
; Retries a few times if nothing readable shows up yet (cards still animating in).
ReadCardSlots(slots, tries := 3) {
    global cardDebug

    loop tries {
        read := []
        anyText := false
        for i, r in slots {
            text := OCRReadText(r[1], r[2], r[3], r[4])
            if (text != "")
                anyText := true
            read.Push({ slot: i, text: text, x: (r[1] + r[3]) // 2, y: (r[2] + r[4]) // 2 })
        }
        if (anyText)
            break
        Sleep(300)
    }

    if (cardDebug) {
        for s in read
            AddToLog("OCR slot " s.slot ": [" s.text "]")
    }
    return read
}

; Does this OCR text belong to this card? Fills tier (0 = no tier found).
MatchCard(card, text, patterns, &tier) {
    tier := 0
    if (text = "" || !patterns.Has(card))
        return false
    if !RegExMatch(text, patterns[card], &m)
        return false
    tier := ParseTier(SubStr(text, m.Pos + m.Len))
    return true
}

; Reads the tier from the last token of the text after the card name:
; "III" / "lll" / "3" / "+3" -> 3, "II" -> 2, "I" / "1" -> 1, anything else -> 0
ParseTier(rest) {
    rest := Trim(rest)
    if !RegExMatch(rest, "(\S+)$", &t)
        return 0
    tok := t[1]
    if RegExMatch(tok, "([123])$", &d)
        return Integer(d[1])
    if RegExMatch(tok, "^[Il|1!]{1,3}$")
        return StrLen(tok)
    return 0
}

; Best slot for a card (highest tier wins), or 0 if it is not on screen
FindBestSlot(card, read, patterns) {
    best := 0
    for s in read {
        if !MatchCard(card, s.text, patterns, &tier)
            continue
        if (!IsObject(best) || tier > best.tier)
            best := { slot: s.slot, x: s.x, y: s.y, tier: tier, text: s.text }
    }
    return best
}

; =============================================================================
; The card picker
; =============================================================================

SelectCardsByMode() {
    local modeText := ModeDropdown.Text

    ; If the mode is Event, use the Event dropdown instead
    if (modeText = "Event" && EventDropdown.Text != "") {
        modeText := EventDropdown.Text
    }

    if (currentCardMode != modeText && modeText != "") {
        SwitchCardMode(modeText)
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
        AddToLog("No card config for [" modeName "] (len " StrLen(modeName) "). Registered: " (keys = "" ? "none" :
            keys))
        return false
    }
    modeName := found
    config := CardModeConfigs[modeName]
    order := config["options"]
    slots := config.Has("slots") ? config["slots"] : cardSlots
    patterns := config.Has("patterns") ? config["patterns"] : cardPatterns
    delay := config.Has("pickDelay") ? config["pickDelay"] : 6500

    AddToLog("Picking card in priority order (" modeName ")")

    if (isMenuOpen("Unit Placement")) {
        FixClick(329, 184) ; close upg menu
        Sleep(500)
    }

    FixClick(59, 572) ; untarget mouse
    Sleep(100)

    read := ReadCardSlots(slots)

    for index, card in order {
        if (card = "")
            continue

        best := FindBestSlot(card, read, patterns)
        if !IsObject(best)
            continue

        FixClick(best.x, best.y)
        Sleep(1000)
        MouseMove(0, 125, 2, "R")
        Click(2)

        msg := "Picked card: " CardLabel(card, config) " (priority " index " of " order.Length ")"
        AddToLog(msg)
        ;Sleep(delay)

        ; Wait for the card screen to go away (still image based, uses your pick_card image)
        while (FT(&px, &py, 270, 127, 532, 161, 0.10, 0.10, pick_card)) {
            Sleep(500)
        }
        return true
    }

    ; Only when nothing matched: show what OCR actually read so the patterns can be fixed
    seen := ""
    for s in read
        seen .= (seen = "" ? "" : " | ") "[" s.text "]"
    AddToLog("Failed to pick a card. OCR read: " (seen = "" ? "nothing" : seen))
    return false
}

; =============================================================================
; GUI  -  dark, flat priority list. Click the arrows to reorder.
; =============================================================================

; Palette (a function with a static Map so it works wherever this file is included)
CardTheme(key) {
    static t := Map(
        "bg", "0F0F14",
        "row", "1A1A23",
        "text", "ECECF3",
        "muted", "7C7C8E",
        "accent", "8B7CFF",
        "btn", "262633",
        "buffFg", "4ADE80",
        "buffBg", "163325",
        "curFg", "FBBF24",
        "curBg", "3A2F12",
        "monFg", "38BDF8",
        "monBg", "11303F"
    )
    return t[key]
}

; Pill styles per type. Unknown types fall back to the Buff style.
CardPillTypes() {
    static list := [
        ["Buff", "buffFg", "buffBg"],
        ["Money", "monFg", "monBg"],
        ["Currency", "curFg", "curBg"]
    ]
    return list
}

CreateCardPriorityGui(config) {
    global CardGUI, cardRows

    if IsObject(CardGUI) {
        try CardGUI.Destroy()
    }

    CardGUI := Gui("+AlwaysOnTop -MaximizeBox")
    CardGUI.BackColor := CardTheme("bg")
    CardGUI.MarginX := 20
    CardGUI.MarginY := 20
    CardGUI.Title := config["title"]
    ; Hide instead of destroy so Show() keeps working
    CardGUI.OnEvent("Close", (*) => (CardGUI.Hide(), 1))
    ; Dark title bar (Windows 10 20H1+ / 11); harmlessly ignored on older builds
    try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", CardGUI.Hwnd, "int", 20, "int*", 1, "int", 4)

    modeName := config["modeName"]
    options := config["options"]

    x0 := 20, w := 300, rowH := 38, gap := 6, yStart := 84
    rowBg := CardTheme("row")

    ; ---- header ----
    CardGUI.SetFont("s16 bold c" CardTheme("text"), "Segoe UI")
    CardGUI.Add("Text", Format("x{} y18 w{} h30", x0, w), "Card Priority")
    CardGUI.SetFont("s9 norm c" CardTheme("muted"), "Segoe UI")
    CardGUI.Add("Text", Format("x{} y50 w{} h18", x0, w), modeName " - The top card is picked first")

    ; ---- rows ----
    cardRows := []
    loop options.Length {
        i := A_Index
        y := yStart + (i - 1) * (rowH + gap)
        row := {}

        ; row plate
        CardGUI.Add("Text", Format("x{} y{} w{} h{} Background{}", x0, y, w, rowH, rowBg))

        ; slot number
        CardGUI.SetFont("s10 bold c" CardTheme("muted"))
        CardGUI.Add("Text", Format("x{} y{} w26 h{} +0x200 +Center Background{}", x0 + 8, y, rowH, rowBg), i)

        ; card name
        CardGUI.SetFont("s11 bold c" CardTheme("text"))
        row.name := CardGUI.Add("Text", Format("x{} y{} w130 h{} +0x200 Background{}", x0 + 40, y, rowH, rowBg), "")

        ; type pills (one per style; RefreshCardRows shows the right one)
        row.pills := Map()
        for entry in CardPillTypes() {
            CardGUI.SetFont("s8 bold c" CardTheme(entry[2]))
            row.pills[entry[1]] := CardGUI.Add("Text", Format("x{} y{} w74 h22 +0x200 +Center Background{}", x0 + 176,
                y + 8, CardTheme(entry[3])), "")
        }

        ; move arrows
        CardGUI.SetFont("s9 norm c" CardTheme("accent"))
        row.up := CardGUI.Add("Text", Format("x{} y{} w22 h{} +0x200 +Center Background{}", x0 + 254, y, rowH, rowBg),
        Chr(0x25B2))
        row.down := CardGUI.Add("Text", Format("x{} y{} w22 h{} +0x200 +Center Background{}", x0 + 276, y, rowH, rowBg),
        Chr(0x25BC))
        row.up.OnEvent("Click", MoveCardClick.Bind(i, -1))
        row.up.OnEvent("DoubleClick", MoveCardClick.Bind(i, -1))
        row.down.OnEvent("Click", MoveCardClick.Bind(i, 1))
        row.down.OnEvent("DoubleClick", MoveCardClick.Bind(i, 1))

        cardRows.Push(row)
    }

    ; ---- footer buttons ----
    yFoot := yStart + options.Length * (rowH + gap) + 10
    btnW := 92, btnGap := 12
    CardGUI.SetFont("s9 bold c" CardTheme("text"))
    importBtn := CardGUI.Add("Text", Format("x{} y{} w{} h30 +0x200 +Center Background{}", x0, yFoot, btnW, CardTheme(
        "btn")), "Import")
    exportBtn := CardGUI.Add("Text", Format("x{} y{} w{} h30 +0x200 +Center Background{}", x0 + btnW + btnGap, yFoot,
        btnW, CardTheme("btn")), "Export")
    resetBtn := CardGUI.Add("Text", Format("x{} y{} w{} h30 +0x200 +Center Background{}", x0 + 2 * (btnW + btnGap),
    yFoot, btnW, CardTheme("btn")), "Reset")
    importBtn.OnEvent("Click", (*) => ImportCardConfig(modeName))
    exportBtn.OnEvent("Click", (*) => ExportCardConfig(modeName))
    resetBtn.OnEvent("Click", (*) => ResetCardPriority(modeName))

    RefreshCardRows()
    return CardGUI
}

; Redraw every row from priorityOrder (names, type pills, which arrows show)
RefreshCardRows() {
    global priorityOrder, cardRows
    if (!IsObject(currentConfig))
        return

    n := priorityOrder.Length
    for i, row in cardRows {
        if (i > n)
            continue
        card := priorityOrder[i]
        type := CardType(card, currentConfig)
        styleKey := row.pills.Has(type) ? type : "Buff"

        row.name.Text := StrTitle(card)
        for pillType, pill in row.pills {
            pill.Text := type
            pill.Visible := (pillType = styleKey)
        }
        row.up.Visible := (i > 1)
        row.down.Visible := (i < n)
    }
}

; Bound as MoveCardClick.Bind(index, direction): -1 = up, +1 = down
MoveCardClick(index, dir, *) {
    global priorityOrder

    target := index + dir
    if (!IsObject(currentConfig) || target < 1 || target > priorityOrder.Length)
        return

    tmp := priorityOrder[index]
    priorityOrder[index] := priorityOrder[target]
    priorityOrder[target] := tmp

    currentConfig["options"] := priorityOrder.Clone()
    SaveCardConfig(currentConfig["modeName"])
    RefreshCardRows()
    AddToLog(Format("Moved {} to priority {}", CardLabel(priorityOrder[target], currentConfig), target))
}

ResetCardPriority(modeName) {
    global priorityOrder

    config := CardModeConfigs[modeName]
    config["options"] := config["defaults"].Clone()
    SaveCardConfig(modeName)

    if (modeName = currentCardMode) {
        priorityOrder := config["options"].Clone()
        RefreshCardRows()
    }
    AddToLog("Card priority reset to default for mode: " modeName)
}

; Push the active mode's options into the GUI (after import/load)
SyncCardGuiFromConfig() {
    global priorityOrder
    if (!IsObject(CardGUI) || !IsObject(currentConfig))
        return

    priorityOrder := currentConfig["options"].Clone()
    RefreshCardRows()
}

; =============================================================================
; Config files:  Settings\<Mode>CardPriority.txt   ([CardPriority] / card=slot)
; =============================================================================

RegisterAllCardModes() {
    RegisterCardMode("Default", ["shield", "regen", "health", "speed", "range", "cooldown", "attack", "yen",
        "explosive", "resistant", "spellproof"])
    RegisterCardMode("Fool's Hunt", ["shield", "regen", "health", "speed", "range", "cooldown", "attack", "yen",
        "explosive", "resistant", "spellproof", "plated"])
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
    selected := FileSelect(3, A_ScriptDir "\Settings\Export", "Select a card config file to import",
        "Text Documents (*.txt)")
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

LogPriorityOrder() {
    if !IsObject(currentConfig)
        return
    text := ""
    for index, card in currentConfig["options"]
        text .= (index = 1 ? "" : ", ") CardLabel(card, currentConfig)
    AddToLog("Current Priority Order (" currentCardMode "): " text)
}

ShowOCRRegions(regions := 0, duration := 5000, winTitle := "ahk_exe RobloxPlayerBeta.exe") {

    if !WinExist(winTitle) {
        return
    }

    ; Get the client area's top-left screen position.
    WinGetClientPos(&offX, &offY, , , winTitle)

    ; If no custom regions were supplied, use the card slots.
    if !regions {
        regions := cardSlots
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

; Reads the card slots with OCR and reports what was seen, without picking anything.
;   modeName : mode to check (default: active mode)
;   report   : ByRef, filled with the raw OCR text of each slot and one line per card
;   scanAll  : true = test EVERY pattern in cardPatterns, not just this mode's cards
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

    slots := config.Has("slots") ? config["slots"] : cardSlots
    patterns := config.Has("patterns") ? config["patterns"] : cardPatterns

    ; Which cards to test
    cards := []
    if (scanAll) {
        for key in patterns
            cards.Push(key)
    } else {
        cards := config["options"]
    }

    report .= "Mode: " modeName " (" (scanAll ? "all cards" : "priority list") ")`n"

    read := ReadCardSlots(slots)
    for s in read
        report .= "  slot " s.slot " OCR: [" s.text "]`n"

    activeCount := 0
    for index, card in cards {
        if (card = "")
            continue
        label := scanAll ? CardLabel(card, config) : "[" index "] " CardLabel(card, config)

        if !patterns.Has(card) {
            report .= "  " label ": NO PATTERN (missing from cardPatterns)`n"
            continue
        }

        best := FindBestSlot(card, read, patterns)
        if !IsObject(best) {
            if (!scanAll)
                report .= "  " label ": not on screen`n"
            continue
        }

        activeCount++
        report .= "  " label ": FOUND in slot " best.slot (best.tier ? " (tier " best.tier ")" : "") "`n"
    }

    report .= activeCount " card(s) detected`n"
    return activeCount
}