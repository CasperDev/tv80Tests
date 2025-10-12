# SystemVerilog Z80

TangNano series FPGA implementation of Z80
Utilize devcontainer of VSCode.
On Windowsw require Docker Desktop (and WSL)

## Running tests

To run all tests use command

	./run_tests.sh

To run one test specify subdirectory from ./tests directory

	./run_tests.sh 00_nop_INT_1

To run one test and open GTKWave with result

	./run_tests.sh 00_nop_INT_1 view

To run several tests at once use quoted wildcard mask

	./run_tests.sh "*nop*


## TODO

[ ] M1 control line (remove register)
[ ] RFSH control line (remove register)
[ ] MREQ control line timing
[ ] IORQ control line timing
[ ] RD control line timing
[ ] WR control line timing

[ ] Fix INT 2 ack cycle - should take 19T and takes 21T 
