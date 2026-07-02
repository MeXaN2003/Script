CLEARSCREEN.
UNTIL ABORT {
    PRINT "Pitch: " + ROUND(SHIP:ANGULARVEL:X, 3) AT (0,0).
    PRINT "Yaw:   " + ROUND(SHIP:ANGULARVEL:Y, 3) AT (0,1).
    PRINT "Roll:  " + ROUND(SHIP:ANGULARVEL:Z, 3) AT (0,2).
    set ship:control:yaw to 0.1.
    PRINT "yaw:  " + ROUND(ship:control:yaw, 3) AT (0,3).
    WAIT 0.
}