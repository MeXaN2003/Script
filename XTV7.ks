global phase to "PRELAUNCH".
global prevPhase to "".



set phase to "WAIT PRE BURN".

until phase = "END" {
    if phase <> prevPhase {
        print ">>> Phase: " + phase.
        set prevPhase to phase.
    }
    else if phase = "WAIT PRE BURN" {
        if ship:orbit:eta:apoapsis < 15 {
            lock steering to prograde.
            set phase to "BURN".
        }
    }
    else if phase = "BURN"{
        lock steering to prograde.
        lock throttle to 1.
        if ship:orbit:apoapsis >= 420000{
            lock throttle to 0.
            set phase to "WAIT APO".
        }
    }
    else if phase = "WAIT APO" {
        if ship:altitude > 420000 {
            lock steering to prograde.
            stage.
            wait 0.5.
            set phase to "END".
        }
    }
}