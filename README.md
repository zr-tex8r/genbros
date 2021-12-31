genbros
=======

LaTeX：「源暎ブライス」フォントをLaTeXで使う

### 前提環境

  * フォーマット： LaTeX
  * エンジン：pdfTeX（DVI出力のみ※）・e-pTeX・e-upTeX  
    ※pdfTeXのPDF出力では「源暎ブライス」のフォント形式（AJ1グリフの
    OpenTypeフォント）はサポートされない。
  * DVIウェア（DVI出力時）： dvipdfmx
  * 「源暎ブライス」のフォントファイル（GenEiBrice.otf）  
    ※以下のサイトからダウンロードできます。  
    源暎フォント置き場  
    https://okoneya.jp/font/download.html#dl-gebr

### インストール

  - `*.sty`     → $TEXMF/tex/latex/genbros/
  - `tfm/*.tfm` → $TEXMF/fonts/tfm/public/genbros/
  - `vf/*.vf`   → $TEXMF/fonts/vf/public/genbros/
  - 「源暎ブライス」のフォントファイル`GenEiBrice.otf`を
    `$TEXMF/fonts/opentype/`以下のどこかに置く。
    ※OSにインストールしていて既にTeXから見えている場合は不要。

### ライセンス

本パッケージは MIT ライセンスの下で配布される。


genbros パッケージ
------------------

### パッケージ読込

    \usepackage[<オプション>,...]{genbros}

以下のオプションが指定できる。

  * `dvipdfmx`：DVI出力でdvipdfmxを用いる場合に指定する。
  * `\genbrossetup`に書く設定（`skscale=‹値›`など）はオプションに書くこと
    も可能。

### 使用法

以下の命令が提供される。

  * `\genbrosfamily`：「源暎ブライス」に切り替える宣言型フォント命令。  
    ※(u)pLaTeXの場合、和文欧文両方のファミリが切り替わる。
  * `\genbros{‹テキスト›}`：引数のテキストを「源暎ブライス」で出力。  
    ※途中で改行されないようにボックスに入れて出力される。(u)pLaTeXの場合
    は和欧文間空白が抑止される。  
    ※「源暎ブライス」でがサポートする文字種は限られていることに注意。
  * `\genbros*{‹テキスト›}`：引数のテキストを「源暎ブライス」で出力し、
    その際に和文文字を縮小する。
    ※(u)pLaTeX以外では`\genbros`と同じ。
  * `\genbrossetup{‹キー›=‹値›}`：パッケージの動作の設定。
      - `skscale=‹値›`：`\genbros*`での和文の縮小率。既定値は0.5。


更新履歴
--------

  * Version 0.2  ‹2021/12/31›
      - 最初の公開版。

--------------------
Takayuki YATO (aka. "ZR")  
https://github.com/zr-tex8r
