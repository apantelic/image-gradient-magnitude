#clk
set_property -dict { PACKAGE_PIN H16 IOSTANDARD LVCMOS33 } [get_ports { clk_in }]

#gpio pin a0 - fpga pin y11
set_property -dict { PACKAGE_PIN Y11   IOSTANDARD LVCMOS33 } [get_ports { tx }]; #IO_L18N_T2_13 Sch=a[0]

# start = btn0
set_property -dict { PACKAGE_PIN M20   IOSTANDARD LVCMOS33 } [get_ports { reset }]; #IO_L7N_T1_AD2N_35 Sch=sw[0]
set_property -dict { PACKAGE_PIN D19   IOSTANDARD LVCMOS33 } [get_ports { start }]; #IO_L4P_T0_35 Sch=btn[0]

set_property -dict { PACKAGE_PIN G14    IOSTANDARD LVCMOS33 } [get_ports { led_transfer }]; #IO_0_35 Sch=LED5_B

