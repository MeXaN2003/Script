// ПАРАМЕТРЫ МИССИИ
local mu is ship:body:mu.               // гравитационный параметр Кербина (м³/с²)
local r1 is ship:orbit:radius.          // радиус вашей текущей орбиты (м)
local r2 is mun:orbit:radius.           // радиус орбиты Муна (м)
local targetBody is mun.                // целевое тело

print "Гравитационный параметр Кербина (mu): " + mu.
print "Текущая высота орбиты (м): " + r1.
print "Высота орбиты Муна (м): " + r2.

// ОПРЕДЕЛЕНИЕ ФАЗОВОГО УГЛА
// Рассчитываем время перелета по формуле Гомана
local transferTime is constant:pi * sqrt((r1 + r2)^3 / (8 * mu)).
print "Время перелета (сек): " + transferTime.

// Угловая скорость цели на орбите
local targetAngularVelocity is 360 / targetBody:orbit:period.
print "Угловая скорость Муна (град/сек): " + targetAngularVelocity.

// Идеальный фазовый угол (в градусах)
local phaseAngle is 180 - targetAngularVelocity * transferTime.
print "Расчетный фазовый угол (град): " + phaseAngle.

// Приводим к диапазону 0-360
set phaseAngle to phaseAngle - 360 * floor(phaseAngle / 360).

print "Целевой фазовый угол для старта (град): " + phaseAngle.