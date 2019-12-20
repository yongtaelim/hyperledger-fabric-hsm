#!/bin/bash
  
echo "base package install..."
sudo apt update
sudo apt install botan gcc libssl-dev openssl make g++
wget https://github.com/protocolbuffers/protobuf/releases/download/v3.10.1/protobuf-all-3.10.1.tar.gz
tar -xvf protobuf-all-3.10.1.tar.gz 
protobuf-3.10.1/configure
