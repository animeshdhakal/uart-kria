DUT ?= uart_tx
VIVADO ?= orb -m vivado vivado -notrace -nojournal -nolog

.PHONY: all test clean project build

all: sim

project:
	$(VIVADO) -mode batch -source scripts/create_project.tcl

build:
	$(VIVADO) -mode batch -source scripts/build.tcl

clean:
	rm -rf *.log *.jou *.str .Xil build/vivado sim/sim_build sim/*.vcd sim/results.xml .pytest_cache
