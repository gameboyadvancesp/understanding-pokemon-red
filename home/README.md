# home

ゲームシステム上必要なコードが入っている

home/以下のプログラムはBank0に配置されるためバンクスイッチなどで利用できなくなることはない。

## ファイル

 ファイル名  |  内容
---- | ----
 audio.asm  |  null
 copy.asm  |  データコピー用のユーティリティ関数
 copy2.asm  |  データコピー用のユーティリティ関数 <br/>copy.asmとは配置されるアドレスが離れている
 fade.asm  |  null
 init.asm  |  null
 joypad.asm  |  キー入力を処理する関数
 overworld.asm  |  null
 pic.asm  |  null
 predef.asm  |  predefに関する処理 <br/>predefについては[ドキュメント](../docs/predef.md)参照
 serial.asm  |  null
 text.asm  |  テキストの配置 <br/>特殊文字の処理 <br/>テキストコマンドの処理
 timer.asm  |  タイマー割り込みハンドラ
 vblank.asm  |  null
 vcopy.asm  |  null