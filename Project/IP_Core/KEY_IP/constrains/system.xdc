# Clock signal 100 MHz
set_property -dict {PACKAGE_PIN H4 IOSTANDARD LVCMOS33} [get_ports Clk_100MHz]
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} -add [get_ports Clk_100MHz]

#key
set_property -dict {PACKAGE_PIN C3 IOSTANDARD LVCMOS33} [get_ports key]

#LED
set_property PACKAGE_PIN J1 [get_ports click]
set_property IOSTANDARD LVCMOS33 [get_ports click]
set_property PACKAGE_PIN A13 [get_ports hold]
set_property IOSTANDARD LVCMOS33 [get_ports hold]

set_property SEVERITY {Warning} [get_drc_checks UCIO-1]