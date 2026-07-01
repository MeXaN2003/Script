//Настройки 



//настройки регуляторов

set vsPID to pidLoop(0.0001,0,0,-1.0, 1.0).
set pitchPID to pidLoop(1,0.1,0).

//Глобальные переменные
global phase to "PRELAUNCH".
global prevPhase to "".
global TimeVisio to 0.
global timerPIDVS to 0.
//вспомогательные функции

function VSControl {
    parameter targetVS is 0.
    local dtPIDVS to missionTime - timerPIDVS.
    print dtPIDVS.
    set timerPIDVS to missionTime.
    print timerPIDVS.
    set vsPID:setpoint to targetVS.
    set pitchCmd to vsPID:update(dtPIDVS, ship:verticalspeed).
    print (ship:verticalspeed).
    set ship:control:pitch to pitchCmd.
}


//Инициализация
set prevTimeVisio to missionTime.
set prevTimeVisio2 to missionTime.
set phase to "VSControl".
//Главный цикл
until phase = "DONE" {
    if phase <> prevPhase {
        print ">>> Phase: " + phase.
        set prevPhase to phase.
    }
    else if phase = "VSControl" {
        if missionTime - timerPIDVS >= 0.1 {
            clearScreen.
            VSControl(0).
            print (vsPID).
        }
    }
    

    wait 0.

}