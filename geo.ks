clearScreen.
global startRunway to latlng(-0.049, -74.7290569575315).
global endRunway to latlng(-0.049, -74.4968318033722).



until false {
// Вектор оси ВПП (от startRunway к endRunway)
// Вектор оси ВПП (от startRunway к endRunway)
LOCAL axisVec TO (endRunway:POSITION - startRunway:POSITION):NORMALIZED.

// Вертикаль в точке startRunway (вектор от центра тела к точке ВПП, нормализованный)
LOCAL upAtRunway TO startRunway:POSITION:NORMALIZED.

// Нормаль к вертикальной плоскости, проходящей через ось ВПП
LOCAL planeNormal TO VCRS(axisVec, upAtRunway):NORMALIZED.

// Вектор от точки ВПП до корабля
// ВАЖНО: используем SHIP:GEOPOSITION:POSITION, а не SHIP:POSITION !!
LOCAL toShipVec TO SHIP:GEOPOSITION:POSITION - startRunway:POSITION.

// Боковое отклонение (знаковое, метры)
LOCAL lateralError TO VDOT(toShipVec, planeNormal).

clearScreen.
print "Lateral deviation: " + round(lateralError, 1) + " m".
print "Azimut: " + round(endRunway:heading, 1) + " deg.".
print "Azimut error: " + round(endRunway:bearing, 1) + " deg.".
wait 0.5.
}
