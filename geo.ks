clearScreen.
global startRunway to latlng(-0.049, -74.7290569575315).
global endRunway to latlng(-0.049, -74.4968318033722).



until false {
    LOCAL axisVec TO (endRunway:POSITION - startRunway:POSITION):NORMALIZED.
    LOCAL toShipVec TO (SHIP:GEOPOSITION:POSITION - startRunway:POSITION).
    // Проекция на ось (расстояние вдоль)
    LOCAL alongDist TO VDOT(toShipVec, axisVec).
    // Перпендикулярный вектор (отклонение)
    LOCAL crossVec TO toShipVec - axisVec * alongDist.
    // Боковое отклонение (модуль) и направление (знак)
    LOCAL crossDist TO crossVec:mag.
    // Знак: плюс, если самолёт справа от оси (смотрим по направлению полёта)
    // Можно использовать векторное произведение: axisVec x toShipVec, но проще взять знак скалярного произведения с боковым направлением
    // Боковое направление: повернём axisVec на 90° по горизонтали
    LOCAL rightVec TO VCRS(axisVec, SHIP:UP:VECTOR):NORMALIZED.
    LOCAL sign TO VDOT(crossVec, rightVec) / abs(VDOT(crossVec, rightVec)).
    SET crossDist TO crossDist * sign.
    clearScreen.
    print "Distance to line: " + round(crossDist, 1) + " m".
    print "Azimut: " + round(endRunway:heading, 1) + " deg.".
    print "Azimut error: " + round(endRunway:bearing, 1) + " deg.".
    wait 0.5.
}
