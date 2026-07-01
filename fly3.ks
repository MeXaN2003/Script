// --- НАСТРОЙКИ ---
set targetVSIN to 0.   // Целевая вертикальная скорость (внешний ввод)
set targetAltitude to 3000.


// --- ИНИЦИАЛИЗАЦИЯ PID ---
// Ты используешь ограничение выхода [-0.3, 0.3] — это разумно, чтобы не дёргать резко рулями.
// Обрати внимание: ты позже переопределяешь Kp, Ki, Kd через деление на скорость,
// но базовые значения заданы здесь.
set VSpid_KP to 2.
set VSpid_KI to 0.5.
set VSpid_KD to 0.2.
set vsPID to pidLoop(VSpid_KP, VSpid_KI, VSpid_KD, -0.3, 0.3).

set ALTpid_KP to 0.09.
set ALTpid_KI to 0.
set ALTpid_KD to 0.
set ALTPID to pidLoop(ALTpid_KP, ALTpid_KI, ALTpid_KD, -10, 20).


// Шаги для изменения коэффициентов (для настройки через AG)
set VSpid_KP_Step to 0.1.
set VSpid_KI_Step to 0.1.
set VSpid_KD_Step to 0.1.

set ALTpid_KP_Step to 0.01.
set ALTpid_KI_Step to 0.01.
set ALTpid_KD_Step to 0.01.


// --- ПЕРЕМЕННЫЕ ---
global phase to "PRELAUNCH".
global prevPhase to "".
global timerPIDVS to 0.
global timerPIDALT to 0.
global VSfiltered to 0.   // Фильтрованное значение вертикальной скорости

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

    // 4. АДАПТАЦИЯ КОЭФФИЦИЕНТОВ К СКОРОСТИ (ключевая фишка!)
    // Ты правильно делишь на скорость, чтобы компенсировать изменение эффективности рулей.
    // Используешь airspeed (приборная) — хороший выбор, т.к. она учитывает плотность воздуха.
    set vsPID:kp to round(VSpid_KP / ship:airspeed, 6).
    set vsPID:ki to round(VSpid_KI / ship:airspeed, 6).
    set vsPID:kd to round(VSpid_Kd / ship:airspeed, 6).

    // 5. ВЫЗОВ PID (передаём dt и фильтрованное значение VS)
    set pitchCmd to vsPID:update(dtPIDVS, VSfiltered).
    if pitchCmd >= 0.3 {
        vsPID:reset().
    }

    // 6. ПРИМЕНЕНИЕ КОМАНДЫ
    set ship:control:pitch to pitchCmd.

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
        clearScreen.
        local dtPIDALT to missionTime - timerPIDALT.
        set timerPIDALT to missionTime.
        set ALTPID:setpoint to targetALT.
        set ALTPID:kp to ALTpid_KP.
        set ALTPID:ki to ALTpid_KI.
        set ALTPID:kd to ALTpid_Kd.
        set VScmd to ALTPID:update(dtPIDALT, ship:altitude).
        print "VScmd: " + VScmd + " m/s".
        print "VS: " + ship:verticalspeed + " m/s".
        print ALTPID.
        set targetVSIN to VScmd.

        if ag1 {
            set ALTpid_KP to ALTpid_KP - ALTpid_KP_Step.
            if ALTpid_KP < 0 {set ALTpid_KP to 0.}
            set ag1 to false.
        }
        if ag2 {
            set ALTpid_KP to ALTpid_KP + ALTpid_KP_Step.
            set ag2 to false.
        }
        if ag3 {
            set ALTpid_KI to ALTpid_KI - ALTpid_KI_Step.
            if ALTpid_KI < 0 {set ALTpid_KI to 0.}
            set ag3 to false.
        }
        if ag4 {
            set ALTpid_KI to ALTpid_KI + ALTpid_KI_Step.
            set ag4 to false.
        }
        if ag5 {
            set ALTpid_KD to ALTpid_KD - ALTpid_KD_Step.
            if ALTpid_KD < 0 {set ALTpid_KD to 0.}
            set ag5 to false.
        }
        if ag6 {
            set ALTpid_KD to ALTpid_KD + ALTpid_KD_Step.
            set ag6 to false.
        }
        if ag10 {
            set ag10 to false.
            reboot.
        }

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
    }
    wait 0.
}