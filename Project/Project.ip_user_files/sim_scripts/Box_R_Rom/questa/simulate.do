onbreak {quit -f}
onerror {quit -f}

vsim -t 1ps -lib xil_defaultlib Box_R_Rom_opt

do {wave.do}

view wave
view structure
view signals

do {Box_R_Rom.udo}

run -all

quit -force
