all: build

build:
	verilator -cc ./cpu.sv -exe ../test/cpu_test.cpp --Mdir ../obj_dir

run: build
	make -C ../obj_dir -f Vcpu.mk
	../obj_dir/Vcpu
