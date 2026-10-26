#Requires AutoHotkey v2.0

; How many acts each stage supports
global RaidMaxActs := Map(
    "Ant Kingdom", 1,
    "Sacred Planet", 5,
    "Strange Town", 5,
    "Ruined City", 1,
    "Cursed Festival", 5,
    "Future City (Tyrant)", 5,
    "Storm Hideout", 5,
    "Future City", 1,
    "Nightmare Train", 1,
    "Sand Village", 1
)

StartRaidStage() {

    ; Get current map and act
    currentRaidMap := RaidDropdown.Text
    currentRaidAct := RaidActDropdown.Text

    ; Execute the movement pattern
    AddToLog("Moving to position for " currentRaidMap)
    RaidMovement()

    ; Start stage
    while !(ok := FT(&X, &Y, 344, 506, 458, 540, 0, 0, ModeCancel)) {
        RaidMovement()
    }

    AddToLog("Starting " currentRaidMap " - " currentRaidAct)
    StartRaid(currentRaidMap, currentRaidAct)
    if (MatchMaking.Value) {
        FindMatch()
    } else {
        PlayHere()
    }
    RestartStage()
}

StartRaid(map, act) {
    return StartContent(map, act, GetRaidMap, GetRaidAct, { x: 695, y: 225 }, { x: 290, y: 245 })
}

ClickStartRaid() {
    ClickUntilGone(0, 0, 313, 433, 489, 496, StartStoryButton)
}

GetRaidMap(map) {
    switch map {
        case "Ant Kingdom":
            return { x: 630, y: 240, scrolls: 0 }
        case "Sacred Planet":
            return { x: 630, y: 290, scrolls: 0 }
        case "Strange Town":
            return { x: 630, y: 340, scrolls: 0 }
        case "Ruined City":
            return { x: 630, y: 390, scrolls: 0 }
        case "Cursed Festival":
            return { x: 630, y: 350, scrolls: 1 }
        case "Future City (Tyrant)":
            return { x: 630, y: 405, scrolls: 1 }

        case "Storm Hideout":
            return { x: 630, y: 355, scrolls: 2 }
        case "Future City":
            return { x: 630, y: 405, scrolls: 2 }

        case "Nightmare Train":
            return { x: 630, y: 360, scrolls: 3 }
        case "Sand Village":
            return { x: 630, y: 410, scrolls: 3 } 
    }
}

GetRaidAct(act) {
    switch act {
        case "Act 1":
            return { x: 285, y: 235, scrolls: 0 }
        case "Act 2":
            return { x: 285, y: 270, scrolls: 0 }
        case "Act 3":
            return { x: 285, y: 305, scrolls: 0 }
        case "Act 4":
            return { x: 285, y: 340, scrolls: 0 }
        case "Act 5":
            return { x: 285, y: 385, scrolls: 0 }
        case "Act 6":
            return { x: 285, y: 395, scrolls: 0 }
    }
}

RaidMovement() {
    FixClick(765, 475) ; Click Area
    Sleep(300)
    FixClick(495, 410)
    Sleep(500)
    SendInput ("{a down}")
    Sleep(400)
    SendInput ("{a up}")
    Sleep(500)
    SendInput ("{w down}")
    Sleep(5000)
    SendInput ("{w up}")
}

TestAllRaidMaps() {
    ; List of all maps in the order you want to test them
    maps := [
        "Ant Kingdom",
        "Sacred Planet",
        "Strange Town",
        "Ruined City",
        "Cursed Festival",
        "Future City (Tyrant)",
        "Storm Hideout",
        "Future City",
        "Nightmare Train",
        "Sand Village"
    ]

    for mapName in maps {
        data := GetRaidMap(mapName)
        if !data {
            continue
        }

        if (!WinActive(rblxID)) {
            AddToLog("Stopped testing because the game window is no longer active.")
            return
        }

        AddToLog("Testing map: " mapName)

        ; Scroll down to the map
        ScrollDown(data.scrolls)

        ; Click the map
        FixClick(data.x, data.y)
        Sleep(800)

        ; Scroll all the way back up
        ScrollUp(data.scrolls)
        Sleep(400)
    }

    AddToLog("Finished testing all raid maps!")
}

; ---------- Helper functions ----------
ScrollDown(times) {
    loop times {
        SendInput("{WheelDown}")
        Sleep(150)
    }
}

ScrollUp(times) {
    loop times {
        SendInput("{WheelUp}")
        Sleep(150)
    }
}