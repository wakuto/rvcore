```sh
git clone git@github.com:eembc/coremark.git
cd coremark
patch -p1 < ../diff.patch
cp ../../../link.ld ./barebones
make PORT_DIR=barebones ITERATIONS=1
riscv32-unknown-elf-objcopy -O binary ./coremark.bin ../../../program.bin
cd ../../../../rtl
make top_test
```
ITERATIONSは実行回数らしい
メモリバカ食いなので注意
