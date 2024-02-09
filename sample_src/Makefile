PREFIX=riscv32-unknown-elf-

all: asm

asm:
	$(PREFIX)as ./start.S -c -o start.o
	$(PREFIX)ld ./start.o -Tlink.ld -o ./start.elf
	$(PREFIX)objcopy -O binary ./start.elf ./program.bin

clang:
	$(PREFIX)gcc -march=rv32i_zicsr -mabi=ilp32 ./test.c -S -o test.S
	$(PREFIX)as ./test.S -c -o test.o
	$(PREFIX)as ./start.S -march=rv32izicsr -c -o start.o
	$(PREFIX)ld ./start.o ./test.o -Tlink.ld -o ./start.elf
	$(PREFIX)objcopy -O binary ./start.elf ./program.bin

dump:
	$(PREFIX)objdump -d -M no-aliases -M numeric ./start.elf | less

commit_log: asm
	-@ ../build/rvcore ./program.bin
	spike -l --log-commits --log=./commit_log_spike_raw.txt \
		-d --debug-cmd=./spike.dbg \
		--isa=RV32I \
		./start.elf
	grep "core   0: 3 0x8" ./commit_log_spike_raw.txt > commit_log_spike.txt

diff_commit_log: commit_log
	diff ./commit_log_spike.txt ./commit_log_rvcore.txt

clean:
	rm -f *.o *.elf *.bin

.PHONY: all clean dump commit_log clang asm
