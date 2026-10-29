#Requires AutoHotkey v2.0

; "Path" placement pattern. Attackers go in a thin line right outside the path's edge lines, Farm units
; (Unit Type = Farm) go in a second line just outside the attackers.
;
; Finding the path: the P button (top right) toggles the game's path highlight. Its colour depends on the
; map and on whether the match has started, so instead of looking for a colour the screen is captured
; with the highlight on and off, twice: the path is what switched in step with P both times. Effects,
; enemies and units don't switch in step with P, so they're left out even when they sit on the path.
; The lane is then sealed into one solid strip (gaps between chevrons and spots covered by enemies are
; filled) and the spots are measured from its outer edge.
;
; The result is kept for the rest of the session per map. Next match on the same map it's reused after a
; quick check that the camera is in the same place, which takes a fraction of the time.

global PathSpotStep := 3      ; Scan every 3rd pixel
global PathHugDist := 12      ; Attackers: px from the path's edge line to the unit's centre
global PathSpotSpacing := 28  ; Minimum distance between spots (px)
global PathSpotReach := 75    ; Half-size of the square used to score how much path a spot covers (px)
global PathEndGap := 30      ; No spots this close (px) to either end of the path
global PathFavor := "Character" ; Which spots go first: "Character" (closest to your character) or "Start"
                                ; (closest to where enemies come in)
global PathFarmDist := 42     ; Farm units: a second line this far out (px), just past the attacker line
global PathDebugSave := false ; The F9 test saves what the scan saw to Logs\PathDetect
global PathCache := Map()     ; "map|WxH" -> { points, bg, frame } for the rest of the session

GeneratePathPoints(useCache := true) {
    global PathCache
    ; Saved custom spots are only used by the Custom pattern - Path always finds the path itself

    try WinGetClientPos(&cx, &cy, &w, &h, rblxID)
    catch
        return GenerateCirclePoints()
    CloseUnitOverview() ; It covers the P button

    key := GetPlacementsForMode(ModeDropdown.Text) "|" w "x" h
    if (useCache && PathCache.Has(key)) {
        cached := PathCache[key]
        if PathCameraMatches(cached, CaptureFrame(cx, cy, w, h)) {
            AddToLog("Path placement: reusing the path found earlier on this map (" cached.points.Length " spots by the path, "
                . cached.points.farm.Length " farm spots)")
            return cached.points
        }
        AddToLog("Path placement: the camera moved since last time - finding the path again")
    }

    start := A_TickCount
    detected := DetectPathMask(cx, cy, w, h)
    points := BuildPathSpots(detected.mask, detected.frame, detected.hill, detected.HasOwnProp("other") ? detected.other : "")
    if (points.Length < 8 && !detected.HasOwnProp("byColor")) {
        ; The P comparison found something, but not a usable path - try the path colours instead
        ; Only one of the two pictures has the highlight on - use whichever shows more path colour
        byColor := PathColorMask(detected.frame), other := PathColorMask(detected.other)
        if (other.count > byColor.count)
            byColor := other
        if (byColor.count >= 100) {
            alt := BuildPathSpots(byColor.mask, detected.frame, detected.hill, detected.other)
            if (alt.Length > points.Length) {
                AddToLog("Path placement: the P comparison didn't give a clear path - using path colours")
                points := alt
            }
        }
    }
    if (points.Length = 0) {
        AddToLog("Path placement: couldn't find the path - using the Circle pattern instead")
        return GenerateCirclePoints()
    }
    AddToLog("Path placement: found " points.Length " spots by the path and " points.farm.Length " farm spots ("
        . (A_TickCount - start) " ms)")
    PathCache[key] := { points: points, bg: points.bg, frame: detected.frame }
    return points
}

; Captures with the highlight one way and the other, twice (4 clicks on P, so it ends the way it started).
; A cell is path if it changed with P both times and looked the same both times it was in the same state
DetectPathMask(cx, cy, w, h) {
    global PathDebugSave
    a1 := CaptureFrame(cx, cy, w, h)
    if PathDebugSave
        SavePathDebugShot(cx, cy, w, h, "path_state_1")
    ClickPathButton(w, h), Sleep(450)
    b1 := CaptureFrame(cx, cy, w, h)
    if PathDebugSave
        SavePathDebugShot(cx, cy, w, h, "path_state_2")
    ClickPathButton(w, h), Sleep(450)
    a2 := CaptureFrame(cx, cy, w, h)
    ClickPathButton(w, h), Sleep(450)
    b2 := CaptureFrame(cx, cy, w, h)
    ClickPathButton(w, h), Sleep(250)

    ; The chevrons can animate, so the highlighted state may differ between its two pictures - only the
    ; other state has to look the same both times. Effects and enemies change in both, so they're still out
    t1 := ChangedMask(a1, b1).mask, t2 := ChangedMask(a2, b2).mask
    sa := ChangedMask(a1, a2).mask, sb := ChangedMask(b1, b2).mask
    ; The hill highlight (solid green) can switch with P too - it's where hill units go, not path
    hill := HillMask([a1, b1])
    mask := Buffer(a1.n, 0), count := 0
    loop a1.n {
        i := A_Index - 1
        if (NumGet(t1, i, "UChar") && NumGet(t2, i, "UChar") && !(NumGet(sa, i, "UChar") && NumGet(sb, i, "UChar"))
            && !NumGet(hill, i, "UChar")) {
            NumPut("UChar", 1, mask, i)
            count += 1
        }
    }
    if (count >= 100)
        return { mask: mask, frame: a1, other: b1, hill: hill }

    ; P didn't change anything (missed the button?) - fall back to the path colours
    AddToLog("Path placement: clicking P didn't change the screen - using path colours only (less reliable)")
    ma := PathColorMask(a1), mb := PathColorMask(b1)
    return (ma.count >= mb.count) ? { mask: ma.mask, frame: a1, hill: hill, byColor: true } : { mask: mb.mask, frame: b1, hill: hill, byColor: true }
}

; Saves the Roblox window to Logs\PathDetect\<name>.png (F9 path test only)
SavePathDebugShot(cx, cy, w, h, name) {
    dir := A_ScriptDir "\Logs\PathDetect"
    try DirCreate(dir)
    pToken := Gdip_Startup()
    if !pToken
        return
    try {
        pBitmap := Gdip_BitmapFromScreen(cx "|" cy "|" w "|" h)
        if pBitmap
            Gdip_SaveBitmapToFile(pBitmap, dir "\" name ".png")
    } finally {
        if (IsSet(pBitmap) && pBitmap)
            Gdip_DisposeImage(pBitmap)
        Gdip_Shutdown(pToken)
    }
}

; Cells showing the solid green hill highlight in any of the frames. Path lime has much more red in it
HillMask(frames) {
    n := frames[1].n
    hill := Buffer(n, 0)
    for f in frames {
        loop n {
            c := NumGet(f.colors, (A_Index - 1) * 4, "UInt")
            if (c && ((c >> 16) & 0xFF) < 90 && ((c >> 8) & 0xFF) > 190 && (c & 0xFF) < 130)
                NumPut("UChar", 1, hill, A_Index - 1)
        }
    }
    return hill
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
            if !PathCaptureBlocked(x, y, w, h)
                NumPut("UInt", FindText().GetColor(cx + x, cy + y, 0) & 0xFFFFFF, colors, (gy * gw + gx) * 4)
        }
    }
    return { colors: colors, n: n, gw: gw, gh: gh, w: w, h: h }
}

; Cells whose colour changed clearly between two frames (sum of R, G and B differences above 80)
ChangedMask(f1, f2) {
    mask := Buffer(f1.n, 0), count := 0
    loop f1.n {
        o := (A_Index - 1) * 4
        c1 := NumGet(f1.colors, o, "UInt"), c2 := NumGet(f2.colors, o, "UInt")
        if (c1 = c2)
            continue
        if (ColorDiff(c1, c2) > 80) {
            NumPut("UChar", 1, mask, A_Index - 1)
            count += 1
        }
    }
    return { mask: mask, count: count }
}

ColorDiff(c1, c2) {
    return Abs(((c1 >> 16) & 0xFF) - ((c2 >> 16) & 0xFF)) + Abs(((c1 >> 8) & 0xFF) - ((c2 >> 8) & 0xFF))
        + Abs((c1 & 0xFF) - (c2 & 0xFF))
}

; Cells with a path colour: lime/yellow chevrons and edge lines, or the red under the chevrons
PathColorMask(frame) {
    mask := Buffer(frame.n, 0), count := 0
    loop frame.n {
        c := NumGet(frame.colors, (A_Index - 1) * 4, "UInt")
        if !c
            continue
        r := (c >> 16) & 0xFF, g := (c >> 8) & 0xFF, b := c & 0xFF
        if ((r > 100 && g > 180 && b < 90) || (r > 180 && g < 90 && b < 90)) {
            NumPut("UChar", 1, mask, A_Index - 1)
            count += 1
        }
    }
    return { mask: mask, count: count }
}

; The P button in the top-right icon row
ClickPathButton(w, h) {
    FixClick(Round(w * 0.742), Round(h * 0.031))
}

; Same camera as when the path was found? Compares the ground well away from the path (enemies and
; effects are on or near the path) - if most of it looks the same, the path is in the same place
PathCameraMatches(cached, frame) {
    if (frame.n != cached.frame.n || cached.bg.Length = 0)
        return false
    same := 0
    for i in cached.bg {
        o := i * 4
        if (ColorDiff(NumGet(frame.colors, o, "UInt"), NumGet(cached.frame.colors, o, "UInt")) <= 60)
            same += 1
    }
    return same >= cached.bg.Length * 0.8
}

; Spots for the path in `mask` (one byte per sampled cell, 1 = path). Returns the attacker spots (best
; first) with extra properties: .farm (farm spots), .ordered (don't shuffle) and .bg (cells for the camera
; check). Empty if there's no path
BuildPathSpots(mask, frame, hill := "", other := "") {
    global PathSpotStep, PathHugDist, PathSpotSpacing, PathSpotReach, PathFarmDist, PathEndGap
    step := PathSpotStep
    gw := frame.gw, gh := frame.gh, n := frame.n, w := frame.w, h := frame.h
    empty := [], empty.farm := [], empty.ordered := true, empty.bg := []
    if !IsObject(hill)
        hill := HillMask([frame])

    blocked := Buffer(n, 0)
    loop gh {
        gy := A_Index - 1
        loop gw {
            gx := A_Index - 1
            if PathSpotUiBlocked(gx * step, gy * step, w, h)
                NumPut("UChar", 1, blocked, gy * gw + gx)
        }
    }

    ; 1. Drop small blobs (coins, UI bits, a stray effect) - the path is one long connected shape
    path := Buffer(n, 0)
    DllCall("RtlMoveMemory", "ptr", path, "ptr", mask, "uptr", n)
    pathCount := DropSmallBlobs(path, gw, gh, 150)
    if (pathCount = 0)
        return empty

    ; 2. Seal the lane: grow it 3 cells to close the gaps between chevrons, then fill enclosed holes that
    ; are too small to be real ground (spots where an enemy covered the path). The island inside a bend
    ; is much bigger, so it stays
    grow := 3
    lane := GrowMask(path, gw, gh, grow)
    FillSmallHoles(lane, blocked, gw, gh, 600)

    ; 3. Distance (in px) from every cell to the lane's real edge. The grown lane sticks out `grow` cells
    ; past the real edge, so add that back. Cells inside the grown margin (distance 0) are never used
    dist := ChamferDistance(lane, gw, gh)
    edgePx(i) => (d := NumGet(dist, i * 2, "UShort")) ? d * step / 3 + grow * step : 0

    ; 4. How much path is near each cell, from a summed-area table of the path cells
    reach := PathSpotReach // step
    sat := SummedArea(path, gw, gh)
    coverage(gx, gy) {
        x1 := Max(0, gx - reach), y1 := Max(0, gy - reach)
        x2 := Min(gw, gx + reach + 1), y2 := Min(gh, gy + reach + 1)
        sw := gw + 1
        return NumGet(sat, (y2 * sw + x2) * 4, "UInt") - NumGet(sat, (y1 * sw + x2) * 4, "UInt")
            - NumGet(sat, (y2 * sw + x1) * 4, "UInt") + NumGet(sat, (y1 * sw + x1) * 4, "UInt")
    }

    ; 5. Which end of the path enemies come from. `along` tells, for every cell, how far along the path the
    ; nearest path cell is, counted from the start ("" if the direction couldn't be told)
    along := PathProgress(lane, frame, other, gw, gh)
    ends := LaneEnds(lane, gw, gh)
    nearEnd(x, y) {
        for e in ends {
            if ((x - e.x) ** 2 + (y - e.y) ** 2 < (PathEndGap + PathHugDist) ** 2)
                return true
        }
        return false
    }

    ; 6. Candidates: a ring one cell wide at PathHugDist for attackers, and a second ring just outside it
    ; at PathFarmDist for farms. Closer to the start of the path comes first; between spots about as far
    ; along, the one covering more path (inside of a bend) wins
    hug := [], farm := [], bg := []
    tol := step * 0.75
    loop gh {
        gy := A_Index - 1
        loop gw {
            gx := A_Index - 1, i := gy * gw + gx
            if NumGet(blocked, i, "UChar")
                continue
            d := edgePx(i)
            if (d >= 60 && Mod(i, 7) = 0)
                bg.Push(i)
            if NumGet(hill, i, "UChar") ; Ground units can't stand on hills
                continue
            if (d <= 0 || nearEnd(gx * step, gy * step))
                continue
            if (Abs(d - PathHugDist) <= tol)
                hug.Push({ x: gx * step, y: gy * step, cov: coverage(gx, gy), pos: IsObject(along) ? along.At(i) : 0 })
            else if (Abs(d - PathFarmDist) <= tol)
                farm.Push({ x: gx * step, y: gy * step, cov: coverage(gx, gy), pos: IsObject(along) ? along.At(i) : 0 })
        }
    }
    ScoreSpots(hug, along, w, h), ScoreSpots(farm, along, w, h)

    points := SpacedSpots(SortByScore(hug), PathSpotSpacing)
    points.farm := SpacedSpots(SortByScore(farm), PathSpotSpacing, 30)
    points.farm.ordered := true
    points.ordered := true
    points.bg := bg
    points.start := IsObject(along) ? { x: along.startX, y: along.startY } : ""
    return points
}

; score = closeness (0-1) plus a smaller share for coverage, so between spots about as close the one
; inside a bend wins. Closeness is to your character with PathFavor = "Character" - the camera follows
; the character, so it's in the middle of the screen - or to the start of the path with "Start" (coverage
; alone if the direction couldn't be told)
ScoreSpots(cands, along, w, h) {
    global PathFavor
    maxCov := 1
    for c in cands
        maxCov := Max(maxCov, c.cov)
    cx := w / 2, cy := h / 2, far := Sqrt(cx * cx + cy * cy)
    for c in cands {
        if (PathFavor = "Character")
            near := 1 - Sqrt((c.x - cx) ** 2 + (c.y - cy) ** 2) / far
        else if IsObject(along)
            near := 1 - c.pos / along.length
        else
            near := 0
        c.score := near + 0.35 * c.cov / maxCov
    }
}

; Works out which way enemies walk and how far along the path every cell is.
; The two ends of the lane are the two lane cells furthest apart (walking inside the lane). The chevrons
; point the way enemies walk: a ">" pointing forward has its edges slanting back on both sides of the
; lane's middle, so the colour edges lean one way on one side and the other way on the other. Adding that
; lean up over the whole lane says which end is the start.
; Returns { At(i), length } or "" if the direction is unclear
PathProgress(lane, frame, other, gw, gh) {
    global PathSpotStep
    n := gw * gh
    first := -1
    loop n {
        if NumGet(lane, A_Index - 1, "UChar") {
            first := A_Index - 1
            break
        }
    }
    if (first < 0)
        return ""
    LaneWalk(lane, gw, gh, first, &endA)
    G := LaneWalk(lane, gw, gh, endA, &endB) ; Steps from end A, inside the lane
    length := NumGet(G, endB * 4, "UInt")
    if (length < 30)
        return ""

    ; The picture with the highlight on has the chevrons - it's the one with more texture inside the lane
    onFrame := frame
    if (IsObject(other) && LaneTexture(lane, other) > LaneTexture(lane, frame))
        onFrame := other

    inner := ChamferDistance(InvertMask(lane, n), gw, gh) ; Distance from lane cells to the lane's edge
    shape := LaneShapeTables(lane, gw, gh)
    lean := 0, total := 0
    gy := 4
    while (gy < gh - 4) {
        gx := 4
        while (gx < gw - 4) {
            x := gx, i := gy * gw + gx
            gx += 2
            if (!NumGet(lane, i, "UChar") || NumGet(inner, i * 2, "UShort") < 18) ; Skip the edge lines
                continue
            ; The lane's direction here, from the shape of the lane around the cell (corners are skipped)
            if !LaneAxis(shape, gw, gh, x, gy, 24, &sx, &sy)
                continue
            ; ...pointing away from end A: the step count only decides which way along that line is forward
            gl := NumGet(G, (i - 3) * 4, "UInt"), gr := NumGet(G, (i + 3) * 4, "UInt")
            gu := NumGet(G, (i - 3 * gw) * 4, "UInt"), gd := NumGet(G, (i + 3 * gw) * 4, "UInt")
            if (gl = 0xFFFFFFFF || gr = 0xFFFFFFFF || gu = 0xFFFFFFFF || gd = 0xFFFFFFFF)
                continue
            if ((gr - gl) * sx + (gd - gu) * sy < 0)
                sx := -sx, sy := -sy
            nx := -sy, ny := sx
            ; Which side of the lane's middle this cell is on: the edge it reaches first going across
            k1 := LaneRun(lane, gw, gh, x, gy, nx, ny), k2 := LaneRun(lane, gw, gh, x, gy, -nx, -ny)
            if (k1 = k2)
                continue
            side := (k1 < k2) ? 1 : -1
            c0 := NumGet(onFrame.colors, i * 4, "UInt")
            cl := NumGet(onFrame.colors, (i - 1) * 4, "UInt"), cr := NumGet(onFrame.colors, (i + 1) * 4, "UInt")
            cu := NumGet(onFrame.colors, (i - gw) * 4, "UInt"), cd := NumGet(onFrame.colors, (i + gw) * 4, "UInt")
            if (!c0 || !cl || !cr || !cu || !cd) ; Game UI
                continue
            cl2 := NumGet(onFrame.colors, (i - 2) * 4, "UInt"), cr2 := NumGet(onFrame.colors, (i + 2) * 4, "UInt")
            cu2 := NumGet(onFrame.colors, (i - 2 * gw) * 4, "UInt"), cd2 := NumGet(onFrame.colors, (i + 2 * gw) * 4, "UInt")
            if (!cl2 || !cr2 || !cu2 || !cd2)
                continue
            lx := Lum(cr) + Lum(cr2) - Lum(cl) - Lum(cl2), ly := Lum(cd) + Lum(cd2) - Lum(cu) - Lum(cu2)
            gs := lx * sx + ly * sy, gn := lx * nx + ly * ny
            lean += gs * gn * side
            total += Abs(gs * gn)
        }
        gy += 2
    }
    if (total = 0 || Abs(lean) < total * 0.08) {
        AddToLog("Path placement: couldn't tell which way the path goes - placing by coverage only")
        return ""
    }

    ; lean > 0: the chevrons point away from end A, so enemies start at A
    startIsA := lean > 0
    label := NearestLaneLabel(lane, G, gw, gh)
    at(this, i) {
        v := NumGet(label, i * 4, "UInt")
        if (v = 0xFFFFFFFF)
            return length
        return startIsA ? Min(v, length) : length - Min(v, length)
    }
    s := startIsA ? endA : endB
    AddToLog("Path placement: enemies start near " Mod(s, gw) * PathSpotStep ", " (s // gw) * PathSpotStep
        . " - placing closest to there first")
    return { At: at, length: length, startX: Mod(s, gw) * PathSpotStep, startY: (s // gw) * PathSpotStep }
}

; The two ends of the path (in px): the two lane cells furthest apart, walking inside the lane
LaneEnds(lane, gw, gh) {
    global PathSpotStep
    first := -1
    loop gw * gh {
        if NumGet(lane, A_Index - 1, "UChar") {
            first := A_Index - 1
            break
        }
    }
    if (first < 0)
        return []
    LaneWalk(lane, gw, gh, first, &a)
    LaneWalk(lane, gw, gh, a, &b)
    return [{ x: Mod(a, gw) * PathSpotStep, y: (a // gw) * PathSpotStep }
        , { x: Mod(b, gw) * PathSpotStep, y: (b // gw) * PathSpotStep }]
}

Lum(c) => ((c >> 16) & 0xFF) + ((c >> 8) & 0xFF) + (c & 0xFF)

; Summed-area tables of the lane cells' count, x, y, x*x, y*y and x*y (Doubles), for LaneAxis
LaneShapeTables(lane, gw, gh) {
    sw := gw + 1, size := sw * (gh + 1) * 8
    t := [Buffer(size, 0), Buffer(size, 0), Buffer(size, 0), Buffer(size, 0), Buffer(size, 0), Buffer(size, 0)]
    row := [0, 0, 0, 0, 0, 0]
    loop gh {
        y := A_Index
        loop 6
            row[A_Index] := 0
        loop gw {
            x := A_Index
            if NumGet(lane, (y - 1) * gw + x - 1, "UChar") {
                cx := x - 1, cy := y - 1
                row[1] += 1, row[2] += cx, row[3] += cy, row[4] += cx * cx, row[5] += cy * cy, row[6] += cx * cy
            }
            o := (y * sw + x) * 8, up := ((y - 1) * sw + x) * 8
            loop 6
                NumPut("Double", NumGet(t[A_Index], up, "Double") + row[A_Index], t[A_Index], o)
        }
    }
    return t
}

; Direction (unit vector, sign arbitrary) the lane runs in around (x, y), from the spread of lane cells
; in a box `r` cells around it. False where there's no clear direction (corners, crossings)
LaneAxis(shape, gw, gh, x, y, r, &ax, &ay) {
    sw := gw + 1
    x1 := Max(0, x - r), y1 := Max(0, y - r), x2 := Min(gw, x + r + 1), y2 := Min(gh, y + r + 1)
    sums := []
    for t in shape
        sums.Push(NumGet(t, (y2 * sw + x2) * 8, "Double") - NumGet(t, (y1 * sw + x2) * 8, "Double")
            - NumGet(t, (y2 * sw + x1) * 8, "Double") + NumGet(t, (y1 * sw + x1) * 8, "Double"))
    c := sums[1]
    if (c < 20)
        return false
    mx := sums[2] / c, my := sums[3] / c
    vxx := sums[4] / c - mx * mx, vyy := sums[5] / c - my * my, vxy := sums[6] / c - mx * my
    ; Largest eigenvector of the 2x2 covariance
    tr := vxx + vyy, det := vxx * vyy - vxy * vxy
    disc := Sqrt(Max(0, tr * tr / 4 - det))
    l1 := tr / 2 + disc, l2 := tr / 2 - disc
    if (l1 <= 0 || l1 < 2.5 * Max(l2, 0.01))
        return false
    if (Abs(vxy) > 0.0001)
        ax := l1 - vyy, ay := vxy
    else
        ax := (vxx >= vyy) ? 1 : 0, ay := (vxx >= vyy) ? 0 : 1
    len := Sqrt(ax * ax + ay * ay)
    ax /= len, ay /= len
    return true
}

; Sum of brightness differences between neighbouring lane cells
LaneTexture(lane, frame) {
    t := 0
    loop frame.n - 1 {
        i := A_Index - 1
        if (NumGet(lane, i, "UChar") && NumGet(lane, i + 1, "UChar"))
            t += Abs(Lum(NumGet(frame.colors, i * 4, "UInt")) - Lum(NumGet(frame.colors, (i + 1) * 4, "UInt")))
    }
    return t
}

InvertMask(mask, n) {
    out := Buffer(n, 0)
    loop n
        NumPut("UChar", !NumGet(mask, A_Index - 1, "UChar"), out, A_Index - 1)
    return out
}

; Cells walked from (x, y) in direction (dx, dy) before leaving the lane (at most 25)
LaneRun(lane, gw, gh, x, y, dx, dy) {
    loop 25 {
        px := Round(x + dx * A_Index), py := Round(y + dy * A_Index)
        if (px < 0 || py < 0 || px >= gw || py >= gh || !NumGet(lane, py * gw + px, "UChar"))
            return A_Index
    }
    return 25
}

; Steps from `src` to every lane cell, walking inside the lane (0xFFFFFFFF = not reachable). `far` gets
; the furthest cell
LaneWalk(lane, gw, gh, src, &far) {
    n := gw * gh
    G := Buffer(n * 4, 0xFF)
    NumPut("UInt", 0, G, src * 4)
    q := [src], k := 1, far := src
    while (k <= q.Length) {
        j := q[k], k += 1, far := j
        d := NumGet(G, j * 4, "UInt") + 1
        jx := Mod(j, gw)
        for m in [jx > 0 ? j - 1 : -1, jx < gw - 1 ? j + 1 : -1, j - gw, j + gw] {
            if (m < 0 || m >= n || !NumGet(lane, m, "UChar") || NumGet(G, m * 4, "UInt") != 0xFFFFFFFF)
                continue
            NumPut("UInt", d, G, m * 4)
            q.Push(m)
        }
    }
    return G
}

; For every cell, the walk value (G) of the nearest lane cell, spreading outwards from the lane
NearestLaneLabel(lane, G, gw, gh) {
    n := gw * gh
    label := Buffer(n * 4, 0xFF)
    q := []
    loop n {
        i := A_Index - 1
        if (NumGet(lane, i, "UChar") && NumGet(G, i * 4, "UInt") != 0xFFFFFFFF) {
            NumPut("UInt", NumGet(G, i * 4, "UInt"), label, i * 4)
            q.Push(i)
        }
    }
    k := 1
    while (k <= q.Length) {
        j := q[k], k += 1
        v := NumGet(label, j * 4, "UInt"), jx := Mod(j, gw)
        for m in [jx > 0 ? j - 1 : -1, jx < gw - 1 ? j + 1 : -1, j - gw, j + gw] {
            if (m < 0 || m >= n || NumGet(label, m * 4, "UInt") != 0xFFFFFFFF)
                continue
            NumPut("UInt", v, label, m * 4)
            q.Push(m)
        }
    }
    return label
}

; Best-first spots at least `spacing` px apart, up to `limit`
SpacedSpots(cands, spacing, limit := 0) {
    spacing2 := spacing * spacing
    points := []
    for c in cands {
        ok := true
        for p in points {
            if ((p.x - c.x) ** 2 + (p.y - c.y) ** 2 < spacing2) {
                ok := false
                break
            }
        }
        if ok {
            points.Push({ x: c.x, y: c.y })
            if (limit && points.Length >= limit)
                break
        }
    }
    return points
}

; Clears connected blobs (8-way, gaps of 1 cell allowed) smaller than `minCells`. Returns cells left
DropSmallBlobs(path, gw, gh, minCells) {
    n := gw * gh, seen := Buffer(n, 0), left := 0
    loop n {
        i := A_Index - 1
        if (!NumGet(path, i, "UChar") || NumGet(seen, i, "UChar"))
            continue
        comp := [i], NumPut("UChar", 1, seen, i), k := 1
        while (k <= comp.Length) {
            j := comp[k], k += 1
            jx := Mod(j, gw), jy := j // gw
            loop 5 {
                ny := jy + A_Index - 3
                if (ny < 0 || ny >= gh)
                    continue
                loop 5 {
                    nx := jx + A_Index - 3
                    if (nx < 0 || nx >= gw)
                        continue
                    m := ny * gw + nx
                    if (NumGet(path, m, "UChar") && !NumGet(seen, m, "UChar")) {
                        NumPut("UChar", 1, seen, m)
                        comp.Push(m)
                    }
                }
            }
        }
        if (comp.Length < minCells) {
            for j in comp
                NumPut("UChar", 0, path, j)
        } else {
            left += comp.Length
        }
    }
    return left
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

; Fills areas of non-lane cells that are enclosed by the lane and smaller than `maxCells`. Areas that
; reach the screen edge or the game UI are open ground, whatever their size
FillSmallHoles(lane, blocked, gw, gh, maxCells) {
    n := gw * gh, seen := Buffer(n, 0)
    loop n {
        i := A_Index - 1
        if (NumGet(lane, i, "UChar") || NumGet(seen, i, "UChar"))
            continue
        comp := [i], NumPut("UChar", 1, seen, i), k := 1, open := false
        while (k <= comp.Length) {
            j := comp[k], k += 1
            jx := Mod(j, gw), jy := j // gw
            if (jx = 0 || jy = 0 || jx = gw - 1 || jy = gh - 1 || NumGet(blocked, j, "UChar"))
                open := true
            for nb in [[1, 0], [-1, 0], [0, 1], [0, -1]] {
                nx := jx + nb[1], ny := jy + nb[2]
                if (nx < 0 || ny < 0 || nx >= gw || ny >= gh)
                    continue
                m := ny * gw + nx
                if (!NumGet(lane, m, "UChar") && !NumGet(seen, m, "UChar")) {
                    NumPut("UChar", 1, seen, m)
                    comp.Push(m)
                }
            }
        }
        if (!open && comp.Length < maxCells) {
            for j in comp
                NumPut("UChar", 1, lane, j)
        }
    }
}

; Distance from every cell to the nearest lane cell, in thirds of a cell (3-4 chamfer, close to round)
ChamferDistance(lane, gw, gh) {
    n := gw * gh
    dist := Buffer(n * 2, 0)
    loop n
        NumPut("UShort", NumGet(lane, A_Index - 1, "UChar") ? 0 : 0xFFF0, dist, (A_Index - 1) * 2)
    get(x, y) => (x < 0 || y < 0 || x >= gw || y >= gh) ? 0xFFF0 : NumGet(dist, (y * gw + x) * 2, "UShort")
    loop gh {
        y := A_Index - 1
        loop gw {
            x := A_Index - 1, o := (y * gw + x) * 2
            d := NumGet(dist, o, "UShort")
            if !d
                continue
            d := Min(d, get(x - 1, y) + 3, get(x, y - 1) + 3, get(x - 1, y - 1) + 4, get(x + 1, y - 1) + 4)
            NumPut("UShort", Min(d, 0xFFF0), dist, o)
        }
    }
    y := gh
    while (--y >= 0) {
        x := gw
        while (--x >= 0) {
            o := (y * gw + x) * 2
            d := NumGet(dist, o, "UShort")
            if !d
                continue
            d := Min(d, get(x + 1, y) + 3, get(x, y + 1) + 3, get(x + 1, y + 1) + 4, get(x - 1, y + 1) + 4)
            NumPut("UShort", Min(d, 0xFFF0), dist, o)
        }
    }
    return dist
}

; Summed-area table of a 0/1 mask, (gw + 1) x (gh + 1) UInts
SummedArea(mask, gw, gh) {
    W := gw + 1
    sat := Buffer(W * (gh + 1) * 4, 0)
    loop gh {
        y := A_Index
        rowSum := 0
        loop gw {
            x := A_Index
            rowSum += NumGet(mask, (y - 1) * gw + x - 1, "UChar")
            NumPut("UInt", NumGet(sat, ((y - 1) * W + x) * 4, "UInt") + rowSum, sat, (y * W + x) * 4)
        }
    }
    return sat
}

; Screen areas covered by game UI, for reading the path. Tighter than PathSpotUiBlocked: the path often
; runs under the wave text strip and beside the hotbar, and cutting it there would split it in two
PathCaptureBlocked(x, y, w, h) {
    return y < 0.10 * h                                    ; Top bar
        || (x < 0.35 * w && y < 0.17 * h)                  ; Wave text
        || (y > 0.84 * h && x > 0.30 * w && x < 0.75 * w)  ; Hotbar, money
        || y > 0.95 * h                                    ; Level bar
        || (x < 0.08 * w && y > 0.88 * h)                  ; Settings button
        || (x < 0.12 * w && y > 0.36 * h && y < 0.52 * h)  ; Units button
        || (x > 0.94 * w && y > 0.44 * h && y < 0.56 * h)  ; F button
        || x < 4 || x > w - 5
}

; Screen areas covered by game UI (relative to the window size) - no spots go here
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

; Debug: find the path fresh (clicks P four times) and show the spots for 8 seconds:
; cyan = the 12 best attacker spots, white = other attacker spots, orange = farm spots
TestPathSpots() {
    if !WinExist(rblxID)
        return "Roblox window not found"
    WinActivate(rblxID)
    global PathDebugSave
    start := A_TickCount
    PathDebugSave := true
    try points := GeneratePathPoints(false)
    finally PathDebugSave := false
    took := A_TickCount - start

    WinGetClientPos(&offX, &offY, &w, &h, rblxID)
    dots := [], size := 12
    addDot(p, color) {
        g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
        g.BackColor := color
        g.Show("x" (p.x + offX - size // 2) " y" (p.y + offY - size // 2) " w" size " h" size " NoActivate")
        WinSetRegion("0-0 W" size " H" size " E", "ahk_id " g.Hwnd)
        dots.Push(g)
    }
    for i, p in points
        addDot(p, (i <= 12) ? "Aqua" : "White")
    farmCount := points.HasOwnProp("farm") ? points.farm.Length : 0
    if farmCount {
        for p in points.farm
            addDot(p, "FF8000")
    }
    Sleep(300)
    SavePathDebugShot(offX, offY, w, h, "spots") ; Pictures of this test are in Logs\PathDetect
    SetTimer(() => DestroyGuis(dots), -8000)
    return "Found " points.Length " spots by the path and " farmCount " farm spots in " took " ms. Dots show for 8 seconds"
        . " - cyan are the 12 best, orange are farm spots."
}

DestroyGuis(guis) {
    for g in guis
        g.Destroy()
}
