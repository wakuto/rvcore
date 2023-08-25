SVFILE=./core.sv ./decoder.sv ./execute.sv ./memory_access.sv ./write_back.sv
FLAGS=--Mdir ../obj_dir/ --trace --trace-params --trace-structs --trace-underscore
all: build

build:
	verilator -cc $(SVFILE) -exe ../test/cpu_test.cpp $(FLAGS)

run: build# program.bin
	make -C ../obj_dir -f Vcore.mk
	../obj_dir/Vcore

program.bin:
	make -C ../sample_src

clean:
	rm -rf *.vcd ../obj_dir
