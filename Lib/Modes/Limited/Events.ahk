#Requires AutoHotkey v2.0

StartEvent() {
    switch (EventDropdown.Text) {
        case "Fool's Hunt":
            StartFoolsHunt()
    }
}