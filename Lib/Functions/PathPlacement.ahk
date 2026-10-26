#Requires AutoHotkey v2.0

; "Path" placement pattern: the P button (top right) toggles the game's path highlight. The highlight's
; colour depends on the map (green, purple, yellow, white...), so instead of looking for a colour the
; screen is captured with the highlight on and off: the path is whatever changed. The ground looks the
; same in both, whatever its colour. Spots are then picked in a band just outside the path, ranked by
; how much path is within reach, so the best spots (corners, inside bends) come first.
; Hill units are not handled yet. Spots on trees/rocks are kept - the game refuses those and the
; placement loop moves on to the next spot.

global PathSpotStep := 3     ; Scan every 3rd pixel
global PathSpotNear := 18    ; Band outside the path where units go (px)
global PathSpotFar := 40
global PathSpotSpacing := 34 ; Minimum distance between spots (px)
global PathSpotReach := 90   ; Radius used to score how much path a spot covers (px)

GeneratePathPoints() {
    ; Spots saved for this map (Placement page) win - finding the path is the fallback for maps without any
    saved := UseCustomPoints()
    if (IsObject(saved) && saved.Length > 0) {
        AddToLog("Path placement: using the " saved.Length " saved spots for " GetPlacementsForMode(ModeDropdown.Text))
        return saved
    }
    AddToLog("Path placement: no saved spots for " GetPlacementsForMode(ModeDropdown.Text) " - finding the path")

    try WinGetClientPos(&cx, &cy, &w, &h, rblxID)
    catch
        return GenerateCirclePoints()
    CloseUnitOverview() ; It covers the P button

    ; Two pictures with the highlight one way, click P, two pictures the other way, click P back.
    ; The path is whatever changed when P was clicked - so its colour doesn't matter, and neither does
    ; the ground's. Things that move on their own (enemies, effects) are measured within each pair and
    ; ignored
    a1 := CaptureFrame(cx, cy, w, h)
    Sleep(400)
    a2 := CaptureFrame(cx, cy, w, h)
    ClickPathButton(w, h)
    Sleep(700)
    b1 := CaptureFrame(cx, cy, w, h)
    Sleep(400)
    b2 := CaptureFrame(cx, cy, w, h)
    ClickPathButton(w, h)
    Sleep(300)

    ; The state with the path hidden has less movement (the chevrons may animate), so use its movement
    motionA := ChangedMask(a1, a2), motionB := ChangedMask(b1, b2)
    motion := (motionA.count <= motionB.count) ? motionA : motionB
    moving := GrowMask(motion.mask, a1.gw, a1.gh, 2)

    toggled := ChangedMask(a2, b1)
    mask := Buffer(a1.n, 0), count := 0
    loop a1.n {
        i := A_Index - 1
        if (NumGet(toggled.mask, i, "UChar") && !NumGet(moving, i, "UChar")) {
            NumPut("UChar", 1, mask, i)
            count += 1
        }
    }

    frame := a1
    if (count < 100) {
        ; P didn't change anything (missed the button?) - fall back to looking for path colours
        AddToLog("Path placement: clicking P didn't change the screen - using path colours only (less reliable)")
        frame := CapturePathColors(cx, cy, w, h)
        mask := frame.path
    }

    points := FindPathSpots(mask, frame)
    if (points.Length = 0) {
        AddToLog("Path placement: couldn't find the path - using the Circle pattern instead")
        return GenerateCirclePoints()
    }
    AddToLog("Path placement: found " points.Length " spots around the path")
    return points
}

; Colour of every sampled pixel (0 where game UI sits), for comparing pictures
CaptureFrame(cx, cy, w, h) {
    global PathSpotStep
    step := PathSpotStep
    gw := w // step, gh := h // step, n := gw * gh
    colors := Buffer(n * 4, 0)
    FindText().ScreenShot(cx, cy, cx + w - 1, cy + h - 1)
    loop gh {
        gy := A_Index - 1, y := gy * step
        loop gw {
            gx := A_Index - 1, x := gx * step
            if !PathSpotUiBlocked(x, y, w, h)
                NumPut("UInt", FindText().GetColor(cx + x, cy + y, 0) & 0xFFFFFF, colors, (gy * gw + gx) * 4)
        }
    }
    ; `hill` is empty: hill spots only show while holding a unit, which this doesn't do
    return { colors: colors, hill: Buffer(n, 0), n: n, gw: gw, gh: gh, w: w, h: h }
}

; Cells whose colour changed clearly between two frames (sum of R, G and B differences above 80)
ChangedMask(f1, f2) {
    mask := Buffer(f1.n, 0), count := 0
    loop f1.n {
        o := (A_Index - 1) * 4
        c1 := NumGet(f1.colors, o, "UInt"), c2 := NumGet(f2.colors, o, "UInt")
        if (c1 = c2)
            continue
        diff := Abs(((c1 >> 16) & 0xFF) - ((c2 >> 16) & 0xFF)) + Abs(((c1 >> 8) & 0xFF) - ((c2 >> 8) & 0xFF))
            + Abs((c1 & 0xFF) - (c2 & 0xFF))
        if (diff > 80) {
            NumPut("UChar", 1, mask, A_Index - 1)
            count += 1
        }
    }
    return { mask: mask, count: count }
}

; Mask grown by `cells` in every direction
GrowMask(mask, gw, gh, cells) {
    grown := Buffer(gw * gh, 0)
    loop gw * gh {
        i := A_Index - 1
        if !NumGet(mask, i, "UChar")
            continue
        ix := Mod(i, gw), iy := i // gw
        loop 2 * cells + 1 {
            ny := iy + A_Index - 1 - cells
            if (ny < 0 || ny >= gh)
                continue
            loop 2 * cells + 1 {
                nx := ix + A_Index - 1 - cells
                if (nx >= 0 && nx < gw)
                    NumPut("UChar", 1, grown, ny * gw + nx)
            }
        }
    }
    return grown
}

; The P button in the top-right icon row
ClickPathButton(w, h) {
    FixClick(Round(w * 0.742), Round(h * 0.031))
}

; Captures the window and marks every sampled pixel that has a path colour (lime/yellow or red
; chevrons) or a hill colour (solid green)
CapturePathColors(cx, cy, w, h) {
    global PathSpotStep
    step := PathSpotStep
    gw := w // step, gh := h // step, n := gw * gh
    path := Buffer(n, 0), hill := Buffer(n, 0), count := 0
    FindText().ScreenShot(cx, cy, cx + w - 1, cy + h - 1)
    loop gh {
        gy := A_Index - 1, y := gy * step
        loop gw {
            gx := A_Index - 1, x := gx * step, i := gy * gw + gx
            if PathSpotUiBlocked(x, y, w, h)
                continue
            c := FindText().GetColor(cx + x, cy + y, 0)
            r := (c >> 16) & 0xFF, g := (c >> 8) & 0xFF, b := c & 0xFF
            if ((r > 100 && g > 180 && b < 90) || (r > 180 && g < 90 && b < 90)) {
                NumPut("UChar", 1, path, i)
                count += 1
            } else if (r < 60 && g > 180 && b < 110) {
                NumPut("UChar", 1, hill, i)
            }
        }
    }
    return { path: path, hill: hill, count: count, n: n, gw: gw, gh: gh, w: w, h: h }
}

; Spots around the path in `mask` (one byte per sampled pixel, 1 = path), best first.
; `frame` is a CapturePathColors result for the grid size and hill spots. Empty if there's no path
FindPathSpots(mask, frame) {
    global PathSpotStep, PathSpotNear, PathSpotFar, PathSpotSpacing, PathSpotReach
    step := PathSpotStep
    gw := frame.gw, gh := frame.gh, n := frame.n, w := frame.w, h := frame.h
    path := mask, hill := frame.hill
    blocked := Buffer(n, 0)
    loop gh {
        gy := A_Index - 1
        loop gw {
            gx := A_Index - 1
            if PathSpotUiBlocked(gx * step, gy * step, w, h)
                NumPut("UChar", 1, blocked, gy * gw + gx)
        }
    }

    ; 2. Drop small blobs (coins, UI bits) - the path is one long connected shape
    seen := Buffer(n, 0)
    loop n {
        i := A_Index - 1
        if (!NumGet(path, i, "UChar") || NumGet(seen, i, "UChar"))
            continue
        comp := [i], NumPut("UChar", 1, seen, i), k := 1
        while (k <= comp.Length) {
            j := comp[k], k += 1
            jx := Mod(j, gw), jy := j // gw
            loop 5 {
                dy := A_Index - 3
                loop 5 {
                    dx := A_Index - 3
                    nx := jx + dx, ny := jy + dy
                    if (nx < 0 || ny < 0 || nx >= gw || ny >= gh)
                        continue
                    m := ny * gw + nx
                    if (NumGet(path, m, "UChar") && !NumGet(seen, m, "UChar")) {
                        NumPut("UChar", 1, seen, m)
                        comp.Push(m)
                    }
                }
            }
        }
        if (comp.Length < 150) {
            for j in comp
                NumPut("UChar", 0, path, j)
        }
    }

    ; 3. Close the gaps between chevrons (grow the path 3 cells), then measure distance from it
    grow := 3
    dist := Buffer(n * 2, 0xFF) ; UShort per cell, 0xFFFF = not reached yet
    queue := []
    loop n {
        i := A_Index - 1
        if !NumGet(path, i, "UChar")
            continue
        ix := Mod(i, gw), iy := i // gw
        loop 2 * grow + 1 {
            ny := iy + A_Index - 1 - grow
            if (ny < 0 || ny >= gh)
                continue
            loop 2 * grow + 1 {
                nx := ix + A_Index - 1 - grow
                if (nx < 0 || nx >= gw)
                    continue
                m := ny * gw + nx
                if (NumGet(dist, m * 2, "UShort") != 0) {
                    NumPut("UShort", 0, dist, m * 2)
                    queue.Push(m)
                }
            }
        }
    }
    if (queue.Length = 0)
        return []
    k := 1
    while (k <= queue.Length) {
        j := queue[k], k += 1
        jx := Mod(j, gw), jy := j // gw, d := NumGet(dist, j * 2, "UShort") + 1
        for nb in [[1, 0], [-1, 0], [0, 1], [0, -1]] {
            nx := jx + nb[1], ny := jy + nb[2]
            if (nx < 0 || ny < 0 || nx >= gw || ny >= gh)
                continue
            m := ny * gw + nx
            if (NumGet(dist, m * 2, "UShort") = 0xFFFF) {
                NumPut("UShort", d, dist, m * 2)
                queue.Push(m)
            }
        }
    }

    ; 4. Candidates in the band, scored by how much path is within reach
    pathCells := []
    loop n {
        i := A_Index - 1
        if (NumGet(path, i, "UChar") && Mod(i, 6) = 0) ; Every 6th path cell is plenty for scoring
            pathCells.Push([Mod(i, gw) * step, (i // gw) * step])
    }
    lo := (PathSpotNear + grow * step) // step, hi := (PathSpotFar + 9) // step
    reach2 := PathSpotReach * PathSpotReach
    cands := []
    gy := 0
    while (gy < gh) {
        gx := 0
        while (gx < gw) {
            i := gy * gw + gx
            d := NumGet(dist, i * 2, "UShort")
            if (d >= lo && d <= hi && !NumGet(hill, i, "UChar") && !NumGet(blocked, i, "UChar")) {
                x := gx * step, y := gy * step, score := 0
                for p in pathCells {
                    if ((p[1] - x) ** 2 + (p[2] - y) ** 2 <= reach2)
                        score += 1
                }
                cands.Push({ x: x, y: y, score: score })
            }
            gx += 2 ; Every other cell is enough for candidates
        }
        gy += 2
    }

    ; 5. Best first, keeping spots at least PathSpotSpacing apart
    SortByScore(cands)
    spacing2 := PathSpotSpacing * PathSpotSpacing
    points := []
    for c in cands {
        ok := true
        for p in points {
            if ((p.x - c.x) ** 2 + (p.y - c.y) ** 2 < spacing2) {
                ok := false
                break
            }
        }
        if ok
            points.Push({ x: c.x, y: c.y })
    }
    return points
}

; Screen areas covered by game UI (relative to the window size)
PathSpotUiBlocked(x, y, w, h) {
    return y < 0.19 * h                                   ; Top bar, wave text
        || y > 0.84 * h                                   ; Hotbar, money
        || (x < 0.12 * w && y > 0.36 * h && y < 0.52 * h) ; Units button
        || (x > 0.94 * w && y > 0.44 * h && y < 0.56 * h) ; F button
        || x < 4 || x > w - 5
}

; Highest score first (merge sort - candidate lists can be large)
SortByScore(arr) {
    if (arr.Length < 2)
        return arr
    tmp := []
    tmp.Length := arr.Length
    width := 1
    while (width < arr.Length) {
        i := 1
        while (i <= arr.Length) {
            mid := Min(i + width, arr.Length + 1), hiEnd := Min(i + 2 * width, arr.Length + 1)
            a := i, b := mid, k := i
            while (a < mid && b < hiEnd) {
                if (arr[a].score >= arr[b].score)
                    tmp[k] := arr[a], a += 1
                else
                    tmp[k] := arr[b], b += 1
                k += 1
            }
            while (a < mid)
                tmp[k] := arr[a], a += 1, k += 1
            while (b < hiEnd)
                tmp[k] := arr[b], b += 1, k += 1
            i += 2 * width
        }
        loop arr.Length
            arr[A_Index] := tmp[A_Index]
        width *= 2
    }
    return arr
}

; Debug: find the spots (clicks P twice) and show them as dots for 8 seconds (cyan = best 12)
TestPathSpots() {
    if !WinExist(rblxID)
        return "Roblox window not found"
    WinActivate(rblxID)
    start := A_TickCount
    points := GeneratePathPoints()
    took := A_TickCount - start

    WinGetClientPos(&offX, &offY, , , rblxID)
    dots := [], size := 12
    for i, p in points {
        g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
        g.BackColor := (i <= 12) ? "Aqua" : "White"
        g.Show("x" (p.x + offX - size // 2) " y" (p.y + offY - size // 2) " w" size " h" size " NoActivate")
        WinSetRegion("0-0 W" size " H" size " E", "ahk_id " g.Hwnd)
        dots.Push(g)
    }
    SetTimer(() => DestroyGuis(dots), -8000)
    return "Found " points.Length " spots in " took " ms. Dots show for 8 seconds - cyan are the 12 best."
}

DestroyGuis(guis) {
    for g in guis
        g.Destroy()
}
