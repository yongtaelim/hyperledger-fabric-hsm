#!/bin/sh
  
echo "install softhsm2..."
wget https://dist.opendnssec.org/source/softhsm-2.5.0.tar.gz
tar -xzf softhsm-2.5.0.tar.gz
./softhsm-2.5.0/configure --disable-gost 
make -f ./Makefile
sudo make install -f ./Makefile
mkdir -p ../../softhsm/lib
cp /usr/local/lib/softhsm/libsofthsm2.so ../../softhsm/lib/.
