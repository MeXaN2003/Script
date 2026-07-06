// ============================================================================
//                 Разворот орбиты (изменение направления движения)
// ============================================================================
// Цель: изменить направление орбитального движения на противоположное.
// Метод: би-эллиптический переход:
//   1. В апоцентре разгоняемся до 0.9 * SOI.
//   2. В новом апоцентре разворачиваем скорость на 180°.
//   3. В перицентре (на исходной высоте) тормозим до круговой.
// ============================================================================

// ----------------------------- НАСТРОЙКИ ------------------------------------
set target_apo_ratio to 0.9.       // Доля от SOI для нового апоцентра

// -------------------------- ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ ---------------------------
global phase to "WAIT_APOAPSIS".
global prevPhase to "".
global original_pe_alt to 0.        // Высота перицентра исходной орбиты (м)
global original_pe_radius to 0.     // Радиус перицентра от центра тела
global big_apo_radius to 0.         // Радиус нового апоцентра (м)

global node_raise to 0.             // Узел для подъёма апоцентра
global node_reverse to 0.           // Узел для разворота
global node_circ to 0.              // Узел для циркуляризации

global deltaV_raise to 0.
global deltaV_reverse to 0.
global deltaV_circ to 0.

global burn_time_raise to 0.
global burn_time_reverse to 0.
global burn_time_circ to 0.

global circStartDV to 0.            // Для статистики

// -------------------------- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ -------------------------

// Функция deltaV_time: рассчитывает время прожига для заданной дельты
function deltaV_time {
    parameter deltaV.
    list engines in englist.
    local totalThrust is 0.
    local weightedIspSum is 0.
    for eng in englist {
        if eng:ignition {
            local f is eng:possiblethrust.
            local isp is eng:visp.
            set totalThrust to totalThrust + f.
            set weightedIspSum to weightedIspSum + f/isp.
        }
    }
    if totalThrust = 0 { return 0. }
    local effectiveIsp is totalThrust / weightedIspSum.
    local m0 is ship:mass * 1000.0.
    local T is totalThrust * 1000.0.
    local expo is (-1.0 * deltaV) / (effectiveIsp * constant:g0).
    local burnTime is (m0 * effectiveIsp * constant:g0 / T) * (1 - constant:e^expo).
    return burnTime.
}

// Функция stage_check_throttle: проверяет тягу и выполняет отделение ступени
function stage_check_throttle {
    if ship:maxthrust <= 0 {
        stage.
        wait 0.5.
    }
}

// Функция выполнения манёвра по узлу (общая для всех фаз)
// Параметры: узел, оставшаяся дельта, имя фазы после завершения
function execute_node {
    parameter nd, remaining_dv, next_phase.
    // Наведение на вектор дельты
    lock steering to lookDirUp(nd:deltaV:vector, up:vector).
    if vAng(facing:vector, nd:deltaV:vector) < 1 {
        local throttle_val is min(1, remaining_dv * ship:mass / ship:availablethrust).
        lock throttle to throttle_val.
    } else {
        lock throttle to 0.
    }
    // Проверка завершения
    if nd:deltaV:mag < 0.5 {
        lock throttle to 0.
        remove nd.
        set phase to next_phase.
        return true.
    }
    stage_check_throttle().
    return false.
}

// -------------------------- ИНИЦИАЛИЗАЦИЯ ----------------------------------
clearScreen.
sas off.

// Сохраняем параметры текущей орбиты
set original_pe_alt to ship:orbit:periapsis - body:radius.
if original_pe_alt < 0 { set original_pe_alt to 0. }
set original_pe_radius to body:radius + original_pe_alt.

// Целевой апоцентр
set big_apo_radius to body:soiradius * target_apo_ratio.

print "Original periapsis altitude: " + round(original_pe_alt/1000,1) + " km".
print "Target apoapsis radius: " + round(big_apo_radius/1000,1) + " km".
print "Starting phase: " + phase.

// -------------------------- ГЛАВНЫЙ ЦИКЛ ------------------------------------
until phase = "DONE" {
    if phase <> prevPhase {
        print ">>> Phase: " + phase.
        set prevPhase to phase.
    }

    // ---------- ФАЗА WAIT_APOAPSIS: ожидание апоцентра ---------------------
    if phase = "WAIT_APOAPSIS" {
        if ship:orbit:eta:apoapsis < 10 {
            // Расчёт дельты для подъёма апоцентра
            local r_apo is ship:orbit:apoapsis.
            local a_current is ship:orbit:semimajoraxis.
            local a_target is (r_apo + big_apo_radius) / 2.
            local V_curr is ship:velocity:orbit:mag.
            local V_req is sqrt(body:mu * (2/r_apo - 1/a_target)).
            set deltaV_raise to V_req - V_curr.
            if deltaV_raise < 0 { set deltaV_raise to 0. }
            set burn_time_raise to deltaV_time(deltaV_raise).

            // Создаём узел манёвра в апоцентре
            set node_raise to node(time:seconds + ship:orbit:eta:apoapsis, 0, 0, deltaV_raise).
            add node_raise.

            print "DeltaV to raise apoapsis: " + round(deltaV_raise,1) + " m/s".
            print "Burn time: " + round(burn_time_raise,2) + " s".
            set phase to "EXECUTE_RAISE".
        }
        wait 0.
    }

    // ---------- ФАЗА EXECUTE_RAISE: выполнение подъёма ---------------------
    else if phase = "EXECUTE_RAISE" {
        if execute_node(node_raise, deltaV_raise, "COAST_TO_BIG_APO") {
            // После завершения манёвра переходим к дрейфу
            print "Raise maneuver completed.".
        }
        wait 0.
    }

    // ---------- ФАЗА COAST_TO_BIG_APO: дрейф к новому апоцентру -----------
    else if phase = "COAST_TO_BIG_APO" {
        // Ожидаем достижения нового апоцентра
        if ship:orbit:eta:apoapsis < 10 {
            // Расчёт дельты для разворота
            local r_apo is ship:orbit:apoapsis.
            local a is ship:orbit:semimajoraxis.
            local V_apo is sqrt(body:mu * (2/r_apo - 1/a)).
            set deltaV_reverse to 2 * V_apo.
            set burn_time_reverse to deltaV_time(deltaV_reverse).

            // Создаём узел разворота
            set node_reverse to node(time:seconds + ship:orbit:eta:apoapsis, 0, 0, -deltaV_reverse). // retrograde
            add node_reverse.

            print "DeltaV for reversal: " + round(deltaV_reverse,1) + " m/s".
            print "Burn time: " + round(burn_time_reverse,2) + " s".
            set phase to "EXECUTE_REVERSE".
        }
        wait 0.
    }

    // ---------- ФАЗА EXECUTE_REVERSE: разворот в апоцентре -----------------
    else if phase = "EXECUTE_REVERSE" {
        if execute_node(node_reverse, deltaV_reverse, "COAST_TO_PERI") {
            print "Reversal maneuver completed.".
        }
        wait 0.
    }

    // ---------- ФАЗА COAST_TO_PERI: ожидание перицентра после разворота ----
    else if phase = "COAST_TO_PERI" {
        // После разворота орбита стала эллиптической с перицентром на исходной высоте.
        // Ждём перицентра.
        if ship:orbit:eta:periapsis < 10 {
            // Расчёт дельты для циркуляризации
            local r_pe is ship:orbit:periapsis.
            local V_curr is ship:velocity:orbit:mag.
            local V_circ is sqrt(body:mu / r_pe).
            set deltaV_circ to V_circ - V_curr.
            if deltaV_circ < 0 { set deltaV_circ to 0. } // должно быть положительным (торможение)
            set burn_time_circ to deltaV_time(deltaV_circ).

            // Создаём узел для циркуляризации (prograde или retrograde? Нам нужно затормозить до круговой,
            // текущая скорость в перицентре больше круговой, так что тормозим (retrograde).
            set node_circ to node(time:seconds + ship:orbit:eta:periapsis, 0, 0, -deltaV_circ).
            add node_circ.

            print "DeltaV for circularization: " + round(deltaV_circ,1) + " m/s".
            print "Burn time: " + round(burn_time_circ,2) + " s".
            set phase to "EXECUTE_CIRC".
        }
        wait 0.
    }

    // ---------- ФАЗА EXECUTE_CIRC: циркуляризация в перицентре -------------
    else if phase = "EXECUTE_CIRC" {
        if execute_node(node_circ, deltaV_circ, "FINISHED") {
            print "Circularization completed.".
            set phase to "DONE".
        }
        wait 0.
    }

    // ---------- ФАЗА FINISHED: вывод статистики ----------------------------
    else if phase = "DONE" {
        print "Orbit reversal successfully completed.".
        print "Final orbit: altitude " + round(ship:orbit:periapsis/1000,1) + " km x " + round(ship:orbit:apoapsis/1000,1) + " km".
        // Здесь можно добавить подсчёт общего расхода Δv, но для простоты опустим.
        unlock throttle.
        break.
    }

    wait 0.   // Один игровой тик
}