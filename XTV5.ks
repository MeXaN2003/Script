lock steering to heading(90,90).
sas off.
lock throttle to 1.
wait 5.
stage.
wait 0.5.
until false {
    if (ship:altitude > 12000) and (ship:altitude < 15000) and (ship:airspeed > 900) and (ship:airspeed < 1150) {
        stage.
        wait 0.5.
        break.
    }
}
wait until ship:altitude > ship:orbit:apoapsis*0.9.
until false {
    lock steering to retrograde.
    if ship:status = "LANDED" {break.}
}

