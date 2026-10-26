#Requires AutoHotkey v2.0

; ============================================================================
;  WindowFollow.ahk  -  FindText that follows Roblox
; ----------------------------------------------------------------------------
;  All FindText search areas in this macro were captured with the GUI in the
;  top-left corner of the screen and Roblox at (offsetX, offsetY) = (-5, 1).
;  FindText always works in screen coordinates, so it only worked there.
;
;  FT() is used instead of FindText(&X, &Y, ...). It shifts the search area by
;  how far the Roblox window has moved from that original spot, then shifts the
;  found X/Y back. So every existing coordinate in the macro stays the same and
;  works wherever the window is.
;
;  Clicks, PixelGetColor, PixelSearch and ImageSearch use CoordMode "Client"
;  (relative to the active window) and already followed Roblox - unchanged.
;  The Roblox window must stay the same size (sizeDown() still enforces that).
; ============================================================================

; How far the Roblox window is from where the search areas were captured.
FT_GetOffset(&dx, &dy) {
    global rblxID, offsetX, offsetY
    dx := 0, dy := 0
    try {
        if WinExist(rblxID) {
            WinGetPos(&wx, &wy,,, rblxID)
            dx := wx - offsetX   ; original spot: GUI at (0, 0) + offsetX
            dy := wy - offsetY   ; original spot: GUI at (0, 0) + offsetY
        }
    }
}

; Screen position of the Roblox client area's top-left corner
FT_ClientOrigin(&cx, &cy, winTitle := "") {
    global rblxID
    cx := 0, cy := 0
    try WinGetClientPos(&cx, &cy, , , winTitle != "" ? winTitle : rblxID)
}

; Drop-in replacement for FindText. x1..y2 are CLIENT coordinates
; (exactly what SetRegion gives you). X/Y are returned in client coordinates too.
FT(&X := "", &Y := "", x1 := 0, y1 := 0, x2 := 0, y2 := 0, args*) {
    if (x1 = 0 && y1 = 0 && x2 = 0 && y2 = 0) {   ; whole screen, leave it
        return FindText(&X, &Y, 0, 0, 0, 0, args*)
    }
    FT_ClientOrigin(&cx, &cy)
    ok := FindText(&X, &Y, x1 + cx, y1 + cy, x2 + cx, y2 + cy, args*)
    if (ok && IsNumber(X) && IsNumber(Y))
        X -= cx, Y -= cy
    return ok
}

; Replacement for FindText().Click(X, Y, ...) when X/Y came from FT()
FTClick(x, y, args*) {
    FT_GetOffset(&dx, &dy)
    return FindText().Click(x + dx, y + dy, args*)
}

; Put the GUI in the middle of the main screen, then Roblox follows it
CenterMacroWindow() {
    global MainUI
    MonitorGetWorkArea(MonitorGetPrimary(), &left, &top, &right, &bottom)
    WinGetPos(,, &w, &h, "ahk_id " MainUI.hWnd)
    x := Max(left, left + (right - left - w) // 2)
    y := Max(top, top + (bottom - top - h) // 2)
    WinMove(x, y,,, "ahk_id " MainUI.hWnd)
}

; Drag the GUI by clicking anywhere on its background
SetupDraggableGui() {
    OnMessage(0x0201, MacroGui_OnLButtonDown)   ; WM_LBUTTONDOWN
    OnMessage(0x0232, MacroGui_OnMoveEnd)       ; WM_EXITSIZEMOVE (finished dragging)
}

MacroGui_OnLButtonDown(wParam, lParam, msg, hwnd) {
    global MainUI
    if (hwnd = MainUI.hWnd)
        PostMessage(0xA1, 2,,, "ahk_id " MainUI.hWnd)   ; start a normal window drag
}

MacroGui_OnMoveEnd(wParam, lParam, msg, hwnd) {
    global MainUI
    if (hwnd = MainUI.hWnd)
        moveRobloxWindow()   ; Roblox snaps back next to the GUI
}
