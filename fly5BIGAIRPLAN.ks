// ============================================================
// 1. НАСТРОЙКИ (задаются здесь, их можно менять в полёте)
// ============================================================

set targetVSIN to 0.          // Целевая вертикальная скорость (м/с) — задаётся внешним контуром высоты
set targetAltitude to 3000.   // Целевая высота (м)
set targetROLLING to 0.       // Целевой угол крена (градусы) — задаётся внешним контуром курса
set targetCourse to 90.       // Целевой курс (градусы, 0-360)
set targetSPEED to 200.
set trimPitch to 0.           // Адаптивный триммер тангажа (компенсирует статическую ошибку)
// ИМБА — действительно отличное решение!

set Vstall to 90. //скорость сваливания, ниже нее не опускаться.


// ============================================================
// 2. ИНИЦИАЛИЗАЦИЯ PID-РЕГУЛЯТОРОВ
// ============================================================

// Внутренний PID по вертикальной скорости (управляет тангажом)
// Выход ограничен [-0.3, 0.3], чтобы не дёргать резко рулями.
// Базовые коэффициенты будут адаптироваться к скорости (делением на airspeed).
set VSpid_KP to 2.
set VSpid_KI to 0.5.
set VSpid_KD to 0.2.
set vsPID to pidLoop(VSpid_KP, VSpid_KI, VSpid_KD, -0.3, 0.3).

// Коэффициент адаптации триммера (медленный интегратор для компенсации смещения)
set trimPitchKP to 0.002.
set yawRollKP to 1.

// Внешний PID по высоте (выдаёт целевое значение VS)
// Выход ограничен [-10, 20] м/с — позволяет набирать высоту быстрее, чем снижаться.
set ALTpid_KP to 0.09.
set ALTpid_KI to 0.
set ALTpid_KD to 0.
set ALTPID to pidLoop(ALTpid_KP, ALTpid_KI, ALTpid_KD, -20, 20).

// Внутренний PID по крену (управляет элеронами)
// Выход ограничен [-0.3, 0.3] — аналогично тангажу, чтобы не перегружать элероны.
set ROLLpid_KP to 1.
set ROLLpid_KI to 0.1.
set ROLLpid_KD to 0.1.
set ROLLPID to pidLoop(ROLLpid_KP, ROLLpid_KI, ROLLpid_KD, -0.3, 0.3).

// Внешний PID по курсу (выдаёт целевой крен)
// Выход ограничен [-maxBankAngle, maxBankAngle] градусов.
set COURSEpid_KP to 3.5.
set COURSEpid_KI to 0.
set COURSEpid_KD to 0.1.
set maxBankAngle to 30.
set COURSEPID to pidLoop(COURSEpid_KP, COURSEpid_KI, COURSEpid_KD, -maxBankAngle, maxBankAngle).


set SPEEDpid_KP to 0.15.
set SPEEDpid_KI to 0.01.
set SPEEDpid_KD to 0.03.
set SPEEDPID to pidLoop(SPEEDpid_KP, SPEEDpid_KI, SPEEDpid_KD, 0.3, 1).

// Шаги для изменения коэффициентов через AG (1-6)
//set SPEEDpid_KP_Step to 0.01.
//set SPEEDpid_KI_Step to 0.01.
//set SPEEDpid_KD_Step to 0.01.

// ============================================================
// 3. ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ (состояние, таймеры, фильтры)
// ============================================================

global phase to "PRELAUNCH".
global prevPhase to "".
global timerPIDVS to 0.
global timerPIDALT to 0.
global timerPIDROLL to 0.
global timerPIDCOURSE to 0.
global timerPIDSPEED to 0.
global timerPrint to 0.
global VSfiltered to 0.      // Фильтрованное значение вертикальной скорости
global ROLLfiltered to 0.    // Фильтрованное значение крена
global SPEEDfiltered to 0.

// ============================================================
// 4. ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
// ============================================================

// --- ФУНКЦИЯ ВЫЧИСЛЕНИЯ УГЛА КРЕНА ---
// Возвращает угол крена в градусах, положительный = правый крен (по документации),
function getRollAngle {
    local starboard to SHIP:FACING:STARVECTOR.
    local upVec to SHIP:UP:VECTOR.
    local horizontalProjection to starboard - upVec * VDOT(starboard, upVec).
    if horizontalProjection:MAG < 0.001 { return 0. }
    set horizontalProjection to horizontalProjection:NORMALIZED.
    local rollAngle to VANG(starboard, horizontalProjection).
    if VDOT(starboard, upVec) > 0 {
        return -rollAngle.
    } else {
        return rollAngle.  
    }
}

// ============================================================
// 5. ФУНКЦИИ УПРАВЛЕНИЯ (вызываются из главного цикла)
// ============================================================

// --- УПРАВЛЕНИЕ ВЕРТИКАЛЬНОЙ СКОРОСТЬЮ (ВНУТРЕННИЙ КОНТУР) ---
// Вызывается с частотой ~10 Гц (проверка внутри)
// targetVS — целевая вертикальная скорость (м/с)
function VSControl {
    parameter targetVS is 0.

    if missionTime - timerPIDVS >= 0.1 {
        // Фильтр нижних частот для сглаживания шума
        local alpha to 0.3.
        set VSfiltered to alpha * ship:verticalSpeed + (1 - alpha) * VSfiltered.

        // Расчёт времени с прошлого вызова
        local dtPIDVS to missionTime - timerPIDVS.
        set timerPIDVS to missionTime.

        // Установка цели и адаптация коэффициентов к скорости
        set vsPID:setpoint to targetVS.

        // Медленный интегратор для триммера (компенсация статической ошибки)
        local errorVS to targetVS - VSfiltered.
        set trimPitch to trimPitch + errorVS * trimPitchKP * dtPIDVS.
        // Ограничиваем триммер, чтобы не уйти в разнос
        if trimPitch > 0.15 { set trimPitch to 0.15. }
        if trimPitch < -0.15 { set trimPitch to -0.15. }

        // Адаптация коэффициентов: делим на воздушную скорость
        set vsPID:kp to round(VSpid_KP / ship:airspeed, 6).
        set vsPID:ki to round(VSpid_KI / ship:airspeed, 6).
        set vsPID:kd to round(VSpid_KD / ship:airspeed, 6).

        // Вызов PID
        set pitchCmd to vsPID:update(missionTime, VSfiltered).

        // Anti-windup: если команда достигла предела, сбрасываем интегратор
        if abs(pitchCmd) >= 0.3 {
            vsPID:reset().
        }

        // Применяем команду + триммер
        set ship:control:pitch to pitchCmd + trimPitch.
    }
}

// --- УПРАВЛЕНИЕ ВЫСОТОЙ (ВНЕШНИЙ КОНТУР) ---
// Вызывается с частотой ~1 Гц (проверка внутри)
// targetALT — целевая высота (м)
function ALTcontrol {
    parameter targetALT is 1000.
    if missionTime - timerPIDALT >= 1.0 {
        set timerPIDALT to missionTime.
        if abs(ALTPID:setpoint - targetALT) > 50 {
            ALTPID:reset().
        }
        // Установка цели
        set ALTPID:setpoint to targetALT.
        if (SPEEDfiltered > 1.5 * Vstall) and (abs(SPEEDfiltered-targetSPEED) <= 0.2*targetSPEED) {
            set ALTPID:minoutput to -40.
            set ALTPID:maxoutput to 40.
        } else if (SPEEDfiltered >= Vstall){
            set ALTPID:minoutput to -20.
            set ALTPID:maxoutput to 20.
        } else {
            set ALTPID:minoutput to -20.
            set ALTPID:maxoutput to 5.
        }

        // Вызов PID — выход — целевая вертикальная скорость
        set VScmd to ALTPID:update(missionTime, ship:altitude).
        set targetVSIN to VScmd.
    }
}

// --- УПРАВЛЕНИЕ КРЕНОМ (ВНУТРЕННИЙ КОНТУР) ---
// Вызывается с частотой ~10 Гц
// targetROLL — целевой угол крена (градусы)
function ROLLcontrol {
    parameter targetROLL is 0.

    if missionTime - timerPIDROLL >= 0.1 {
        // Фильтр для крена
        local alpha to 0.3.
        set ROLLfiltered to alpha * getRollAngle() + (1 - alpha) * ROLLfiltered.
        set timerPIDROLL to missionTime.

        // Если цель изменилась более чем на 3°, сбрасываем интегратор
        if abs(ROLLPID:setpoint - targetROLL) > 3 {
            ROLLPID:reset().
        }
        set ROLLPID:setpoint to targetROLL.

        // Адаптация коэффициентов к скорости (делим на airspeed)
        set ROLLPID:kp to round(ROLLpid_KP / ship:airspeed, 6).
        set ROLLPID:ki to round(ROLLpid_KI / ship:airspeed, 6).
        set ROLLPID:kd to round(ROLLpid_KD / ship:airspeed, 6).

        // Вызов PID
        set rollCmd to ROLLPID:update(missionTime, ROLLfiltered).
        
        set yawCMDroll to ship:angularVel:z*yawRollKP. //Важно, демпфер по рысканью.
        if yawCMDroll > 0.3 {set yawCMDroll to 0.1.}
        if yawCMDroll < -0.3 {set yawCMDroll to -0.1.}

        // Anti-windup
        if abs(rollCmd) >= 0.3 {
            ROLLPID:reset().
        }

        // Применяем команду
        set ship:control:roll to rollCmd.
        set ship:control:yaw to yawCMDroll.
    }
}

// --- УПРАВЛЕНИЕ КУРСОМ (ВНЕШНИЙ КОНТУР) ---
// Вызывается с частотой ~1 Гц
// targetCoursor — целевой курс (градусы, 0-360)
function COURSEcontrol {
    parameter targetCoursor is 90.

    if missionTime - timerPIDCOURSE >= 1.0 {
        // Получение текущего курса
        local nowCourse to -ship:bearing.
        if nowCourse < 0 { set nowCourse to nowCourse + 360. }

        set timerPIDCOURSE to missionTime.
        if abs(nowCourse - targetCoursor) > 5 {
            COURSEPID:reset().
        }
        // Вычисление ошибки с учётом перехода через 0/360
        local diff to targetCoursor - nowCourse.
        if diff > 180 { set diff to diff - 360. }
        if diff < -180 { set diff to diff + 360. }

        set COURSEPID:setpoint to 0.
        local rolltarget to COURSEPID:update(missionTime, -diff).

        set targetROLLING to rolltarget.

        // Вывод отладки
        clearScreen.
    }
}

function SPEEDcontrol {
    parameter SpeedTarget is 200.
    if missionTime - timerPIDSPEED >= 0.1 {
        set timerPIDSPEED to missionTime.
        local alpha to 0.2.
        set SPEEDfiltered to alpha * ship:airspeed + (1 - alpha) * SPEEDfiltered.
        if abs(SPEEDPID:setpoint - SpeedTarget) > 30 {
            SPEEDPID:reset().
        }
        Set SPEEDPID:setpoint to SpeedTarget.
        local throttleCmd to SPEEDPID:update(missionTime, ship:airspeed).
        lock throttle to throttleCmd. 
    }

}

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
        ALTcontrol(targetAltitude).
        VSControl(targetVSIN).
        ROLLcontrol(targetROLLING).
        COURSEcontrol(targetCourse).
        SPEEDcontrol(targetSPEED).

        if  missionTime - timerPrint >= 0.5 {
            set timerPrint to missionTime.
            clearScreen.
            print "1/2 Altitude: " + targetAltitude + " m".
            print "3/4 Course: " + targetCourse + " deg".
            print "5/6 Speed: " + targetSPEED + " m/s".
            print "7/8 yaw KP: " + yawRollKP + "    yaw: " + round(ship:control:yaw, 4).
        }

        // --- УПРАВЛЕНИЕ НАСТРОЙКАМИ КУРСА ЧЕРЕЗ AG ---
        // AG1-AG6: изменение коэффициентов PID курса
        // AG7, AG8: изменение целевого курса на ±30°
        // AG10: перезагрузка
        if ag1 {
            set targetAltitude to targetAltitude - 100.
            set ag1 to false.
        }
        if ag2 {
            set targetAltitude to targetAltitude + 100.
            set ag2 to false.
        }
        if ag3 {
            set targetCourse to targetCourse - 30.
            if targetCourse < 0 {set targetCourse to targetCourse + 360.}
            set ag3 to false.
        }
        if ag4 {
            set targetCourse to targetCourse + 30.
            if targetCourse > 360 {set targetCourse to targetCourse - 360.}
            set ag4 to false.
        }
        if ag5 {
            set targetSPEED to targetSPEED - 10.
            set ag5 to false.
        }
        if ag6 {
            set targetSPEED to targetSPEED + 10.
            set ag6 to false.
        }
        if ag7 {
            set yawRollKP to yawRollKP-0.1.

            set ag7 to false.
        }
        if ag8 {
            set yawRollKP to yawRollKP+0.1.
            set ag8 to false.
        }
        if ag10 {
            set ag10 to false.
            reboot.
        }
    }
    wait 0.  
}