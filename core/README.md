## coreテストの実行方法

### メモリのテスト

```sh
git clone git@github.com:wakuto/rvcore.git
cd rvcore/core/
mkdir build
cd build
cmake -GNinja ..
ninja
./memory_test
```
