@SET CMD=%1%
@SET UUT=..\src\top.v ..\src\tv80s.v ..\src\tv80_alu.v ..\src\tv80_core.v ..\src\tv80_mcode.v ..\src\tv80_reg.v
@SET TESTFILE=testbus

iverilog -g 2012 -o %TESTFILE%.vvp %TESTFILE%.v %UUT%
vvp %TESTFILE%.vvp
