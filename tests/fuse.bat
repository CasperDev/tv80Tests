@SET CMD=%1%
@SET UUT=..\src\tv80s.v ..\src\tv80_alu.v ..\src\tv80_core.v ..\src\tv80_mcode.v ..\src\tv80_reg.v
@SET TESTFILE=fuse

iverilog -g 2012 -o %TESTFILE%.vvp %TESTFILE%.v %UUT%
@if ERRORLEVEL 1 GOTO COMPILEERROR
vvp %TESTFILE%.vvp >log.txt
@GOTO END

:COMPILEERROR
@echo "Compile error!"

:END

