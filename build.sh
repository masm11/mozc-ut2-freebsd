#!/usr/local/bin/bash

prefix=$HOME/.local/mozc
#root=/tmp/mozc

. ./mozc-ut2/PKGBUILD

_emacs_mozc=yes
_NICODIC=true

# _bldtype=Debug

download () {
  mkdir -p arcs
  cd arcs

  set -- $sha1sum
  i=0
  while :; do
    url=${source[$i]}
    if [ -z "$url" ]; then
      break
    fi
    echo $url
    sha1=${sha1sums[$i]}
    case $url in
    mozc::* )
      if [ -d mozc.git ]; then
	cd mozc.git
	git fetch
	cd ..
      else
	git clone --bare https://github.com/hrs-allbsd/mozc
      fi
      shift
      ;;
    http:* | https:* )
      filename=$(echo $url | sed -e 's|.*/||')
      if [ -f $filename ]; then
	if [ $(sha1 $filename | sed -e 's/.* = //') != $sha1 ]; then
	  echo "$filename: sha1 not match. reobtaining..." >&2
	  rm -f $filename
	fi
      fi
      if [ ! -f $filename ]; then
	wget $url
	if [ $(sha1 $filename | sed -e 's/.* = //') != $sha1 ]; then
	  echo "$filename: sha1 not match." >&2
	  exit 1
	fi
      fi
      ;;
    * )
      filename=$(echo $url | sed -e 's|.*/||')
      if [ -f $filename ]; then
	if [ $(sha1 $filename | sed -e 's/.* = //') != $sha1 ]; then
	  echo "$filename: sha1 not match. reobtaining..." >&2
	  rm -f $filename
	fi
      fi
      if [ ! -f $filename ]; then
	ln -s ../mozc-ut2/$url .
	if [ $(sha1 $filename | sed -e 's/.* = //') != $sha1 ]; then
	  echo "$filename: sha1 not match." >&2
	  exit 1
	fi
      fi

      if [ $(sha1 $url | sed -e 's/.* = //') != $sha1 ]; then
	echo "$url: sha1 not match." >&2
	exit 1
      fi
      ;;
    esac

    i=$(($i+1))
  done

  cd ..
}

extract () {
  rm -fr build
  mkdir build
  cd build

  i=0
  while :; do
    url=${source[$i]}
    if [ -z "$url" ]; then
      break
    fi

    case $url in
    mozc::* )
      rev=v2.20.2677.102.02
      git clone ../arcs/mozc.git
      cd mozc
      git checkout $rev
      cd ..
      ;;

    http:* | https:* )
      filename=$(echo $url | sed -e 's|.*/||')
      echo extracting $filename
      case $filename in
      *.zip )
	unzip ../arcs/$filename
	;;
      *.tar.* )
	tar xf ../arcs/$filename
	;;
      *.gz )
	cp ../arcs/$filename .
	gunzip $filename
	;;
      * )
	cp ../arcs/$filename .
	;;
      esac
      ;;

    * )
      cp ../arcs/$url .
      ;;
    esac

    i=$(($i+1))
  done

  cat mod-generate-dictionary.sh |
    sed -e '1s|.*|#!/usr/local/bin/bash|' \
	-e '/modify zip code data/s|/a|/a \\@|' |
    tr '@' '\012' > mod-generate-dictionary.sh.new
  mv mod-generate-dictionary.sh.new mod-generate-dictionary.sh
  chmod a+x mod-generate-dictionary.sh

  cd ..
}

prepare () {
  cd build

  ln -sf `which python2.7` "./python"

  cd "./mozc/"
  git submodule update --init --recursive

  patch -Np1 < ../mozc.patch

  cd "../mozcdic-ut2-${_utdicver}"

  ../mod-generate-dictionary.sh
  cat ./generate-dictionary.sh |
    sed -e 's|sed -i "|sed -i.bak -e "|' \
	-e 's|python2 |python2.7 |' \
	-e '1s|.*|#!/usr/local/bin/bash -e|' \
	-e 's/^MOZCVER=\(.*\)/: ${MOZCVER:=\1}/' \
	-e 's/^DICVER=\(.*\)/: ${DICVER:=\1}/' > generate-dictionary.sh.new
  mv generate-dictionary.sh.new ./generate-dictionary.sh
  chmod a+x ./generate-dictionary.sh
  echo "Generating UT dictionary seed..."
  MOZCVER="$_mozcver" DICVER="$_utdicver" NICODIC="$_NICODIC" \
    ./generate-dictionary.sh
  echo "Done."

  cd "../${pkgbase}-${pkgver}/src"

  # uim-mozc
  if [[ "$_uim_mozc" == "yes" ]]; then
    cp -rf "${srcdir}/uim-mozc/Mozc/uim" unix/
    # kill-line patch
    if [[ "$_kill_line" == "yes" ]]; then
      patch -p0 < "${srcdir}/uim-mozc/Mozc/mozc-kill-line.diff"
    fi
    # Extract license part of uim-mozc
    head -n 32 unix/uim/mozc.cc > unix/uim/LICENSE

  fi

  cd ../..
  cp ../leim-list.el .

  cd ..
}

build () {
  cd build

  PATH="$(/bin/pwd):${PATH}"

  cd "./${pkgbase}-${pkgver}/src"

  patch -p1 < /usr/ports/japanese/mozc-server/files/patch-src-unix_emacs_mozc.el

  LOCALBASE=/usr/local
  CC=clang60
  CXX=clang++60
  AR=/usr/local/bin/ar

  GYP_DEFINES="	use_libprotobuf=1
		channel_dev=0
		enable_unittest=0
		compiler_host=clang
		compiler_target=clang
		use_libzinnia=1
		zinnia_model_file=${LOCALBASE}/share/tegaki/models/zinnia/handwriting-ja.model
		ibus_mozc_icon_path=${LOCALBASE}/share/ibus-mozc/icons/product_icon.png
		ibus_mozc_path=${prefix}/libexec/ibus-engine-mozc
		use_libibus=1
		enable_gtk_renderer=1"


  GYP_OPTIONS="
	--noqt
      "
  # PYTHONPATH=${PYTHON_SITELIBDIR}/gyp
  PATH="${PATH}" \
  GYP_DEFINES="${GYP_DEFINES}" \
  CC_host="${CC}" \
  CC_target="${CC}" \
  CXX_host="${CXX}" \
  CXX_target="${CXX}" \
  LD_host="${CXX}" \
  AR_host="${AR}" \
  python2.7 build_mozc.py \
	gyp \
	    --gypdir=${LOCALBASE}/bin \
	    --server_dir="${prefix}/bin" \
	    --tool_dir="${prefix}/libexec" \
	    --renderer_dir="${prefix}/libexec" \
	    --localbase="${LOCALBASE}" \
	    --ldflags="${LDFLAGS} -fstack-protector -L${LOCALBASE}/lib" \
	    --cflags="${CFLAGS:Q}" \
	    --cflags_cc="${CXXFLAGS:Q}" \
	    --include_dirs="${LOCALBASE}/include" \
	    ${GYP_OPTIONS}

  # PYTHONPATH=${PYTHON_SITELIBDIR}/gyp
  PATH="${PATH}" \
  GYP_DEFINES="${GYP_DEFINES}" \
  CC_host="${CC}" \
  CC_target="${CC}" \
  CXX_host="${CXX}" \
  CXX_target="${CXX}" \
  LD_host="${CXX}" \
  AR_host="${AR}" \
  python2.7 build_mozc.py \
  build -c ${_bldtype} \
	server/server.gyp:mozc_server \
	unix/emacs/emacs.gyp:mozc_emacs_helper \
	gui/gui.gyp:mozc_tool \
	unix/ibus/ibus.gyp:ibus_mozc \
	renderer/renderer.gyp:mozc_renderer

  cd ../../
  cd ..
}

### package-mozc

install() {
    make_dir=
    if [ "$1" = "-D" ]; then
	make_dir=t
	shift
    fi
    
    mode=
    if [ "$1" = "-m" ]; then
	shift
	mode=$1
	shift
    fi

    src=$1; shift
    dst=$1; shift

    if [ -n "$make_dir" ]; then
	mkdir -p -m 0755 $(dirname $dst)
    fi

    rm -f $dst
    cp $src $dst
    if [ -n "$mode" ]; then
	chmod $mode $dst
    fi
}

install_mozc() {

  cd "build/${pkgbase}-${pkgver}/src"
  install -D -m 755 out_linux/${_bldtype}/mozc_server "${root}${prefix}/bin/mozc_server"
  install -D -m 755 out_linux/${_bldtype}/mozc_tool   "${root}${prefix}/libexec/mozc_tool"

  for x in data/installer/*.html; do
      install -D -m 644 $x "${root}${prefix}/lib/mozc/documents/$(basename $x)"
  done

  cd "../../.."
}

install_emacs_mozc() {

  cd "build/${pkgbase}-${pkgver}/src"
  install -D -m 755 out_linux/${_bldtype}/mozc_emacs_helper "${root}${prefix}/libexec/mozc_emacs_helper"

  cat unix/emacs/mozc.el | sed -e 's|%%PREFIX%%|'${prefix}'|' > unix/emacs/mozc.el.new
  install -D -m 644 unix/emacs/mozc.el.new "${root}${prefix}/share/emacs/site-lisp/emacs-mozc"/mozc.el
  rm -f unix/emacs/mozc.el.new
  cd ../..
  install -D -m 644 leim-list.el "${root}${prefix}/share/emacs/site-lisp/emacs-mozc"/leim-list.el
  cd ..
}

install_ibus_mozc() {

  cd "build/${pkgbase}-${pkgver}/src"
  install -D -m 755 out_linux/${_bldtype}/ibus_mozc       "${root}${prefix}/libexec/ibus-mozc/ibus-engine-mozc"
  cat out_linux/${_bldtype}/gen/unix/ibus/mozc.xml | sed -e 's|/libexec/ibus-engine-mozc|/libexec/ibus-mozc/ibus-engine-mozc|' > out_linux/${_bldtype}/gen/unix/ibus/mozc.xml.new
  install -D -m 644 out_linux/${_bldtype}/gen/unix/ibus/mozc.xml.new "${root}${prefix}/share/ibus/component/mozc.xml"
  
  install -D -m 644 data/images/unix/ime_product_icon_opensource-32.png "${root}${prefix}/share/ibus-mozc/product_icon.png"
  install -D -m 644 data/images/unix/ui-tool.png          "${root}${prefix}/share/ibus-mozc/tool.png"
  install -D -m 644 data/images/unix/ui-properties.png    "${root}${prefix}/share/ibus-mozc/properties.png"
  install -D -m 644 data/images/unix/ui-dictionary.png    "${root}${prefix}/share/ibus-mozc/dictionary.png"
  install -D -m 644 data/images/unix/ui-direct.png        "${root}${prefix}/share/ibus-mozc/direct.png"
  install -D -m 644 data/images/unix/ui-hiragana.png      "${root}${prefix}/share/ibus-mozc/hiragana.png"
  install -D -m 644 data/images/unix/ui-katakana_half.png "${root}${prefix}/share/ibus-mozc/katakana_half.png"
  install -D -m 644 data/images/unix/ui-katakana_full.png "${root}${prefix}/share/ibus-mozc/katakana_full.png"
  install -D -m 644 data/images/unix/ui-alpha_half.png    "${root}${prefix}/share/ibus-mozc/alpha_half.png"
  install -D -m 644 data/images/unix/ui-alpha_full.png    "${root}${prefix}/share/ibus-mozc/alpha_full.png"

  install -D -m 755 out_linux/${_bldtype}/mozc_renderer "${root}${prefix}/libexec/mozc_renderer"

  cd ../../..
}

download
extract
prepare
build

install_mozc
install_emacs_mozc
install_ibus_mozc
