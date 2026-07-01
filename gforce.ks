//Настройки 

set targetGFORCEIN to 0.2.
//настройки регуляторов

set GFORCEPID to pidLoop(0.1,0,0,-0.3, 0.3).
set GFORCEpid_KP_Step to 0.01.
set GFORCEpid_KI_Step to 0.001.
set GFORCEpid_KD_Step to 0.001.

//Глобальные переменные
global phase to "PRELAUNCH".
global prevPhase to "".
//global TimeVisio to 0.
global timerPIDGFORCE to 0.
//вспомогательные функции

function VSControl {
    parameter targetVS is 0.
    local dtPIDVS to missionTime - timerPIDGFORCE.
    local gForce to VDOT(ship:sensors:acc, SHIP:UP:VECTOR)/constant:g0.
    print "dt: " + round (dtPIDVS, 5).
    set timerPIDGFORCE to missionTime.
    set GFORCEPID:setpoint to targetVS.
    set pitchCmd to GFORCEPID:update(dtPIDVS, gForce).
    print "VS = " + round(ship:verticalspeed,1) + " m/s".
    print "GFORCE = " + round(VDOT(ship:sensors:acc, SHIP:UP:VECTOR)/constant:g0,1).
    set ship:control:pitch to pitchCmd.

    if ag1 {
        set GFORCEPID:kp to GFORCEPID:kp - GFORCEpid_KP_Step.
        if GFORCEPID:kp < 0 {set GFORCEPID:kp to 0.}
        set ag1 to false.
    }
    if ag2 {
        set GFORCEPID:kp to GFORCEPID:kp + GFORCEpid_KP_Step.
        set ag2 to false.
    }
    if ag3 {
        set GFORCEPID:ki to GFORCEPID:ki - GFORCEpid_KI_Step.
        if GFORCEPID:ki < 0 {set GFORCEPID:ki to 0.}
        set ag3 to false.
    }
    if ag4 {
        set GFORCEPID:ki to GFORCEPID:ki + GFORCEpid_KI_Step.
        set ag4 to false.
    }
    if ag5 {
        set GFORCEPID:kd to GFORCEPID:kd - GFORCEpid_KD_Step.
        if GFORCEPID:kd < 0 {set GFORCEPID:kd to 0.}
        set ag5 to false.
    }
    if ag6 {
        set GFORCEPID:kd to GFORCEPID:kd + GFORCEpid_KD_Step.
        set ag6 to false.
    }
    if ag7 {
        set targetGFORCEIN to 0.2.
        set ag7 to false.
    }
    if ag8 {
        set targetGFORCEIN to 0.5.
        set ag8 to false.
    }
    if ag10 {
        set ag10 to false.
        reboot.
    }
}


//Инициализация
set phase to "GFORCEControl".
//Главный цикл
until phase = "DONE" {
    if phase <> prevPhase {
        print ">>> Phase: " + phase.
        set prevPhase to phase.
    }
    else if phase = "GFORCEControl" {
        if missionTime - timerPIDGFORCE >= 0.1 {
            clearScreen.
            VSControl(targetGFORCEIN).
            print (GFORCEPID).
        }
    }
    

    wait 0.

}
