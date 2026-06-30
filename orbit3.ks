clearScreen.

gettooorbit(80000,10000,60000).

function startnextstage{
    if ship:maxThrust = 0{
        stage.
        wait 0.5.
    }
}

function VertAscent {
    lock steering to heading(90,90).
}

function GravityTurn {
    parameter vstart.
    parameter AP45.
    parameter APstop is 60000.
    parameter v45 is 1000.

    local vsm to velocity:surface:mag.
    local pitch to 0.
    if (vsm < v45) {
        set pitch to 90-arcTan((vsm-vstart)/(v45-vstart)).
    } else {
        set pitch to max(0,(apoapsis-APstop)/(AP45-APstop)).
    }
    lock steering to heading (90, pitch).
    print "Apoapsis: " + round( apoapsis/1000, 2 ) + " km    " at (0,30).
    print "Periapsis: " + round( periapsis/1000, 2 ) + " km    " at (0,31).
    print " Altitude: " + round( altitude/1000, 2 ) + " km    " at (24,30).
    print " Pitch: " + round( pitch ) + " deg  " at (24,31).
}

function shutdownAfterMaxAP {
    parameter APmax is body:atm:height + 10000.
    if apoapsis > APmax {lock throttle to 0.}
}

function circularize {
    local th to 0.
    local Vcircdir to vxcl(up:vector, velocity:orbit):normalized.
    local Vcircmag to sqrt(body:mu/body:position:mag).
    local Vcirc to Vcircmag*Vcircdir.
    local deltav to Vcirc - velocity:orbit.

    lock steering to lookDirUp(deltav, up:vector).
    wait until vAng(facing:vector, deltav) < 1.
    lock throttle to th.
    until deltav:mag < 0.05{
        set Vcircdir to vxcl(up:vector, velocity:orbit):normalized.
        set Vcircmag to sqrt(body:mu / body:position:mag).
        set Vcirc to Vcircmag*Vcircdir.
        set deltav to Vcirc - velocity:orbit.
        if vang(facing:vector, deltav) > 5 {
            set th to 0.
        } else {
            set th to min (1, deltav:mag*ship:mass / ship:availablethrust).
        }
        wait 0.1.
    }
    set th to 0.
    set ship:control:pilotmainthrottle to 0.
    unlock throttle.
}

function gettooorbit {
    parameter Horb to body:atm:height + 10000.
    parameter GTstart to 1000.
    parameter GTendAP to 60000.
    lock throttle to 1.
    local initialpos to ship:facing.
    lock steering to initialpos.
    startnextstage().
    until altitude > GTstart {
        VertAscent().
        if ship:availableThrust = 0 startnextstage().
        wait 0.1.
    }

    local GTStartSpd to velocity:surface:mag.
    local Apo45 to apoapsis.
    local lock pitch to 90 - vAng(up:vector,velocity:surface).
    until altitude > body:atm:height {
        if pitch >= 45 {set Apo45 to apoapsis.}
        GravityTurn(GTStartSpd,Apo45,GTendAP).
        shutdownAfterMaxAP(Horb).
        startnextstage().
        wait 0.01.
    }
    until altitude > Horb - 500 {
        lock steering to prograde.
        wait 0.01.
    }

    circularize().
    print "we are in orbit: " + round(apoapsis,2) + " x " + round(periapsis,2) + "km. ".

    lock steering to prograde.
}