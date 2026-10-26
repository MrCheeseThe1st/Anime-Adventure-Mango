
#Requires AutoHotkey v2.0

class TimerManager {
    static timers := Map()
    static pausedTimers := Map()
    static paused := false


    static Start(name, durationMs) {
        ; Remove any existing instance from either map
        if (this.timers.Has(name))
            this.timers.Delete(name)

        if (this.pausedTimers.Has(name))
            this.pausedTimers.Delete(name)

        ; Store as remaining time if globally paused
        if (this.paused) {
            this.pausedTimers[name] := durationMs
        } else {
            this.timers[name] := A_TickCount + durationMs
        }

        if (debugMessages) {
            totalSeconds := Floor(durationMs / 1000)
            minutes := Floor(totalSeconds / 60)
            seconds := Mod(totalSeconds, 60)
            formattedTime := minutes ":" Format("{:02}", seconds)

            AddToLog("[Timer] '" name "' will trigger in " formattedTime
                (this.paused ? " (paused)" : " (" durationMs " ms)"))
        }
    }


    ; Checks if the timer has expired
    static HasExpired(name) {
        if (this.paused)
            return false

        return this.timers.Has(name)
        && A_TickCount >= this.timers[name]
    }

    ; Gets remaining time in milliseconds
    static GetRemaining(name) {
        if (this.paused) {
            return this.pausedTimers.Has(name)
                ? this.pausedTimers[name]
                : 0
        }

        if !this.timers.Has(name)
            return 0

        remaining := this.timers[name] - A_TickCount
        return remaining > 0 ? remaining : 0
    }


    ; Pause one timer, or all timers if no name is supplied
    static Pause(name := "") {
        if (name = "") {
            if (this.paused)
                return

            this.paused := true

            for timerName, expiry in this.timers
                this.pausedTimers[timerName] := Max(0, expiry - A_TickCount)

            this.timers.Clear()
            return
        }

        if (this.timers.Has(name)) {
            this.pausedTimers[name] := Max(0, this.timers[name] - A_TickCount)
            this.timers.Delete(name)
        }
    }

    ; Resume one timer, or all timers if no name is supplied
    static Resume(name := "") {
        if (name = "") {
            if (!this.paused)
                return

            this.paused := false

            for timerName, remaining in this.pausedTimers
                this.timers[timerName] := A_TickCount + remaining

            this.pausedTimers.Clear()
            return
        }

        if (this.pausedTimers.Has(name)) {
            this.timers[name] := A_TickCount + this.pausedTimers[name]
            this.pausedTimers.Delete(name)
        }
    }


    ; Returns whether all timers or a specific timer is paused
    static IsPaused(name := "") {
        if (name = "")
            return this.paused

        return this.pausedTimers.Has(name)
    }

    ; Clears a timer
    static Clear(name) {
        existed := false

        if (this.timers.Has(name)) {
            this.timers.Delete(name)
            existed := true
        }

        if (this.pausedTimers.Has(name)) {
            this.pausedTimers.Delete(name)
            existed := true
        }

        if (existed && debugMessages)
            AddToLog("[Timer] '" name "' has been cleared")
    }

    ; Resets the timer
    static Reset(name, durationMs) {
        this.Start(name, durationMs)
    }

    static CheckAndRestart(name, durationMs) {
        if this.HasExpired(name) {
            this.Start(name, durationMs)
            return true
        }

        return false
    }

    static ClearAll() {
        this.timers.Clear()
        this.pausedTimers.Clear()

        if (debugMessages)
            AddToLog("[Timer] All timers have been cleared")
    }
}
