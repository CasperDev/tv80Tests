//Copyright (C)2014-2025 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.12 (64-bit) 
//Created Time: 2025-10-12 15:45:40
create_clock -name clk -period 10 -waveform {0 5} [get_ports {clk}]
