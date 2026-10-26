#Requires AutoHotkey v2.0

HttpGet(url, timeoutMs := 8000) {
    req := ComObject("WinHttp.WinHttpRequest.5.1")
    req.SetTimeouts(timeoutMs, timeoutMs, timeoutMs, timeoutMs) ; resolve, connect, send, receive
    req.Open("GET", url, false)
    req.SetRequestHeader("User-Agent", "AHK-UpdateChecker")
    req.SetRequestHeader("Accept", "application/vnd.github+json")
    req.Send()
    return req
}

    ; Returns "Yes" (user clicked Update Now) or "No" (Later / X / Esc)
    ShowChangelogPopup(currentVer, latestVer, releaseTitle, notes) {
        result := "No"
        hovered := 0
        hoverMap := Map()

        ; --- Palette ---
        cBg := "11111B", cCard := "181825", cPill := "313244"
        cText := "CDD6F4", cMuted := "9399B2"
        cAccent := "89B4FA", cAccentHi := "B4D0FF"
        cGhost := "313244", cGhostHi := "45475A", cCloseHi := "F38BA8"

        W := 520, H := 506, pad := 24, inner := W - pad * 2

        curTxt := "v" RegExReplace(currentVer, "i)^v")
        newTxt := "v" RegExReplace(latestVer, "i)^v")

        ui := Gui("+AlwaysOnTop -Caption +Border", "Update Available")
        ui.BackColor := cBg
        ui.MarginX := 0
        ui.MarginY := 0

        ; --- Accent bar ---
        ui.AddText("x0 y0 w" W " h4 Background" cAccent)

        ; --- Close button ---
        ui.SetFont("s11 norm c" cMuted, "Segoe UI")
        closeBtn := ui.AddText("x" (W - 44) " y14 w32 h32 Center +0x200 Background" cBg, "✕")
        closeBtn.OnEvent("Click", (*) => Finish("No"))

        ; --- Title + subtitle (0x80 = no & accelerator, 0x4000 = end ellipsis) ---
        ui.SetFont("s17 c" cText, "Segoe UI Semibold")
        ui.AddText("x" pad " y20 w" (inner - 50) " h34 BackgroundTrans", "Update Available")
        ui.SetFont("s10 c" cMuted, "Segoe UI")
        ui.AddText("x" pad " y56 w" (inner - 50) " h20 +0x80 +0x4000 BackgroundTrans", releaseTitle)

        ; --- Version pill ---
        ui.SetFont("s10 bold c" cAccent, "Segoe UI")
        ui.AddText("x" pad " y92 w190 h28 Center +0x200 Background" cPill, curTxt "   →   " newTxt)

        ; --- Changelog ---
        ui.SetFont("s8 bold c" cMuted, "Segoe UI")
        ui.AddText("x" pad " y136 w200 BackgroundTrans", "WHAT'S NEW")
        ui.SetFont("s10 norm c" cText, "Segoe UI")
        edit := ui.AddEdit("x" pad " y158 w" inner " h244 ReadOnly -E0x200 -Tabstop +VScroll Background" cCard,
            FormatChangelog(notes))
        SendMessage(0xD3, 3, 14 | (14 << 16), edit)  ; EM_SETMARGINS: 14px left/right padding
        DllCall("uxtheme\SetWindowTheme", "Ptr", edit.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0) ; dark scrollbar

        ; --- Footer note ---
        ui.SetFont("s9 c" cMuted, "Segoe UI")
        ui.AddText("x" pad " y414 w" inner " BackgroundTrans", "Your Settings folder will be backed up and preserved.")

        ; --- Buttons ---
        ui.SetFont("s10 bold", "Segoe UI")
        updateBtn := ui.AddText("x" (W - pad - 170) " y446 w170 h40 Center +0x200 c11111B Background" cAccent,
        "Update Now")
        laterBtn := ui.AddText("x" (W - pad - 170 - 12 - 110) " y446 w110 h40 Center +0x200 c" cText " Background" cGhost,
        "Later")
        updateBtn.OnEvent("Click", (*) => Finish("Yes"))
        laterBtn.OnEvent("Click", (*) => Finish("No"))

        hoverMap[updateBtn.Hwnd] := [updateBtn, cAccent, cAccentHi]
        hoverMap[laterBtn.Hwnd] := [laterBtn, cGhost, cGhostHi]
        hoverMap[closeBtn.Hwnd] := [closeBtn, cBg, cCloseHi]

        ui.OnEvent("Escape", (*) => Finish("No"))
        ui.OnEvent("Close", (*) => Finish("No"))
        OnMessage(0x201, OnDrag)       ; WM_LBUTTONDOWN (drag by header)
        SetTimer(OnHover, 40)

        ; --- Show: rounded corners (Win11) + fade in ---
        ui.Show("w" W " h" H " Center Hide")
        DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", ui.Hwnd, "Int", 33, "Int*", 2, "Int", 4)
        SendMessage(0xB1, 0, 0, edit)  ; EM_SETSEL 0,0 so no text starts highlighted
        hwnd := ui.Hwnd
        DllCall("AnimateWindow", "Ptr", hwnd, "UInt", 180, "UInt", 0x80000) ; AW_BLEND
        WinActivate(hwnd)

        WinWaitClose(hwnd)
        return result

        ; ---------- helpers ----------
        Finish(choice) {
            result := choice
            SetTimer(OnHover, 0)
            OnMessage(0x201, OnDrag, 0)
            ui.Destroy()
        }

        OnDrag(wParam, lParam, msg, h) {
            if (h = ui.Hwnd && ((lParam >> 16) & 0xFFFF) < 84 * A_ScreenDPI / 96)
                PostMessage(0xA1, 2, , , "ahk_id " ui.Hwnd)  ; WM_NCLBUTTONDOWN + HTCAPTION
        }

        OnHover() {
            MouseGetPos(, , , &h, 2)
            if (h = hovered)
                return
            if hoverMap.Has(hovered)
                SetBtn(hoverMap[hovered], 2)
            if hoverMap.Has(h)
                SetBtn(hoverMap[h], 3)
            hovered := h
        }

        SetBtn(info, which) {
            info[1].Opt("+Background" info[which])
            info[1].Redraw()
        }
    }

    ; Turns GitHub markdown into clean plain text for the Edit control
    FormatChangelog(notes) {
        out := ""
        for raw in StrSplit(StrReplace(notes, "`r"), "`n") {
            line := RTrim(raw)
            indent := RegExMatch(line, "^(\s+)", &m) ? StrLen(m[1]) : 0
            line := Trim(line)

            if (line = "") {
                if (out != "" && SubStr(out, -3) != "`r`n`r`n")
                    out .= "`r`n"
                continue
            }

            ; strip bold, inline code, and links
            line := RegExReplace(line, "\*\*(.+?)\*\*", "$1")
            line := RegExReplace(line, "__(.+?)__", "$1")
            line := RegExReplace(line, "``(.+?)``", "$1")
            line := RegExReplace(line, "\[(.+?)\]\(.+?\)", "$1")

            if RegExMatch(line, "^#{1,6}\s*(.+)$", &h) {
                if (out != "" && SubStr(out, -3) != "`r`n`r`n")
                    out .= "`r`n"
                out .= StrUpper(h[1]) "`r`n"
            } else if RegExMatch(line, "^[-*+]\s+(.+)$", &b) {
                out .= (indent >= 2 ? "       ◦  " : "   •  ") b[1] "`r`n"
            } else {
                out .= line "`r`n"
            }
        }
        return Trim(out, "`r`n ")
    }

CheckForUpdates() {
    global repoOwner, repoName, version

    if (!UpdateChecker.Value) {
        return
    }

    ; --- Get latest release info from GitHub ---
    url := "https://api.github.com/repos/" repoOwner "/" repoName "/releases/latest"
    try {
        http := HttpGet(url)
        if (http.Status != 200) {
            AddToLog("❌ Failed to check for updates. HTTP " http.Status)
            AddToLog("Current Version: " version)
            return
        }
        release := JSON.parse(http.ResponseText)
        latestVersion := release["tag_name"]
        assets := release["assets"]
    } catch as e {
        AddToLog("❌ Update check failed: " e.Message)
        return
    }

    ; --- Read release title and description (changelog) ---
    releaseTitle := release.Has("name") ? release["name"] : latestVersion
    if release.Has("body") && release["body"] != ""
        releaseNotes := release["body"]
    else
        releaseNotes := "(No changelog or description provided for this release.)"

    ; Clean up for readability
    releaseNotes := StrReplace(releaseNotes, "`r", "")
    releaseNotes := StrReplace(releaseNotes, "`n`n", "`n")

    ; --- Compare versions ---
    comparison := VerCompare(version, latestVersion)

    if (comparison < 0) {
        MainUI.Opt("-AlwaysOnTop")

        ; --- Prompt user for update ---
        MsgBoxResult := ShowChangelogPopup(version, latestVersion, releaseTitle, releaseNotes)

        if (MsgBoxResult = "Yes") {
            AddToLog("⬇️ Accepted update, starting download...")

            if (assets.Length = 0) {
                MainUI.Opt("+AlwaysOnTop")
                AddToLog("⚠️ No release files found for version " latestVersion)
                return
            }

            ; --- Download the first asset ---
            downloadUrl := assets[1]["browser_download_url"]
            fileName := A_Temp "\" assets[1]["name"]
            Download(downloadUrl, fileName)

            ; --- Create a unique script-local temp extraction folder ---
            extractDir := A_ScriptDir "\update_extract_" A_TickCount
            DirCreate(extractDir)

            ; --- Extract update ZIP to this folder ---
            psCmd := Format('powershell -NoProfile -Command "Expand-Archive -Force ' '{}' ' ' '{}' '"', fileName,
                extractDir)
            RunWait(psCmd, , "Hide")

            ; --- Backup user Settings ---
            settingsDir := A_ScriptDir "\Settings"
            if DirExist(settingsDir) {
                backupDir := A_ScriptDir "\Settings_Backup_" version
                DirCreate(backupDir)
                DirCopy(settingsDir, backupDir, true)
                AddToLog("💾 Backed up settings...")
            }

            ; --- Delete old files but preserve key folders ---
            loop files, A_ScriptDir "\*.*", "R" {
                file := A_LoopFileFullPath

                if InStr(file, "\Settings\")
                    continue
                if InStr(file, "\Settings_Backup_")
                    continue
                if (file = A_ScriptFullPath)
                    continue
                if InStr(file, extractDir)
                    continue

                FileDelete(file)
            }

            ; --- Remove empty folders safely ---
            loop files, A_ScriptDir "\*", "DR" {
                dir := A_LoopFileFullPath

                if InStr(dir, "\Settings") || InStr(dir, "\Settings_Backup_") || InStr(dir, extractDir)
                    continue

                try DirDelete(dir, false)  ; delete only if empty, skip errors
                catch
                    continue
            }

            ; --- Keep the user's own settings: drop any settings file from the update they already have ---
            loop files, extractDir "\Settings\*.*", "R" {
                rel := SubStr(A_LoopFileFullPath, StrLen(extractDir) + 2)
                if FileExist(A_ScriptDir "\" rel)
                    FileDelete(A_LoopFileFullPath)
            }

            ; --- Copy new update contents ---
            DirCopy(extractDir, A_ScriptDir, true)
            AddToLog("✅ Update files copied successfully")

            ; --- Clean up temporary extraction folder ---
            try {
                DirDelete(extractDir, true)  ; true = recursive delete
            }


            Sleep(2000)
            Run(A_ScriptFullPath)
            ExitApp
        } else {
            MainUI.Opt("+AlwaysOnTop")
        }

    } else if (comparison > 0) {
        AddToLog("🚨 Your version is newer than the latest published (" latestVersion ")")
    } else {
        AddToLog("✅ You are already using the latest version (" version ")")
    }
}

; W.I.P (DON'T USE THIS YET)
OpenVersionDownloader() {
    global repoOwner, repoName, version, MainUI

    ; -------------------------------------------------
    ; 1. Fetch ALL releases from GitHub
    ; -------------------------------------------------
    url := "https://api.github.com/repos/" repoOwner "/" repoName "/releases"
    try {
        http := ComObject("MSXML2.XMLHTTP")
        http.Open("GET", url, false)
        http.Send()
        if (http.Status != 200)
            throw Error("HTTP " http.Status)

        releases := JSON.parse(http.responseText)
        if (!releases.Length)
            throw Error("No releases found")
    } catch as e {
        AddToLog("Failed to fetch releases: " e.Message)
        return
    }

    ; -------------------------------------------------
    ; 2. Build version dropdown (latest first)
    ; -------------------------------------------------
    versions := []
    versionMap := Map()  ; tag → release object

    for release in releases {
        tag := release["tag_name"]
        versions.Push(tag)
        versionMap[tag] := release
    }

    ; === MANUAL SORT: LATEST → OLDEST (works in ALL AHK v2.0 versions) ===
    loop (versions.Length - 1) {
        swapped := false
        loop (versions.Length - A_Index) {
            i := A_Index
            if (VerCompare(versions[i], versions[i + 1]) < 0) {
                ; Swap
                temp := versions[i]
                versions[i] := versions[i + 1]
                versions[i + 1] := temp
                swapped := true
            }
        }
        if (!swapped)
            break
    }

    ; -------------------------------------------------
    ; 3. Create Update GUI
    ; -------------------------------------------------
    MainUI.Opt("-AlwaysOnTop")
    UpdateGUI := Gui(, "Update Manager")
    UpdateGUI.AddText("w300", "Select a version to install:")
    ddl := UpdateGUI.AddDropDownList("w300 vSelectedVersion", versions)

    currentVersion := RegExReplace(version, "^v", "")
    found := false
    for i, item in versions {
        if (RegExReplace(item, "^v", "") = currentVersion) {
            ddl.Choose(i)
            found := true
            break
        }
    }
    if (!found)
        ddl.Choose(1)  ; fallback to latest

    UpdateGUI.AddText("w300 vStatus", "Ready.")

    btn := UpdateGUI.AddButton("w300", "Download && Install")
    btn.OnEvent("Click", (*) => InstallSelectedVersion())

    UpdateGUI.Show("AutoSize Center")

    ; -------------------------------------------------
    ; 4. Install Logic (shared for latest & older)
    ; -------------------------------------------------
    InstallSelectedVersion() {
        selected := UpdateGUI["SelectedVersion"].Text
        if (!selected) {
            UpdateGUI["Status"].Text := "Please select a version."
            return
        }

        release := versionMap[selected]
        assets := release["assets"]
        if (!assets.Length) {
            UpdateGUI["Status"].Text := "No downloadable files."
            return
        }

        ; Use first .zip or .exe
        asset := assets[1]
        downloadUrl := asset["browser_download_url"]
        fileName := A_Temp "\" asset["name"]

        UpdateGUI["Status"].Text := "Downloading " selected "..."

        try {
            Download(downloadUrl, fileName)
        } catch {
            UpdateGUI["Status"].Text := "Download failed."
            return
        }

        UpdateGUI["Status"].Text := "Installing " selected "..."
        InstallUpdate(fileName, selected, release)
    }

    ; -------------------------------------------------
    ; 5. Core Installer (used by both latest & older)
    ; -------------------------------------------------
    InstallUpdate(zipPath, newVersion, release) {
        ; --- Changelog ---
        notes := release.Has("body") ? release["body"] : "(No notes)"
        notes := StrReplace(notes, "`r", "")
        notes := StrReplace(notes, "`n`n", "`n")
        if StrLen(notes) > 1000
            notes := SubStr(notes, 1, 1000) " ... (truncated)"

        ; --- Confirm ---
        msg := Format(
            "Install v{}?`n`n{} `n`nSettings will be backed up.",
            newVersion, notes
        )
        if MsgBox(msg, "Confirm Install", "YesNo") != "Yes"
            return

        AddToLog("Installing v" newVersion "...")

        ; --- Extract ---
        extractDir := A_ScriptDir "\update_extract_" A_TickCount
        DirCreate(extractDir)

        psCmd := Format('powershell -NoProfile -Command "Expand-Archive -Force ' '{}' ' ' '{}' '"', zipPath, extractDir
        )
        try RunWait(psCmd, , "Hide")
        catch {
            UpdateGUI["Status"].Text := "Extraction failed."
            return
        }

        ; --- Backup Settings ---
        settingsDir := A_ScriptDir "\Settings"
        if DirExist(settingsDir) {
            backupDir := A_ScriptDir "\Settings_Backup_" version
            DirCreate(backupDir)
            DirCopy(settingsDir, backupDir, true)
            AddToLog("Backed up settings to " backupDir)
        }

        ; --- Replace files ---
        loop files, A_ScriptDir "\*.*", "R" {
            f := A_LoopFileFullPath
            if InStr(f, "\Settings\") || InStr(f, "\Settings_Backup_") || InStr(f, extractDir) || (f = A_ScriptFullPath
            )
                continue
            try FileDelete(f)
        }

        ; --- Copy new files ---
        DirCopy(extractDir, A_ScriptDir, true)
        AddToLog("Update installed: v" newVersion)

        ; --- Cleanup ---
        try DirDelete(extractDir, true)
        FileDelete(zipPath)

        ; --- Restart ---
        UpdateGUI["Status"].Text := "Restarting..."
        Sleep(1000)
        Run(A_ScriptFullPath)
        ExitApp
    }
}

TestChangelogPopup(*) {
    global repoOwner, repoName, version

    cleanVer := RegExReplace(version, "i)^v")
    base := "https://api.github.com/repos/" repoOwner "/" repoName "/releases/"
    release := ""

    ; Try the tag with and without a leading "v", then fall back to the latest release
    for endpoint in ["tags/" cleanVer, "tags/v" cleanVer, "latest"] {
        try {
            http := HttpGet(base endpoint)
            if (http.Status = 200) {
                release := JSON.parse(http.ResponseText)
                if (endpoint = "latest")
                    AddToLog("🧪 No release found for " version ", using latest instead")
                break
            }
        }
    }

    if (!IsObject(release)) {
        AddToLog("🧪 Test failed: couldn't fetch any release from GitHub")
        return
    }

    title := (release.Has("name") && release["name"] != "") ? release["name"] : release["tag_name"]
    notes := (release.Has("body") && release["body"] != "")
        ? release["body"]
        : "(No changelog or description provided for this release.)"
    notes := StrReplace(notes, "`r", "")

    choice := ShowChangelogPopup(version, release["tag_name"], title, notes)
    AddToLog("🧪 Test popup closed with: " choice " (nothing was downloaded)")
}
