#Requires AutoHotkey v2.0

; How many acts each stage supports
global LegendMaxActs := Map(
    "Magic Hills", 3,
    "Spirit Invasion", 6,
    "Space Center", 3,
    "Fabled Kingdom", 3,
    "Ruined City", 6,
    "Virtual Dungeon", 3,
    "Dungeon Throne", 3,
    "Rain Village", 3
)

StartLegendStage() {

    ; Get current map and act
    currentLegendMap := LegendDropDown.Text
    currentLegendAct := LegendActDropdown.Text

    ; Execute the movement pattern
    AddToLog("Moving to position for " currentLegendMap)
    StoryMovement()

    ; Start stage
    while !(ok := FT(&X, &Y, 325, 520, 489, 587, 0, 0, ModeCancel)) {
        StoryMovement()
    }

    AddToLog("Starting " currentLegendMap " - " currentLegendAct)
    StartLegend(currentLegendMap, currentLegendAct)
    if (MatchMaking.Value) {
        FindMatch()
    } else {
        PlayHere()
    }
    RestartStage()
}

StartLegend(map, act) {
    FixClick(705, 140) ; Select Legend Stages
    return StartContent(map, act, GetLegendMap, GetLegendAct, { x: 695, y: 225 }, { x: 290, y: 245 })
}

ClickStartLegend() {
    ClickUntilGone(0, 0, 313, 433, 489, 496, StartStoryButton)
}

GetLegendMap(map) {
    switch map {
        case "Magic Hills":
            return { x: 630, y: 240, scrolls: 0 }
        case "Spirit Invasion":
            return { x: 630, y: 290, scrolls: 0 }
        case "Space Center":
            return { x: 630, y: 340, scrolls: 0 }
        case "Fabled Kingdom":
            return { x: 630, y: 390, scrolls: 0 }
        case "Ruined City":
            return { x: 630, y: 350, scrolls: 1 }
        case "Virtual Dungeon":
            return { x: 630, y: 405, scrolls: 1 }
        case "Dungeon Throne":
            return { x: 630, y: 440, scrolls: 1 }
        case "Rain Village":
            return { x: 630, y: 405, scrolls: 2 }
    }
}

GetLegendAct(act) {
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
        case "Random":
            return GetRandomAct()
    }
}

GetRandomAct(map := "") {
    ; If no map is passed, try to use the currently selected one
    if (map = "")
        map := LegendDropDown.Text

    ; Get max acts for this map (default 6)
    maxActs := LegendMaxActs.Has(map) ? LegendMaxActs[map] : 6

    ; Build the pool of allowed acts
    acts := []

    ; Add only the acts that this map supports
    loop maxActs {
        acts.Push(GetLegendAct("Act " A_Index))
    }

    return acts[Random(1, acts.Length)]
}

TestAllLegendMaps() {
    ; List of all maps in the order you want to test them
    maps := [
        "Magic Hills",
        "Spirit Invasion",
        "Space Center",
        "Fabled Kingdom",
        "Ruined City",
        "Virtual Dungeon",
        "Dungeon Throne",
        "Rain Village"
    ]

    for mapName in maps {
        data := GetLegendMap(mapName)
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

    AddToLog("Finished testing all legend stage maps!")
}