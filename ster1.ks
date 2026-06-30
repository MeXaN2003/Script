clearScreen.
lock steering to heading(90,90)+r(0,0,-90).
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
wait until alt:radar > 150.
until ship:availablethrust = 0 {
    lock steering to heading(90,80).
    print "AoA:" + round(vAng(ship:facing:forevector,velocity:surface),1) + "deg.".
    wait 1.
}
stage.
wait until vDot(velocity:surface,up:forevector) < 0.
lock steering to lookDirUp(-velocity:surface,up:starvector).
wait 0.5.
stage.
wait until ship:status = "SPLASHED" or ship:status = "LANDED".
print "We have" + ship:status.