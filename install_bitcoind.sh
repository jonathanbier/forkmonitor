#!/bin/bash
cd $TRAVIS_BUILD_DIR/vendor
# test/config.ini is normally generated at compile time, copy it manually:
cp bitcoin-config.ini bitcoin/test/config.ini
wget --quiet https://bitcoincore.org/bin/bitcoin-core-0.19.1/test.rc1/bitcoin-$BITCOIN_VERSION-x86_64-linux-gnu.tar.gz
tar -xzf bitcoin-$BITCOIN_VERSION-x86_64-linux-gnu.tar.gz bitcoin-$BITCOIN_VERSION
