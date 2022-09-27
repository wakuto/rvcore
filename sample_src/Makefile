PREFIX=riscv32-unknown-elf-
all:
	$(PREFIX)as ./start.S -c -o start.o
	$(PREFIX)ld ./start.o -Tlink.ld -o ./start.elf
	$(PREFIX)objcopy -O binary ./start.elf ./program.bin

clean:
	rm -f *.o *.elf *.bin

