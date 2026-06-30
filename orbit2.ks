set VtoAngle to 400.
set DangAlt to 35000.
set UnDangAlt to 60000.
set targetApo to 80000.
set minAngle to 20.0.
set maxAngle to 85.0.

set mu to 3.5316e12.
set Rkerb to 600000.0.


clearScreen.
lock throttle to 1.0.
sas off.
lock steering to heading(90,90)+r(0,0,0).
print "3".
wait 1.
print "2".
wait 1.
print "1".
wait 1.
print "Launch!".
stage.
wait 1.
clearScreen.

wait until velocity:surface:mag > VtoAngle. //просто скорость, пока не вертикальная
set altgrav to ship:altitude.
set pitchDang to 90.0.
lock steering to heading(90,pitchDang).

until ship:altitude > DangAlt{
    if (ship:altitude-altgrav) < 3500 {
        set pitchDang to 80.0.
        print "pitchDang:" + pitchDang.
    } else {
       lock steering to srfPrograde.
        print "AoA:" + round(vAng(ship:facing:forevector,velocity:surface),1) + "deg". 
    }
    wait 0.5.
    clearScreen.
}
lock steering to heading(90,pitchDang).
until ship:maxthrust = 0{   
    set pitchDang to (90.0-minAngle)-(maxAngle-minAngle)*((ship:altitude-DangAlt)/(UnDangAlt-DangAlt)).
    print "pitch:" + round(pitchDang,1) + "deg".
    wait 0.5.
    clearScreen.
}
stage.
lock pitchTwo to minAngle*(1-(ship:apoapsis/targetApo))+5.
lock steering to heading(90, pitchTwo).
until ship:apoapsis > targetApo{
    print "angle:" + round(pitchTwo,2) + "deg".
    wait 0.5.
}
lock throttle to 0.
print "apoapsis is targeting:" + round(ship:apoapsis,2).
lock steering to prograde.
wait until ship:altitude > 70000.

set Vap to sqrt(mu*((1.0-ship:orbit:eccentricity)/(ship:orbit:semimajoraxis*(1.0+ship:orbit:eccentricity)))).
print "Speed on Apo:" + round(Vap,1) + "m/s".
set Vcir to sqrt(mu/(Rkerb+ship:orbit:apoapsis)).
print "Speed for circ:" + Vcir + "m/s".
print "deltaV:" + (Vcir-Vap)+"m/s".
set deltaV_timer to deltaV_time(Vcir-Vap).
print "Burn Time:" + round(deltaV_timer,2) + "s".
unlock throttle.
if deltaV_timer < 100 {
    wait until ship:orbit:eta:apoapsis - deltaV_timer/1.8 < 0.
} else {
    wait until ship:orbit:eta:apoapsis - deltaV_timer/1.3 < 0.
}

circularize().

wait until false.

function deltaV_time {
    parameter deltaV.
    list engines in englist.
    local totalThrust is 0.
    local weightedIspSum is 0.
    for eng in englist {
        if eng:ignition {
            local f is eng:possiblethrust.
            local isp is eng:visp.
            set totalThrust to totalThrust + f.
            set weightedIspSum to weightedIspSum + f/isp.
        }
    }
    local effectiveIsp is totalThrust / weightedIspSum.
    local m0 is ship:mass * 1000.0.
    local T is totalThrust*1000.0.
    local isp is effectiveIsp.
    local expo is (-1.0*deltaV)/(isp*constant:g0).
    local burnTime is (m0*isp*constant:g0/T)*(1-constant:e^expo).
    return burnTime.
}

function circularize {
    local STdeltaV to ship:deltav:current.
    local TOTdeltaV to 0.
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
    set TOTdeltaV to STdeltaV - ship:deltav:current.
    set ship:control:pilotmainthrottle to 0.
    unlock throttle.
    print "escaped " + TOTdeltaV + "m/s".
}