set VtoAngle to 400.
set targetApo to 80000.
set maxAngle to 45.0.

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

set STloadFuel to stage:solidfuel.
lock pitchFirst to (90.0-maxAngle)+maxAngle*(stage:solidfuel/STloadFuel).
lock steering to heading(90,pitchFirst).
until ship:maxthrust = 0 {
    print "angle:" + round(pitchFirst,2) + "deg".
    wait 0.5.
    clearScreen.
}
stage.
lock pitchTwo to maxAngle*(1-(ship:apoapsis/targetApo)).
lock steering to heading(90, pitchTwo).
until ship:apoapsis > targetApo{
    print "angle:" + round(pitchTwo,2) + "deg".
    wait 0.5.
}
lock throttle to 0.
print "apoapsis is targeting:" + round(ship:apoapsis,2).
lock steering to prograde.

wait until false.