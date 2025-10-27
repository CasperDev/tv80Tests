# SystemVerilog Z80

TangNano series FPGA implementation of Z80
Utilize devcontainer of VSCode.
On Windowsw require Docker Desktop (and WSL)

## Running tests

To run all tests use command

	./run_tests.sh

To run one test specify subdirectory from ./tests directory

	./run_tests.sh 00

To run one test and open GTKWave with result

	./run_tests.sh 00 view

To run several tests at once use quoted wildcard mask (enclosed in quotes!)

	./run_tests.sh "cb??*


## TODO

- [ ] M1 control line (remove register), real timing 
- [ ] RFSH control line (remove register), real timing
- [ ] MREQ control real line timing
- [ ] IORQ control real line timing
- [ ] RD control real line timing
- [ ] WR control real line timing

- [ ] Fix INT 2 ack cycle 
	- should take 19T and takes 21T (store PCL and PCH on stack should take 3T each but takes 4T each)

- [ ] Fix NMI ack cycle 
	- should take 11T and takes 15T (store PCL and PCH on stack should take 3T each but takes 4T each), 
	- fake fech should take 4T but takes 6T (2 wait states should not be included)


