PREFIX=riscv32-unknown-elf-
all:
	$(PREFIX)as ./start.S -c -o start.o
	$(PREFIX)ld ./start.o -Tlink.ld -o ./start.elf
	$(PREFIX)objcopy -O binary ./start.elf ./program.bin

clang:
	$(PREFIX)gcc -march=rv32i -mabi=ilp32 ./test.c -S -o test.S
	$(PREFIX)as ./test.S -c -o test.o
	$(PREFIX)as ./start.S -march=rv32i -c -o start.o
	$(PREFIX)ld ./start.o ./test.o -Tlink.ld -o ./start.elf
	$(PREFIX)objcopy -O binary ./start.elf ./program.bin

clean:
	rm -f *.o *.elf *.bin

