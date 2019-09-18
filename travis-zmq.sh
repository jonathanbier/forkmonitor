git clone https://github.com/zeromq/zeromq4-x libzmq
cd libzmq
git checkout v4.0.9
./autogen.sh
./configure --with-pgm
make
sudo make install
#!/bin/bash
