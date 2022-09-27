製作中のCPUコア。
## ビルド方法

```
# まずは使用するプログラムのビルド
make -C ./sample_src

# 出来上がったprogram.binでシミュレーションを開始
make run -C ./rtl
```

## ディレクトリ構成
```
.
├── obj_dir 		# verilatorの出力ファイル類
├── rtl					# HDLファイル。コアの設計
├── sample_src  # コア上で実行するプログラム
└── test 			  # シミュレーション（verilator）のためのc++のプログラム
```

