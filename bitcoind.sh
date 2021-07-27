#!/bin/bash
set -o xtrace
set -e
cd $TRAVIS_BUILD_DIR/vendor/bitcoin
if [ ! -f "$HOME/bin/bitcoind" ] || [ `$HOME/bin/bitcoind --version | head -n1 | grep -o '............$' ` != "670425431a8a" ]; then
  mkdir -p $HOME
  ./autogen.sh
  ./configure --prefix=$HOME --enable-wallet --without-bdb --without-gui --disable-tests --disable-bench --disable-fuzz-binary --without-miniupnpc --without-natpmp --enable-suppress-external-warnings --disable-external-signer
  make
  make install
fi
