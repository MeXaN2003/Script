// ============================================================
// 1. НАСТРОЙКИ (задаются здесь, их можно менять в полёте)
// ============================================================


set Vstall to 90. //скорость сваливания, ниже нее не опускаться.


// ============================================================
// 2. ИНИЦИАЛИЗАЦИЯ PID-РЕГУЛЯТОРОВ
// ============================================================

set WHELLCOURSEpid_KP to 0.2.
set WHELLCOURSEpid_KI to 0.
set WHELLCOURSEpid_KD to 0.
set WHELLCOURSEPID to pidLoop(WHELLCOURSEpid_KP, WHELLCOURSEpid_KI, WHELLCOURSEpid_KD, -0.5, 0.5).

set YAWCOURSEpid_KP to 2.
set YAWCOURSEpid_KI to 0.
set YAWCOURSEpid_KD to 0.
set YAWCOURSEPID to pidLoop(YAWCOURSEpid_KP, YAWCOURSEpid_KI, YAWCOURSEpid_KD, -0.3, 0.3).

// Шаги для изменения коэффициентов через AG (1-6)
set pid_KP_Step to 0.1.
set pid_KI_Step to 0.01.
set pid_KD_Step to 0.01.

// ============================================================
// 3. ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ (состояние, таймеры, фильтры)
// ============================================================

global phase to "PRELAUNCH".
global prevPhase to "".
global timerPrint to 0.
global timerPIDWHELLCOURSE to 0.


// ============================================================
// 4. ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
// ============================================================
function preparationTOtakeOFF {
    sas off.
    brakes on.
    ag9 on.
    stage.
    wait 1.
    lock throttle to 1.
}

function CoursetaLOSPDControl {
    parameter targetCourse is 90.
    if time:seconds - timerPIDWHELLCOURSE >= 0.1{
        set timerPIDWHELLCOURSE to time:seconds.
        clearScreen.
        local nowCourse to -ship:bearing.
        if nowCourse < 0 { set nowCourse to nowCourse + 360. }
        local diff to targetCourse - nowCourse.
        if diff > 180 { set diff to diff - 360. }
        if diff < -180 { set diff to diff + 360. }
        set WHELLCOURSEPID:kp to WHELLCOURSEpid_KP/ship:groundspeed.
        set WHELLCOURSEPID:ki to WHELLCOURSEpid_KI/ship:groundspeed.
        set WHELLCOURSEPID:kd to WHELLCOURSEpid_KD/ship:groundspeed.
        set WHELLCOURSEPID:setpoint to 0.

        set YAWCOURSEPID:kp to YAWCOURSEpid_KP/ship:groundspeed.
        set YAWCOURSEPID:ki to YAWCOURSEpid_KI/ship:groundspeed.
        set YAWCOURSEPID:kd to YAWCOURSEpid_KD/ship:groundspeed.
        set YAWCOURSEPID:setpoint to 0.

        local whellCmd to WHELLCOURSEPID:update(time:seconds, diff).

        local YAWCmd to YAWCOURSEPID:update(time:seconds, -diff).

        set ship:control:wheelsteer to whellCmd.
        set ship:control:yaw to YAWCmd.
        print "target course: " + round(targetCourse,2) + " deg".
        print "now course: " + round(nowCourse,2) + " deg".
        print "KP: " + YAWCOURSEpid_KP + "    KI: " + YAWCOURSEpid_KI + "    KD: " + YAWCOURSEpid_KD.
        print YAWCOURSEPID.

    }

}


// ============================================================
// 5. ФУНКЦИИ УПРАВЛЕНИЯ (вызываются из главного цикла)
// ============================================================

// --- УПРАВЛЕНИЕ ВЕРТИКАЛЬНОЙ СКОРОСТЬЮ (ВНУТРЕННИЙ КОНТУР) ---
// Вызывается с частотой ~10 Гц (проверка внутри)
// targetVS — целевая вертикальная скорость (м/с)

// ============================================================
// 6. ИНИЦИАЛИЗАЦИЯ И ГЛАВНЫЙ ЦИКЛ
// ============================================================

set phase to "VSControl".

until phase = "DONE" {
    if phase <> prevPhase {
        print ">>> Phase: " + phase.
        set prevPhase to phase.
    }
    else if phase = "VSControl" {
        if ship:status = "LANDED"{
            CoursetaLOSPDControl(90).
        }
        
        // --- УПРАВЛЕНИЕ НАСТРОЙКАМИ КУРСА ЧЕРЕЗ AG ---
        // AG1-AG6: изменение коэффициентов PID курса
        // AG7, AG8: изменение целевого курса на ±30°
        // AG10: перезагрузка
        if ag1 {
            set YAWCOURSEpid_KP to YAWCOURSEpid_KP - pid_KP_Step.
            if YAWCOURSEpid_KP < 0 {set YAWCOURSEpid_KP to 0.}
            set ag1 to false.
        }
        if ag2 {
            set YAWCOURSEpid_KP to YAWCOURSEpid_KP + pid_KP_Step.
            set ag2 to false.
        }
        if ag3 {
            set YAWCOURSEpid_KI to YAWCOURSEpid_KI - pid_KI_Step.
            if YAWCOURSEpid_KI < 0 {set YAWCOURSEpid_KI to 0.}
            set ag3 to false.
        }
        if ag4 {
            set YAWCOURSEpid_KI to YAWCOURSEpid_KI + pid_KI_Step.
            set ag4 to false.
        }
        if ag5 {
            set YAWCOURSEpid_KD to YAWCOURSEpid_KD - pid_KD_Step.
            if YAWCOURSEpid_KD < 0 {set YAWCOURSEpid_KD to 0.}
            set ag5 to false.
        }
        if ag6 {
            set YAWCOURSEpid_KD to YAWCOURSEpid_KD + pid_KD_Step.
            set ag6 to false.
        }
        if ag7 {
            set ag7 to false.
        }
        if ag8 {
            set ag8 to false.
        }
        if ag10 {
            set ag10 to false.
            reboot.
        }
    }
    wait 0.  
}