wait until ship:unpacked.
clearscreen.
print "Hello. I am the boot file.".
print "If you see this, that proves the boot file ran.".
CD("0:").
copyPath("/XTV71.ks", "1:/XTV71.ks").
copyPath("/XTV7.ks", "1:/XTV7.ks").
CD("1:").
run XTV71.