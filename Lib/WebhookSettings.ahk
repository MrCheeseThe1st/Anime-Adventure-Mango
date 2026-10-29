#Include %A_ScriptDir%\Lib\Discord-Webhook-master\lib\WEBHOOK.ahk
#Include %A_ScriptDir%\Lib\AHKv2-Gdip-master\Gdip_All.ahk

global WebhookURL := WebhookURLBox.Text
global WebhookGifURL := "https://klipy.com/gifs/i-i-wish-i-had-shiny"
global webhook := ""
global currentStreak := 0
global lastResult := "none"
global Wins := 0
global loss := 0
global Unknown := 0
global stageStartTime := A_TickCount
global macroStartTime := A_TickCount
global currentMap := ""

if (!FileExist("Settings")) {
    DirCreate("Settings")
}

; Function to update streak
UpdateStreak(isWin) {
    global currentStreak, lastResult, Wins, loss
    
    ; Initialize lastResult if it doesn't exist
    if (!IsSet(lastResult)) {
        lastResult := "none"
    }
    
    if (isWin) {
        Wins++
        if (lastResult = "win")
            currentStreak += 1
        else
            currentStreak := 1
    } else {
        loss++
        if (lastResult = "lose")
            currentStreak -= 1
        else
            currentStreak := -1
    }
    
    lastResult := isWin ? "win" : "lose"
}

SendWebhookWithTime(isWin, stageLength) {
    global currentStreak, Wins, loss, WebhookURL, webhook, macroStartTime, currentMap, ModeDropdown

    if (!IsSet(WebhookURL) || Trim(WebhookURL) = "") {
        AddToLog("Webhook Error: WebhookURL is not set or empty.")
        return
    }
    if (!(WebhookURL ~= "i)^https?://discord\.com/api/webhooks/(\d{18,19})/[\w-]{68}$")) {
        AddToLog("Webhook Error: Invalid Discord webhook URL format.")
        return
    }

    if !IsObject(webhook)
        webhook := WebHookBuilder(WebhookURL)

    UpdateStreak(isWin)

    macroLength := FormatStageTime(A_TickCount - macroStartTime)
    totalRuns := Wins + loss
    winRate := totalRuns > 0 ? Format("{:.1f}%", (Wins / totalRuns) * 100) : "0.0%"

    ; Streak text
    if (currentStreak > 0)
        streakText := currentStreak " Win Streak"
    else if (currentStreak < 0)
        streakText := Abs(currentStreak) " Loss Streak"
    else
        streakText := "None"

    modeText := (ModeDropdown.Text = "") ? "None" : GetTextForMode(ModeDropdown.Text)
    mapText := (currentMap != "") ? currentMap : "None"

    ; Color + Title
    embedColor := isWin ? 0x57F287 : 0xED4245
    title := isWin ? "✅ Stage Complete" : "❌ Stage Failed"

    ; Send with structured fields instead of a wall of text
    WebhookScreenshot(title, "", embedColor, isWin ? "win" : "lose", {
        macroLength: macroLength,
        stageLength: stageLength,
        map: mapText,
        mode: modeText,
        streak: streakText,
        wins: Wins,
        losses: loss,
        total: totalRuns,
        winRate: winRate
    })
}

CropImage(pBitmap, x, y, width, height) {
    ; Initialize GDI+ Graphics from the source bitmap
    pGraphics := Gdip_GraphicsFromImage(pBitmap)
    if !pGraphics {
        MsgBox("Failed to initialize graphics object")
        return
    }

    ; Create a new bitmap for the cropped image
    pCroppedBitmap := Gdip_CreateBitmap(width, height)
    if !pCroppedBitmap {
        MsgBox("Failed to create cropped bitmap")
        Gdip_DeleteGraphics(pGraphics)
        return
    }

    ; Initialize GDI+ Graphics for the new cropped bitmap
    pTargetGraphics := Gdip_GraphicsFromImage(pCroppedBitmap)
    if !pTargetGraphics {
        MsgBox("Failed to initialize graphics for cropped bitmap")
        Gdip_DisposeImage(pCroppedBitmap)
        Gdip_DeleteGraphics(pGraphics)
        return
    }

    ; Copy the selected area from the source bitmap to the new cropped bitmap
    Gdip_DrawImage(pTargetGraphics, pBitmap, 0, 0, width, height, x, y, width, height)

    ; Cleanup
    Gdip_DeleteGraphics(pGraphics)
    Gdip_DeleteGraphics(pTargetGraphics)

    ; Return the cropped bitmap
    return pCroppedBitmap
}

TextWebhook() {
    global lastlog, WebhookURL, webhook

    ; Check if WebhookURL is initialized and valid
    if (!IsSet(WebhookURL) || WebhookURL = "" || !(WebhookURL ~=
        "i)^https?:\/\/discord\.com\/api\/webhooks\/(\d{18,19})\/[\w-]{68}$")) {
        AddToLog("Webhook URL is missing or invalid - skipping webhook")
        return
    }

    ; Build webhook object if not already initialized
    if !IsObject(webhook) {
        webhook := WebHookBuilder(WebhookURL)
    }

    ; Calculate the runtime
    ElapsedTimeMs := A_TickCount - StartTime
    ElapsedTimeSec := Floor(ElapsedTimeMs / 1000)
    ElapsedHours := Floor(ElapsedTimeSec / 3600)
    ElapsedMinutes := Floor(Mod(ElapsedTimeSec, 3600) / 60)
    ElapsedSeconds := Mod(ElapsedTimeSec, 60)
    Runtime := Format("{} hours, {} minutes", ElapsedHours, ElapsedMinutes)

    ; Prepare the attachment and embed
    myEmbed := EmbedBuilder().setTitle("").setDescription("[" FormatTime(A_Now, "hh:mm tt") "] " lastlog).setColor(0x0077ff)
        

    ; Send the webhook
    webhook.send({
        content: (""),
        embeds: [myEmbed],
        files: []
    })

    ; Clean up resources
}

WebhookLog() {
    TextWebhook()
}

WebhookScreenshot(title, description := "", color := 0x57F287, status := "", stats := unset) {
    global webhook, WebhookURL, GameTitle, version, rblxID, MainUI, stageStartTime, WebhookGifURL

    if (!IsSet(stageStartTime))
        stageStartTime := A_TickCount

    if !(WebhookURL ~= "i)^https?://discord\.com/api/webhooks/(\d{18,19})/[\w-]{68}$")
        return

    footerText := GameTitle " • " version
    statsObj := (IsSet(stats) && IsObject(stats)) ? stats : ""

    ; --- Roblox client area --- (if it can't be captured, the summary still goes out without a picture)
    if !WinExist(rblxID) || (WinGetMinMax(rblxID) = -1) {
        AddToLog("Webhook: Roblox window minimized or missing - sending the summary without a screenshot")
        return SendWebhookChecked(WebhookTextEmbed(title, description, color, footerText, statsObj), "summary, no screenshot")
    }
    WinGetClientPos(&rX, &rY, &rW, &rH, rblxID)
    if (rW <= 0 || rH <= 0) {
        AddToLog("Webhook: Roblox window has no size - sending the summary without a screenshot")
        return SendWebhookChecked(WebhookTextEmbed(title, description, color, footerText, statsObj), "summary, no screenshot")
    }

    left := rX, top := rY, right := rX + rW, bottom := rY + rH

    if (IsSet(MainUI) && IsObject(MainUI) && WinExist("ahk_id " MainUI.Hwnd)) {
        WinGetPos(&oX, &oY, &oW, &oH, "ahk_id " MainUI.Hwnd)
        if (oW > 0 && oH > 0) {
            left := Min(left, oX)
            top := Min(top, oY)
            right := Max(right, oX + oW)
            bottom := Max(bottom, oY + oH)
        }
    }

    capW := right - left
    capH := bottom - top

    pToken := Gdip_Startup()
    if !pToken {
        AddToLog("Webhook: couldn't start the screenshot library - sending the summary without a screenshot")
        return SendWebhookChecked(WebhookTextEmbed(title, description, color, footerText, statsObj), "summary, no screenshot")
    }

    sent := false
    try {
        pBitmap := Gdip_BitmapFromScreen(left . "|" . top . "|" . capW . "|" . capH)
        if pBitmap {
            attachment := AttachmentBuilder(pBitmap)
            myEmbed := WebhookTextEmbed(title, description, color, footerText, statsObj)
            myEmbed.setImage(attachment)
            sent := SendWebhookChecked({ content: "", embeds: [myEmbed], files: [attachment] }, "summary with screenshot")
        } else {
            AddToLog("Webhook: screen capture failed")
        }
    } catch as e {
        AddToLog("Webhook: error while sending the screenshot - " e.Message)
    } finally {
        ; Always free the picture and the library, even if sending failed - otherwise later sends can break
        if (IsSet(pBitmap) && pBitmap)
            Gdip_DisposeImage(pBitmap)
        Gdip_Shutdown(pToken)
    }

    ; The screenshot version didn't go through - try once more with just the text
    if !sent
        sent := SendWebhookChecked(WebhookTextEmbed(title, description, color, footerText, statsObj), "summary, no screenshot")
    return sent
}

WebhookTextEmbed(title, description, color, footerText, stats := "") {
    e := EmbedBuilder()
    e.setTitle(title)
    e.setColor(color)
    e.setThumbnail({
        url: "https://static2.klipy.com/ii/d7aec6f6f171607374b2065c836f92f4/b3/69/Is3AxyCv.gif"
    })
    e.setFooter({ text: footerText })

    if IsObject(stats) {
        e.addFields([{ name: "⏱ Runtime", value: "``" stats.macroLength "``", inline: true }, { name: "⏱ Stage Runtime",
            value: "``" stats.stageLength "``", inline: true }, { name: "🔥 Streak", value: "``" stats.streak "``", inline: true }, { name: "🗺️ Map / Mode",
                value: "``" stats.map "``  •  ``" stats.mode "``", inline: false }, { name: "📊 Results", value: "✅ ``" stats
                    .wins "``   ❌ ``" stats.losses "``   📈 ``" stats.total "``   (``" stats.winRate "``)", inline: false }
        ])
    } else if (description != "") {
        e.setDescription(description)
    }
    return e
}

; Sends `payload` (an embed or a send() object) and checks Discord's reply - 200/204 means delivered.
; Every outcome is logged, so a summary that doesn't arrive shows up in the log with the reason
SendWebhookChecked(payload, what) {
    global webhook
    if (payload is EmbedBuilder)
        payload := { content: "", embeds: [payload] }
    try {
        res := webhook.send(payload)
    } catch as e {
        AddToLog("Webhook failed (" what "): " e.Message)
        return false
    }
    if (res.status = 200 || res.status = 204) {
        AddToLog("Webhook sent (" what ")")
        return true
    }
    AddToLog("Webhook failed (" what "): Discord replied " res.status " - " SubStr(RegExReplace(res.text, "\s+", " "), 1, 150))
    return false
}

SendWebhookRequest(webhook, params, maxRetries := 3) {
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("POST", webhook, false)
        whr.SetRequestHeader("Content-Type", "application/json")
        whr.Send(JSON.Stringify(params))
        AddToLog("Webhook sent successfully")
        return true
    } catch {
        AddToLog("Unable to send webhook - continuing without sending")
        return false
    }
}

sendDCWebhook() {
    MacroRuntime := CalculateElapsedTime(MacroStartTime)
    StageRuntime := CalculateElapsedTime(StageStartTime)

    ; Prepare the embed
    myEmbed := EmbedBuilder()
    myEmbed.setTitle(":exclamation: Client Disconnected :exclamation:")
    myEmbed.setDescription(":stopwatch: Disconnected At: " MacroRuntime "`n:stopwatch: Stage Runtime: " StageRuntime "")
    myEmbed.setColor(0xB00A0A)

    try {

        ; Check if WebhookURL is initialized and valid
        if (!IsSet(WebhookURL) || WebhookURL = "" || !(WebhookURL ~= "i)^https?:\/\/discord\.com\/api\/webhooks\/(\d{18,19})\/[\w-]{68}$")) {
            AddToLog("Webhook URL is missing or invalid - skipping webhook")
            return
        }

        ; Build webhook object if not already initialized
        if !IsObject(webhook) {
            webhook := WebHookBuilder(WebhookURL)
        }

    } catch {
        AddToLog("Webhook URL is not set or invalid.")
        return
    }

    ; Send the webhook
    try {
        Webhook.send({
            embeds: [myEmbed],
        })

        AddToLog("Sent webhook successfully")
    } catch {
        AddToLog("Failed to send webhook")
    }

}

sendTestWebhook(isVictory := true, map := "") {
    global Wins := 1
    global currentMap := map
    SendWebhookWithTime(isVictory, 1)
}

GetTextForMode(mode) {
    switch mode {
        case "Event":
            return EventDropdown.Text " Event"
        default:
            return mode
    }
}

UpdateWebhookURL(*) {
    global WebhookURL, WebhookURLBox, WebhookEnabled
    WebhookURL := WebhookURLBox.Value
    if (!RegExMatch(WebhookURL, "^https://discord\.com/api/webhooks/.*")) {
        WebhookEnabled.Value := false
    }
}