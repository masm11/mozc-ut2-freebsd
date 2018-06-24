# Mozc-UT2 を FreeBSD で使う

Mozc-UT2 を FreeBSD でビルドできるようにしてみた。

ただし、ibus にのみ対応で、uim や fcitx については未確認。
emacs については動作する。

## 依存ソフトウェア

以下のものが必要なので、あらかじめインストールしておくこと。

- ninja
- py-gyp
- protobuf
- zinnia
- xdg-utils
- fontconfig
- freetype2
- tegaki-zinnia-japanese
- ibus

## インストール方法

1. まず、このリポジトリを clone する。

   ```sh
   git clone https://github.com/masm11/mozc-ut2-freebsd
   cd mozc-ut2-freebsd
   ```

2. `build.sh` が build script なので、
  
   ```sh
   vi build.sh
   ```

   でざっと眺めて、修正の必要があれば修正する。
   デフォルトでは `$HOME/.local/mozc/` にインストールする。

3. AUR からダウンロードし、展開する。

   ```sh
   wget https://aur.archlinux.org/cgit/aur.git/snapshot/mozc-ut2.tar.gz
   tar xf mozc-ut2.tar.gz
   ```

4. インストール済み mozc 関連パッケージを削除しておく。

5. おもむろに build を開始する。

   ```sh
   ./build.sh
   ```

   インストールも行われる。

6. mozc.xml に symbolic link を張る。

   ```sh
   sudo ln -s ~/.local/mozc/share/ibus/component/mozc.xml /usr/local/share/ibus/component/mozc.xml
   ```

## 設定

GNOME3 の場合は設定の「地域と言語」からいつも通り設定する。

そうでなくて ibus を直接起動している場合については、私は知らないので割愛。

Emacs の場合は、`~/.local/mozc/share/emacs/site-lisp/emacs-mozc` に
`load-path` を通し、

```elisp
(load "leim-list" nil t)
(setq default-input-method "japanese-mozc")
```

する。

## ライセンス

`build.sh` は GPLv3 とする。

以下のソフトウェアやデータをダウンロード、ビルド、インストールしている。

- mozc: 3-clause BSD
- mozc-ut2: 3-clause BSD
- altcanna, jinmei, skk: GPL
- hatena: 不明
- edict: Creative Commons Attribution-ShareAlike License (V3.0)
- ekimei: redistributable
- zip code: public domain
- niconico: 不明
- ruby/shell scripts: GPL
- leim-list.el: 2-clause BSD

ライセンス的に互換性のない辞書を混ぜて使っているようなので、
バイナリ配布はやめておくのが無難。

## 作者

masm11
