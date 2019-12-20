# hyperledger-fabric-hsm
hyperledger fabric hsm 적용 테스트

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

## hyperledger fabric network compose
### yongbric clone :)
yongbric을 clone 받는다.
```
1. git init fabric-hsm
2. cd fabric-hsm
3. git config core.sparseCheckout true
4. git remote add -f origin https://github.com/yongtaelim/hyperledger-fabric-project.git
5. echo "hyperledger-fabric-hsm/yongbric" >> .git/info/sparse-checkout
6. git pull origin master
```

### all
make를 이용하여 아래의 항목을 실행한다.
```
## ID argument 세팅
make all ID=yong
```
description)
>ID : orderer, peer 계정 등록할 때 사용
>>orderer-admin : $(ID)ordereradmin / $(ID)ordereradminpw
>>peer-admin : $(ID)peeradmin / $(ID)peeradminpw
>>peer-user : $(ID)peeruser / $(ID)peeruserpw

### softhsm2 설치
#### 사전 작업
1. openssl
```
apt update
apt install openssl
```
2. botan 설치
```
apt update
apt install botan
```
#### softhsm
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
5. check
정상적으로 설치가 됐는지 체크한다. softhsm의 slot list를 불러온다.
```
softhsm2-util --show-slots
```
정상적으로 설치가 완료되었다면 아래의 경로에 관련 파일 및 폴더 생성
```
## so file
/usr/local/lib/softhsm/libsofthsm2.so
## token folder
/var/lib/softhsm/tokens/
## config file
/etc/softhsm2.conf

export SOFTHSM2_CONF="/etc/softhsm2.conf"
```
6. init-token
hyperledger fabric에 필요한 token을 생성한다. ( hyperledger fabric document criteria )
```
softhsm2-util --init-token --slot 0 --label "ForFabric" --so-pin 1234 --pin 98765432
```
description)  
>--slot :: 추가할 slot 넘버를 입력한다. 현재 2번 slot까지 등록이 되있고 3번에 추가를 원할 경우 '3'을 입력한다.  
>--label :: DB로 비교해봤을 경우 table이라고 생각하면 된다.  
>--so-pin :: 관리자 비밀번호  
>--pin :: user 비밀번호

### ca server start
fabric ca server를 시작한다.
1. docker-compose-ca.yaml
```
fabric-ca-server:
   image: hyperledger/fabric-ca
   container_name: fabric-ca-server
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
2. fabric-ca-server-config.yaml
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
3. docker container 실행
```
docker-compose -f docker-compose-ca.yaml up -d
```
### ca admin enroll
fabric-ca-client를 이용하여 ca admin 계정을 enroll한다.
### generate orderer admin enroll
1. fabric-ca-client를 이용하여 orderer admin 계정을 register한다.
2. fabric-ca-client를 이용하여 orderer admin 계정을 enroll한다.
3. msp폴더에서 admincert 폴더 생성
4. signcerts 폴더 내 cert파일을 admincert 폴더 내로 복사
### generate peer admin enroll
1. fabric-ca-client를 이용하여 peer admin 계정을 register한다.
2. fabric-ca-client를 이용하여 peer admin 계정을 enroll한다.
3. msp폴더에서 admincert 폴더 생성
4. signcerts 폴더 내 cert파일을 admincert 폴더 내로 복사
### generate peer user enroll
1. fabric-ca-client를 이용하여 peer user 계정을 register한다.
2. fabric-ca-client를 이용하여 peer user 계정을 enroll한다.
3. msp폴더에서 admincert 폴더 생성
4. peer admin msp signcerts 폴더 내 cert파일을 peer user msp admincert 폴더 내로 복사
### create genesis.block
configtxgen 바이너리 파일을 이용하여 configtx.yaml 파일 기반 genesis.block 파일 생성
### create channel.tx
configtxgen 바이너리 파일을 이용하여 configtx.yaml 파일 기반 channel.tx 파일 생성
### orderer node start
orderer node를 시작한다.
1. docker-compose-orderer.yaml
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
2. orderer.yaml
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
3. docker container 실행
```
docker-compose -f docker-compose-orderer.yaml up -d
```
### peer node start
peer node를 시작한다.
1. docker-compose-peer.yaml
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
2. core.yaml
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
3. docker container 실행
```
docker-compose -f docker-compose-peer.yaml up -d
```
### cli node start
cli node를 시작한다.
1. docker-compose-cli.yaml
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
2. core.yaml, orderer.yaml
peer node start, orderer node start 와 동일

3. docker container 실행
```
docker-compose -f docker-compose-cli.yaml up -d
```
### create channel
channel.tx 파일을 이용하여 channel 생성
### join channel
channel.block 파일을 이용하여 peer를 channel에 가입