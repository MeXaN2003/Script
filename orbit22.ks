// === Настройки ===
set VtoAngle to 250.
set DangAlt to 35000.
set UnDangAlt to 60000.
set targetApo to 80000.
set minAngle to 20.0.
set maxAngle to 85.0.
set mu to 3.5316e12.
set Rkerb to 600000.0.

// Настройки регулятора
set desiredAoA to -5.
set K_gain to 0.3.        // усиление: градусы коррекции на градус ошибки
set D_gain to 0.08.       // усиление: градусы коррекции на градус ошибки
set deadband to 0.2.      // мёртвая зона, градусы
set maxPitchRate to 0.6.  // макс. изменение pitch за одну итерацию
set minPitch to 40.       // минимально допустимый тангаж
set maxPitch to 85.       // максимально допустимый тангаж

// === Глобальные переменные ===
global phase to "PRELAUNCH".
global prevPhase to "".

global pitchDang to 80.0.
global pitchTwo to 0.
global Vap to 0.
global Vcir to 0.
global deltaV_timer to 0.
global circStartDV to 0.   // для учёта потраченного Δv
global circThrottle to 0.

// === Вспомогательная функция (без изменений) ===
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
    local effectiveIsp is totalThrust / weightedIspSum.
    local m0 is ship:mass * 1000.0.
    local T is totalThrust*1000.0.
    local isp is effectiveIsp.
    local expo is (-1.0*deltaV)/(isp*constant:g0).
    local burnTime is (m0*isp*constant:g0/T)*(1-constant:e^expo).
    return burnTime.
}

function signedAoA {
    local absAoA is vAng(ship:facing:forevector, velocity:surface).
    local crossProd is vcrs(ship:facing:forevector, velocity:surface).
    local refDir is vcrs(srfprograde:vector, up:vector):normalized. // боковое направление
    local sign is vdot(crossProd, refDir).
    if sign >= 0 {
        return absAoA.   // нос выше prograde
    } else {
        return -absAoA.  // нос ниже prograde
    }
}

function clamp {
    parameter val, minVal, maxVal.
    if val < minVal return minVal.
    if val > maxVal return maxVal.
    return val.
}

set prevTimeDeltaV to missionTime.
set deltaV_loses to 0.
// === Инициализация ===
clearScreen.
lock throttle to 1.0.
sas off.
lock steering to heading(90,90)+r(0,0,0).
print "3". wait 1.
print "2". wait 1.
print "1". wait 1.
print "Launch!".
stage.
wait 1.
clearScreen.


set phase to "LIFTOFF".

// === Главный цикл ===
until phase = "DONE" {
    // Сообщение при смене фазы
    if phase <> prevPhase {
        print ">>> Phase: " + phase.
        set prevPhase to phase.
    }

    if phase = "LIFTOFF" {
        lock steering to heading(90, 90).
        if velocity:surface:mag > VtoAngle {
            set phase to "GRAVITY_TURN_PHASE1".
        }
    }
    else if phase = "GRAVITY_TURN_PHASE1" {
        // Первая часть разворота до высоты DangAlt
        if ship:altitude < DangAlt {
            local currentAoA to signedAoA().
            local error to desiredAoA + currentAoA.
            if abs(error) > deadband {
                // Плавная коррекция
                local correction to clamp(error * K_gain - ship:angularvel:y*D_gain, -maxPitchRate, maxPitchRate).
                set pitchDang to pitchDang + correction.
                set pitchDang to clamp(pitchDang, minPitch, maxPitch).
                print "AoA: " + round(currentAoA,2) + "°  target pitch: " + round(pitchDang,2) + "correction: " + round(correction,2).
            }
            lock steering to heading(90, pitchDang).
        } else {
            set phase to "GRAVITY_TURN_PHASE2".
        }
    }
    else if phase = "GRAVITY_TURN_PHASE2" {
        // Вторая часть разворота до выгорания первой ступени (maxthrust=0)
        if ship:maxthrust > 0 {
            set pitchDang to (90.0-minAngle) - (maxAngle-minAngle)*((ship:altitude-DangAlt)/(UnDangAlt-DangAlt)).
            lock steering to heading(90, pitchDang).
            print "pitch:" + round(pitchDang,1) + "deg".
        } else {
            stage. // сброс первой ступени и запуск второй
            set pitchTwo to minAngle*(1-(ship:apoapsis/targetApo))+5.
            lock steering to heading(90, pitchTwo).
            set phase to "COAST_TO_AP".
        }
    }
    else if phase = "COAST_TO_AP" {
        // Дожиг до целевого апоцентра
        if ship:apoapsis < targetApo {
            set pitchTwo to minAngle*(1-(ship:apoapsis/targetApo))+5.
            lock steering to heading(90, pitchTwo).
            print "angle:" + round(pitchTwo,2) + "deg".
        } else {
            lock throttle to 0.
            print "apoapsis is targeting:" + round(ship:apoapsis,2).
            lock steering to prograde.
            // Расчёт параметров циркуляризации
            wait until ship:altitude > 70000. // ждём выхода из атмосферы (можно оставить, короткое ожидание)
            set Vap to sqrt(mu*((1.0-ship:orbit:eccentricity)/(ship:orbit:semimajoraxis*(1.0+ship:orbit:eccentricity)))).
            set Vcir to sqrt(mu/(Rkerb+ship:orbit:apoapsis)).
            print "Speed on Apo:" + round(Vap,1) + "m/s".
            print "Speed for circ:" + round(Vcir,1) + "m/s".
            print "deltaV:" + round((Vcir-Vap),1)+"m/s".
            set deltaV_timer to deltaV_time(Vcir-Vap).
            print "Burn Time:" + round(deltaV_timer,2) + "s".
            unlock throttle.
            set circStartDV to ship:deltav:current.
            set phase to "WAIT_FOR_BURN".
        }
    }
    else if phase = "WAIT_FOR_BURN" {
        // Ждём момента зажигания
        local leadTime is 1.8.
        if deltaV_timer >= 100 { set leadTime to 1.3. }
        if ship:orbit:eta:apoapsis - deltaV_timer/leadTime < 0 {
            // Начинаем циркуляризацию
            lock throttle to 1.0.
            set phase to "CIRCULARIZE".
        }
    }
    else if phase = "CIRCULARIZE" {
        // Выполнение циркуляризации (разобрано на кадры)
        local VcircDir is vxcl(up:vector, velocity:orbit):normalized.
        local VcircMag is sqrt(body:mu / body:position:mag).
        local Vcirc is VcircMag * VcircDir.
        local deltav is Vcirc - velocity:orbit.

        lock steering to lookDirUp(deltav, up:vector).

        if vAng(facing:vector, deltav) < 1 {
            // Наведение почти завершено, можно добавлять тягу
            set circThrottle to min(1, deltav:mag * ship:mass / ship:availablethrust).
            lock throttle to circThrottle.
        } else {
            lock throttle to 0.
        }

        if deltav:mag < 0.05 {
            // Манёвр выполнен
            lock throttle to 0.
            set phase to "FINISHED".
        }
    }
    else if phase = "FINISHED" {
        local TOTdeltaV is circStartDV - ship:deltav:current. // circStartDV был до манёвра, но ship:deltav:current уменьшается? В kOS deltav:current обнуляется или показывает оставшийся? Я использую подход из исходной circularize: там STdeltaV до, TOTdeltaV = STdeltaV - ship:deltav:current. Так оставлю.
        // На самом деле ship:deltav:current в kOS показывает оставшийся запас Δv ступени, а не потраченный. Но в исходном коде было именно так, оставим.
        print "Circularization used " + round(TOTdeltaV,1) + "m/s".
        print "Launch to orbit used " + round(deltaV_loses,1) + "m/s".
        unlock throttle.
        set phase to "DONE".
    }

    if missionTime >= prevTimeDeltaV + 0.5 {
        set prevTimeDeltaV to missionTime.
        set deltaV_loses to deltaV_loses + (ship:thrust/ship:mass)*0.5.
    }

    wait 0. // один кадр

}