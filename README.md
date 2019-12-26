# Future
- hyperledger fabric hsm 적용 binary
- TLS Apply

# Getting Started
- hyperledger fabric hsm 적용 docker

## hyerperledger fabric node docker image 생성
### fabric-ca 
1. fabric ca 소스 clone
```
git clone -b release-1.4 https://github.com/hyperledger/fabric-ca.git
```
2. Makefile 수정
```
vim Makefile

130 라인 수정
AS-IS : go install -ldflags "$(DOCKER_GO_LDFLAGS)" $(PKGNAME)/$(path-map.${@F})
TO-BE : go install -tags "$(GO_TAGS)" -ldflags "$(DOCKER_GO_LDFLAGS)" $(PKGNAME)/$(path-map.${@F})
```
3. docker image 생성
```
GO_TAGS=pkcs11 make docker
```

### fabric-orderer, fabric-peer, fabric-cli, fabric-ccenv
1. fabric ca 소스 clone
```
git clone -b release-1.4 https://github.com/hyperledger/fabric.git
```

2. peer, orderer docker image 생성 
```
GO_TAGS=pkcs11 make docker
```

3. cli docker image 생성
.build/image/tools/Dockerfile 수정 후 image 생성
```
make tools-docker

docker rmi -f hyperledger/fabric-tools

vim Dockerfile

[modify]11번째 줄
AS-IS : RUN make configtxgen configtxlator cryptogen peer discover idemixgen
TO-BE : RUN make GO_TAGS=pkcs11  configtxgen configtxlator cryptogen peer discover idemixgen

make tools-docker
```

4. fabric-ccenv
.build/image/ccenv/Dockerfile 수정 후 image 생성
```
make ccenv

docker rmi -f hyperledger/fabric-ccenv

vim Docker

[add]
ENV GODEBUG netdns=go
```

## hyperledger fabric network start
### 설치 환경 구성
#### 1. git source clone
```
git clone https://github.com/yongtaelim/hyperledger-fabric-hsm.git
```
#### 2. softhsm을 사용하기 위한 환경 세팅
```
cd hyperledger-fabric-hsm/init/base/
chmod +x package-install.sh
./package-install.sh
```
##### package-install details
>openssl
>botan
>gcc
>libssl-dev
>make
>g++
>protobuf

##### /etc/hosts 파일 수정
>127.0.0.1  ca.org1.example.com
>127.0.0.1  tlsca.org1.example.com

#### 3. softhsm 설치
```
cd hyperledger-fabric-hsm/init/softhsm/
chmod +x softhsm-install.sh
./softhsm-install.sh
```
##### softhsm install detail
1. download
```
wget https://dist.opendnssec.org/source/softhsm-2.5.0.tar.gz
```
2. tar 압축 해제
```
tar -xzf softhsm-2.5.0.tar.gz
```
3. configure 실행
```
./configure --disable-gost
```
4. make 
```
make

make install
```

#### 4. fabric start
- make로 softhsm, fabric start를 진행한다.
```
make 
```
description)
>softhsm 세팅 및 fabric 구성 실행
##### init-token
- hyperledger fabric에 필요한 token을 생성한다. ( hyperledger fabric document 기준 )
```
export SOFTHSM2_CONF="/etc/softhsm2.conf"
softhsm2-util --init-token --slot 0 --label "ForFabric" --so-pin 1234 --pin 98765432
```
description)  
>--slot :: 추가할 slot 넘버를 입력한다. 현재 2번 slot까지 등록이 되있고 3번에 추가를 원할 경우 '3'을 입력한다.  
>--label :: DB로 비교해봤을 경우 table이라고 생각하면 된다.  
>--so-pin :: 관리자 비밀번호  
>--pin :: user 비밀번호

##### softhsm-show-slots 
- slot list를 조회한다.
```
softhsm2-util --show-slots
```
- 정상적으로 설치가 완료되었다면 아래의 경로에 관련 파일 및 폴더 생성
```
## so file
./softhsm/libsofthsm2.so
## token folder
./softhsm/tokens/
## config file
./softhsm/softhsm2.conf
```

##### ca-start
- fabric ca server를 시작한다.
###### docker-compose-ca.yaml
```
ca.org1.example.com:
   image: hyperledger/fabric-ca
   container_name: ca.org1.example.com
   ports:
     - "7054:7054"
   environment:
     - FABRIC_CA_HOME=/etc/hyperledger/fabric-ca-server
     - FABRIC_CA_SERVER_DEBUG=true
     - GODEBUG=netdns=go
     - SOFTHSM2_CONF=/etc/hyperledger/fabric/softhsm/config/softhsm2.conf
   volumes:
     - ./ca:/etc/hyperledger/fabric-ca-server
     - ../softhsm/config/softhsm2.conf:/etc/hyperledger/fabric/softhsm/config/softhsm2.conf
     - ../softhsm/tokens/:/etc/hyperledger/fabric/softhsm/tokens
     - ../softhsm/lib/libsofthsm2.so:/etc/hyperledger/fabric/libsofthsm2.so
   command: sh -c 'fabric-ca-server start -b admin:adminpw'
```
###### fabric-ca-server-config.yaml
```
bccsp:
    default: PKCS11
    pkcs11:
      Library: /etc/hyperledger/fabric/libsofthsm2.so
      Pin: 98765432
      Label: ForFabric
      hash: SHA2
      security: 256
      filekeystore:
      # The directory used for the software file-based keystore
        keystore: msp/keystore
```
###### docker container 실행
```
docker-compose -f docker-compose-ca.yaml up -d
```
##### ca-enroll
- fabric-ca-client를 이용하여 ca admin 계정을 enroll한다.
##### generate-orderer-admin
1. fabric-ca-client를 이용하여 orderer admin 계정을 register한다.
2. fabric-ca-client를 이용하여 orderer admin 계정을 enroll한다.
3. msp폴더에서 admincert 폴더 생성
4. signcerts 폴더 내 cert파일을 admincert 폴더 내로 복사
##### generate-peer-admin
1. fabric-ca-client를 이용하여 peer admin 계정을 register한다.
2. fabric-ca-client를 이용하여 peer admin 계정을 enroll한다.
3. msp폴더에서 admincert 폴더 생성
4. signcerts 폴더 내 cert파일을 admincert 폴더 내로 복사
##### generate-peer-user
1. fabric-ca-client를 이용하여 peer user 계정을 register한다.
2. fabric-ca-client를 이용하여 peer user 계정을 enroll한다.
3. msp폴더에서 admincert 폴더 생성
4. peer admin msp signcerts 폴더 내 cert파일을 peer user msp admincert 폴더 내로 복사
##### create-genesis-block
- configtxgen 바이너리 파일을 이용하여 configtx.yaml 파일 기반 genesis.block 파일 생성
##### create-channel-transaction
- configtxgen 바이너리 파일을 이용하여 configtx.yaml 파일 기반 channel.tx 파일 생성
##### orderer-start
- orderer node를 시작한다.
###### docker-compose-orderer.yaml
```
services:
  orderer.example.com:
    container_name: orderer.example.com
    image: hyperledger/fabric-orderer
    environment:
      - FABRIC_LOGGING_SPEC=debug
      - ORDERER_GENERAL_LISTENADDRESS=0.0.0.0
      - ORDERER_GENERAL_GENESISMETHOD=file
      - ORDERER_GENERAL_GENESISFILE=/etc/hyperledger/configtx/genesis.block
      - ORDERER_GENERAL_LOCALMSPID=OrdererMSP
      - ORDERER_GENERAL_LOCALMSPDIR=/etc/hyperledger/msp/orderer/msp
      - GODEBUG=netdns=go
      - SOFTHSM2_CONF=/etc/hyperledger/fabric/softhsm/config/softhsm2.conf
    working_dir: /opt/gopath/src/github.com/hyperledger/fabric/orderer
    command: orderer
    ports:
      - 7050:7050
    volumes:
        - ../config/:/etc/hyperledger/configtx
        - ../crypto-config/ordererOrganizations/ordererorg/:/etc/hyperledger/msp/orderer
        - ./orderer/orderer.yaml:/etc/hyperledger/fabric/orderer.yaml
        - ./orderer/msp/:/etc/hyperledger/fabric/msp
        - ../softhsm/config/softhsm2.conf:/etc/hyperledger/fabric/softhsm/config/softhsm2.conf
        - ../softhsm/tokens/:/etc/hyperledger/fabric/softhsm/tokens
        - ../softhsm/lib/libsofthsm2.so:/etc/hyperledger/fabric/libsofthsm2.so
```
###### orderer.yaml
```
    BCCSP:
        # Default specifies the preferred blockchain crypto service provider
        # to use. If the preferred provider is not available, the software
        # based provider ("SW") will be used.
        # Valid providers are:
        #  - SW: a software based crypto provider
        #  - PKCS11: a CA hardware security module crypto provider.
        Default: PKCS11
        PKCS11:
            # Location of the PKCS11 module library
            Library: /etc/hyperledger/fabric/libsofthsm2.so
            # Token Label
            Label: ForFabric
            # User PIN
            Pin: 98765432
            Hash: SHA2
            Security: 256
            FileKeyStore:
                KeyStore: msp/keystore
```
###### docker container 실행
```
docker-compose -f docker-compose-orderer.yaml up -d
```
##### peer-start
- peer node를 시작한다.
###### docker-compose-peer.yaml
```
services:
  peer0.org1.example.com:
    container_name: peer0.org1.example.com
    image: hyperledger/fabric-peer
    environment:
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      - CORE_PEER_ID=peer0.org1.example.com
      - CORE_PEER_ENDORSER_ENABLED=true
      - FABRIC_LOGGING_SPEC=debug
      - CORE_CHAINCODE_LOGGING_LEVEL=debug
      - CORE_PEER_LOCALMSPID=Org1MSP
      - CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/msp/peer/msp
      - CORE_PEER_LISTENADDRESS=0.0.0.0:7051
      - CORE_PEER_ADDRESS=peer0.org1.example.com:7051
      - CORE_PEER_CHAINCODEADDRESS=peer0.org1.example.com:7052
      - CORE_PEER_CHAINCODELISTENADDRESS=0.0.0.0:7052
      - GODEBUG=netdns=go
      - CORE_LEDGER_STATE_STATEDATABASE=CouchDB
      - CORE_LEDGER_STATE_COUCHDBCONFIG_COUCHDBADDRESS=couchdb:5984
      - CORE_LEDGER_STATE_COUCHDBCONFIG_USERNAME=
      - CORE_LEDGER_STATE_COUCHDBCONFIG_PASSWORD=
      - SOFTHSM2_CONF=/etc/hyperledger/fabric/softhsm/config/softhsm2.conf
    working_dir: /opt/gopath/src/github.com/hyperledger/fabric
    command: peer node start
    ports:
      - 7051:7051
      - 7053:7053
    volumes:
        - /var/run/:/host/var/run/
        - ../crypto-config/peerOrganizations/peerorg1/msp:/etc/hyperledger/msp/peer/msp
        - ../crypto-config/peerOrganizations/peerorg1/users:/etc/hyperledger/msp/users
        - ../config:/etc/hyperledger/configtx
        - ./peer/core.yaml:/etc/hyperledger/fabric/core.yaml
        - ./peer/msp/:/etc/hyperledger/fabric/msp
        - ../chaincode/:/opt/gopath/src/github.com/chaincode
        - ../softhsm/config/softhsm2.conf:/etc/hyperledger/fabric/softhsm/config/softhsm2.conf
        - ../softhsm/tokens/:/etc/hyperledger/fabric/softhsm/tokens
        - ../softhsm/lib/libsofthsm2.so:/etc/hyperledger/fabric/libsofthsm2.so

    depends_on:            
      - couchdb

  couchdb:
    container_name: couchdb
    image: hyperledger/fabric-couchdb
    environment:
      - COUCHDB_USER=
      - COUCHDB_PASSWORD=
    ports:
      - 5984:5984
```
###### core.yaml
```
    BCCSP:
        Default: PKCS11
        # Settings for the PKCS#11 crypto provider (i.e. when DEFAULT: PKCS11)
        PKCS11:
            # Location of the PKCS11 module library
            Library: /etc/hyperledger/fabric/libsofthsm2.so
            # Token Label
            Label: ForFabric
            # User PIN
            Pin: 98765432
            Hash: SHA2
            Security: 256
            FileKeyStore:
                KeyStore: msp/keystore
```
###### docker container 실행
```
docker-compose -f docker-compose-peer.yaml up -d
```
##### cli-start
- cli node를 시작한다.
###### docker-compose-cli.yaml
```
services:
  cli:
    container_name: cli
    image: hyperledger/fabric-tools
    tty: true
    environment:
      - GOPATH=/opt/gopath
      - GODEBUG=netdns=go
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      - FABRIC_LOGGING_SPEC=debug
      - CORE_PEER_ID=cli
      - CORE_PEER_ADDRESS=peer0.org1.example.com:7051
      - CORE_PEER_LOCALMSPID=Org1MSP
      - CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/peerorg1/users/Admin@org1.example.com/msp
      - CORE_CHAINCODE_KEEPALIVE=10
      - SOFTHSM2_CONF=/etc/hyperledger/fabric/softhsm/config/softhsm2.conf
    working_dir: /opt/gopath/src/github.com/hyperledger/fabric/peer
    command: /bin/bash
    volumes:
        - /var/run/:/host/var/run/
        - ./../chaincode/:/opt/gopath/src/github.com/chaincode
        - ./../crypto-config:/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/
        - ./cli/:/etc/hyperledger/fabric
        - ../softhsm/config/softhsm2.conf:/etc/hyperledger/fabric/softhsm/config/softhsm2.conf
        - ../softhsm/tokens/:/etc/hyperledger/fabric/softhsm/tokens
        - ../softhsm/lib/libsofthsm2.so:/etc/hyperledger/fabric/libsofthsm2.so          
```
###### core.yaml, orderer.yaml
- peer node start, orderer node start 와 동일

###### docker container 실행
```
docker-compose -f docker-compose-cli.yaml up -d
```
##### channel-create
- channel.tx 파일을 이용하여 channel 생성
##### channel-join
- channel.block 파일을 이용하여 peer를 channel에 가입

#### 5. fabric tls start
- make로 softhsm, fabric tls적용 버전을 진행한다.
```
make softhsm
make fabric-tls
```
description)
>softhsm 세팅 및 fabric tls 구성 실행
##### init-token
- 위와 동일

##### softhsm-show-slots 
- 위와 동일

##### catls-start
- TLS 적용된 fabric ca server를 시작한다.
###### docker-compose-catls.yaml
```
ca.org1.example.com:
    image: hyperledger/fabric-ca
    container_name: ca.org1.example.com
    ports:
      - "7054:7054"
    environment:
      - FABRIC_CA_HOME=/etc/hyperledger/fabric-ca-server
      - FABRIC_CA_SERVER_DEBUG=true
      - GODEBUG=netdns=go  
      - SOFTHSM2_CONF=/etc/hyperledger/fabric/softhsm/config/softhsm2.conf 
      - FABRIC_CA_SERVER_TLS_ENABLED=true
      - FABRIC_CA_SERVER_TLS_CERTFILE=/etc/hyperledger/fabric-ca-server-config/ca.org1.example.com-cert.pem
      - FABRIC_CA_SERVER_TLS_KEYFILE=/etc/hyperledger/fabric-ca-server-config/27032b3010f9976a4145f8e49185f9f065d1f343a78855c2bfb12bf1556ac312_sk
    volumes:
      - ./ca:/etc/hyperledger/fabric-ca-server
      - ../softhsm/config/softhsm2.conf:/etc/hyperledger/fabric/softhsm/config/softhsm2.conf
      - ../softhsm/tokens/:/etc/hyperledger/fabric/softhsm/tokens
      - ../softhsm/lib/libsofthsm2.so:/etc/hyperledger/fabric/libsofthsm2.so
      - ../crypto-config/catlsOrganizations/ca/:/etc/hyperledger/fabric-ca-server-config
    command: sh -c 'fabric-ca-server start --ca.certfile /etc/hyperledger/fabric-ca-server-config/ca.org1.example.com-cert.pem --ca.keyfile /etc/hyperledger/fabric-ca-server-config/27032b3010f9976a4145f8e49185f9f065d1f343a78855c2bfb12bf1556ac312_sk -b admin:adminpw -d'
```
###### fabric-ca-server-config.yaml
```
bccsp:
    default: PKCS11
    pkcs11:
      Library: /etc/hyperledger/fabric/libsofthsm2.so
      Pin: 98765432
      Label: ForFabric
      hash: SHA2
      security: 256
      filekeystore:
      # The directory used for the software file-based keystore
        keystore: msp/keystore
```

###### docker container 실행
```
docker-compose -f docker-compose-catls.yaml up -d
```
##### ca-enroll
- tls 적용된 fabric-ca-client를 이용하여 ca admin 계정을 enroll한다.
```
fabric-ca-client enroll \
				-u https://admin:adminpw@ca.org1.example.com:7054 \
				--tls.certfiles $(PROJECT_PATH)/crypto-config/catlsOrganizations/ca/ca.org1.example.com-cert.pem \
				--home ./client/admin	
```
##### generate-orderertls-admin
1. tls 적용된 fabric-ca-client를 이용하여 orderer admin 계정을 register한다.
2. tls 적용된 fabric-ca-client를 이용하여 orderer admin 계정을 enroll한다.
3. msp폴더에서 admincert 폴더 생성
4. signcerts 폴더 내 cert파일을 admincert 폴더 내로 복사
##### generate-peertls-admin
1. tls 적용된 fabric-ca-client를 이용하여 peer admin 계정을 register한다.
2. tls 적용된 fabric-ca-client를 이용하여 peer admin 계정을 enroll한다.
3. msp폴더에서 admincert 폴더 생성
4. signcerts 폴더 내 cert파일을 admincert 폴더 내로 복사
##### generate-peertls-user
1. tls 적용된 fabric-ca-client를 이용하여 peer user 계정을 register한다.
2. tls 적용된 fabric-ca-client를 이용하여 peer user 계정을 enroll한다.
3. msp폴더에서 admincert 폴더 생성
4. peer admin msp signcerts 폴더 내 cert파일을 peer user msp admincert 폴더 내로 복사
##### ca-tls-start
- TLS 발급 전용 fabric ca server를 시작한다.
###### docker-compose-ca-tls.yaml
```
tlsca.org1.example.com:
   image: hyperledger/fabric-ca
   container_name: tlsca.org1.example.com
   ports:
     - "8054:7054"
   environment:
     - FABRIC_CA_HOME=/etc/hyperledger/fabric-ca-server
     - FABRIC_CA_SERVER_DEBUG=true
     - GODEBUG=netdns=go  
     - FABRIC_CA_SERVER_TLS_ENABLED=true     
     - FABRIC_CA_SERVER_TLS_CERTFILE=/etc/hyperledger/fabric-ca-server-config/tlsca.org1.example.com-cert.pem
     - FABRIC_CA_SERVER_TLS_KEYFILE=/etc/hyperledger/fabric-ca-server-config/729ce212c363f324abb320ca1406aa7e65ef5a121ae634103ef6e8d2d787a49b_sk
     - FABRIC_CA_SERVER_PORT=7054
   volumes:
     - ./ca-tls:/etc/hyperledger/fabric-ca-server
     - ../crypto-config/catlsOrganizations/tlsca/:/etc/hyperledger/fabric-ca-server-config
     
   command: sh -c 'fabric-ca-server start --ca.certfile /etc/hyperledger/fabric-ca-server-config/tlsca.org1.example.com-cert.pem --ca.keyfile /etc/hyperledger/fabric-ca-server-config/729ce212c363f324abb320ca1406aa7e65ef5a121ae634103ef6e8d2d787a49b_sk -b admin:adminpw -d'
```
###### fabric-ca-server-config.yaml
- default로 생성되는 yaml파일로 진행

###### docker container 실행
```
docker-compose -f docker-compose-ca-tls.yaml up -d
```
##### ca-enroll
- tls 적용된 fabric-ca-client를 이용하여 ca-tls admin 계정을 enroll한다.
```
fabric-ca-client enroll \
				-u https://admin:adminpw@tlsca.org1.example.com:8054 \
				--enrollment.profile tls \
				--tls.certfiles $(PROJECT_PATH)/crypto-config/catlsOrganizations/ca/ca.org1.example.com-cert.pem \
				--home ./client/tls/admin	
```
##### generate-orderer-tls-admin
1. tls 적용된 fabric-ca-client를 이용하여 orderer server tls 계정을 register한다.
2. tls 적용된 fabric-ca-client를 이용하여 orderer server tls 계정을 enroll한다.
3. msp폴더에서 tls 폴더 생성
4. 생성된 파일들을 tls 폴더로 복사한다.
```
cp $(ORDERER_MSP_PATH)/tlsca/keystore/* $(ORDERER_MSP_PATH)/tls/server.key
cp $(ORDERER_MSP_PATH)/tlsca/signcerts/* $(ORDERER_MSP_PATH)/tls/server.crt
cp $(ORDERER_MSP_PATH)/tlsca/tlscacerts/* $(ORDERER_MSP_PATH)/tls/ca.crt
```
##### generate-peer-tls-admin
1. tls 적용된 fabric-ca-client를 이용하여 peer server tls 계정을 register한다.
2. tls 적용된 fabric-ca-client를 이용하여 peer server tls 계정을 enroll한다.
3. msp폴더에서 tls 폴더 생성
4. 생성된 파일들을 tls 폴더로 복사한다.
```
cp $(ORDERER_MSP_PATH)/tlsca/keystore/* $(ORDERER_MSP_PATH)/tls/server.key
cp $(ORDERER_MSP_PATH)/tlsca/signcerts/* $(ORDERER_MSP_PATH)/tls/server.crt
cp $(ORDERER_MSP_PATH)/tlsca/tlscacerts/* $(ORDERER_MSP_PATH)/tls/ca.crt
```
##### create-genesis-block
- configtxgen 바이너리 파일을 이용하여 configtx.yaml 파일 기반 genesis.block 파일 생성
##### create-channel-transaction
- configtxgen 바이너리 파일을 이용하여 configtx.yaml 파일 기반 channel.tx 파일 생성
##### orderertls-start
- orderer node를 시작한다.
###### docker-compose-orderertls.yaml
```
services:
  orderer.example.com:
    container_name: orderer.example.com
    image: hyperledger/fabric-orderer
    environment:
      - FABRIC_LOGGING_SPEC=debug
      - ORDERER_GENERAL_LISTENADDRESS=0.0.0.0
      - ORDERER_GENERAL_GENESISMETHOD=file
      - ORDERER_GENERAL_GENESISFILE=/etc/hyperledger/configtx/genesis.block
      - ORDERER_GENERAL_LOCALMSPID=OrdererMSP
      - ORDERER_GENERAL_LOCALMSPDIR=/etc/hyperledger/msp/orderer/msp
      - GODEBUG=netdns=go  
      - SOFTHSM2_CONF=/etc/hyperledger/fabric/softhsm/config/softhsm2.conf  
      - ORDERER_GENERAL_TLS_ENABLED=true
      - ORDERER_GENERAL_TLS_PRIVATEKEY=/etc/hyperledger/msp/orderer/tls/server.key
      - ORDERER_GENERAL_TLS_CERTIFICATE=/etc/hyperledger/msp/orderer/tls/server.crt
      - ORDERER_GENERAL_TLS_ROOTCAS=[/etc/hyperledger/msp/orderer/tls/ca.crt]
    working_dir: /opt/gopath/src/github.com/hyperledger/fabric/orderer
    command: orderer
    ports:
      - 7050:7050
    volumes:
        - ../config/:/etc/hyperledger/configtx
        - ../crypto-config/ordererOrganizations/ordererorg/:/etc/hyperledger/msp/orderer
        - ./orderer/orderer.yaml:/etc/hyperledger/fabric/orderer.yaml
        - ./orderer/msp/:/etc/hyperledger/fabric/msp
        - ../softhsm/config/softhsm2.conf:/etc/hyperledger/fabric/softhsm/config/softhsm2.conf  
        - ../softhsm/lib/libsofthsm2.so:/etc/hyperledger/fabric/libsofthsm2.so
        - ../softhsm/tokens/:/etc/hyperledger/fabric/softhsm/tokens  
```
###### orderer.yaml
```
    BCCSP:
        # Default specifies the preferred blockchain crypto service provider
        # to use. If the preferred provider is not available, the software
        # based provider ("SW") will be used.
        # Valid providers are:
        #  - SW: a software based crypto provider
        #  - PKCS11: a CA hardware security module crypto provider.
        Default: PKCS11
        PKCS11:
            # Location of the PKCS11 module library
            Library: /etc/hyperledger/fabric/libsofthsm2.so
            # Token Label
            Label: ForFabric
            # User PIN
            Pin: 98765432
            Hash: SHA2
            Security: 256
            FileKeyStore:
                KeyStore: msp/keystore
```
###### docker container 실행
```
docker-compose -f docker-compose-orderertls.yaml up -d
```
##### peertls-start
- peer node를 시작한다.
###### docker-compose-peertls.yaml
```
services:
  peer0.org1.example.com:
    container_name: peer0.org1.example.com
    image: hyperledger/fabric-peer
    environment:
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      - CORE_PEER_ID=peer0.org1.example.com
      - CORE_PEER_ENDORSER_ENABLED=true  
      - FABRIC_LOGGING_SPEC=debug
      - CORE_CHAINCODE_LOGGING_LEVEL=debug
      - CORE_PEER_LOCALMSPID=Org1MSP
      - CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/msp/peer/msp
      - CORE_PEER_LISTENADDRESS=0.0.0.0:7051  
      - CORE_PEER_ADDRESS=peer0.org1.example.com:7051
      - CORE_PEER_CHAINCODEADDRESS=peer0.org1.example.com:7052  
      - CORE_PEER_CHAINCODELISTENADDRESS=0.0.0.0:7052 
      - GODEBUG=netdns=go  
      # # the following setting starts chaincode containers on the same
      # # bridge network as the peers
      # # https://docs.docker.com/compose/networking/
      #- CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=net_basic
      - CORE_LEDGER_STATE_STATEDATABASE=CouchDB
      - CORE_LEDGER_STATE_COUCHDBCONFIG_COUCHDBADDRESS=couchdb:5984
      # The CORE_LEDGER_STATE_COUCHDBCONFIG_USERNAME and CORE_LEDGER_STATE_COUCHDBCONFIG_PASSWORD
      # provide the credentials for ledger to connect to CouchDB.  The username and password must
      # match the username and password set for the associated CouchDB.
      - CORE_LEDGER_STATE_COUCHDBCONFIG_USERNAME=
      - CORE_LEDGER_STATE_COUCHDBCONFIG_PASSWORD=
      - SOFTHSM2_CONF=/etc/hyperledger/fabric/softhsm/config/softhsm2.conf  
      - CORE_PEER_TLS_ENABLED=true
      - CORE_PEER_GOSSIP_USELEADERELECTION=true
      - CORE_PEER_GOSSIP_ORGLEADER=false
      - CORE_PEER_PROFILE_ENABLED=true
      - CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/msp/tls/server.crt
      - CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/msp/tls/server.key
      - CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/msp/tls/ca.crt
    working_dir: /opt/gopath/src/github.com/hyperledger/fabric
    command: peer node start
    # command: peer node start --peer-chaincodedev=true
    ports:
      - 7051:7051
      - 7053:7053
    volumes:
        - /var/run/:/host/var/run/
        - ../crypto-config/peerOrganizations/peerorg1/msp:/etc/hyperledger/msp/peer/msp
        - ../crypto-config/peerOrganizations/peerorg1/users:/etc/hyperledger/msp/users
        - ../crypto-config/peerOrganizations/peerorg1/tls:/etc/hyperledger/msp/tls
        - ../config:/etc/hyperledger/configtx
        - ./peer/core.yaml:/etc/hyperledger/fabric/core.yaml
        - ./peer/msp/:/etc/hyperledger/fabric/msp
        - ../chaincode/:/opt/gopath/src/github.com/chaincode  
        - ../softhsm/config/softhsm2.conf:/etc/hyperledger/fabric/softhsm/config/softhsm2.conf
        - ../softhsm/lib/libsofthsm2.so:/etc/hyperledger/fabric/libsofthsm2.so
        - ../softhsm/tokens/:/etc/hyperledger/fabric/softhsm/tokens
  
    depends_on:
            # - orderer.example.com
      - couchdb
        #networks:
        #- basic

  couchdb:
    container_name: couchdb
    image: hyperledger/fabric-couchdb
    # Populate the COUCHDB_USER and COUCHDB_PASSWORD to set an admin user and password
    # for CouchDB.  This will prevent CouchDB from operating in an "Admin Party" mode.
    environment:
      - COUCHDB_USER=
      - COUCHDB_PASSWORD=
    ports:
      - 5984:5984
```
###### core.yaml
```
    BCCSP:
        Default: PKCS11
        # Settings for the PKCS#11 crypto provider (i.e. when DEFAULT: PKCS11)
        PKCS11:
            # Location of the PKCS11 module library
            Library: /etc/hyperledger/fabric/libsofthsm2.so
            # Token Label
            Label: ForFabric
            # User PIN
            Pin: 98765432
            Hash: SHA2
            Security: 256
            FileKeyStore:
                KeyStore: msp/keystore
```
###### docker container 실행
```
docker-compose -f docker-compose-peertls.yaml up -d
```
##### cli-start
- cli node를 시작한다.
###### docker-compose-clitls.yaml
```
services:
  cli:
    container_name: cli
    image: hyperledger/fabric-tools
    tty: true
    environment:
      - GOPATH=/opt/gopath
      - GODEBUG=netdns=go  
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      - FABRIC_LOGGING_SPEC=debug
      - CORE_PEER_ID=cli
      - CORE_PEER_ADDRESS=peer0.org1.example.com:7051
      - CORE_PEER_LOCALMSPID=Org1MSP
      - CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/peerorg1/users/testpeeradmin/msp
      - CORE_CHAINCODE_KEEPALIVE=10
      - SOFTHSM2_CONF=/etc/hyperledger/fabric/softhsm/config/softhsm2.conf  
      - CORE_PEER_TLS_ENABLED=true
      - CORE_PEER_TLS_CERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/peerorg1/tls/server.crt
      - CORE_PEER_TLS_KEY_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/peerorg1/tls/server.key
      - CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/peerorg1/tls/ca.crt
    working_dir: /opt/gopath/src/github.com/hyperledger/fabric/peer
    command: /bin/bash 
    volumes:
        - /var/run/:/host/var/run/
        - ./../chaincode/:/opt/gopath/src/github.com/chaincode
        - ./../crypto-config:/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/
        - ./cli/:/etc/hyperledger/fabric
        - ../config/:/opt/gopath/src/github.com/hyperledger/fabric/peer/config
        - ../softhsm/config/softhsm2.conf:/etc/hyperledger/fabric/softhsm/config/softhsm2.conf
        - ../softhsm/lib/libsofthsm2.so:/etc/hyperledger/fabric/libsofthsm2.so
        - ../softhsm/tokens/:/etc/hyperledger/fabric/softhsm/tokens         
```
###### core.yaml, orderer.yaml
- peer node start, orderer node start 와 동일

###### docker container 실행
```
docker-compose -f docker-compose-clitls.yaml up -d
```
##### channel-create
- channel.tx 파일을 이용하여 channel 생성
```
docker exec -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/peerorg1/users/$(ID)peeradmin/msp" \
		cli \
		peer channel create \
						-o orderer.example.com:7050 \
						-c yongchannel \
						-f /opt/gopath/src/github.com/hyperledger/fabric/peer/config/channel.tx \
						--tls \
						--cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/ordererorg/tls/ca.crt
```
##### channel-join
- channel.block 파일을 이용하여 peer를 channel에 가입
```
docker exec \
		cli \
		peer channel join \
						-b yongchannel.block \
						--tls \
						--cafile $CORE_PEER_TLS_ROOTCERT_FILE \
						--certfile $CORE_PEER_TLS_CERT_FILE
```