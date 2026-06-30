
//настройки регуляторов

//Глобальные переменные
global phase to "PRELAUNCH".
global prevPhase to "".
global timePrintAlt to 0.
global target_ALT to 6000.
global target_course to 135.
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
        set STEERINGMANAGER:pitchts to 1.
        set STEERINGMANAGER:pitchpid:kp to 1.5.
        set STEERINGMANAGER:pitchpid:ki to 0.3.
        set STEERINGMANAGER:yawts to 1.
        set STEERINGMANAGER:yawpid:kp to 1.5.
        set STEERINGMANAGER:pitchpid:ki to 0.3.
        sas off.
        global StartPosition to ship:geoPosition.
        brakes on.
        lock throttle to 1.0.
        lock steering to heading(90,0).
        wait 5.
        stage.
        set phase to "TAKEOFF".
        
    }
    else if phase = "TAKEOFF" {
        lock steering to heading(90,5).
        if ship:groundspeed > 10 {
            brakes off.
        }
        if ship:groundspeed >= 70 {
            lock steering to heading(90,40).
        }
        if alt:radar > 50 {
            set phase to "CLIMBING".
        }
    }
    else if phase = "CLIMBING" {
        lock throttle to 1.
        if ship:altitude < 1000 {
            lock steering to heading(90,20).
        }
        else if ship:altitude < target_ALT and ship:altitude > 1000{
            lock steering to heading(target_course,15).
        }
        else {
            lock steering to heading(target_course,0).
            set phase to "RETENTION".
        }

        if missionTime - timePrintAlt > 0.5 {
            clearScreen.
            set timePrintAlt to missionTime.
            print STEERINGMANAGER:pitchpid.
            print STEERINGMANAGER:yawpid.
            print "Distance:" + round(StartPosition:distance/1000,2) + " km".
            print "Speed:" + round(StartPosition:distance/0.5,2) + " m/s".
        }
    }
    else if phase = "RETENTION" {
        if missionTime - timePrintAlt > 0.5 {
            clearScreen.
            set timePrintAlt to missionTime.
            print STEERINGMANAGER:pitchpid.
            print STEERINGMANAGER:yawpid.
            print "Distance:" + round(StartPosition:distance/1000,2) + " km".
            print "Speed:" + round(StartPosition:distance/0.5,2) + " m/s".
        }
        lock steering to heading(target_course,5).
        lock throttle to 1.
        if (target_ALT - ship:altitude) >= 0.2*target_ALT {
            set phase to "CLIMBING".
        }

    }

    
    wait 0.

}