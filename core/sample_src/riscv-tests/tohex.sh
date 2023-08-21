#!/bin/bash

FILES=./share/riscv-tests/isa/rv32*i-p-*
SAVE_DIR=./bin/

for f in $FILES
do
    FILE_NAME="${f##*/}"
    if [[ ! $f =~ "dump" ]]; then 
        riscv64-unknown-elf-objcopy -O binary $f $SAVE_DIR/$FILE_NAME.bin
    fi
done
