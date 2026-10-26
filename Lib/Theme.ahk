#Requires AutoHotkey v2.0
; =============================================================================
;  Theme.ahk  -  customizable UI theme (live preview / save / reset / import / export)
; =============================================================================
;  Saved to:  Settings\Theme.ini        Edited in-app:  Settings > Customize Theme...
;
;  Public API
;    Theme_Init()                   load the saved theme (or defaults), fill uiTheme + uiColors
;    Theme_BindMainUI()             tag every MainUI control with a colour role (call once, after the GUI is built)
;    Theme_Apply()                  push the current theme onto the live GUI
;    Theme_OpenEditor()             open the editor window
;    Theme_Get(key)                 Primary, Body, Background, Border, Card, Highlight, InputText, TitleFont
;    Theme_Bind(ctrl, role, kind)   theme a control you add later (kind: "text" or "bg")
;    Theme_Mix(a, b, t)             blend two hex colours (t = 0..1), handy for popup windows
;    Theme_DarkInt(hex)             1 if the colour is dark, else 0 (for the dark title bar flag)
;
;  Colour roles
;    Primary     titles, group-box titles, labels, console text      (uiTheme[1])
;    Background  window + title bar background                       (uiTheme[2])
;    Border      borders and lines                                   (uiTheme[3])
;    Card        unit card fill                                      (uiTheme[4])
;    InputText   text inside dropdowns / edit boxes / lists          (uiTheme[6])
;    Highlight   newest console line                                 (uiTheme[7])
;    Body        checkbox + description text                         (uiTheme[8], new)
;  uiTheme[5] is the see-through key colour for the Roblox window and is NOT customizable.
; =============================================================================

global ThemeFile     := A_ScriptDir "\Settings\Theme.ini"
global ThemeReserved := "3D3C36"      ; see-through key colour (Roblox window) - can't be used as a theme colour
global uiColors      := Map()         ; legacy colour map, kept in sync by Theme_SyncLegacy()

global ThemeOrder := ["Primary", "Body", "Background", "Border", "Card", "Highlight", "InputText"]

global ThemeLabels := Map(
    "Primary",    "Titles and labels",
    "Body",       "Checkbox and body text",
    "Background", "Window background",
    "Border",     "Borders and lines",
    "Card",       "Unit card fill",
    "Highlight",  "Newest console line",
    "InputText",  "Dropdown and input text"
)

global ThemeDefaults := Map(
    "Primary",    "F2F2F2",
    "Body",       "FFFFFF",
    "Background", "0C000A",
    "Border",     "22A9E8",
    "Card",       "0C000A",
    "Highlight",  "22A9E8",
    "InputText",  "000000",
    "TitleFont",  "Verdana"
)

global ThemeFonts := ["Verdana", "Segoe UI", "Tahoma", "Arial", "Calibri", "Consolas", "Trebuchet MS"]

Theme_MakePreset(primary, body, bg, border, card, highlight, inputText) {
    return Map("Primary", primary, "Body", body, "Background", bg, "Border", border
        , "Card", card, "Highlight", highlight, "InputText", inputText)
}

global ThemePresetNames := ["Default", "Midnight", "Crimson", "Forest", "Amethyst", "Monochrome", "Light"]
global ThemePresets := Map(
    "Default",    ThemeDefaults,
    "Midnight",   Theme_MakePreset("E6EDF3", "C9D1D9", "0D1117", "58A6FF", "161B22", "58A6FF", "000000"),
    "Crimson",    Theme_MakePreset("F5E9E9", "FFFFFF", "140607", "E5384F", "1F0B0E", "FF5C73", "000000"),
    "Forest",     Theme_MakePreset("E8F3EA", "F4FFF6", "07140C", "3FB950", "0E2216", "56D364", "000000"),
    "Amethyst",   Theme_MakePreset("F1E9FF", "FFFFFF", "120A1F", "A371F7", "1B1130", "BC8CFF", "000000"),
    "Monochrome", Theme_MakePreset("EDEDED", "FFFFFF", "121212", "8A8A8A", "1C1C1C", "FFFFFF", "000000"),
    "Light",      Theme_MakePreset("1F2328", "24292F", "F3F4F6", "0969DA", "FFFFFF", "0969DA", "000000")
)

; ---- runtime state ----
global ThemeCurrent  := Map()     ; what the GUI is showing right now
global ThemeSaved    := Map()     ; what is stored in Theme.ini
global ThemeBindings := []        ; { ctrl, role, kind, last }
global ThemeProfileDir := A_ScriptDir "\Settings\ThemeProfiles"   ; one .ini per user profile
global ThemeProfiles := Map()     ; name -> full theme Map (colours + TitleFont)
global ThemeActiveProfile := ""   ; user profile currently being used / edited ("" = none)
global ThemeDeleteBtn := ""
global ThemeUI       := ""        ; editor window
global ThemeEdits    := Map()
global ThemeSwatches := Map()
global ThemeStatus   := ""
global ThemePresetDDL := ""
global ThemeFontDDL  := ""
global ThemeSuspend  := false     ; true while the editor itself is rewriting its own controls


; =============================================================================
;  Core: load / save / sync
; =============================================================================

Theme_Init() {
    global ThemeCurrent, ThemeSaved, ThemeDefaults, ThemeFile

    ThemeCurrent := ThemeDefaults.Clone()
    loaded := Theme_ReadFile(ThemeFile)
    if IsObject(loaded) {
        for key, value in loaded
            ThemeCurrent[key] := value
    }
    ThemeSaved := ThemeCurrent.Clone()
    Theme_SyncLegacy()
    Theme_LoadProfiles()
}

Theme_Get(key) {
    global ThemeCurrent
    return ThemeCurrent.Has(key) ? ThemeCurrent[key] : ""
}

; Keeps the old uiTheme[] array and uiColors map (used all over the macro) in step with the theme.
Theme_SyncLegacy() {
    global uiTheme, uiColors, ThemeCurrent

    uiTheme.Length := 0
    uiTheme.Push(ThemeCurrent["Primary"])      ; 1  header / label text
    uiTheme.Push(ThemeCurrent["Background"])   ; 2  window background
    uiTheme.Push(ThemeCurrent["Border"])       ; 3  borders
    uiTheme.Push(ThemeCurrent["Card"])         ; 4  unit card fill
    uiTheme.Push("0x3d3c36")                   ; 5  see-through key (fixed)
    uiTheme.Push(ThemeCurrent["InputText"])    ; 6  textbox text
    uiTheme.Push(ThemeCurrent["Highlight"])    ; 7  highlight
    uiTheme.Push(ThemeCurrent["Body"])         ; 8  body text

    uiColors["Primary"]          := uiTheme[1]
    uiColors["Background"]       := uiTheme[2]
    uiColors["Border"]           := uiTheme[3]
    uiColors["RobloxBox"]        := uiTheme[5]
    uiColors["ProcessHighlight"] := uiTheme[7]
}

; Returns a Map of the values found in the file, or "" if the file is missing / has nothing usable.
Theme_ReadFile(path) {
    global ThemeOrder, ThemeReserved

    if !FileExist(path)
        return ""

    result := Map()
    for key in ThemeOrder {
        hex := Theme_Normalize(IniRead(path, "Theme", key, ""))
        if (hex != "" && hex != ThemeReserved)
            result[key] := hex
    }
    font := Trim(IniRead(path, "Theme", "TitleFont", ""))
    if (font != "")
        result["TitleFont"] := font

    return result.Count ? result : ""
}

Theme_WriteFile(path, theme, name := "") {
    global ThemeOrder
    try {
        SplitPath(path, , &dir)
        if (dir != "" && !DirExist(dir))
            DirCreate(dir)
        if (name != "")
            IniWrite(name, path, "Theme", "Name")
        for key in ThemeOrder
            IniWrite(theme[key], path, "Theme", key)
        IniWrite(theme["TitleFont"], path, "Theme", "TitleFont")
        return true
    } catch {
        return false
    }
}

Theme_Save() {
    global ThemeCurrent, ThemeSaved, ThemeFile

    if !Theme_WriteFile(ThemeFile, ThemeCurrent) {
        MsgBox("Couldn't write the theme file:`n" ThemeFile, "UI Theme", "Icon!")
        return false
    }
    ThemeSaved := ThemeCurrent.Clone()
    Theme_UpdateStatus()
    return true
}

Theme_IsDirty() {
    global ThemeCurrent, ThemeSaved, ThemeOrder
    for key in ThemeOrder {
        if (ThemeCurrent[key] != ThemeSaved[key])
            return true
    }
    return (ThemeCurrent["TitleFont"] != ThemeSaved["TitleFont"])
}


; =============================================================================
;  User profiles (Settings\ThemeProfiles\<name>.ini)
; =============================================================================

Theme_ProfilePath(name) {
    global ThemeProfileDir
    return ThemeProfileDir "\" RegExReplace(name, "[\\/:*?`"<>|]", "_") ".ini"
}

Theme_CleanName(name) {
    return SubStr(Trim(RegExReplace(name, "[\\/:*?`"<>|`r`n`t]", "")), 1, 40)
}

Theme_ReadName(path) {
    return Theme_CleanName(IniRead(path, "Theme", "Name", ""))
}

Theme_IsPresetName(name) {
    global ThemePresetNames
    for preset in ThemePresetNames {
        if (preset = name)
            return true
    }
    return false
}

; Built-in presets first, then the user's profiles.
Theme_AllNames() {
    global ThemePresetNames, ThemeProfiles
    names := ThemePresetNames.Clone()
    for name in ThemeProfiles
        names.Push(name)
    return names
}

; A name that doesn't clash with a preset or an existing profile ("Foo", "Foo (2)", ...)
Theme_UniqueName(name) {
    global ThemeProfiles
    base := name, n := 2
    while (Theme_IsPresetName(name) || ThemeProfiles.Has(name)) {
        name := base " (" n ")"
        n += 1
    }
    return name
}

Theme_LoadProfiles() {
    global ThemeProfiles, ThemeProfileDir, ThemeDefaults
    ThemeProfiles := Map()
    if !DirExist(ThemeProfileDir)
        return
    loop files ThemeProfileDir "\*.ini" {
        colors := Theme_ReadFile(A_LoopFileFullPath)
        if !IsObject(colors)
            continue
        name := Theme_ReadName(A_LoopFileFullPath)
        if (name = "")
            name := Theme_CleanName(RegExReplace(A_LoopFileName, "i)\.ini$"))
        if (name = "" || Theme_IsPresetName(name))
            continue
        profile := ThemeDefaults.Clone()
        for key, value in colors
            profile[key] := value
        ThemeProfiles[name] := profile
    }
}

; Write the current theme to a profile (creates or overwrites it).
Theme_StoreProfile(name) {
    global ThemeProfiles, ThemeCurrent, ThemeDefaults
    profile := ThemeDefaults.Clone()
    for key, value in ThemeCurrent
        profile[key] := value
    ThemeProfiles[name] := profile
    if !Theme_WriteFile(Theme_ProfilePath(name), profile, name)
        MsgBox("Couldn't write the profile file:`n" Theme_ProfilePath(name), "UI Theme", "Icon!")
}

Theme_RebuildPresetList() {
    global ThemePresetDDL, ThemeSuspend
    ThemeSuspend := true
    ThemePresetDDL.Delete()
    ThemePresetDDL.Add(Theme_AllNames())
    ThemeSuspend := false
}

; Ask for a name and save the current theme as a profile. Returns true if one was saved.
Theme_SaveAs() {
    global ThemeUI, ThemeProfiles, ThemeActiveProfile

    ThemeUI.Opt("+OwnDialogs")
    suggestion := (ThemeActiveProfile != "") ? ThemeActiveProfile : Theme_UniqueName("My Theme")
    box := InputBox("Name for this theme profile:", "Save Theme Profile", "w300 h130", suggestion)
    if (box.Result != "OK")
        return false

    name := Theme_CleanName(box.Value)
    if (name = "")
        return false
    if Theme_IsPresetName(name) {
        MsgBox("That name belongs to a built-in preset. Please choose another.", "Save Theme Profile", "Icon!")
        return false
    }
    if (ThemeProfiles.Has(name) && name != ThemeActiveProfile) {
        if (MsgBox("A profile named '" name "' already exists. Overwrite it?", "Save Theme Profile", "YesNo Icon?") != "Yes")
            return false
    }

    Theme_StoreProfile(name)
    ThemeActiveProfile := name
    Theme_RebuildPresetList()
    Theme_RefreshEditor()
    return true
}

; Save button logic: update the active profile, or offer to name a brand-new custom theme.
Theme_SaveAll() {
    global ThemeActiveProfile
    if (ThemeActiveProfile != "")
        Theme_StoreProfile(ThemeActiveProfile)
    else if (Theme_MatchPreset() = 0)
        Theme_SaveAs()                  ; cancelling just skips creating a profile
    return Theme_Save()
}


; =============================================================================
;  Colour helpers
; =============================================================================

; "#22a9e8" / "0x22A9E8" / "22a9e8"  ->  "22A9E8"   (or "" if it isn't a 6-digit hex colour)
Theme_Normalize(value) {
    value := RegExReplace(Trim(value), "i)^(#|0x)")
    return RegExMatch(value, "^[0-9A-Fa-f]{6}$") ? StrUpper(value) : ""
}

; Blend colour a toward colour b.  t = 0 gives a, t = 1 gives b.
Theme_Mix(a, b, t) {
    ar := Integer("0x" SubStr(a, 1, 2)), ag := Integer("0x" SubStr(a, 3, 2)), ab := Integer("0x" SubStr(a, 5, 2))
    br := Integer("0x" SubStr(b, 1, 2)), bg := Integer("0x" SubStr(b, 3, 2)), bb := Integer("0x" SubStr(b, 5, 2))
    return Format("{:02X}{:02X}{:02X}"
        , Round(ar + (br - ar) * t), Round(ag + (bg - ag) * t), Round(ab + (bb - ab) * t))
}

Theme_Luma(hex) {
    r := Integer("0x" SubStr(hex, 1, 2))
    g := Integer("0x" SubStr(hex, 3, 2))
    b := Integer("0x" SubStr(hex, 5, 2))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b
}

Theme_DarkInt(hex) {
    return (Theme_Luma(hex) < 140) ? 1 : 0
}


; =============================================================================
;  Binding: tell the theme which MainUI control uses which colour
; =============================================================================

Theme_Bind(ctrl, role, kind := "text") {
    global ThemeBindings
    ThemeBindings.Push({ ctrl: ctrl, role: role, kind: kind, last: "" })
}

Theme_BindBlock(ctrl, role, skip) {
    skip[ctrl.Hwnd] := true
    Theme_Bind(ctrl, role, "bg")
}

; Call ONCE after every MainUI control has been created.
Theme_BindMainUI() {
    global MainUI, ThemeBindings, uiBorders, gameModeBorders, uiBackgrounds, UnitData, processList

    if ThemeBindings.Length
        return

    skip := Map()   ; hwnd -> true, controls the generic pass must leave alone

    ; Fixed pieces that must never be recoloured (Roblox see-through box, etched divider, hidden focus sink)
    for name in ["robloxHolder", "PlacementDivider", "Webhookdiverter"] {
        if IsSet(%name%)
            skip[%name%.Hwnd] := true
    }

    ; --- Solid colour blocks (borders / backgrounds) ---
    for ctrl in uiBorders
        Theme_BindBlock(ctrl, "Border", skip)
    for ctrl in gameModeBorders
        Theme_BindBlock(ctrl, "Border", skip)
    for ctrl in uiBackgrounds
        Theme_BindBlock(ctrl, "Background", skip)
    if IsSet(minimizeButton)
        Theme_BindBlock(minimizeButton, "Background", skip)

    ; --- Unit cards: fill + borders ---
    for unit in UnitData {
        Theme_BindBlock(unit.Background, "Card", skip)
        for part in ["BorderTop", "BorderBottom", "BorderLeft", "BorderRight", "BorderRight2", "BorderRight3"]
            Theme_BindBlock(unit.%part%, "Border", skip)
    }

    ; --- Console: newest line uses the highlight colour ---
    for i, ctrl in processList {
        skip[ctrl.Hwnd] := true
        Theme_Bind(ctrl, (i = 1) ? "Highlight" : "Primary")
    }

    ; --- Text that uses the "body" colour (was hard-coded white) ---
    bodyText := Map()
    for name in ["RecordMapText", "WalkMapText", "WalkTipText", "CustomPlacementMap"
        , "PlacementStatusText", "PlacementListHeader", "PlacementCaptureHeader", "FoolsHuntCardText"] {
        if IsSet(%name%)
            bodyText[%name%.Hwnd] := true
    }

    ; --- Everything else, by control type ---
    for hwnd, ctrl in MainUI {
        if skip.Has(hwnd)
            continue
        switch ctrl.Type {
            case "GroupBox":
                role := "Primary"
            case "CheckBox":
                role := "Body"
            case "Edit", "DDL", "ComboBox", "ListBox", "ListView":
                role := "InputText"
            case "Text":
                role := bodyText.Has(hwnd) ? "Body" : "Primary"
            default:
                continue
        }
        Theme_Bind(ctrl, role)
    }
}


; =============================================================================
;  Apply the current theme to the live GUI
; =============================================================================

Theme_Apply() {
    global MainUI, ThemeCurrent, ThemeBindings

    Theme_SyncLegacy()

    try MainUI.BackColor := ThemeCurrent["Background"]
    try {
        windowTitle.SetFont("s16 Bold", ThemeCurrent["TitleFont"])
        Theme_SetTextColor(windowTitle, ThemeCurrent["Primary"])
    }

    for b in ThemeBindings {
        hex := ThemeCurrent[b.role]
        if (b.last = hex)
            continue                       ; unchanged since the last apply - skip the work
        b.last := hex
        try {
            if (b.kind = "bg")
                b.ctrl.Opt("+Background" hex)
            else
                Theme_SetTextColor(b.ctrl, hex)
        }
    }

    Theme_Redraw()
}

; Changes ONLY the text colour of a control (Opt leaves the font size / face alone).
; Falls back to SetFont if this control type doesn't accept the colour option.
Theme_SetTextColor(ctrl, color) {
    try {
        ctrl.Opt("c" color)
    } catch {
        try ctrl.SetFont("c" color)
    }
}

Theme_Redraw() {
    global MainUI
    ; RDW_INVALIDATE | RDW_ERASE | RDW_ALLCHILDREN | RDW_UPDATENOW
    try DllCall("user32\RedrawWindow", "ptr", MainUI.Hwnd, "ptr", 0, "ptr", 0, "uint", 0x0001 | 0x0004 | 0x0080 | 0x0100)
}


; =============================================================================
;  Editor window
; =============================================================================

Theme_OpenEditor(*) {
    global MainUI, ThemeUI, ThemeOrder, ThemeLabels, ThemeCurrent, ThemeEdits, ThemeSwatches
    global ThemeStatus, ThemePresetDDL, ThemeFontDDL, ThemeDeleteBtn
    global ThemeFonts

    if IsObject(ThemeUI) {                 ; already open -> bring it forward
        try {
            ThemeUI.Show()
            return
        }
    }

    ; The editor deliberately uses its own fixed colours, so a bad theme can never make it unreadable.
    E := { bg: "14161B", text: "E6EDF3", muted: "8B949E", line: "30363D" }

    ThemeEdits := Map()
    ThemeSwatches := Map()

    ThemeUI := Gui("+AlwaysOnTop +Owner" MainUI.Hwnd " -MaximizeBox -MinimizeBox", "UI Theme Editor")
    ThemeUI.BackColor := E.bg
    try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", ThemeUI.Hwnd, "int", 20, "int*", 1, "int", 4)

    ; ---- Header ----
    ThemeUI.SetFont("s13 Bold c" E.text, "Segoe UI")
    ThemeUI.Add("Text", "x16 y14 w230 h26", "Customize UI Theme")
    ThemeUI.SetFont("s9 Norm c" E.muted, "Segoe UI")
    ThemeUI.Add("Text", "x16 y42 w398 h18", "Changes preview live on the macro window. Press Save to keep them.")
    ThemeStatus := ThemeUI.Add("Text", "x246 y19 w168 h20 Right", "")

    ; ---- Presets / import / export ----
    ThemeUI.SetFont("s10 Norm c" E.text, "Segoe UI")
    ThemeUI.Add("Text", "x16 y80 w52 h24 +0x200", "Preset")
    ThemePresetDDL := ThemeUI.Add("DropDownList", "x70 y78 w118 r10 cBlack", Theme_AllNames())
    ThemePresetDDL.OnEvent("Change", Theme_OnPreset)
    ThemeDeleteBtn := ThemeUI.Add("Button", "x192 y77 w30 h26", "X")
    ThemeDeleteBtn.OnEvent("Click", Theme_OnDelete)
    ThemeUI.Add("Button", "x228 y77 w88 h26", "Import...").OnEvent("Click", Theme_OnImport)
    ThemeUI.Add("Button", "x322 y77 w92 h26", "Export...").OnEvent("Click", Theme_OnExport)

    ThemeUI.Add("Text", "x16 y114 w398 h1 +Background" E.line)

    ; ---- One row per colour: swatch | label | hex | Pick | Reset ----
    y := 126
    for key in ThemeOrder {
        col := ThemeCurrent[key]

        sw := ThemeUI.Add("Text", "x16 y" y " w30 h26 +0x100 +Border +Background" col)
        sw.OnEvent("Click", Theme_OnPick.Bind(key))
        ThemeSwatches[key] := sw

        ThemeUI.Add("Text", "x56 y" y " w166 h26 +0x200 BackgroundTrans", ThemeLabels[key])

        ed := ThemeUI.Add("Edit", "x228 y" y " w70 h26 Limit7 Uppercase Center cBlack", col)
        ed.OnEvent("Change", Theme_OnHexChange.Bind(key))
        ed.OnEvent("LoseFocus", Theme_OnHexCommit.Bind(key))
        ThemeEdits[key] := ed

        ThemeUI.Add("Button", "x304 y" y " w54 h26", "Pick").OnEvent("Click", Theme_OnPick.Bind(key))
        ThemeUI.Add("Button", "x364 y" y " w50 h26", "Reset").OnEvent("Click", Theme_OnResetKey.Bind(key))
        y += 36
    }

    ; ---- Title font ----
    ThemeUI.Add("Text", "x56 y" y " w166 h26 +0x200 BackgroundTrans", "Title font")
    ThemeFontDDL := ThemeUI.Add("DropDownList", "x228 y" y " w130 r8 cBlack", ThemeFonts)
    ThemeFontDDL.OnEvent("Change", Theme_OnFont)
    ThemeUI.Add("Button", "x364 y" y " w50 h26", "Reset").OnEvent("Click", Theme_OnResetFont)
    y += 44

    ; ---- Bottom buttons ----
    ThemeUI.Add("Text", "x16 y" y " w398 h1 +Background" E.line)
    y += 14
    ThemeUI.Add("Button", "x16 y" y " w72 h30 Default", "Save").OnEvent("Click", (*) => Theme_SaveAll())
    ThemeUI.Add("Button", "x97 y" y " w72 h30", "Save As").OnEvent("Click", Theme_OnSaveAs)
    ThemeUI.Add("Button", "x178 y" y " w72 h30", "Revert").OnEvent("Click", Theme_OnRevert)
    ThemeUI.Add("Button", "x259 y" y " w72 h30", "Reset All").OnEvent("Click", Theme_OnResetAll)
    ThemeUI.Add("Button", "x340 y" y " w72 h30", "Close").OnEvent("Click", Theme_OnClose)
    y += 46

    ThemeUI.OnEvent("Close", Theme_OnClose)
    ThemeUI.OnEvent("Escape", Theme_OnClose)

    ; Open over the left (Roblox) half of the macro so the controls on the right stay visible.
    pos := ""
    try {
        MainUI.GetPos(&mx, &my)
        pos := "x" (mx + 14) " y" (my + 44)
    }
    ThemeUI.Show("w430 h" y " " pos)
    Theme_RefreshEditor()
}


; ---------- editor helpers ----------

; Redraw the editor's swatches / hex boxes / dropdowns from ThemeCurrent.
; skipKey = the hex box the user is typing in (don't rewrite it under their cursor).
Theme_RefreshEditor(skipKey := "") {
    global ThemeUI, ThemeCurrent, ThemeEdits, ThemeSwatches, ThemeFontDDL, ThemePresetDDL, ThemeSuspend
    global ThemeActiveProfile, ThemeDeleteBtn

    if !IsObject(ThemeUI)
        return

    ThemeSuspend := true
    for key, sw in ThemeSwatches {
        sw.Opt("+Background" ThemeCurrent[key])
        sw.Redraw()
        if (key != skipKey) {
            ThemeEdits[key].Value := ThemeCurrent[key]
            Theme_SetTextColor(ThemeEdits[key], "Black")
        }
    }
    try ThemeFontDDL.Choose(ThemeCurrent["TitleFont"])
    try ThemePresetDDL.Value := Theme_MatchPreset()     ; 0 = custom (nothing selected)
    try ThemeDeleteBtn.Enabled := (ThemeActiveProfile != "")
    ThemeSuspend := false

    Theme_UpdateStatus()
}

; Index of the preset that exactly matches the current colours, or 0.
; Index (in Theme_AllNames) of the preset / profile that matches the current colours, or 0.
Theme_MatchPreset() {
    global ThemePresets, ThemeProfiles, ThemeCurrent, ThemeOrder, ThemeActiveProfile

    names := Theme_AllNames()
    if (ThemeActiveProfile != "") {        ; while editing a profile, keep it selected
        for i, name in names {
            if (name = ThemeActiveProfile)
                return i
        }
    }
    for i, name in names {
        source := ThemePresets.Has(name) ? ThemePresets[name] : ThemeProfiles[name]
        same := true
        for key in ThemeOrder {
            if (source[key] != ThemeCurrent[key]) {
                same := false
                break
            }
        }
        if same
            return i
    }
    return 0
}

Theme_UpdateStatus(*) {
    global ThemeUI, ThemeStatus
    if !IsObject(ThemeUI)
        return
    if Theme_IsDirty() {
        Theme_SetTextColor(ThemeStatus, "E3B341")
        ThemeStatus.Text := "● Unsaved changes"
    } else {
        Theme_SetTextColor(ThemeStatus, "3FB950")
        ThemeStatus.Text := "● Saved"
    }
}

Theme_Notice(message) {
    global ThemeUI, ThemeStatus
    if !IsObject(ThemeUI)
        return
    Theme_SetTextColor(ThemeStatus, "FF6B6B")
    ThemeStatus.Text := message
    SetTimer(Theme_UpdateStatus, -2500)
}

; Any change to ThemeCurrent funnels through here: update the macro window, then the editor.
Theme_Changed(skipKey := "") {
    Theme_Apply()
    Theme_RefreshEditor(skipKey)
}

Theme_ChooseColor(hex, owner := 0) {
    static custom := Buffer(64, 0)          ; the dialog's 16 "custom colour" slots, remembered between calls

    r := Integer("0x" SubStr(hex, 1, 2))
    g := Integer("0x" SubStr(hex, 3, 2))
    b := Integer("0x" SubStr(hex, 5, 2))

    cc := Buffer(A_PtrSize = 8 ? 72 : 36, 0)                 ; CHOOSECOLORW
    NumPut("uint", cc.Size, cc, 0)                           ; lStructSize
    NumPut("ptr", owner, cc, A_PtrSize)                      ; hwndOwner
    NumPut("uint", (b << 16) | (g << 8) | r, cc, 3 * A_PtrSize)   ; rgbResult (COLORREF is BGR)
    NumPut("ptr", custom.Ptr, cc, 4 * A_PtrSize)             ; lpCustColors
    NumPut("uint", 0x103, cc, 5 * A_PtrSize)                 ; CC_RGBINIT | CC_FULLOPEN | CC_ANYCOLOR

    if !DllCall("comdlg32\ChooseColorW", "ptr", cc, "int")
        return ""

    bgr := NumGet(cc, 3 * A_PtrSize, "uint")
    return Format("{:02X}{:02X}{:02X}", bgr & 0xFF, (bgr >> 8) & 0xFF, (bgr >> 16) & 0xFF)
}

Theme_CloseEditor() {
    global ThemeUI, ThemeEdits, ThemeSwatches
    try ThemeUI.Destroy()
    ThemeUI := ""
    ThemeEdits := Map()
    ThemeSwatches := Map()
}


; ---------- editor events ----------

Theme_OnHexChange(key, ctrl, *) {
    global ThemeSuspend, ThemeCurrent, ThemeReserved

    if ThemeSuspend
        return

    hex := Theme_Normalize(ctrl.Value)
    if (hex = "") {
        Theme_SetTextColor(ctrl, "D73A49")             ; red while it isn't a valid 6-digit hex yet
        return
    }
    if (hex = ThemeReserved) {
        Theme_SetTextColor(ctrl, "D73A49")
        Theme_Notice("Reserved - pick another")
        return
    }

    Theme_SetTextColor(ctrl, "Black")
    if (hex != ThemeCurrent[key]) {
        ThemeCurrent[key] := hex
        Theme_Changed(key)
    }
}

; When the box loses focus, snap its text back to the colour that is actually applied.
Theme_OnHexCommit(key, ctrl, *) {
    global ThemeSuspend, ThemeCurrent

    ThemeSuspend := true
    ctrl.Value := ThemeCurrent[key]
    ThemeSuspend := false
    Theme_SetTextColor(ctrl, "Black")
}

Theme_OnPick(key, *) {
    global ThemeUI, ThemeCurrent, ThemeReserved

    picked := Theme_ChooseColor(ThemeCurrent[key], ThemeUI.Hwnd)
    if (picked = "")
        return
    if (picked = ThemeReserved) {
        Theme_Notice("Reserved - pick another")
        return
    }
    ThemeCurrent[key] := picked
    Theme_Changed()
}

Theme_OnResetKey(key, *) {
    global ThemeCurrent, ThemeDefaults
    ThemeCurrent[key] := ThemeDefaults[key]
    Theme_Changed()
}

Theme_OnFont(ctrl, *) {
    global ThemeCurrent
    if (ctrl.Text = "")
        return
    ThemeCurrent["TitleFont"] := ctrl.Text
    Theme_Changed()
}

Theme_OnResetFont(*) {
    global ThemeCurrent, ThemeDefaults
    ThemeCurrent["TitleFont"] := ThemeDefaults["TitleFont"]
    Theme_Changed()
}

Theme_OnPreset(ctrl, *) {
    global ThemeSuspend, ThemeCurrent, ThemePresets, ThemeProfiles, ThemeOrder, ThemeActiveProfile

    if ThemeSuspend
        return
    name := ctrl.Text

    if ThemePresets.Has(name) {
        preset := ThemePresets[name]
        for key in ThemeOrder
            ThemeCurrent[key] := preset[key]       ; built-in presets change colours only
        ThemeActiveProfile := ""
    } else if ThemeProfiles.Has(name) {
        for key, value in ThemeProfiles[name]
            ThemeCurrent[key] := value             ; user profiles include the title font
        ThemeActiveProfile := name
    } else {
        return
    }
    Theme_Changed()
}

Theme_OnRevert(*) {
    global ThemeCurrent, ThemeSaved
    for key, value in ThemeSaved
        ThemeCurrent[key] := value
    Theme_Changed()
}

Theme_OnResetAll(*) {
    global ThemeUI, ThemeCurrent, ThemeDefaults, ThemeActiveProfile

    ThemeUI.Opt("+OwnDialogs")
    answer := MsgBox("Reset every colour and the title font to the default theme?`n`n"
        . "Nothing is saved until you press Save.", "Reset Theme", "YesNo Icon?")
    if (answer != "Yes")
        return

    for key, value in ThemeDefaults
        ThemeCurrent[key] := value
    ThemeActiveProfile := ""
    Theme_Changed()
}

Theme_OnExport(*) {
    global ThemeUI, ThemeCurrent, ThemeActiveProfile

    ThemeUI.Opt("+OwnDialogs")
    suggestion := (ThemeActiveProfile != "") ? ThemeActiveProfile : "MyTheme"
    path := FileSelect("S16", A_ScriptDir "\Settings\" Theme_CleanName(suggestion) ".ini", "Export Theme", "Theme (*.ini)")
    if (path = "")
        return
    if !RegExMatch(path, "i)\.ini$")
        path .= ".ini"

    ; The profile name travels inside the file so it shows up under the same name when imported.
    SplitPath(path, , , , &stem)
    name := (ThemeActiveProfile != "") ? ThemeActiveProfile : Theme_CleanName(stem)
    if !Theme_WriteFile(path, ThemeCurrent, name)
        MsgBox("Couldn't write that file.", "Export Theme", "Icon!")
}

Theme_OnImport(*) {
    global ThemeUI, ThemeCurrent, ThemeProfiles, ThemeDefaults, ThemeOrder, ThemeActiveProfile

    ThemeUI.Opt("+OwnDialogs")
    path := FileSelect(3, A_ScriptDir "\Settings", "Import Theme", "Theme (*.ini)")
    if (path = "")
        return

    colors := Theme_ReadFile(path)
    if !IsObject(colors) {
        MsgBox("That file doesn't contain a valid theme.", "Import Theme", "Icon!")
        return
    }
    imported := ThemeDefaults.Clone()
    for key, value in colors
        imported[key] := value

    ; Use the name stored in the file (falls back to the file name)
    name := Theme_ReadName(path)
    if (name = "") {
        SplitPath(path, , , , &stem)
        name := Theme_CleanName(stem)
    }
    if (name = "")
        name := "Imported Theme"

    ; Same name + identical colours = it's already there, just select it. Otherwise never overwrite.
    existing := ThemeProfiles.Has(name) ? ThemeProfiles[name] : ""
    same := IsObject(existing)
    if same {
        for key in ThemeOrder {
            if (existing[key] != imported[key]) {
                same := false
                break
            }
        }
        if (existing["TitleFont"] != imported["TitleFont"])
            same := false
    }
    if !same
        name := Theme_UniqueName(name)

    for key, value in imported
        ThemeCurrent[key] := value
    Theme_StoreProfile(name)
    ThemeActiveProfile := name
    Theme_RebuildPresetList()
    Theme_Changed()
}

Theme_OnSaveAs(*) {
    if Theme_SaveAs()
        Theme_Save()
}

Theme_OnDelete(*) {
    global ThemeUI, ThemeProfiles, ThemeActiveProfile

    if (ThemeActiveProfile = "")
        return
    ThemeUI.Opt("+OwnDialogs")
    if (MsgBox("Delete the profile '" ThemeActiveProfile "'?`n`nYour current colours stay as they are.", "Delete Profile", "YesNo Icon?") != "Yes")
        return

    try FileDelete(Theme_ProfilePath(ThemeActiveProfile))
    ThemeProfiles.Delete(ThemeActiveProfile)
    ThemeActiveProfile := ""
    Theme_RebuildPresetList()
    Theme_RefreshEditor()
}

; Close button / window X / Escape.  Returning true stops AutoHotkey's default close handling.
Theme_OnClose(*) {
    global ThemeUI, ThemeCurrent, ThemeSaved

    ThemeUI.Opt("+OwnDialogs")
    if Theme_IsDirty() {
        answer := MsgBox("You have unsaved theme changes.`n`n"
            . "Yes = save them`nNo = discard them`nCancel = keep editing", "UI Theme", "YesNoCancel Icon?")
        if (answer = "Cancel")
            return true
        if (answer = "Yes") {
            if !Theme_SaveAll()
                return true
        } else {
            for key, value in ThemeSaved
                ThemeCurrent[key] := value
            Theme_Apply()
        }
    }
    Theme_CloseEditor()
    return true
}
