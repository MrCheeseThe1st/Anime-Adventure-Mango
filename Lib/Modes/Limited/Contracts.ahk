#Requires AutoHotkey v2.0

global contractPageCounter := 0
global contractSwitchPattern := 0

StartContracts() {
    AddToLog("Starting Contracts")
    FixClick(33, 400)
    Sleep(2500)
    HandleContractJoin()
    Sleep(2500)
    RestartStage()
}

HandleContractJoin() {
    loop {
        selectedPage := ContractPageDropdown.Text
        joinType := ContractJoinDropdown.Text

        ; Handle 4-5 Page pattern selection
        if (selectedPage = "Page 4-5") {
            selectedPage := GetContractPage()
            AddToLog("Pattern selected: " selectedPage)
        }

        pageNum := selectedPage = "Page 4-5" ? GetContractPage() : selectedPage
        pageNum := Integer(RegExReplace(RegExReplace(pageNum, "Page\s*", ""), "-.*", ""))

        ; Define click coordinates for each page
        clickCoords := Map(
            1, { openHere: { x: 170, y: 420 }, matchmaking: { x: 240, y: 420 } },  ; Example coords for page 1
            2, { openHere: { x: 330, y: 420 }, matchmaking: { x: 400, y: 420 } },  ; Example coords for page 2
            3, { openHere: { x: 490, y: 420 }, matchmaking: { x: 560, y: 420 } }, ; Example coords for page 3
            4, { openHere: { x: 237, y: 420 }, matchmaking: { x: 305, y: 420 } },  ; Example coords for page 4
            5, { openHere: { x: 397, y: 420 }, matchmaking: { x: 465, y: 420 } },  ; Example coords for page 5
            6, { openHere: { x: 557, y: 420 }, matchmaking: { x: 625, y: 420 } }  ; Example coords for page 6
        )

        ; First scroll if needed for pages 4-6
        if (pageNum >= 4) {
            FixClick(445, 300)
            Sleep(200)
            loop 5 {
                SendInput("{WheelDown}")
                Sleep(150)
            }
            Sleep(300)
        }

        if (TeamSwap.Value) {
            CheckBuffs()
        }
        Sleep 1500

        ; Get coordinates for the selected page
        pageCoords := clickCoords[pageNum]

        ; Handle different join types
        if (joinType = "Hosting") {
            AddToLog("Hosting contract portal on page " pageNum)
            FixClick(pageCoords.openHere.x, pageCoords.openHere.y)
            Sleep(300)
            FixClick(255, 355)
            Sleep(20000)
            AddToLog("Waiting 20 seconds for others to join")
            FixClick(400, 460)
        } else if (joinType = "Joining") {
            AddToLog("Attempting to join by holding E")
            SendInput("{e down}")
            Sleep(5000)
            SendInput("{e up}")
        } else if (joinType = "Solo") {
            if (MatchMaking.Value) {
                AddToLog("Joining matchmaking for contract on page " pageNum)
                FixClick(pageCoords.matchmaking.x, pageCoords.matchmaking.y)  ; Click matchmaking button
                Sleep(300)

                ; Try captcha
                if (!CaptchaDetect(252, 292, 300, 50, 400, 335)) {
                    AddToLog("Captcha not detected, retrying...")
                    FixClick(585, 190)  ; Click close
                    return
                }
                FixClick(300, 385)  ; Enter captcha

                startTime := A_TickCount
                while (A_TickCount - startTime < 20000) {  ; Check for 20 seconds
                    if !(ok := FT(&X, &Y, 746, 514, 789, 530, 0, 0, AreaText)) {
                        AddToLog("Area text gone - matchmaking successful")
                        return true
                    }
                    Sleep(200)  ; Check every 200ms
                }

                AddToLog("Matchmaking failed - still on area screen after 20s, retrying...")
                FixClick(445, 220)
                Sleep(1000)
                loop 5 {
                    SendInput("{WheelUp}")
                    Sleep(150)
                }
                Sleep(1000)
                continue ; retry (was: return HandleContractJoin())
            } else {
                FixClick(pageCoords.openHere.x, pageCoords.openHere.y)
                Sleep(300)
                FixClick(255, 355)
                Sleep(300)
                FixClick(400, 468) ; Start Contract
            }
        }
        return true
    }
}

HandleContractEnd() {
    global inChallengeMode, challengeStartTime

    loop {
        Sleep(800)

        ; Click to claim any drops/rewards
        FixClick(560, 560)

        if (isMenuOpen("Unit Placement")) {
            FixClick(329, 184) ; close upg menu
            Sleep(500)
        }

        if !WaitAndCheck(3000, NextText, 266, 376, 377, 413) {
            ClickUntilGone(0, 0, 266, 376, 377, 413, NextText)
            Sleep(1500)
        } else {
            FixClick(321, 387)
        }

        ; Check for both lobby texts
        if (ok := FT(&X, &Y, 80, 85, 739, 224, 0, 0, LobbyText) or (ok := FT(&X, &Y, 80, 85, 739, 224, 0, 0, LobbyText2))) {
            AddToLog("Found Lobby Text - proceeding with contract end options")
            Sleep(2000)  ; Wait for UI to settle

            if (inChallengeMode) {
                AddToLog("Challenge completed - returning to selected mode")
                inChallengeMode := false
                challengeStartTime := A_TickCount
                Sleep(1500)
                ClickUntilGone(0, 0, 80, 85, 739, 224, LobbyText, 0, -35, LobbyText2)
                return CheckLobby()
            }

          /*  ; Check if it's time for challenge mode
            if (!inChallengeMode && ChallengeBox.Value) {
                timeElapsed := A_TickCount - challengeStartTime
                if (timeElapsed >= 1800000) {  ; 30 minutes in milliseconds
                    AddToLog("30 minutes passed - switching to Challenge mode")
                    inChallengeMode := true
                    challengeStartTime := A_TickCount
                    Sleep(1500)
                    ClickUntilGone(0, 0, 80, 85, 739, 224, LobbyText, 0, -35, LobbyText2)
                    return NextStep(CheckLobby)
                }
            } */
            if (ReturnLobbyBox.Value) {
                AddToLog("Contract complete - returning to lobby")
                Sleep(1500)
                ClickReturnToLobby()
                CheckLobby()
                return StartSelectedMode()
            } else {
                AddToLog("Starting next contract")
                Sleep(1500)
                ClickNextContract()
                return HandleNextContract()
            }
        }
        Reconnect()
    }
}

ClickNextContract() {
    if (!WaitAndCheck(3000, NextContract, 403, 99, 576, 145)) {
        FixClick(490, 119)
    }
}

HandleNextContract() {
    selectedPage := ContractPageDropdown.Text
    if (selectedPage = "Page 4-5") {
        selectedPage := GetContractPage()
    }

    pageNum := Integer(RegExReplace(selectedPage, "Page ", ""))

    ; Define click coordinates to vote
    clickCoords := Map(
        1, { x: 205, y: 470 },
        2, { x: 365, y: 470 },
        3, { x: 525, y: 470 },
        4, { x: 272, y: 470 },
        5, { x: 432, y: 470 },
        6, { x: 592, y: 470 }
    )

    ; First scroll if needed for pages 4-6
    if (pageNum >= 4) {
        FixClick(400, 300)
        Sleep(200)
        loop 5 {
            SendInput("{WheelDown}")
            Sleep(150)
        }
        Sleep(300)
    }

    ; Click the Open Here button for the selected page
    AddToLog("Opening contract on page " selectedPage)
    FixClick(clickCoords[pageNum].x, clickCoords[pageNum].y)
    Sleep(500)

    return RestartStage()
}

GetContractPage() {
    global contractPageCounter, contractSwitchPattern

    if (contractSwitchPattern = 0) {  ; During page 4 phase
        contractPageCounter++
        if (contractPageCounter >= 6) {  ; After 6 times on page 4
            contractPageCounter := 0
            contractSwitchPattern := 1  ; Switch to page 5
            return "Page 5"
        }
        return "Page 4"
    } else {  ; During page 5 phase
        contractPageCounter := 0
        contractSwitchPattern := 0  ; Switch back to page 4 pattern
        return "Page 4"
    }
}

CheckBuffs() {
    contractPage := ContractPageDropdown.Text
    ; Handle 4-5 Page pattern selection
    if (contractPage = "Page 4-5") {
        contractPage := GetContractPage()
    }
    pages := [{ name: "Page 1", coords: [131, 232, 286, 477] }, { name: "Page 2", coords: [292, 232, 443, 477] }, { name: "Page 3",
        coords: [450, 231, 605, 477] }, { name: "Page 4", coords: [196, 229, 351, 477] }, { name: "Page 5", coords: [
            358, 229, 510, 477] }, { name: "Page 6", coords: [517, 232, 668, 476] },
    ]

    for index, page in pages {
        if (contractPage = page.name) {
            if (ok := FT(&X, &Y, page.coords[1], page.coords[2], page.coords[3], page.coords[4], 0, 0, PhysicalBuff)) {
                AddToLog("Found Physical Buff")
                Sleep 1000
                SwapTeam(false)
            } else {
                if (ok := FT(&X, &Y, page.coords[1], page.coords[2], page.coords[3], page.coords[4], 0, 0, MagicBuff)) {
                    AddToLog("Found Magic Buff")
                    Sleep 1000
                    SwapTeam(true)
                }
            }
        }
    }
}

SwapTeam(magic := false) {
    global physicalTeam, magicTeam
    teamNum := magic ? magicTeam.Text : physicalTeam.Text
    teamNum := Integer(RegExReplace(RegExReplace(teamNum, "", ""), "", ""))

    SendInput("K") ; Open Units
    Sleep 1000
    FixClick(398, 223) ; Click Teams
    Sleep 1000

    teams := [{ name: "1", coords: [556, 230] }, { name: "2", coords: [556, 320] }, { name: "3", coords: [556, 410] }, { name: "4",
        coords: [556, 256] }, { name: "5", coords: [566, 340] }, { name: "6", coords: [566, 427] },
    ]

    if (teamNum >= 3) {
        FixClick(390, 245)
        Sleep(200)
        loop 5 {
            SendInput("{WheelDown}")
            Sleep(150)
        }
        Sleep(300)
    }
    for index, team in teams {
        if (magic) {
            if (magicTeam.Text = team.name) {
                AddToLog("Equipped Magic Team")
                FixClick(team.coords[1], team.coords[2])
                Sleep 300
            }
        } else {
            if (physicalTeam.Text = team.name) {
                AddToLog("Equipped Physical Team")
                FixClick(team.coords[1], team.coords[2])
                Sleep 300
            }
        }
    }
    FixClick(33, 400) ; Reopen Contracts
    Sleep 1000
}