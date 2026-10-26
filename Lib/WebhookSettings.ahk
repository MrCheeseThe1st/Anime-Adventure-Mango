#Include %A_ScriptDir%\Lib\Discord-Webhook-master\lib\WEBHOOK.ahk
#Include %A_ScriptDir%\Lib\AHKv2-Gdip-master\Gdip_All.ahk

global WebhookURL := WebhookURLBox.Text
global webhook := ""
global currentStreak := 0
global lastResult := "none"
global Wins := 0
global loss := 0
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
    global currentStreak, Wins, loss, WebhookURL, webhook, macroStartTime
    
    ; Check if WebhookURL is initialized and valid
    if (!IsSet(WebhookURL) || WebhookURL = "" || !(WebhookURL ~= "i)^https?:\/\/discord\.com\/api\/webhooks\/(\d{18,19})\/[\w-]{68}$")) {
        AddToLog("Webhook URL is missing or invalid - skipping webhook")
        return
    }

    ; Build webhook object if not already initialized
    if !IsObject(webhook) {
        webhook := WebHookBuilder(WebhookURL)
    }

    ; Update streak
    UpdateStreak(isWin)
    
    ; Calculate macro runtime (total time)
    macroLength := FormatStageTime(A_TickCount - macroStartTime)
    
    ; Build session data
    totalRuns := Wins + loss
    winRate := totalRuns > 0 ? (Wins / totalRuns) * 100 : 0

    sessionData := "📊 **SESSION SUMMARY**`n"
        . "⌛ Macro Runtime: " macroLength "`n"
        . "⏱️ Stage Length: " stageLength "`n"

    ; Current map (only display when one is selected)
    if (currentMap != "")
        sessionData .= "🗺️ Current Map: " currentMap "`n"

    ; Mode
    sessionData .= ":video_game: Current Mode: "
        . (ModeDropdown.Text = ""
            ? "No Mode Selected"
                : GetTextForMode(ModeDropdown.Text)) "`n"

    ; Streak
    sessionData .= "🔥 Current Streak: "
        . (currentStreak > 0
            ? currentStreak " Win Streak"
                : currentStreak < 0
                    ? Abs(currentStreak) " Loss Streak"
                    : "No Active Streak") "`n"

    ; Results
    sessionData .= "`n📈 **RUN RESULTS**`n"
        . ":white_check_mark: Successful Runs: " Wins "`n"
        . "❌ Failed Runs: " loss "`n"
        . ":bar_chart: Total Runs: " totalRuns "`n"
        . ":scales: Win Rate: " Format("{:.1f}%", winRate)

    ; Embed color and status
    embedColor := isWin ? 0x0AB02D : 0xB00A0A
    embedStatus := isWin ? "win" : "lose"
    
    
    ; Send webhook
    WebhookScreenshot(
        isWin ? "Stage Complete!" : "Stage Failed",
        sessionData,
        isWin ? 0x0AB02D : 0xB00A0A,
        isWin ? "win" : "lose"
    )
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

WebhookScreenshot(title, description, color := 0x0dffff, status := "") {
    global webhook, WebhookURL, wins, loss, currentStreak, stageStartTime, rblxID, MainUI

    if (!IsSet(stageStartTime)) {
        stageStartTime := A_TickCount
    }

    if !(webhookURL ~= 'i)https?:\/\/discord\.com\/api\/webhooks\/(\d{18,19})\/[\w-]{68}') {
        return
    }

    footerText := GameTitle . version

    stageLength := CalculateElapsedTime(stageStartTime)
    stageMinutes := Floor((A_TickCount - stageStartTime) / (1000 * 60))

    UserIDSent := ""

    ; --- Roblox client area --- (if it can't be captured, the summary still goes out without a picture)
    if !WinExist(rblxID) || (WinGetMinMax(rblxID) = -1) {
        AddToLog("Webhook: Roblox window minimized or missing - sending the summary without a screenshot")
        return SendWebhookChecked(WebhookTextEmbed(title, description, color, footerText), "summary, no screenshot")
    }
    WinGetClientPos(&rX, &rY, &rW, &rH, rblxID)
    if (rW <= 0 || rH <= 0) {
        AddToLog("Webhook: Roblox window has no size - sending the summary without a screenshot")
        return SendWebhookChecked(WebhookTextEmbed(title, description, color, footerText), "summary, no screenshot")
    }

    ; Start with Roblox's rectangle
    left := rX, top := rY, right := rX + rW, bottom := rY + rH

    ; --- Expand to include the overlay window ---
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
        return SendWebhookChecked(WebhookTextEmbed(title, description, color, footerText), "summary, no screenshot")
    }

    sent := false
    try {
        pBitmap := Gdip_BitmapFromScreen(left . "|" . top . "|" . capW . "|" . capH)
        if pBitmap {
            attachment := AttachmentBuilder(pBitmap)
            myEmbed := WebhookTextEmbed(title, description, color, footerText)
            myEmbed.setImage(attachment)
            sent := SendWebhookChecked({ content: UserIDSent, embeds: [myEmbed], files: [attachment] }, "summary with screenshot")
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
        sent := SendWebhookChecked(WebhookTextEmbed(title, description, color, footerText), "summary, no screenshot")
    return sent
}

WebhookTextEmbed(title, description, color, footerText) {
    e := EmbedBuilder()
    e.setTitle(title)
    e.setDescription(description)
    e.setColor(color)
    e.setFooter({ text: footerText })
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