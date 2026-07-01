//Настройки 

set targetVSIN to 0.
//настройки регуляторов


set VSpid_KP to 2.
set VSpid_KI to 0.5.
set VSpid_KD to 0.2.
set vsPID to pidLoop(VSpid_KP,VSpid_KI,VSpid_KD,-0.3, 0.3).
set VSpid_KP_Step to 0.2.
set VSpid_KI_Step to 0.1.
set VSpid_KD_Step to 0.1.
//set pitchPID to pidLoop(1,0.1,0).

//Глобальные переменные
global phase to "PRELAUNCH".
global prevPhase to "".
//global TimeVisio to 0.
global timerPIDVS to 0.
global VSfiltered to 0.
//вспомогательные функции

function VSControl {
    parameter targetVS is 0.
    local alpha to 0.3.
    set VSfiltered to alpha * ship:verticalSpeed + (1 - alpha) * VSfiltered.
    local dtPIDVS to missionTime - timerPIDVS.
    print "dt: " + round (dtPIDVS, 5).
    set timerPIDVS to missionTime.
    set vsPID:setpoint to targetVS.
    set vsPID:kp to round(VSpid_KP/ship:airspeed, 6).
    set vsPID:ki to round(VSpid_KI/ship:airspeed, 6).
    set vsPID:kd to round(VSpid_Kd/ship:airspeed, 6).
    print "KP: " + VSpid_KP + "  KI: " + VSpid_KI + "  KD: " + VSpid_KD.
    set pitchCmd to vsPID:update(dtPIDVS, VSfiltered).
    if pitchCmd >= 0.3 {
        vsPID:reset().
    }
    print "VS = " + round(ship:verticalspeed,1) + " m/s".
    print "VSF = " + round(VSfiltered,1) + " m/s".
    set ship:control:pitch to pitchCmd.

    if ag1 {
        set VSpid_KP to VSpid_KP - VSpid_KP_Step.
        if VSpid_KP < 0 {set VSpid_KP to 0.}
        set ag1 to false.
    }
    if ag2 {
        set VSpid_KP to VSpid_KP + VSpid_KP_Step.
        set ag2 to false.
    }
    if ag3 {
        set VSpid_KI to VSpid_KI - VSpid_KI_Step.
        if VSpid_KI < 0 {set VSpid_KI to 0.}
        set ag3 to false.
    }
    if ag4 {
        set VSpid_KI to VSpid_KI + VSpid_KI_Step.
        set ag4 to false.
    }
    if ag5 {
        set VSpid_KD to VSpid_KD - VSpid_KD_Step.
        if VSpid_KD < 0 {set VSpid_KD to 0.}
        set ag5 to false.
    }
    if ag6 {
        set VSpid_KD to VSpid_KD + VSpid_KD_Step.
        set ag6 to false.
    }
    if ag7 {
        set targetVSIN to -5.
        set ag7 to false.
    }
    if ag8 {
        set targetVSIN to 10.
        set ag8 to false.
    }
    if ag10 {
        set ag10 to false.
        reboot.
    }
}


//Инициализация
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
            VSControl(targetVSIN).
            print (vsPID).
        }
    }
    

    wait 0.

}
