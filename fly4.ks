// --- НАСТРОЙКИ ---
set targetVSIN to 0.   // Целевая вертикальная скорость (внешний ввод)
set targetAltitude to 3000.
set targetROLLING to 0.
set targetCourse to 90.

set trimPitch to 0. //Иимба, выравнивает самолет идеально.


// --- ИНИЦИАЛИЗАЦИЯ PID ---
// Ты используешь ограничение выхода [-0.3, 0.3] — это разумно, чтобы не дёргать резко рулями.
// Обрати внимание: ты позже переопределяешь Kp, Ki, Kd через деление на скорость,
// но базовые значения заданы здесь.
set VSpid_KP to 2.
set VSpid_KI to 0.5.
set VSpid_KD to 0.2.
set vsPID to pidLoop(VSpid_KP, VSpid_KI, VSpid_KD, -0.3, 0.3).

set trimPitchKP to 0.002.

set ALTpid_KP to 0.09.
set ALTpid_KI to 0.
set ALTpid_KD to 0.
set ALTPID to pidLoop(ALTpid_KP, ALTpid_KI, ALTpid_KD, -10, 20).

set ROLLpid_KP to 1.
set ROLLpid_KI to 0.1.
set ROLLpid_KD to 0.1.
set ROLLPID to pidLoop(ROLLpid_KP, ROLLpid_KI, ROLLpid_KD, -0.3, 0.3).

set COURSEpid_KP to 5.
set COURSEpid_KI to 0.
set COURSEpid_KD to 0.1.
set maxBankAngle to 30.
set COURSEPID to pidLoop(COURSEpid_KP, COURSEpid_KI, COURSEpid_KD, -maxBankAngle, maxBankAngle).


// Шаги для изменения коэффициентов (для настройки через AG)

set COURSEpid_KP_Step to 0.5.
set COURSEpid_KI_Step to 0.1.
set COURSEpid_KD_Step to 0.1.


// --- ПЕРЕМЕННЫЕ ---
global phase to "PRELAUNCH".
global prevPhase to "".
global timerPIDVS to 0.
global timerPIDALT to 0.
global timerPIDROLL to 0.
global timerPIDCOURSE to 0.
global VSfiltered to 0.   // Фильтрованное значение вертикальной скорости
global ROLLfiltered to 0.


// --- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ---
function getRollAngle {
    // Вектор, указывающий в правое крыло самолёта
    local starboard to SHIP:FACING:STARVECTOR.

    // Вектор, указывающий строго вверх от планеты
    local upVec to SHIP:UP:VECTOR.

    // 1. Находим проекцию вектора starboard на горизонтальную плоскость.
    //    Для этого из вектора starboard вычитаем его проекцию на upVec.
    local horizontalProjection to starboard - upVec * VDOT(starboard, upVec).

    // Если проекция почти нулевая (самолёт направлен строго вверх или вниз),
    // то крен не определён. Возвращаем 0, чтобы избежать деления на ноль.
    if horizontalProjection:MAG < 0.001 {
        return 0.
    }

    // 2. Нормализуем проекцию, чтобы получить единичный вектор.
    set horizontalProjection to horizontalProjection:NORMALIZED.

    // 3. Вычисляем угол между исходным вектором (правым крылом) и его проекцией на горизонт.
    //    Этот угол и будет углом крена.
    local rollAngle to VANG(starboard, horizontalProjection).

    // 4. Определяем знак крена.
    //    Если конец вектора starboard направлен вверх (проекция на upVec > 0),
    //    то это левый крен (+), иначе правый (-).
    if VDOT(starboard, upVec) > 0 {
        return -rollAngle.  // Правый крен
    } else {
        return rollAngle. // Левый крен
    }
}

// --- ФУНКЦИЯ УПРАВЛЕНИЯ ---
function VSControl {
    parameter targetVS is 0.

    if missionTime - timerPIDVS >= 0.1 {

    // 1. ФИЛЬТР НИЖНИХ ЧАСТОТ для вертикальной скорости
    // Сглаживает шум датчиков, α=0.3 даёт хороший баланс.
    local alpha to 0.3.
    set VSfiltered to alpha * ship:verticalSpeed + (1 - alpha) * VSfiltered.

    // 2. ВРЕМЯ С МОМЕНТА ПОСЛЕДНЕГО ВЫЗОВА
    local dtPIDVS to missionTime - timerPIDVS.
    set timerPIDVS to missionTime.

    // 3. УСТАНОВКА ЦЕЛЕВОГО ЗНАЧЕНИЯ
    set vsPID:setpoint to targetVS.
    
    // Добавление триммера для смещения статической ошибки.

    local errorVS to targetVS - VSfiltered.
    set trimPitch to trimPitch + errorVS*trimPitchKP*dtPIDVS.
    if trimPitch > 0.15 {set trimPitch to 0.15.}
    if trimPitch < -0.15 {set trimPitch to -0.15.}
    
    // 4. АДАПТАЦИЯ КОЭФФИЦИЕНТОВ К СКОРОСТИ (ключевая фишка!)
    // Ты правильно делишь на скорость, чтобы компенсировать изменение эффективности рулей.
    // Используешь airspeed (приборная) — хороший выбор, т.к. она учитывает плотность воздуха.
    set vsPID:kp to round(VSpid_KP / ship:airspeed, 6).
    set vsPID:ki to round(VSpid_KI / ship:airspeed, 6).
    set vsPID:kd to round(VSpid_Kd / ship:airspeed, 6).

    // 5. ВЫЗОВ PID (передаём dt и фильтрованное значение VS)
    set pitchCmd to vsPID:update(dtPIDVS, VSfiltered).
    if abs(pitchCmd) >= 0.3 {
        vsPID:reset().
    }
    // 6. ПРИМЕНЕНИЕ КОМАНДЫ
    set ship:control:pitch to pitchCmd+trimPitch.

    // --- УПРАВЛЕНИЕ НАСТРОЙКАМИ ЧЕРЕЗ ACTION GROUPS ---
    // AG1-AG6: изменение коэффициентов PID
    // AG7: установить цель 0 м/с
    // AG8: установить цель 10 м/с
    // AG10: перезагрузка (hard reset)
    
    }
}

function ALTcontrol {
    parameter targetALT is 1000.
    if missionTime - timerPIDALT >= 1.0 {
        local dtPIDALT to missionTime - timerPIDALT.
        set timerPIDALT to missionTime.
        set ALTPID:setpoint to targetALT.
        set ALTPID:kp to ALTpid_KP.
        set ALTPID:ki to ALTpid_KI.
        set ALTPID:kd to ALTpid_Kd.
        set VScmd to ALTPID:update(dtPIDALT, ship:altitude).
        set targetVSIN to VScmd.
    }
}

// Функция для получения угла крена в градусах
// Возвращает: положительное значение для правого крена, отрицательное для левого


function ROLLcontrol {
    parameter targetROLL is 0.

    if missionTime - timerPIDROLL >= 0.1 {
        // 1. ФИЛЬТР НИЖНИХ ЧАСТОТ для вертикальной скорости
        // Сглаживает шум датчиков, α=0.3 даёт хороший баланс.
        local alpha to 0.3.
        set ROLLfiltered to alpha * getRollAngle() + (1 - alpha) * ROLLfiltered.
        // 2. ВРЕМЯ С МОМЕНТА ПОСЛЕДНЕГО ВЫЗОВА
        local dtPIDROLL to missionTime - timerPIDROLL.
        set timerPIDROLL to missionTime.

        // 3. УСТАНОВКА ЦЕЛЕВОГО ЗНАЧЕНИЯ
        if abs(ROLLPID:setpoint - targetROLL) > 3{
            ROLLPID:reset().
        }
        set ROLLPID:setpoint to targetROLL.


        set ROLLPID:kp to round(ROLLpid_KP / ship:airspeed, 6).
        set ROLLPID:ki to round(ROLLpid_KI / ship:airspeed, 6).
        set ROLLPID:kd to round(ROLLpid_Kd / ship:airspeed, 6).
        set rollCmd to ROLLPID:update(dtPIDROLL, ROLLfiltered).
        if abs(rollCmd) >= 0.3 {
            ROLLPID:reset().
        }
        // 6. ПРИМЕНЕНИЕ КОМАНДЫ
        set ship:control:roll to rollCmd.

    }
}

function COURSEcontrol {
    parameter targetCoursor is 90.
    if missionTime - timerPIDCOURSE >= 1.0 {
        clearScreen.
        local nowCourse to -ship:bearing.
        if nowCourse < 0 {set nowCourse to nowCourse + 360.}
        local dtPIDCOURSE to missionTime - timerPIDCOURSE.
        set timerPIDCOURSE to missionTime.
        local diff to targetCoursor - nowCourse.
        if diff > 180 {set diff to diff - 360.0.}
        if diff < -180 {set diff to diff + 360.0.}
        print "course now: " + round(nowCourse,1) + " deg".
        print "target course: " + round(targetCoursor,1) + " deg".
        print "error: " + round(diff,1) + " deg".
        print COURSEPID.

        set COURSEPID:setpoint to 0.
        local rolltarget to COURSEPID:update(dtPIDCOURSE, -diff).
        set targetROLLING to rolltarget.

    }

    if ag1 {
            set COURSEPID:kp to COURSEPID:kp - COURSEpid_KP_Step.
            if COURSEPID:kp < 0 {set COURSEPID:kp to 0.}
            set ag1 to false.
        }
        if ag2 {
            set COURSEPID:kp to COURSEPID:kp + COURSEpid_KP_Step.
            set ag2 to false.
        }
        if ag3 {
            set COURSEPID:ki to COURSEPID:ki - COURSEpid_KI_Step.
            if COURSEPID:ki < 0 {set COURSEPID:ki to 0.}
            set ag3 to false.
        }
        if ag4 {
            set COURSEPID:ki to COURSEPID:ki + COURSEpid_KI_Step.
            set ag4 to false.
        }
        if ag5 {
            set COURSEPID:kd to COURSEPID:kd - COURSEpid_KD_Step.
            if COURSEPID:kd < 0 {set COURSEPID:kd to 0.}
            set ag5 to false.
        }
        if ag6 {
            set COURSEPID:kd to COURSEPID:kd + COURSEpid_KD_Step.
            set ag6 to false.
        }
        if ag7 {
            set targetCourse to targetCourse - 30.
            set ag7 to false.
        }
        if ag8 {
            set targetCourse to targetCourse + 30.
            set ag8 to false.
        }
        if ag10 {
            set ag10 to false.
            reboot.
        }
}
// --- ИНИЦИАЛИЗАЦИЯ ---
set phase to "VSControl".

// --- ГЛАВНЫЙ ЦИКЛ ---
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
    }
    wait 0.
}