#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\Lib\GUI.ahk
global confirmClicked := false
 
 ;Minimizes the UI
 minimizeUI(*){
    MainUI.Minimize()
 }
 
 Destroy(*){
    MainUI.Destroy()
    ExitApp
 }

 LogToFile(text) {
     global currentOutputFile
     SplitPath(currentOutputFile, , &dir)
     try {
         if !DirExist(dir)
             DirCreate(dir)
         FileAppend(text, currentOutputFile)
     }
 }

 ;Login Text
setupOutputFile() {
    LogToFile("`n==" GameTitle "" version "==`nStart Time: [" currentTime "]`n")
}

; Gets the current time in 12-hour format
getCurrentTime() {
    currentHour := A_Hour
    currentMinute := A_Min
    currentSecond := A_Sec
    amPm := (currentHour >= 12) ? "PM" : "AM"
    
    ; Convert to 12-hour format
    currentHour := Mod(currentHour - 1, 12) + 1

    return Format("{:d}:{:02}:{:02} {}", currentHour, currentMinute, currentSecond, amPm)
}

OnModeChange(*) {
    ; Hide all
    for ctrl in [StoryDropdown, StoryActDropdown, InfinityCastleDropdown, LegendDropDown, LegendActDropdown, RaidDropdown, RaidActDropdown, PortalDropdown, PortalRoleDropdown, SwapFromPortal, EventDropdown, ContractJoinDropdown, ContractPageDropdown, PhysicalTeamText, PhysicalTeam, MagicTeamText, MagicTeam, TeamSwap, BringOwnTeam]
        ctrl.Visible := false

    if (ActiveControlGroup = "Mode") {
        ToggleControlGroup(ModeDropdown.Text)
    }

    ; Show based on selection
    switch ModeDropdown.Text {
        case "Contracts":
            ContractJoinDropdown.Visible := true
            ContractPageDropdown.Visible := true
            PhysicalTeamText.Visible := true
            PhysicalTeam.Visible := true
            MagicTeamText.Visible := true
            MagicTeam.Visible := true
            TeamSwap.Visible := true
        case "Event":
            EventDropdown.Visible := true
        case "Story":
            StoryDropdown.Visible := true
            StoryActDropdown.Visible := true
        case "Legend Stages":
            LegendDropDown.Visible := true
            LegendActDropdown.Visible := true
        case "Raid":
            RaidDropdown.Visible := RaidActDropdown.Visible := true
        case "Portal":
            PortalDropdown.Visible := PortalRoleDropdown.Visible := true
            SwapFromPortal.Visible := true
        case "Infinity Castle":
            InfinityCastleDropdown.Visible := true
        case "Custom":
            ; Add handling if needed
    }

    if (ModeConfigurations.Value) {
        LoadUnitSettingsByMode()
    }
}

OnStoryChange(*) {
    if (StoryDropdown.Text != "") {
        StoryActDropdown.Visible := true
    } else {
        StoryActDropdown.Visible := false
    }
}

OnEventChange(*) {
    if (EventDropdown.Text = "Fool's Hunt") {
        BringOwnTeam.Visible := true
    } else {
        BringOwnTeam.Visible := false
    }
}

OnLegendChange(*) {
    selected := LegendDropDown.Text

    if (selected = "") {
        ; Clear the act dropdown when no stage is selected
        LegendActDropdown.Delete()
        return
    }

    ; Get how many acts this stage supports (default to 6 if not listed)
    maxActs := LegendMaxActs.Has(selected) ? LegendMaxActs[selected] : 6

    ; Rebuild the Act dropdown
    LegendActDropdown.Delete()

    ; Add only the acts that this stage actually has
    loop maxActs {
        LegendActDropdown.Add(["Act " A_Index])
    }

    ; Optional: always include Random if you want them
    LegendActDropdown.Add(["Random"])

    ; Select the first real act by default
    LegendActDropdown.Choose(1)
}

OnRaidChange(*) {
    if (RaidDropdown.Text != "") {
        RaidActDropdown.Visible := true
    } else {
        RaidActDropdown.Visible := false
    }
}

OnPlacementChange(*) {
    if (PlacementPatternDropdown.Text = "Custom") {
        enabledPlacements := UseCustomPoints()
        if (!enabledPlacements) {
            AddToLog("No placements set, please set at least one placement!")
        }
    }
}

OnConfirmClick(*) {
    mode := ModeDropdown.Text
    if (mode = "") {
        AddToLog("Please select a gamemode before confirming")
        return
    }

    ; Validation per mode
    missing := ""
    switch mode {
        case "Story":
            if (StoryDropdown.Text = "" || StoryActDropdown.Text = "")
                missing := "both Story and Act"
            else
                AddToLog("Selected " StoryDropdown.Text)

        case "Legend Stages":
            if (LegendDropDown.Text = "")
                missing := "both Legend Stage and Act"
            else
                AddToLog("Selected " LegendDropDown.Text)

        case "Raid":
            if (RaidDropdown.Text = "")
                missing := "both Raid and Act"
            else
                AddToLog("Selected " RaidDropdown.Text)

        case "Custom":
            AddToLog("Selected Custom")

        default:
            AddToLog("Selected " mode " mode")
    }

    if (missing) {
        AddToLog("Please select " missing " before confirming")
        return
    }

    ; Hide all dropdowns and confirm button
    for ctrl in [ModeDropdown, ContractJoinDropdown, ContractPageDropdown, InfinityCastleDropdown, StoryDropdown, StoryActDropdown, LegendDropDown, LegendActDropdown,
        RaidDropdown, RaidActDropdown, PortalDropdown,
        PortalRoleDropdown, EventDropdown, ConfirmButton] {
        ctrl.Visible := false
        ToggleGameModeSelection(false)
    }

    ; Show hotkey texts
    for ctrl in [Hotkeytext, Hotkeytext2, Hotkeytext3]
        ctrl.Visible := true

    global confirmClicked := true
}

ToggleGameModeSelection(show := true) {
    ; Borders
    for border in gameModeBorders
        border.Visible := show

    ; Title
    gameModeTitle.Visible := show

    ; All the controls that belong to this section
    controls := [
        ModeDropdown, ContractJoinDropdown, ContractPageDropdown,
        InfinityCastleDropdown, StoryDropdown, StoryActDropdown,
        LegendDropDown, LegendActDropdown, RaidDropdown, RaidActDropdown,
        PortalDropdown, PortalRoleDropdown, EventDropdown, ConfirmButton
    ]

    for ctrl in controls
        ctrl.Visible := show
}

FixClick(x, y, LR := "Left", shouldWiggle := false) {
    MouseMove(x, y)
    MouseMove(1, 0, , "R")
    Sleep(50)
    if (shouldWiggle) {
        wiggle()
    }
    MouseClick(LR, -1, 0, , , , "R")
}

GetWindowCenter(WinTitle) {
    x := 0 y := 0 Width := 0 Height := 0
    WinGetPos(&X, &Y, &Width, &Height, WinTitle)

    centerX := X + (Width / 2)
    centerY := Y + (Height / 2)

    return { x: centerX, y: centerY, width: Width, height: Height }
}

FindAndClickColor(targetColor := 0xFAFF4D, searchArea := [0, 0, GetWindowCenter(rblxID).Width, GetWindowCenter(rblxID).Height]) {
    ; Extract the search area boundaries
    x1 := searchArea[1], y1 := searchArea[2], x2 := searchArea[3], y2 := searchArea[4]

    ; Perform the pixel search
    if (PixelSearch(&foundX, &foundY, x1, y1, x2, y2, targetColor, 0)) {
        ; Color found, click on the detected coordinates
        FixClick(foundX, foundY, "Right")
        AddToLog("Color found and clicked at: X" foundX " Y" foundY)
        return true

    }
}

FindAndClickImage(imagePath, searchArea := [0, 0, A_ScreenWidth, A_ScreenHeight]) {

    AddToLog(imagePath)

    ; Extract the search area boundaries
    x1 := searchArea[1], y1 := searchArea[2], x2 := searchArea[3], y2 := searchArea[4]

    ; Perform the image search
    if (ImageSearch(&foundX, &foundY, x1, y1, x2, y2, imagePath)) {
        ; Image found, click on the detected coordinates
        FixClick(foundX, foundY, "Right")
        AddToLog("Image found and clicked at: X" foundX " Y" foundY)
        return true
    }
}

FindAndClickText(textToFind, searchArea := [0, 0, GetWindowCenter(rblxID).Width, GetWindowCenter(rblxID).Height]) {
    ; Extract the search area boundaries
    x1 := searchArea[1], y1 := searchArea[2], x2 := searchArea[3], y2 := searchArea[4]

    ; Perform the text search
    if (FindText(&foundX, &foundY, x1, y1, x2, y2, textToFind)) {
        ; Text found, click on the detected coordinates
        FixClick(foundX, foundY, "Right")
        AddToLog("Text found and clicked at: X" foundX " Y" foundY)
        return true
    }
}

OpenGithub() {
    Run("https://github.com/" repoOwner "/" repoName)
}

OpenDiscord() {
    Run("https://discord.gg/rynsrealm")
}

StringJoin(array, delimiter := ", ") {
    result := ""
    ; Convert the array to an Object to make it enumerable
    for index, value in array {
        if (index > 1)
            result .= delimiter
        result .= value
    }
    return result
}

CopyMouseCoords(withColor := false) {
    MouseGetPos(&x, &y)
    color := PixelGetColor(x, y, "RGB")  ; Correct usage in AHK v2

    A_Clipboard := ""  ; Clear clipboard
    ClipWait(0.5)

    if (withColor) {
        A_Clipboard := x ", " y " | Color: " color
    } else {
        A_Clipboard := x ", " y
    }

    ClipWait(0.5)

    ; Check if the clipboard content matches the expected format

    if (withColor) {
        if (A_Clipboard = x ", " y " | Color: " color) {
            AddToLog("Copied: " x ", " y " | Color: " color)
        }
    } 
    else {
        if (A_Clipboard = x ", " y) {
            AddToLog("Copied: " x ", " y)
        }
    }
}

CalculateElapsedTime(startTime) {
    elapsedTimeMs := A_TickCount - startTime
    elapsedTimeSec := Floor(elapsedTimeMs / 1000)
    elapsedHours := Floor(elapsedTimeSec / 3600)
    elapsedMinutes := Floor(Mod(elapsedTimeSec, 3600) / 60)
    elapsedSeconds := Mod(elapsedTimeSec, 60)
    return Format("{:02}:{:02}:{:02}", elapsedHours, elapsedMinutes, elapsedSeconds)
}

GetPixel(color, x1, y1, extraX, extraY, variation) {
    global foundX, foundY
    try {
        if PixelSearch(&foundX, &foundY, x1, y1, x1 + extraX, y1 + extraY, color, variation) {
            return [foundX, foundY] AND true
        }
        return false
    }
}

Teleport(mode := "") {
    FixClick(33, 340) ; Open teleport menu
    Sleep 500
    switch mode {
        case "Dungeon":
            FixClick(407, 382) ; Click on Dungeon
        case "Story":
            FixClick(393, 329) ; Click on Story
        case "Raid":
            FixClick(531, 206) ; Move mouse to scroll down
            Sleep (500)
            Scroll(20, 'WheelDown', 5)
            Sleep 1000
            FixClick(407, 382)
        default:
            AddToLog("Invalid teleport mode specified")
    }
    Sleep 500
    FixClick(33, 340) ; Close the teleport menu
    Sleep(1000)
}

Scroll(times, direction, delay) {
    if (times < 1) {
        if (debugMessages) {
            AddToLog("Invalid number of times")
        }
        return
    }
    if (direction != "WheelUp" and direction != "WheelDown") {
        if (debugMessages) {
            AddToLog("Invalid scroll direction: " direction)
        }
        return
    }
    if (delay < 0) {
        if (debugMessages) {
            AddToLog("Invalid delay: " delay)
        }
        return
    }
    loop times {
        Send("{" direction "}")
        Sleep(delay)
    }
}

RotateCameraAngle() {
    Send("{Right down}")
    Sleep 800
    Send("{Right up}")
}

CloseLobbyPopups() {
    CloseLeaderboard(true)
    Sleep(500)
    FixClick(400, 340)
    FixClick(400, 390)
    if (CheckForNotification()) {
        ClickUntilGone(0, 0, 748, 94, 778, 551, ExitNotification, -3)
        Sleep (1000)
    }
}

ClickUnit(slot) {
    global totalUnits
    baseX := 585
    baseY := 175
    colSpacing := 80
    rowSpacing := 115
    maxCols := 3

    totalCount := 0
    for _, count in totalUnits {
        totalCount += count
    }

    fullRows := Floor(totalCount / maxCols)
    lastRowUnits := Mod(totalCount, maxCols)

    index := slot - 1
    row := Floor(index / maxCols)
    colInRow := Mod(index, maxCols)
    isLastRow := (row = fullRows)

    if (lastRowUnits != 0 && isLastRow) {
        rowStartX := baseX + Floor((maxCols - lastRowUnits) * colSpacing / 2)
        clickX := rowStartX + (colInRow * colSpacing)
    } else {
        clickX := baseX + (colInRow * colSpacing)
    }

    clickY := baseY + (row * rowSpacing)

    OpenMenu("Unit Manager")
    Sleep(500)

    if (CheckForXp()) {
        CloseMenu("Unit Manager")
        return MonitorStage()
    }

    FixClick(clickX, clickY)
    Sleep(150)
}

CloseMenu(name := "") {
    if (!name)
        return

    key := ""
    clickX := 0, clickY := 0
    if (name = "Unit Manager")
        key := "F"
    else if (name = "Ability Manager")
        key := "Z"

    if (!key)
        return  ; Unknown menu name

    if (isMenuOpen(name)) {
        AddToLog("Closing " name)
        Send(key)  ; Close menu if it's open
        Sleep(300)
    }
}

OpenMenu(name := "") {
    static menuKeys := Map(
        "Unit Manager", "F"
    )

    if !name || !menuKeys.Has(name)
        return  ; Invalid or unknown menu

    key := menuKeys[name]

    if isMenuOpen(name)
        return true  ; Already open

    AddToLog("Opening " name)

    maxAttempts := 3
    delay := 700  ; ms between checks

    loop maxAttempts {
        Send(key)
        if WaitForMenuOpen(name, delay) {
            AddToLog("✅ " name " opened after " A_Index " attempt(s).")
            return true
        }
        Sleep(150)  ; small pause before retrying
    }

    AddToLog("⚠️ Failed to open " name " after " maxAttempts " attempts.")
    return false
}

WaitForMenuOpen(name, timeout := 700) {
    start := A_TickCount
    while (A_TickCount - start < timeout) {
        if isMenuOpen(name)
            return true
        Sleep(50)
    }
    return false
}

CleanString(str) {
    ; Remove emojis and any adjacent spaces (handles gaps)
    return RegExReplace(str, "\s*[^\x00-\x7F]+\s*", "")
}

OnPriorityChange(type, priorityNumber, newPriorityNumber) {
    if (newPriorityNumber == "") {
        newPriorityNumber := "Disabled"
    }
    if (type == "Placement") {
        AddToLog("Placement priority changed: Slot " priorityNumber " → " newPriorityNumber)
    } else {
        AddToLog("Upgrade priority changed: Slot " priorityNumber " → " newPriorityNumber)
    }
}

CheckForCardSelection() {
    if (ok := FT(&cardX, &cardY, 270, 127, 532, 161, 0, 0, pick_card)) {
        SelectCardsByMode()
        return true
    }
    return false
}

SearchForImage(X1, Y1, X2, Y2, image) {
    if !WinExist(rblxID) {
        AddToLog("Roblox window not found.")
        return false
    }

    WinActivate(rblxID)

    return ImageSearch(&FoundX, &FoundY, X1, Y1, X2, Y2, image)
}

OpenCardConfig() {
    if (EventDropdown.Text = "Halloween") {
        SwitchCardMode("Halloween")
    }
    else {
        AddToLog("No card configuration available for mode: " (ModeDropdown.Text = "" ? "None" : ModeDropdown.Text))
    }
}

AddWaitingFor(action) {
    global waitingState, waitingForClick
    waitingState := action
    waitingForClick := true
}

WaitingFor(action) {
    global waitingState
    if (waitingState = action) {
        return true
    }
    return false
}

RemoveWaiting() {
    global waitingState, waitingForClick
    waitingForClick := false
    waitingState := ""
}

CheckUnitAbilities() {
    global successfulCoordinates, maxedCoordinates

    AddToLog("Checking auto abilities of placed units...")

    for coord in successfulCoordinates {

        slot := coord.slot

        if (CheckForXp()) {
            AddToLog("Stopping auto ability check because the game ended")
            return MonitorStage()
        }

        if (CheckForCardSelection()) {
            SelectCardsByMode()
        }

        FixClick(coord.x, coord.y)
        Sleep(500)

        HandleAutoAbility()
    }
}

; Global variable to track current coordinate mode (default is Screen)
global currentCoordMode := "Screen"
global oldCoordMode := ""

; Wrapper function to set coord mode and save state
SetCoordModeTracked(mode) {
    global currentCoordMode, oldCoordMode
    oldCoordMode := currentCoordMode
    CoordMode("Mouse", mode)
    currentCoordMode := mode
}

isConnectedToInternet() {
    return DllCall("Wininet.dll\InternetGetConnectedState", "int*", 0, "int", 0)
}

GetPrivateServerCode(link) {
    if RegExMatch(link, "privateServerLinkCode=([\w-]+)", &m)
        return m[1]
    return ""
}

UpdateActiveConfiguration(*) {
    ToggleControlGroup(ConfigurationDropdown.Text)
}

CloseLeaderboard(clickFailsafe := true) {
    if (ok := FT(&X, &Y, 480, 62, 651, 84, 0.15, 0.15, OpenLeaderboard)) {
        SendInput("{Tab}")
    } else {
        if (clickFailsafe) {
            FixClick(564, 72)
            FixClick(641, 72)
        }
    }
}

ClaimBingo() {
    ; Base starting coordinate
    startX := 190
    startY := 420

    ; Number of clicks in each direction
    horizontalClicks := 6
    verticalClicks := 6

    ; Spacing in pixels between clicks
    spacing := 50

    while (true) {
        ; --- Redeem Stamp ---
        loop 25 {
            FixClick(543, 423)
        }

        ; --- Horizontal row ---
        loop horizontalClicks {
            FixClick(startX + (A_Index - 1) * spacing, startY)
        }

        ; --- Vertical column ---
        finalX := startX + (horizontalClicks - 1) * spacing
        loop verticalClicks {
            FixClick(finalX, startY - (A_Index - 1) * spacing)
        }

        ; --- Claim Bingo ---
        FixClick(543, 423)
        Sleep(1500)
    }
}

class Region {
    __New(x1, y1, x2, y2) {
        this.x1 := x1
        this.y1 := y1
        this.x2 := x2
        this.y2 := y2
    }

    GetAbsCoords(&X1, &Y1, &X2, &Y2) {
        if !WinExist(rblxID)
            return false

        WinGetPos &winX, &winY, &winW, &winH, rblxID

        X1 := winX + this.x1
        Y1 := winY + this.y1
        X2 := winX + this.x2
        Y2 := winY + this.y2

        return true
    }

    ; ---------- PixelSearch wrapper ----------
    Pixel(&outX := "", &outY := "", color := 0, variation := 10) {
        if !this.GetAbsCoords(&X1, &Y1, &X2, &Y2)
            return false

        return PixelSearch(&outX, &outY, X1, Y1, X2, Y2, color, variation)
    }

    ; ---------- FindText wrapper ----------
    FindTextMatch(&outX := "", &outY := "", text := "", s1 := 0.20, s2 := 0.20) {
        if !this.GetAbsCoords(&X1, &Y1, &X2, &Y2) {
            return false
        }

        return FindText(&outX, &outY, X1, Y1, X2, Y2, s1, s2, text)
    }
}

WinBoundFindText(&outX, &outY, X1, Y1, X2, Y2, s1, s2, text) {

    WinGetPos &winX, &winY, &winW, &winH, rblxID

    ; Convert to window-relative offsets
    relX1 := X1 - winX
    relY1 := Y1 - winY
    relX2 := X2 - winX
    relY2 := Y2 - winY

    ; Call Region-based FindText temporarily
    searchRegion := Region(relX1, relY1, relX2, relY2)
    return searchRegion.FindTextMatch(&outX, &outY, text, s1, s2)
}

WinBoundPixel(&outX, &outY, X1, Y1, X2, Y2, color, variation := 10) {
    WinGetPos &winX, &winY, &winW, &winH, rblxID
    relX1 := X1 - winX
    relY1 := Y1 - winY
    relX2 := X2 - winX
    relY2 := Y2 - winY

    searchRegion := Region(relX1, relY1, relX2, relY2)
    return searchRegion.Pixel(&outX, &outY, color, variation)
}

ShowRegion(x, y, w, h, ms := 2000) {
    g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
    g.BackColor := "Red"
    g.Show("x" x " y" y " w" w " h" h " NoActivate")
    WinSetTransparent(110, g)
    SetTimer(() => g.Destroy(), -ms)
}

ShowRegionByCoords(x1, y1, x2, y2, ms := 2000, winTitle := "") {
    if (winTitle != "") {
        WinGetClientPos(&cx, &cy, , , winTitle)
        x1 += cx, x2 += cx
        y1 += cy, y2 += cy
    }
    ShowRegion(x1, y1, x2 - x1, y2 - y1, ms)
}


CaptchaDetect(x1, y1, x2, y2, inputX, inputY, clientRel := true, sendInput := true, resultEdit := false) {
    ; Send messages to ResultEdit when requested
    LogResult(message) {
        if resultEdit
            ResultEdit.Value .= message "`n"
        else
            AddToLog(message)
    }

    LogResult("Checking for numbers...")
    lastError := "", lastRead := ""

    loop 10 {
        try {
            number := ReadCaptchaNumber(x1, y1, x2, y2, clientRel, &text)
            if (text != "")
                LogResult("Captcha text: [" text "]")

            ; Only trust a number read the same way twice in a row - a single misread digit fails the captcha
            if (number != "" && number = lastRead) {
                LogResult("Detected captcha: " number)

                if !sendInput
                    return true

                Loop 2 {
                    FixClick(inputX, inputY)
                    Sleep(300)
                }
                Send("^a{Backspace}") ; Clear anything left in the box from an earlier try

                for digit in StrSplit(number) {
                    Send(digit)
                    Sleep(120)
                }

                Sleep(200)
                ; Typed, not accepted - SolveCaptcha checks whether the game took it
                LogResult("Typed captcha: " number)
                return number
            }
            lastRead := number
        } catch as e {
            if (e.Message != lastError) {
                LogResult("OCR error: " e.Message)
                lastError := e.Message
            }
        }

        Sleep(200)
    }

    LogResult("Could not detect valid captcha after 10 attempts.")
    return false
}

; OCRs the captcha area and returns the 5-7 digit number on its first line, or "" if there isn't one.
; `text` gets the raw OCR text
ReadCaptchaNumber(x1, y1, x2, y2, clientRel := true, &text := "") {
    x := Min(x1, x2), y := Min(y1, y2)
    w := Abs(x2 - x1), h := Abs(y2 - y1)
    if clientRel {
        WinGetClientPos(&rX, &rY, , , rblxID)
        x += rX, y += rY
    }
    result := OCR.FromRect(x, y, w, h, {
        grayscale: true,
        scale: 2.0,
        monochrome: 128,
        invertcolors: false
    })
    text := result ? Trim(result.Text, " `t`r`n") : ""
    if (text = "")
        return ""
    firstLine := StrSplit(text, "`n", "`r")[1]
    ; Correct common OCR confusion between O and 0
    firstLine := StrReplace(StrReplace(firstLine, "O", "0"), "o", "0")
    number := RegExReplace(firstLine, "[^\d]")
    return (StrLen(number) >= 5 && StrLen(number) <= 7) ? number : ""
}

; Reads the captcha, types it, presses Enter and checks the game took it: an accepted captcha closes, a
; wrong one stays up (or shows a new code). Tries up to 3 codes. Returns true only once it's accepted
SolveCaptcha(x1 := 235, y1 := 262, x2 := 569, y2 := 309, inputX := 400, inputY := 335, enterX := 300, enterY := 385) {
    loop 3 {
        typed := CaptchaDetect(x1, y1, x2, y2, inputX, inputY)
        if !typed
            return false
        FixClick(enterX, enterY)  ; Enter captcha

        ; Give the game a moment, then see if a code is still showing
        stillUp := false
        loop 4 {
            Sleep(500)
            try stillUp := (ReadCaptchaNumber(x1, y1, x2, y2) != "")
            catch
                stillUp := false
            if !stillUp
                break
        }
        if !stillUp {
            AddToLog("Captcha accepted")
            return true
        }
        AddToLog("Captcha " typed " was rejected - trying again (" A_Index "/3)")
    }
    AddToLog("Captcha failed 3 times")
    return false
}


DetectMapImageSearch() {
    AddToLog("Trying to determine map using Image Search")
    startTime := A_TickCount
    robloxWin := "ahk_exe RobloxPlayerBeta.exe"
    variation := 15   ; main tolerance, same as before
    passes := 0
    loadedAt := 0
    static unfinished := Map("Air Craft", true, "Hellish City", true) ; Only used if a tie-break fails

    ; Built once instead of every loop pass
    static loadingScreens := Map()
    if (!loadingScreens.Count) {
        loadingScreens := Map(
            ; Story Maps
            "Planet Greenie", [PlanetGreenieLoadingScreen],
            "Walled City", [WalledCityLoadingScreen],
            "Snowy Town", [SnowyTownLoadingScreen],
            "Sand Village", [SandVillageLoadingScreen],
            "Navy Bay", [NavyBayLoadingScreen],
            "Fiend City", [FiendCityLoadingScreen],
            "Spirit World", [SpiritWorldLoadingScreen],
            "Ant Kingdom", [AntKingdomLoadingScreen, AntKingdomLoadingScreen2, AntKingdomLoadingScreen3],
            "Magic Town", [MagicTownLoadingScreen],
            "Magic Hills", [MagicHillsLoadingScreen, MagicHillsLegendLoadingScreen, MagicHillsLegendLoadingScreenAct3, AntKingdomRaidLoadingScreen],
            "Haunted Academy", [HauntedAcademyLoadingScreen],
            "Alien Spaceship", [AlienSpaceshipLoadingScreen],
            "Space Center", [SpaceCenterLoadingScreen],
            "Fabled Kingdom", [FabledKingdomLoadingScreen, FabledKingdomLoadingScreen2],
            "Ruined City", [RuinedCityLoadingScreen],
            "Puppet Island", [PuppetIslandLoadingScreen],
            "Virtual Dungeon", [VirtualDungeonLoadingScreen],
            "Snowy Kingdom", [SnowyKingdomLoadingScreen],
            "Dungeon Throne", [DungeonThroneLoadingScreen],
            "Mountain Temple", [MountainTempleLoadingScreen],
            "Rain Village", [RainVillageLoadingScreen],
            "Shibuya District", [ShibuyaDistrictLoadingScreen],
            ; Legend Stages
            "Spirit Town", [SpiritTownTitle, SpiritTownLoadingScreen],
            ; Raids
            "Sacred Planet", [SacredPlanetLoadingScreen],
            "Strange Town", [StrangeTownLoadingScreen],
            "Cursed Festival", [CursedFestivalLoadingScreen],
            "Storm Hideout", [StormHideoutLoadingScreen],
            "Nightmare Train", [NightmareTrainLoadingScreen],
            "Future City", [FutureCityLoadingScreen],
            ; Event Maps
            "Assassin Park", [AssassinParkLoadingScreen],
            "Haunted Mansion", [HauntedMansionLoadingScreen],
            ; Unfinished Maps
            "Air Craft", [AirCraftLoadingScreen],
            "Hellish City", [HellishCityLoadingScreen]
        )
    }

    ; Returns true if any image of the map is found at the given tolerance
    MapMatches(patterns, cw, ch, tolerance) {
        for pattern in patterns {
            try {
                if (ImageSearch(&X, &Y, 0, 0, cw, ch, "*" tolerance " " pattern))
                    return true
            } catch as err {
                ; A bad file path only skips that image, not the rest of the map
                ;;AddToLog("ImageSearch error (" pattern "): " err.Message)
            }
        }
        return false
    }

    loop {
        CloseLeaderboard(false)

        ; Check if we waited more than 5 minutes for vote start
        if (A_TickCount - startTime > 300000) {
            if (CheckForLobbySettings() && !CheckIfIngame()) {
                AddToLog("Found in lobby - restarting selected mode")
                return StartSelectedMode()
            }
            AddToLog("Could not detect map after 5 minutes - proceeding without movement")
            return "no map found"
        }

        ; Loaded in - but some maps only show their name after loading (the "Spirit Town" title appears
        ; over the map once the Units button is up), so keep looking for 5 more seconds before giving up
        if (!loadedAt && HasLoadedIn())
            loadedAt := A_TickCount
        if (loadedAt && A_TickCount - loadedAt > 5000) {
            AddToLog("No map detected before loading in, moving on....")
            if (passes > 0)
                AddToLog("Saved what the loading screen looked like to Logs\MapDetect - send it to fix detection")
            return "no map found"
        }

        ; Most loading screens write the map's name top left ("Travelling to... Planet Greenie"). Reading it
        ; works even where the picture differs from the saved one (Infinity Castle shows other camera angles)
        if (named := ReadLoadingScreenMapName(loadingScreens)) {
            AddToLog("Detected Map: " named " (read from the loading screen)")
            return named
        }

        ; Client size is read once per pass, not once per image
        if (!WinExist(robloxWin)) {
            Sleep 1000
            Reconnect()
            continue
        }
        WinGetClientPos(, , &cw, &ch, robloxWin)

        ; Collect every map that matches instead of returning on the first hit
        matches := []
        for mapName, patterns in loadingScreens {
            if (MapMatches(patterns, cw, ch, variation))
                matches.Push(mapName)
        }

        if (matches.Length = 1) {
            AddToLog("Detected Map: " matches[1])
            return matches[1]
        }

        if (matches.Length > 1) {
            ; Tie-break: tighten the tolerance and keep only the maps that still match
            for tolerance in [8, 3, 0] {
                strict := []
                for mapName in matches {
                    if (MapMatches(loadingScreens[mapName], cw, ch, tolerance))
                        strict.Push(mapName)
                }
                if (strict.Length = 1) {
                    AddToLog("Detected Map: " strict[1] " (tie-break at *" tolerance ")")
                    return strict[1]
                }
                if (strict.Length > 1)
                    matches := strict
            }

            list := ""
            for m in matches
                list .= (list ? ", " : "") m

            ; Still tied at every tolerance - prefer a finished map (unfinished maps' images can show up on others)
            chosen := matches[1]
            for mapName in matches {
                if !unfinished.Has(mapName) {
                    chosen := mapName
                    break
                }
            }
            AddToLog("Loading screen matched several maps (" list ") - using " chosen)
            return chosen
        }

        ; Nothing matched - keep a picture of each try so a missing/outdated map image can be remade
        passes += 1
        SaveMapDetectFrame(passes)

        Sleep(loadedAt ? 300 : 1000)
        Reconnect()
    }
}

; Reads the map name under "Travelling to..." on the loading screen and matches it to a known map (the
; keys of `maps`). Returns "" if there's no readable name. OCR can drop or swap a letter, so small
; differences are allowed; a single word (the rest covered by a pop-up) only counts if just one map has it
ReadLoadingScreenMapName(maps) {
    try {
        WinGetClientPos(&cx, &cy, &w, &h, rblxID)
        sx := w / 800, sy := h / 600
        result := OCR.FromRect(cx + Round(8 * sx), cy + Round(50 * sy), Round(420 * sx), Round(70 * sy), { scale: 2.0 })
    } catch
        return ""
    if !result
        return ""
    for line in result.Lines {
        text := MapNameKey(line.Text)
        if (StrLen(text) < 5)
            continue
        best := "", bestDiff := 99
        for name in maps {
            key := MapNameKey(name)
            if (text = key || InStr(text, key))
                return name
            diff := EditDistance(text, key)
            if (diff < bestDiff)
                best := name, bestDiff := diff
        }
        if (bestDiff <= Max(1, StrLen(text) // 6))
            return best
        ; One word of the name - accept it only if no other map shares it
        hit := "", hits := 0
        for name in maps {
            for word in StrSplit(name, " ") {
                if (MapNameKey(word) = text) {
                    hit := name, hits += 1
                    break
                }
            }
        }
        if (hits = 1)
            return hit
    }
    return ""
}

MapNameKey(s) => StrLower(RegExReplace(s, "[^A-Za-z]"))

EditDistance(a, b) {
    la := StrLen(a), lb := StrLen(b)
    if (Abs(la - lb) > 4)
        return 99
    prev := []
    loop lb + 1
        prev.Push(A_Index - 1)
    loop la {
        i := A_Index
        cur := [i]
        ca := SubStr(a, i, 1)
        loop lb {
            j := A_Index
            cost := (ca = SubStr(b, j, 1)) ? 0 : 1
            cur.Push(Min(prev[j + 1] + 1, cur[j] + 1, prev[j] + cost))
        }
        prev := cur
    }
    return prev[lb + 1]
}

; Saves the Roblox window to Logs\MapDetect\try_N.png (the folder is emptied on the first try of each
; detection). Only the first 10 tries are kept
SaveMapDetectFrame(pass) {
    if (pass > 10)
        return
    dir := A_ScriptDir "\Logs\MapDetect"
    try {
        if (pass = 1 && DirExist(dir))
            DirDelete(dir, true)
        DirCreate(dir)
        WinGetClientPos(&cx, &cy, &w, &h, rblxID)
    } catch
        return
    pToken := Gdip_Startup()
    if !pToken
        return
    try {
        pBitmap := Gdip_BitmapFromScreen(cx "|" cy "|" w "|" h)
        if pBitmap
            Gdip_SaveBitmapToFile(pBitmap, dir "\try_" pass ".png")
    } finally {
        if (IsSet(pBitmap) && pBitmap)
            Gdip_DisposeImage(pBitmap)
        Gdip_Shutdown(pToken)
    }
}

WaitAndCheck(ms, findText, x1 := 0, y1 := 0, x2 := A_ScreenWidth, y2 := A_ScreenHeight) {
    global X, Y

    start := A_TickCount

    while (A_TickCount - start < ms) {
        if (FT(&X, &Y, x1, y1, x2, y2, 0.10, 0.10, findText))
            return false

        Sleep(50)
    }

    return true
}

; Releases any held movement keys
StopMovement() {
    SendInput("{w up}{a up}{s up}{d up}")
}

CheckForNotification() {
    return FT(&X, &Y, 748, 94, 778, 551, 0, 0, ExitNotification) ? true : false
}

CheckAllGameOptions(&report := "") {
    report := ""
    foundAny := false

    ; Each option now uses its own FT definition
    options := [
    { name: "Next Level", ft: NextLevel },
    { name: "Next Room", ft: NextRoom },
    { name: "Replay", ft: Replay },
    { name: "Return to Lobby", ft: ReturnToLobby },
    { name: "Retry", ft: Retry }]

    for opt in options {
        if (FT(&X, &Y, 137, 94, 663, 147, 0, 0, opt.ft)) {
            report .= "✓ " opt.name " is available`n"
            foundAny := true
        } else {
            report .= "✗ " opt.name " is NOT available`n"
        }
    }

    if !foundAny
        report := "No game-over options detected.`n"

    return foundAny
}

ClickUntilGone(x, y, searchX1, searchY1, searchX2, searchY2, textToFind, offsetX := 0, offsetY := 0, textToFind2 := "") {
    while (ok := FT(&X, &Y, searchX1, searchY1, searchX2, searchY2, 0.10, 0.10, textToFind) || textToFind2 && FT(&X, &Y,
        searchX1, searchY1, searchX2, searchY2, 0.10, 0.10, textToFind2)) {
        if (offsetX != 0 || offsetY != 0) {
            FixClick(X + offsetX, Y + offsetY)
        } else {
            FixClick(x, y)
        }
        Sleep(1000)
    }
}

ClickReplay() {
    if (!WaitAndCheck(7500, Replay, 139, 99, 660, 144) || !WaitAndCheck(7500, Retry, 139, 99, 660, 144)) {
        return ClickUntilGone(0, 0, 139, 99, 660, 144, Replay, 0.10, 0.10) || ClickUntilGone(0, 0, 139, 99, 660, 144, Retry, 0.10, 0.10)
    }
}

ClickNextLevel() {
    if (!WaitAndCheck(7500, NextLevel, 139, 99, 660, 144)) {
        AddToLog("Next level button detected, clicking...")
        return ClickUntilGone(0, 0, 139, 99, 660, 144, NextLevel, -5)
    }
}

ClickNextRoom() {
    if (!WaitAndCheck(7500, NextRoom, 139, 99, 660, 144)) {
        AddToLog("Next room button detected, clicking...")
        return ClickUntilGone(0, 0, 139, 99, 660, 144, NextRoom, -5)
    }
}

; After a win, reward pop-ups can come out one after another on top of the Return to Lobby button, and
; each one needs a click. So once the button has been found, keep clicking that same spot once a second
; until the lobby loads. Nothing is clicked before the button is found - other spots on this screen
; are buttons like Play Again
ClickReturnToLobby() {
    static lastSpot := ""  ; Where the button was last time, in case rewards cover it from the start
    spot := ""
    start := A_TickCount
    while (A_TickCount - start < 90000) {
        if CheckForLobby()
            return true
        if FT(&X, &Y, 80, 85, 739, 224, 0.10, 0.10, ReturnToLobby) {
            if (spot = "")
                AddToLog("Clicking Return to Lobby until the lobby loads")
            spot := lastSpot := { x: X, y: Y } ; FindText gives the centre of the button
        } else if (spot = "" && lastSpot != "" && A_TickCount - start > 5000) {
            AddToLog("Return to Lobby is covered - clicking where it was last time")
            spot := lastSpot
        }
        if (spot != "")
            FixClick(spot.x, spot.y)
        Sleep(1000)
    }
    AddToLog("Still not in the lobby after 90 seconds" (spot = "" ? " - the Return to Lobby button was never found" : ""))
    return false
}

CheckFirstRun() {
    firstRunFile := A_ScriptDir "\Settings\first_run.dat"

    if FileExist(firstRunFile)
        return

    OpenGuide()
    AddToLog("First time running detected, opening the setup guide.")

    ; Create the marker file so the guide won't open again.
    FileAppend("complete", firstRunFile)
}

HasLoadedIn() {
    if (ok := FT(&X, &Y, 301, 64, 503, 154, 0, 0, VoteStart)
    or FT(&X, &Y, 301, 64, 503, 154, 0, 0, VoteStartLaptop)
    or FT(&X, &Y, 0, 0, 742, 287, 832, 377, 0.10, 0.10, Units)
    or FT(&X, &Y, 0, 0, 1080, 1080, 0, 0, UnitManager)
    or PixelGetColor(320, 60) = 0x00EE00) {
        AddToLog("Successfully Loaded In")
        if (TeleportFailsafe.Value) {
            TimerManager.Clear("Teleport Failsafe")
        }
        return true
    }
    Reconnect()
    return false
}
