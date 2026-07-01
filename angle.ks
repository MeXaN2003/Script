// 1. Параметры миссии
// -----------------
SET target_moon TO Mun.              // Выбираем Луну в качестве цели
SET parking_altitude TO SHIP:ALTITUDE. // Текущая высота орбиты

// 2. Расчет орбитальных параметров
// --------------------------------
// Гравитационный параметр Кербина
SET mu_kerbin TO BODY:MU.

// Орбитальный период Луны (секунды)
SET period_mun TO (2 * 3.1415926535) * SQRT(target_moon:ORBIT:SEMIMAJORAXIS^3 / mu_kerbin).

// Радиусы орбит (метры)
SET r_park TO BODY:RADIUS + parking_altitude.
SET r_mun TO target_moon:ORBIT:SEMIMAJORAXIS.

// 3. Расчет необходимого угла опережения (φ)
// ------------------------------------------
// Время перелета по гомановской траектории
SET transfer_time TO 3.1415926535 * SQRT( (r_park + r_mun)^3 / (8 * mu_kerbin) ).

// Рассчитываем угол отставания Луны (в радианах)
SET angle_rad TO (period_mun - (2 * transfer_time)) * ( (2 * 3.1415926535) / period_mun)*0.5.

PRINT "Phase angle: " + ROUND(angle_rad * (180/3.1415926535), 3) + "°".
wait 5.

// Функция для вычисления текущего угла отставания Луны
// Угол между направлением от Кербина к нам и к Луне

// Функция: stateVectors(orbit, nu)
// orbit - структура с полями: mu, a, ecc, inc, lan, argPe
// nu - истинная аномалия, рад
// Возвращает список из двух векторов: rVec, vVec (мировые координаты)

FUNCTION current_angle {
    LOCAL vec_ship IS SHIP:POSITION - BODY:POSITION.
    LOCAL vec_mun IS Mun:POSITION - BODY:POSITION.
    LOCAL abs_angle IS VANG(vec_ship, vec_mun).          // всегда 0..180
    LOCAL cross_prod IS VCRS(vec_ship, vec_mun).         // векторное произведение
    // В системе KSP ось Y — нормаль к плоскости эклиптики.
    // Если cross_prod:Y отрицательный, значит угол нужно взять со знаком минус.
    IF cross_prod:Y >= 0 {
        RETURN 360.0-abs_angle.
    }
    else {
        RETURN abs_angle.
    }
}

SET target_angle_deg TO angle_rad * (180/3.1415926535).
SET heading_deadband TO 0.5.
UNTIL ABS( current_angle() - target_angle_deg ) < heading_deadband {
    print "Angle now: " + round(current_angle(),1) + "deg".
    wait 0.5.
    clearScreen.
}

// 5. Расчет и выполнение маневра
// ------------------------------
// Скорость после разгона для перехода на эллипс встречи
SET v_transfer_to_mun TO SQRT( mu_kerbin * (2/r_park - 2/(r_park + r_mun)) ).

// Текущая орбитальная скорость
SET v_current TO SHIP:VELOCITY:ORBIT:MAG.

// Необходимая дельта-v для разгона
SET deltaV_needed TO v_transfer_to_mun - v_current.
PRINT "Delta-V required: " + ROUND(deltaV_needed, 1) + " m/s".