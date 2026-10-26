#Requires AutoHotkey v2.0

StartStoryMode() {
    
    ; Get current map and act
    currentStoryMap := StoryDropdown.Text
    currentStoryAct := StoryActDropdown.Text
        
    ; Execute the movement pattern
    AddToLog("Moving to position for " currentStoryMap)
    StoryMovement()
    
    ; Start stage
    while !(ok := FT(&X, &Y, 344, 506, 458, 540, 0, 0, ModeCancel)) {
        StoryMovement()
    }

    AddToLog("Starting " currentStoryMap " - " currentStoryAct)
    StartStory(currentStoryMap, currentStoryAct)
    ; Handle play mode selection
    if (StoryActDropdown.Text != "Infinity") {
        PlayHere()
    } else {
        if (MatchMaking.Value) {
            FindMatch()
        } else {
            PlayHere()
        }
    }
    RestartStage()
}

StartStory(map, act) {
    return StartContent(map, act, GetStoryMap, GetStoryAct, { x: 695, y: 225 }, { x: 300, y: 240 })
}

ClickStartStory() {
    ClickUntilGone(0, 0, 313, 433, 489, 496, StartStoryButton, 0, 0)
}

StoryMovement() {
    FixClick(85, 295)

    if !WaitAndCheck(1000, ModeCancel, 344, 506, 458, 540) {
        return false
    }

    SendInput("{w down}")
    if !WaitAndCheck(300, ModeCancel, 344, 506, 458, 540) {
        StopMovement()
        return false
    }
    SendInput("{w up}")

    if !WaitAndCheck(300, ModeCancel, 344, 506, 458, 540) {
        StopMovement()
        return false
    }

    SendInput("{d down}{w down}")
    if !WaitAndCheck(4500, ModeCancel, 344, 506, 458, 540) {
        StopMovement()
        return false
    }
    SendInput("{d up}{w up}")

    if !WaitAndCheck(500, ModeCancel, 344, 506, 458, 540) {
        StopMovement()
        return false
    }

    return true
}

GetStoryMap(map) {
    switch map {
        case "Planet Greenie": return { x: 695, y: 250, scrolls: 0 }
        case "Walled City": return { x: 695, y: 305, scrolls: 0 }
        case "Snowy Town": return { x: 695, y: 355, scrolls: 0 }
        case "Sand Village": return { x: 695, y: 410, scrolls: 0 }

        case "Navy Bay": return { x: 695, y: 365, scrolls: 1 }
        case "Fiend City": return { x: 695, y: 415, scrolls: 1 }

        case "Spirit World": return { x: 695, y: 370, scrolls: 2 }
        case "Ant Kingdom": return { x: 695, y: 420, scrolls: 2 }

        case "Magic Town": return { x: 695, y: 375, scrolls: 3 }
        case "Haunted Academy": return { x: 695, y: 420, scrolls: 3 }

        case "Magic Hills": return { x: 695, y: 370, scrolls: 4 }
        case "Space Center": return { x: 695, y: 420, scrolls: 4 }

        case "Alien Spaceship": return { x: 695, y: 375, scrolls: 5 }
        case "Fabled Kingdom": return { x: 695, y: 425, scrolls: 5 }

        case "Ruined City": return { x: 695, y: 380, scrolls: 6 }
        case "Puppet Island": return { x: 695, y: 435, scrolls: 6 }

        case "Virtual Dungeon": return { x: 695, y: 315, scrolls: 8 }
        case "Snowy Kingdom": return { x: 695, y: 365, scrolls: 8 }
        case "Dungeon Throne": return { x: 695, y: 400, scrolls: 8 }

        case "Mountain Temple": return { x: 695, y: 290, scrolls: 10 }
        case "Rain Village": return { x: 695, y: 335, scrolls: 10 }
        case "Shibuya District": return { x: 695, y: 385, scrolls: 10 }
    }
}

GetStoryAct(act) {
    switch act {
        case "Infinity", "Infinite":
            return { x: 285, y: 235, scrolls: 0 }
        case "Act 1":
            return { x: 285, y: 270, scrolls: 0 }
        case "Act 2":
            return { x: 285, y: 305, scrolls: 0 }
        case "Act 3":
            return { x: 285, y: 340, scrolls: 0 }
        case "Act 4":
            return { x: 285, y: 385, scrolls: 0 }
        case "Act 5":
            return { x: 300, y: 350, scrolls: 1 }
        case "Act 6":
            return { x: 300, y: 385, scrolls: 1 }
    }
}

SelectDifficulty(name := "") {
    switch name {
        case "Normal":
            FixClick(270, 185)
        case "Nightmare":
            FixClick(270, 220)    
    }
    Sleep(1000)
}

WalkToStoryRoom(angle) {
    switch angle {
        case 1:
            SendInput("{a down}")
            Sleep(400)
            SendInput("{a up}")
            KeyWait "a"  ; Wait for the key to be fully processed
            SendInput("{s down}")
            Sleep(800)
            SendInput("{s up}")
            KeyWait "s"  ; Wait for the key to be fully processed
            SendInput("{a down}")
            Sleep(400)
            SendInput("{a up}")
            KeyWait "a"  ; Wait for the key to be fully processed
            Sleep (1000)
        case 2:
            SendInput("{d down}")
            Sleep(400)
            SendInput("{d up}")
            KeyWait "d"  ; Wait for the key to be fully processed
            Sleep (250)
            SendInput("{s down}")
            Sleep(2000)
            SendInput("{s up}")
            KeyWait "s"  ; Wait for the key to be fully processed   
            Sleep (1000) 
    }
}

TestAllStoryMaps() {
    ; List of all maps in the order you want to test them
    maps := [
        "Planet Greenie",
        "Snowy Town",
        "Sand Village",
        "Navy Bay",
        "Fiend City",
        "Spirit World",
        "Ant Kingdom",
        "Magic Town",
        "Haunted Academy",
        "Magic Hills",
        "Space Center",
        "Alien Spaceship",
        "Fabled Kingdom",
        "Ruined City",
        "Puppet Island",
        "Virtual Dungeon",
        "Snowy Kingdom",
        "Dungeon Throne",
        "Mountain Temple",
        "Rain Village",
        "Shibuya District"
    ]

    for mapName in maps {
        data := GetStoryMap(mapName)
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

    AddToLog("Finished testing all story maps!")
}