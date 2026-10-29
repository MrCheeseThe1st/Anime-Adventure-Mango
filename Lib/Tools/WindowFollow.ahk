#Requires AutoHotkey v2.0

; Screen position of the Roblox client area's top-left corner
GetClientOrigin(&cx, &cy, &cw := 0, &ch := 0, winTitle := "") {
    global rblxID
    cx := cy := cw := ch := 0
    winTitle := (winTitle != "") ? winTitle : rblxID
    if !WinExist(winTitle) || WinGetMinMax(winTitle) = -1
        return false
    WinGetClientPos(&cx, &cy, &cw, &ch, winTitle)
    return true
}

; Drop-in replacement for FindText. x1..y2 are CLIENT coordinates
FT(&X := "", &Y := "", x1 := 0, y1 := 0, x2 := 0, y2 := 0, args*) {
    if !GetClientOrigin(&cx, &cy, &cw, &ch)
        return 0

    if (x1 = 0 && y1 = 0 && x2 = 0 && y2 = 0)
        x2 := cw, y2 := ch

    ok := FindText(&X, &Y, x1 + cx, y1 + cy, x2 + cx, y2 + cy, args*)
    if (ok && IsNumber(X) && IsNumber(Y))
        X -= cx, Y -= cy
    return ok
}