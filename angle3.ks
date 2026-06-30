//Настройки 
set target_body to mun.
set altitude_at_body to 200000.


//настройки регуляторов

//Глобальные переменные
global phase to "PRELAUNCH".
global prevPhase to "".
global TimeVisio to 0.
global flyby_altitude is altitude_at_body.
global spam is false.
//вспомогательные функции

function hyperbolic_flyby {
    parameter mu_t, r_flyby, v_inf.
    local bee is r_flyby * sqrt(1 + (2 * mu_t) / (r_flyby * v_inf^2)).
    return bee.
}

function time_to_angle_phase {
    parameter time_for_calc.
    parameter target_body is Mun.
    local w_ship is sqrt(body:mu / (body:radius+ship:altitude)^3).
    local w_target is sqrt(body:mu / target_body:orbit:semimajoraxis^3).
    return abs((w_ship-w_target)*constant:radtodeg*time_for_calc).
}

function stage_check_throttle {.
    if ship:maxthrust <= 0 {
        stage.
        wait 0.5.
    }
}

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
    if weightedIspSum > 0{
    local effectiveIsp is totalThrust / weightedIspSum.
    local m0 is ship:mass * 1000.0.
    local T is totalThrust*1000.0.
    local isp is effectiveIsp.
    local expo is (-1.0*deltaV)/(isp*constant:g0).
    local burnTime is (m0*isp*constant:g0/T)*(1-constant:e^expo).
    return burnTime.
    } else {
        print "NO THRUST?".
        return 0.
    }
    
}

function calc_target_angle{
    parameter target_body is Mun.
    parameter flyby_alt is flyby_altitude.

    local r_target_orbit is target_body:orbit:semimajoraxis.
    local r_parking is body:radius + ship:altitude.
    local r_target_soi is target_body:soiradius.
    local r_flyby is target_body:radius + flyby_alt.
    local v_inf is sqrt(body:mu / r_target_orbit) * (sqrt(2) - 1).
    local bi is hyperbolic_flyby(target_body:mu, r_flyby, v_inf).
    local r_encounter is sqrt(r_target_orbit^2 + bi^2).
    
    local transfer_time is constant:pi * sqrt((r_parking + r_encounter)^3 / (8 * body:mu)).
    
    local target_period is (2 * constant:pi) * SQRT(r_target_orbit^3 / body:mu).

    local angle_rad is (target_period - (2 * transfer_time)) * ( (2 * constant:pi) / target_period)*0.5.
    if spam {
        print "flyby_alt: " + round(flyby_alt,2).
        print "r_target_orbit: " + round(r_target_orbit,2).
        print "r_parking: " + round(r_parking,2).
        print "r_target_soi: " + round(r_target_soi,2).
        print "r_flyby: " + round(r_flyby,2).
        print "v_inf: " + round(v_inf,2).
        print "bi: " + round(bi,2).
        print "r_encounter: " + round(r_encounter,2).
        print "transfer_time: " + round(transfer_time,2).
        print "target_period: " + round(target_period,2).
        print "angle_rad*constant:radtodeg: " + round(angle_rad*constant:radtodeg,2).
    }
    
    return angle_rad*constant:radtodeg.
}

function current_angle_to_target {
    parameter target_body is Mun.
    local vec_ship is ship:position - body:position.
    local vec_target is target_body:position - body:position.
    local abs_angle is vang(vec_ship, vec_target).
    local cross_prod is vcrs(vec_ship, vec_target).
    if cross_prod:y >= 0 {
        return 360.0 - abs_angle.
    } else {
        return abs_angle.
    }
}

function calc_transfer_to_target {
    parameter target_body is Mun.
    parameter flyby_alt is flyby_altitude.
    local r_parking is body:radius + ship:altitude.
    local r_target_orbit is target_body:orbit:semimajoraxis.
    local r_target_soi is target_body:soiradius.
    local r_flyby is target_body:radius + flyby_alt.

    local v_inf is sqrt(body:mu / r_target_orbit)*(sqrt(2)-1).

    local bi is hyperbolic_flyby(target_body:mu, r_flyby, v_inf).

    local r_encounter is sqrt(r_target_orbit^2 + bi^2).
    
    local v_transfer_to_mun is sqrt(body:mu * (2/r_parking - 2/(r_parking + r_encounter))).
    local v_current is ship:velocity:orbit:mag.
    local v_deltaV_transfer is v_transfer_to_mun - v_current.
    return v_deltaV_transfer.
}
//Инициализация
set prevTimeVisio to missionTime.
set prevTimeVisio2 to missionTime.
set phase to "WAIT_LAUNCH_WINDOW".
//Главный цикл
until phase = "DONE" {
    if phase <> prevPhase {
        print ">>> Phase: " + phase.
        set prevPhase to phase.
    }

    else if phase = "WAIT_LAUNCH_WINDOW" {
        set time_to_burn to deltaV_time(abs(calc_transfer_to_target(target_body))).
        if missionTime - prevTimeVisio >= 0.5 {
            clearScreen.
            set prevTimeVisio to missionTime.
            print "target angle: " + round(calc_target_angle(target_body),1) + "°".
            print "current angle: " + round(current_angle_to_target(target_body),1) + "°".
            print "angle to next phase: " + round((calc_target_angle(target_body)+time_to_angle_phase(90+time_to_burn/2,target_body)),1) + "°".
        }
        
        if ABS( current_angle_to_target(target_body) - calc_target_angle(target_body) ) < time_to_angle_phase(90+time_to_burn/2) {
            set phase to "PREV_MANEURE".
        }
    }

    else if phase = "PREV_MANEURE" {
        lock steering to prograde.
        if missionTime - prevTimeVisio2 >= 0.5{
            clearScreen.
            set prevTimeVisio2 to missionTime.
            print "Delta V: " + round(calc_transfer_to_target(target_body),1) + " m/s".
            calc_target_angle(target_body).
        }
        if ABS( current_angle_to_target(target_body) - calc_target_angle(target_body) ) <= time_to_angle_phase(time_to_burn/1.9) {
            set phase to "MANEURE_TO_TRANSFER".
        }
    }

    else if phase = "MANEURE_TO_TRANSFER" {
        local v_deltav is calc_transfer_to_target(target_body)*(velocity:orbit:normalized).
        lock steering to lookDirUp(v_deltav, up:vector).
        stage_check_throttle().
        if vAng(facing:vector, v_deltav) < 1 {
            local burn_throttle is min(1,calc_transfer_to_target(target_body)*ship:mass/ship:availablethrust).
            lock throttle to burn_throttle.
        } else {
            lock throttle to 0.
        }
        if calc_transfer_to_target(target_body) < 0.05 {
            lock throttle to 0.
            set phase to "DONE".
        }
    }

    wait 0.

}
