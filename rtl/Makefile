SVFILE=./cpu.sv ./decoder.sv ./execute.sv ./memory_access.sv ./write_back.sv
all: build

build:
	verilator -cc $(SVFILE) -exe ../test/cpu_test.cpp --Mdir ../obj_dir

run: build# program.bin
	make -C ../obj_dir -f Vcpu.mk
	../obj_dir/Vcpu


program.bin:
	make -C ../sample_src
