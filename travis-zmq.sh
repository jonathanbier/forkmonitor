#!/bin/bash
if [ ! -d "$HOME/libzmq/.git/" ]; then
  git clone https://github.com/zeromq/zeromq4-x $HOME/libzmq
  cd $HOME/libzmq
  git checkout v4.0.9
  ./autogen.sh
  ./configure --with-pgm
  make
fi
cd $HOME/libzmq
sudo make install
