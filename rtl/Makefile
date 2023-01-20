SVFILE=./cpu.sv ./decoder.sv ./execute.sv ./memory_access.sv ./write_back.sv
FLAGS=--Mdir ../obj_dir/ --trace --trace-params --trace-structs --trace-underscore
all: build

build:
	verilator -cc $(SVFILE) -exe ../test/cpu_test.cpp $(FLAGS)

run: build# program.bin
	make -C ../obj_dir -f Vcpu.mk
	../obj_dir/Vcpu

fifo_test:
	verilator -cc ./fifo.sv -exe ../test/fifo_test.cpp $(FLAGS)
	make -C ../obj_dir -f Vfifo.mk
	../obj_dir/Vfifo

i_cache_test:
	verilator -cc ./i_cache_with_memory.sv ./axi_memory.sv ./i_cache.sv ./direct_map.sv ./bram.sv -exe ../test/i_cache_test.cpp $(FLAGS)
	make -C ../obj_dir -f Vi_cache_with_memory.mk
	../obj_dir/Vi_cache_with_memory

d_cache_test:
	verilator -cc ./d_cache_with_memory.sv ./axi_memory.sv ./d_cache.sv ./direct_map.sv ./bram.sv -exe ../test/d_cache_test.cpp $(FLAGS)
	make -C ../obj_dir -f Vd_cache_with_memory.mk
	../obj_dir/Vd_cache_with_memory

direct_map_test:
	verilator -cc ./direct_map.sv ./bram.sv -exe ../test/direct_map_test.cpp $(FLAGS)
	make -C ../obj_dir -f Vdirect_map.mk
	../obj_dir/Vdirect_map

axi_memory_test:
	verilator -cc ./axi_memory.sv -exe ../test/axi_memory_test.cpp $(FLAGS)
	make -C ../obj_dir -f Vaxi_memory.mk
	../obj_dir/Vaxi_memory

top_test:
	verilator -cc ./top.sv ./axi_memory.sv ./i_cache.sv ./d_cache.sv ./direct_map.sv ./bram.sv $(SVFILE) -exe ../test/top_test.cpp $(FLAGS)
	make -C ../obj_dir -f Vtop.mk
	../obj_dir/Vtop

program.bin:
	make -C ../sample_src

clean:
	rm -rf *.vcd ../obj_dir
