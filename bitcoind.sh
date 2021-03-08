#!/bin/bash
set -o xtrace
set -e
cd $TRAVIS_BUILD_DIR/vendor/bitcoin
if [ ! -f "$HOME/bin/bitcoind" ] || [ `$HOME/bin/bitcoind --version | head -n1 | grep -o '.........$' ` != "a8746f976" ]; then
  mkdir -p $HOME
  ./autogen.sh
  ./configure --prefix=$HOME --enable-wallet --without-bdb --without-gui --disable-tests --disable-bench --without-miniupnpc
  make
  make install
fi
