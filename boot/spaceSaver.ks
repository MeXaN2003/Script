wait until ship:unpacked.
clearscreen.
print "Hello. I am the boot file.".
print "If you see this, that proves the boot file ran.".
CD("0:").
copyPath("/orbitSaver.ks", "1:/orbitSaver.ks").
copyPath("/munReverce.ks", "1:/munReverce.ks").
CD("1:").
run orbitSaver.