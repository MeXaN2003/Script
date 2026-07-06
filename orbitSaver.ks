// ============================================================================
//                          Aвтоматический вывод на орбиту
// ============================================================================
// Цель: вывести корабль на круговую орбиту Кербина высотой ~80 км.
// Алгоритм:
//   1. Вертикальный старт до 150 м/с.
//   2. Гравитационный разворот с управлением по углу атаки (PD-регулятор)
//      до высоты 35 км.
//   3. Дожиг до целевого апоцентра с плавным уменьшением тангажа.
//   4. Ожидание апоцентра и выполнение циркуляризации.
//   5. Вывод итоговой статистики.
// ============================================================================

// ----------------------------- НАСТРОЙКИ ------------------------------------
set VtoAngle to 150.        // Скорость (м/с), при которой начинается поворот
set DangAlt to 35000.       // Высота (м), до которой активен гравитационный разворот
set UnDangAlt to 60000.     // Не используется в коде (можно удалить)
set targetApo to 80000.     // Целевая высота апоцентра (м) – 80 км
set minAngle to 20.0.       // Минимальный угол тангажа (градусы) во время дожига
set maxAngle to 85.0.       // Максимальный угол тангажа (градусы) во время разворота
set mu to 3.5316e12.        // Гравитационный параметр Кербина (м³/с²)
set Rkerb to 600000.0.      // Радиус Кербина (м)

// Настройки PD-регулятора для угла атаки
set desiredAoA to -15.      // Желаемый угол атаки (отрицательный – нос ниже вектора скорости)
set P_gain to 0.9.          // Пропорциональный коэффициент
set D_gain to 0.6.          // Дифференциальный коэффициент (демпфирование)
set deadband to 0.2.        // Мёртвая зона для ошибки (градусы) – в ней коррекция не применяется
set maxPitchRate to 1.      // Максимальное изменение тангажа за одну итерацию (градусы)
set minPitch to 50.         // Минимально допустимый тангаж (градусы)
set maxPitch to 85.         // Максимально допустимый тангаж (градусы)

// -------------------------- ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ ---------------------------
global phase to "PRELAUNCH".      // Текущая фаза полёта
global prevPhase to "".           // Предыдущая фаза (для вывода сообщений)

global pitchDang to 80.0.         // Текущий целевой угол тангажа (градусы)
global pitchTwo to 0.             // Угол тангажа во время дожига
global Vap to 0.                  // Скорость в апоцентре (м/с)
global Vcir to 0.                 // Круговая скорость на целевой высоте (м/с)
global deltaV_timer to 0.         // Рассчитанное время прожига для циркуляризации (с)
global circStartDV to 0.          // Запас Δv до начала циркуляризации (для статистики)
global circThrottle to 0.         // Вычисленное значение тяги (0..1) для циркуляризации

// -------------------------- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ -------------------------

// Функция deltaV_time: рассчитывает время работы двигателя для изменения скорости на deltaV
// Параметр: deltaV – требуемое приращение скорости (м/с)
// Возвращает: время прожига в секундах (с учётом изменения массы)
// Использует формулу Циолковского: t = (m0 * Isp * g0 / T) * (1 - exp(-deltaV / (Isp * g0)))
function deltaV_time {
    parameter deltaV.
    list engines in englist.       // Получаем список всех двигателей на корабле
    local totalThrust is 0.
    local weightedIspSum is 0.
    for eng in englist {
        if eng:ignition {          // Только работающие двигатели
            local f is eng:possiblethrust.  // Тяга в кН (при текущем дросселе = 1)
            local isp is eng:visp.          // Удельный импульс в вакууме (с)
            set totalThrust to totalThrust + f.
            set weightedIspSum to weightedIspSum + f/isp.
        }
    }
    local effectiveIsp is totalThrust / weightedIspSum. // Средневзвешенный Isp
    local m0 is ship:mass * 1000.0.      // Начальная масса в кг (ship:mass в тоннах)
    local T is totalThrust * 1000.0.     // Суммарная тяга в Н (из кН)
    local isp is effectiveIsp.
    local expo is (-1.0 * deltaV) / (isp * constant:g0).
    local burnTime is (m0 * isp * constant:g0 / T) * (1 - constant:e^expo).
    return burnTime.
}

// Функция signedAoA: возвращает знаковый угол атаки (положительный – нос выше скорости)
// Используется для определения, выше или ниже вектор скорости направлен нос.
// Возвращает: угол в градусах (от -180 до 180), но обычно в пределах [-90, 90].
function signedAoA {
    local absAoA is vAng(ship:facing:forevector, velocity:surface). // абсолютный угол
    local crossProd is vcrs(ship:facing:forevector, velocity:surface). // векторное произведение
    local refDir is vcrs(srfprograde:vector, up:vector):normalized. // боковое направление (перпендикуляр плоскости "скорость-вертикаль")
    local sign is vdot(crossProd, refDir). // проекция на боковое направление
    if sign >= 0 {
        return absAoA.   // нос выше prograde (положительный AoA)
    } else {
        return -absAoA.  // нос ниже prograde (отрицательный AoA)
    }
}

// Функция clamp: ограничивает значение val в диапазоне [minVal, maxVal]
function clamp {
    parameter val, minVal, maxVal.
    if val < minVal return minVal.
    if val > maxVal return maxVal.
    return val.
}

// Функция stage_check_throttle: проверяет, есть ли тяга; если нет – выполняет отделение ступени
// Вызывается в фазах, где двигатель должен работать.
function stage_check_throttle {
    if ship:maxthrust <= 0 {
        stage.
        wait 0.5.
    }
}

// -------------------------- ИНИЦИАЛИЗАЦИЯ ПЕРЕМЕННЫХ ------------------------
set prevTimeDeltaV to time:seconds.   // Для интегратора потерь Δv
set prevTimeGravity to time:seconds.  // Для управления частотой обновления PD-регулятора
set deltaV_loses to 0.               // Накопленные потери Δv (интеграл ускорения от тяги)

clearScreen.
lock throttle to 1.0.                // Полный газ на старте
sas off.                             // Отключаем штатный SAS (управление через kOS)
lock steering to heading(90,90) + r(0,0,0). // Направляем строго вверх (курс 90°, тангаж 90°)

// Обратный отсчёт
print "3". wait 1.
print "2". wait 1.
print "1". wait 1.
print "Launch!".
stage.      // Запуск первой ступени
wait 1.
clearScreen.

set phase to "LIFTOFF".   // Переход в первую фазу

// ============================ ГЛАВНЫЙ ЦИКЛ ==================================
until phase = "DONE" {
    // Вывод сообщения при смене фазы
    if phase <> prevPhase {
        print ">>> Phase: " + phase.
        set prevPhase to phase.
    }

    // ----------------------- ФАЗА LIFTOFF -----------------------------------
    if phase = "LIFTOFF" {
        lock steering to heading(90, 90).   // Строго вертикально
        if velocity:surface:mag > VtoAngle {
            set phase to "GRAVITY_TURN_PHASE1".
        }
    }

    // ------------------- ФАЗА GRAVITY_TURN_PHASE1 --------------------------
    else if phase = "GRAVITY_TURN_PHASE1" {
        // Первая часть гравитационного разворота: управление углом атаки через PD-регулятор
        // Выполняется до высоты DangAlt (35 км)
        if ship:altitude < DangAlt and time:seconds - prevTimeGravity >= 0.5 {
            set prevTimeGravity to time:seconds.
            local currentAoA to signedAoA().                 // Текущий угол атаки
            local error to desiredAoA + currentAoA.         // Ошибка: желаемый AoA = -15°
            if abs(error) > deadband {
                // PD-регулятор: пропорциональная часть + демпфирование по угловой скорости (yaw)
                // ship:angularvel:y – угловая скорость по оси рыскания (в kOS оси: x-тангаж, y-рыскание, z-крен)
                local correction to clamp(error * P_gain - ship:angularvel:y * D_gain, -maxPitchRate, maxPitchRate).
                set pitchDang to pitchDang + correction.       // Корректируем целевой тангаж
                set pitchDang to clamp(pitchDang, minPitch, maxPitch).
                print "AoA: " + round(currentAoA,2) + "°  target pitch: " + round(pitchDang,2) + "correction: " + round(correction,2).
            }
            lock steering to heading(90, pitchDang).    // Устанавливаем новый курс
            stage_check_throttle().                    // Проверка ступеней
        } else if ship:altitude >= DangAlt {
            set phase to "COAST_TO_AP".                // Переход к дожигу
        }
    }

    // ------------------- ФАЗА COAST_TO_AP ---------------------------------
    else if phase = "COAST_TO_AP" {
        // Дожиг до достижения целевого апоцентра (80 км)
        // Угол тангажа уменьшается линейно от 15° до minAngle (20°) в зависимости от текущего апоцентра
        if ship:apoapsis < targetApo {
            stage_check_throttle().
            // Формула: pitchTwo = minAngle * (1 - apoapsis/targetApo) + 15
            // При apoapsis = 0 -> 15°, при apoapsis = targetApo -> minAngle + 15°? Не совсем: если minAngle=20, то при targetApo даст 20+15=35? 
            // Возможно, автор хотел: при приближении к цели угол падает до minAngle.
            set pitchTwo to minAngle * (1 - (ship:apoapsis / targetApo)) + 15.
            lock steering to heading(90, pitchTwo).
            print "angle:" + round(pitchTwo,2) + "deg".
        } else {
            // Достигнут целевой апоцентр – выключаем двигатель и готовим циркуляризацию
            lock throttle to 0.
            print "apoapsis is targeting:" + round(ship:apoapsis,2).
            lock steering to prograde.   // Ориентируемся по скорости

            // Ждём выхода из атмосферы (высота > 70 км) – это гарантирует, что аэродинамика не помешает
            wait until ship:altitude > 70000.

            // Расчёт скорости в апоцентре текущей орбиты
            // Формула: Vap = sqrt(mu * (1 - e) / (a * (1 + e))) – скорость в апоцентре
            set Vap to sqrt(mu * ((1.0 - ship:orbit:eccentricity) / (ship:orbit:semimajoraxis * (1.0 + ship:orbit:eccentricity)))).

            // Круговая скорость на высоте текущего апоцентра
            set Vcir to sqrt(mu / (Rkerb + ship:orbit:apoapsis)).

            print "Speed on Apo:" + round(Vap,1) + "m/s".
            print "Speed for circ:" + round(Vcir,1) + "m/s".
            print "deltaV:" + round((Vcir - Vap),1) + "m/s".

            set deltaV_timer to deltaV_time(Vcir - Vap).   // Время прожига для циркуляризации
            print "Burn Time:" + round(deltaV_timer,2) + "s".

            unlock throttle.
            set circStartDV to ship:deltav:current.   // Запоминаем текущий запас Δv (для статистики)
            set phase to "WAIT_FOR_BURN".
        }
    }

    // ------------------- ФАЗА WAIT_FOR_BURN --------------------------------
    else if phase = "WAIT_FOR_BURN" {
        // Ожидание момента включения двигателя для циркуляризации
        // Момент старта: когда время до апоцентра станет равным половине времени прожига (с учётом поправки)
        local leadTime is 1.8.                  // Коэффициент упреждения (по умолчанию)
        if deltaV_timer >= 100 { set leadTime to 1.3. } // Для длинных прожигов уменьшаем упреждение

        // Если время до апоцентра меньше половины времени прожига, делённого на leadTime, начинаем
        if ship:orbit:eta:apoapsis - deltaV_timer / leadTime < 0 {
            lock throttle to 1.0.
            set phase to "CIRCULARIZE".
        }
    }

    // ------------------- ФАЗА CIRCULARIZE ----------------------------------
    else if phase = "CIRCULARIZE" {
        // Выполнение циркуляризации: управление по вектору необходимой дельты
        // Вектор дельты = Vcirc (круговая скорость на текущем радиусе) - текущая орбитальная скорость
        local VcircDir is vxcl(up:vector, velocity:orbit):normalized.   // Направление по касательной к орбите (перпендикулярно вертикали)
        local VcircMag is sqrt(body:mu / body:position:mag).           // Круговая скорость на текущем радиусе
        local Vcirc is VcircMag * VcircDir.
        local deltav is Vcirc - velocity:orbit.   // Вектор требуемого приращения скорости

        // Наводимся на направление дельты
        lock steering to lookDirUp(deltav, up:vector).

        if vAng(facing:vector, deltav) < 1 {
            // Когда навели достаточно точно (ошибка < 1°), рассчитываем дроссель
            // Чтобы не пережечь, ограничиваем тягу так, чтобы ускорение было пропорционально оставшейся дельте
            // Формула: throttle = min(1, deltav:mag * mass / availablethrust) – это даёт постоянное время до завершения
            set circThrottle to min(1, deltav:mag * ship:mass / ship:availablethrust).
            lock throttle to circThrottle.
        } else {
            lock throttle to 0.   // Ждём наведения
        }

        // Если остаток дельты меньше 0.05 м/с, считаем манёвр завершённым
        if deltav:mag < 0.05 {
            lock throttle to 0.
            set phase to "FINISHED".
        }
    }

    // ------------------- ФАЗА FINISHED -------------------------------------
    else if phase = "FINISHED" {
        // Вывод статистики
        // ВНИМАНИЕ: в kOS ship:deltav:current – это общий запас Δv, а не потраченный.
        // Здесь circStartDV было установлено до манёвра, и разница показывает, сколько Δv было израсходовано,
        // но только если запас Δv не менялся за счёт отделения ступеней. В данном случае это приблизительно верно.
        local TOTdeltaV is circStartDV - ship:deltav:current.
        print "Circularization used " + round(TOTdeltaV,1) + "m/s".
        print "Launch to orbit used " + round(deltaV_loses,1) + "m/s".
        unlock throttle.
        set phase to "DONE".
    }

    // ------------------- ИНТЕГРАТОР ПОТЕРЬ ΔV -----------------------------
    // Каждые 0.5 секунды добавляем к deltaV_loses произведение текущего ускорения от тяги на время
    // Это даёт оценку полного затраченного Δv (включая гравитационные и аэродинамические потери)
    if time:seconds >= prevTimeDeltaV + 0.5 {
        set prevTimeDeltaV to time:seconds.
        set deltaV_loses to deltaV_loses + (ship:thrust / ship:mass) * 0.5.
    }

    wait 0.   // Один игровой тик (примерно 0.02 с) – для производительности
}