PREFIX=riscv32-unknown-elf-
all:
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

clean:
	rm -f *.o *.elf *.bin

