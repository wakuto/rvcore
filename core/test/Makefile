RTLDIR=../rtl/
SVFILE=./core.sv ./decoder.sv ./execute.sv ./memory_access.sv ./write_back.sv
FLAGS=--Mdir ../obj_dir/ --trace --trace-params --trace-structs --trace-underscore

all: build

build:
	cd $(RTLDIR) && verilator -cc $(SVFILE) -exe ../test/cpu_test.cpp $(FLAGS)

run: build# program.bin
	make -C ../obj_dir -f Vcore.mk
	../obj_dir/Vcore

top_test:
	cd $(RTLDIR) && verilator -cc ./top.sv ./memory.sv $(SVFILE) -exe ../test/top_test.cpp $(FLAGS)
	make -C ../obj_dir -f Vtop.mk
	../obj_dir/Vtop

memory_test:
	cd $(RTLDIR) && verilator -cc ./memory.sv -exe ../test/memory_test.cpp $(FLAGS)
	make -C ../obj_dir -f Vmemory.mk
	../obj_dir/Vmemory

program.bin:
	make -C ../sample_src

clean:
	rm -rf *.vcd ../obj_dir
