
//настройки регуляторов

//Глобальные переменные
global phase to "PRELAUNCH".
global prevPhase to "".
global timePrintAlt to 0.
global targetTWR to 2.5.
//вспомогательные функции

function stage_check_throttle {.
    if ship:maxthrust <= 0 {
        stage.
        wait 0.5.
    }
}

//Инициализация
//Главный цикл
until phase = "DONE" {
    if phase <> prevPhase {
        print ">>> Phase: " + phase.
        set prevPhase to phase.
    }

    else if phase = "PRELAUNCH" {
        sas off.
        lock throttle to 1.0.
        lock steering to heading(90,90).
        wait 5.
        stage.
        set phase to "LAUNCH".
    }
    else if phase = "LAUNCH" {
        if ship:maxthrust <= 0 {
            set phase to "WAIT APO".
        }
        else {
            local neededThrottle to (targetTWR * ship:mass * constant:g0) / ship:availablethrust.
            if neededThrottle > 1.0 { set neededThrottle to 1.0. }
            if neededThrottle < 0.0 { set neededThrottle to 0.0. }
            lock throttle to neededThrottle.
        }
    }
    else if phase = "WAIT APO"{
        if missionTime - timePrintAlt >= 0.5{
            clearScreen.
            set timePrintAlt to missionTime.
            print "APO: " + ship:orbit:apoapsis + "m".
        }
        if abs(ship:altitude - ship:orbit:apoapsis)<= 100{
            set phase to "DESCENT".
        }
    }

    else if phase = "DESCENT" {
        lock throttle to 0.
        lock steering to srfRetrograde.
        if stage:number > 0{
            stage.
            wait 0.5.
        }
        if (ship:status = "LANDED") or (ship:status = "SPLASHED") {
            print "The mission is over!".
            set phase to "DONE".
        }
    }

    
    wait 0.

}