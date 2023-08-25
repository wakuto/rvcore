製作中のCPUコア。キャッシュは今動かないかも

## テストの実行方法

```
mkdir build
cd build
cmake -GNinja ..
ninja
ctest
```


## ディレクトリ構成
```
.
├── rtl	        # HDLファイル。コアの設計
├── sample_src  # コア上で実行するプログラム
└── test        # シミュレーション（verilator）のためのc++のプログラム
```

