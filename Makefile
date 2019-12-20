# help
# This makefile defines the following targets
#
#   - all(default) :: softhsm token initialize and fabric network start
#   - softhsm :: softhsm token initialize
#   - fabric-start :: hyperledger fabric network start
#   - clean :: cleans docker container && msp && config
#
# This makefile parameter info.
#     - PROJECT_PATH :: set this project path
#     - ID :: peer and orderer register id
#
# this makefile hsm parameter info.
#     - HSM_SLOT_NUMBER :: hsm slot number
#     - HSM_LABLE_NAME :: hsm label name
#     - HSM_SO_PIN_NUMBER :: hsm admin pin number
#     - HSM_USER_PIN_NUMBER :: hsm user pin number


PROJECT_PATH?=$(shell printenv HOME)/hyperledger-fabric-hsm

PATH=$(shell printenv PATH):$(PROJECT_PATH)/bin

FABRIC_CA_CLIENT_HOME=$(PROJECT_PATH)/client/admin
FABRIC_CA_CLIENT_MSP=$(FABRIC_CA_CLIENT_HOME)/msp

SOFTHSM_TOKEN=$(PROJECT_PATH)/softhsm/tokens/*
# hardcording in config.yaml file
PEER_ORG=peerorg1
ORDERER_ORG=ordererorg

PEER_MSP_PATH=$(PROJECT_PATH)/crypto-config/peerOrganizations/$(PEER_ORG)
PEER_ADMIN_MSP_PATH=$(PEER_MSP_PATH)/users/$(ID)peeradmin
PEER_USER_MSP_PATH=$(PEER_MSP_PATH)/users/$(ID)peeruser

ORDERER_MSP_PATH=$(PROJECT_PATH)/crypto-config/ordererOrganizations/$(ORDERER_ORG)
ORDERER_ADMIN_MSP_PATH=$(ORDERER_MSP_PATH)/users/$(ID)ordereradmin

MSPS=orderer-admin peer-admin peer-user
NODES=orderer peer cli
CONFIGS=genesis-block channel-transaction
CHANNEL_INVOCATIONS=create join

ID?=test

HSM_SLOT_NUMBER?=0
HSM_LABLE_NAME?=ForFabric
HSM_SO_PIN_NUMBER?=1234
HSM_USER_PIN_NUMBER?=98765432

.PHONY: all
all: softhsm fabric-start

softhsm: softhsm-env softhsm-init-token softhsm-show-slots 

fabric-start: ca-start ca-enroll $(patsubst %,generate-%,$(MSPS)) $(patsubst %,generate-%,$(CONFIGS)) $(patsubst %,%-start,$(NODES)) $(patsubst %,channel-%,$(CHANNEL_INVOCATIONS))

generate-msp: ca-enroll generate-orderer-admin generate-peer-admin generate-peer-user

generate-msp-not-ca: generate-orderer-admin generate-peer-admin generate-peer-user	

softhsm-env:
	@echo "set softhsm env..."
	@echo "directories.tokendir = $(PROJECT_PATH)/softhsm/tokens/\nobjectstore.backend = file\nlog.level = ERROR\nslots.removable = false" > softhsm2.conf
	sudo mv -f softhsm2.conf /etc/.
	mkdir -p softhsm/tokens

softhsm-show-slots:
	@echo "softhsm show slots..."
	@softhsm2-util --show-slots

softhsm-init-token:
	@echo "softhsm init token..."
	@softhsm2-util --init-token --slot $(HSM_SLOT_NUMBER) --label $(HSM_LABLE_NAME) --so-pin $(HSM_SO_PIN_NUMBER) --pin $(HSM_USER_PIN_NUMBER)

ca-start:
	@echo "fabric ca server start..."
	@docker-compose -f docker/docker-compose-ca.yml up -d
	@echo "fabric ca server wait run time..."
	sleep 2

orderer-start:
	@echo "fabric orderer start..."
	@docker-compose -f docker/docker-compose-orderer.yml up -d

peer-start:
	@echo "fabric peer start.."
	@docker-compose -f docker/docker-compose-peer.yml up -d		

cli-start:
	@echo "fabric-cli start.."
	@docker-compose -f docker/docker-compose-cli.yml up -d		

generate-genesis-block:
	@echo "generate geneis block.."
	@mkdir -p config
	@configtxgen -profile OneOrgOrdererGenesis -outputBlock ./config/genesis.block

generate-channel-transaction:
	@echo "generate channel transaction.."
	@mkdir -p config
	@configtxgen -profile OneOrgChannel -outputCreateChannelTx ./config/channel.tx -channelID yongchannel

ca-enroll: 
	@echo "admin enroll.."
	$(shell chmod +x bin/*)
	@fabric-ca-client enroll -u http://admin:adminpw@localhost:7054 --home ./client/admin

generate-orderer-admin: 		
	@echo "orderer admin register.."
	@fabric-ca-client register \
			--id.name $(ID)ordereradmin \
			--id.secret $(ID)ordereradminpw \
			--id.type client \
			--id.affiliation ordererorg \
			--id.attrs '"hf.Registrar.Roles=client,orderer,peer,user"' \
			--id.attrs '"hf.Registrar.DelegateRoles=client,orderer,peer,user"' \
			--id.attrs hf.Registrar.Attributes="*" \
			--id.attrs hf.GenCRL=true \
			--id.attrs hf.Revoker=true \
			--id.attrs hf.AffiliationMgr=true \
			--id.attrs hf.IntermediateCA=true \
			--id.attrs admin=true:ecert \
			--home $(FABRIC_CA_CLIENT_HOME)

	@echo "orderer admin enroll.."
	@fabric-ca-client enroll \
			-u http://$(ID)ordereradmin:$(ID)ordereradminpw@localhost:7054 \
			-M $(ORDERER_ADMIN_MSP_PATH)/msp \
			--home $(FABRIC_CA_CLIENT_HOME)

	@echo "create orderer admin admincerts.."

	@echo mkdir -p $(ORDERER_ADMIN_MSP_PATH)/msp/admincerts
	@mkdir -p $(ORDERER_ADMIN_MSP_PATH)/msp/admincerts

	@echo "cp $(ORDERER_ADMIN_MSP_PATH)/msp/signcerts/cert.pem $(ORDERER_ADMIN_MSP_PATH)/msp/admincerts/."
	@cp $(ORDERER_ADMIN_MSP_PATH)/msp/signcerts/cert.pem $(ORDERER_ADMIN_MSP_PATH)/msp/admincerts/.

	@echo cp -r $(ORDERER_ADMIN_MSP_PATH)/msp $(ORDERER_MSP_PATH)/.
	@cp -r $(ORDERER_ADMIN_MSP_PATH)/msp $(ORDERER_MSP_PATH)/.
	

generate-peer-admin: 		
	@echo "peer admin register.."
	@fabric-ca-client register \
			--id.name $(ID)peeradmin \
			--id.secret $(ID)peeradminpw \
			--id.type client \
			--id.affiliation peerorg1 \
			--id.attrs '"hf.Registrar.Roles=client,orderer,peer,user"' \
			--id.attrs '"hf.Registrar.DelegateRoles=client,orderer,peer,user"' \
			--id.attrs hf.Registrar.Attributes="*" \
			--id.attrs hf.GenCRL=true \
			--id.attrs hf.Revoker=true \
			--id.attrs hf.AffiliationMgr=true \
			--id.attrs hf.IntermediateCA=true \
			--id.attrs admin=true:ecert \
			--home $(FABRIC_CA_CLIENT_HOME)

	@echo "peer admin enroll.."
	@fabric-ca-client enroll \
			-u http://$(ID)peeradmin:$(ID)peeradminpw@localhost:7054 \
			-M $(PEER_ADMIN_MSP_PATH)/msp \
			--home $(FABRIC_CA_CLIENT_HOME)

	@echo "create peer admin admincerts.."

	@echo mkdir -p $(PEER_ADMIN_MSP_PATH)/msp/admincerts
	@mkdir -p $(PEER_ADMIN_MSP_PATH)/msp/admincerts

	@echo cp $(PEER_ADMIN_MSP_PATH)/msp/signcerts/cert.pem $(PEER_ADMIN_MSP_PATH)/msp/admincerts/.
	@cp $(PEER_ADMIN_MSP_PATH)/msp/signcerts/cert.pem $(PEER_ADMIN_MSP_PATH)/msp/admincerts/.

	@echo cp -r $(PEER_ADMIN_MSP_PATH)/msp $(PEER_MSP_PATH)/.
	@cp -r $(PEER_ADMIN_MSP_PATH)/msp $(PEER_MSP_PATH)/.

generate-peer-user:
	@echo "peer user register.."
	@cp $(FABRIC_CA_CLIENT_HOME)/fabric-ca-client-config.yaml $(PEER_ADMIN_MSP_PATH)/.

	@fabric-ca-client register \
			--id.name $(ID)peeruser \
			--id.secret $(ID)peeruserpw \
			--id.type peer \
			--id.affiliation peerorg1 \
			--id.attrs peer=true:ecert \
			--home $(PEER_ADMIN_MSP_PATH)

	@echo "peer user enroll.."
	@fabric-ca-client enroll \
			-u http://$(ID)peeruser:$(ID)peeruserpw@localhost:7054 \
			-M $(PEER_USER_MSP_PATH)/msp \
			--home $(PEER_ADMIN_MSP_PATH)

	@echo "create peer user admincerts.."

	@echo mkdir -p $(PEER_USER_MSP_PATH)/admincerts
	@mkdir -p $(PEER_USER_MSP_PATH)/admincerts

	@echo cp $(PEER_ADMIN_MSP_PATH)/msp/signcerts/cert.pem $(PEER_USER_MSP_PATH)/admincerts/.
	@cp $(PEER_ADMIN_MSP_PATH)/msp/signcerts/cert.pem $(PEER_USER_MSP_PATH)/admincerts/.
	
channel-create:
	@echo "create the channel.."
	@docker exec peer0.org1.example.com peer channel create -o orderer.example.com:7050 -c yongchannel -f /etc/hyperledger/configtx/channel.tx

channel-join:
	@echo "join peer to the channel.."
	@docker exec peer0.org1.example.com peer channel join -b yongchannel.block

chaincode-intall:
	@echo "chaincode install.."
	@docker exec cli bash CORE_PEER_ADDRESS=peer0.org1.example.com:7051 CORE_PEER_LOCALMSPID=Org1MSP CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/$(PEER_ORG)/users/$(ID)peeradmin/msp peer chaincode install -n fabcar -p github.com/chaincode/fabcar -v v0
	#@docker exec cli bash CORE_PEER_ADDRESS=peer0.org1.example.com:7051 CORE_PEER_LOCALMSPID=Org1MSP CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/$(PEER_ORG)/users/$(ID)peeradmin/msp peer chaincode install -n fabcar -p github.com/chaincode/fabcar/fabcar -v v0

.PHONY: clean
clean: clean-msp clean-container clean-fabric-config clean-softhsm

.PHONY: clean-msp
clean-msp:	
	@echo "clean the msp.."
	-sudo rm -rf $(PEER_MSP_PATH) 
	-sudo rm -rf $(ORDERER_MSP_PATH)
	-sudo rm -rf $(FABRIC_CA_CLIENT_MSP)
	-sudo find docker/ca/ ! -name fabric-ca-server-config.yaml -delete
 
clean-softhsm:
	@echo "clean softhsm tokens..."
	-sudo rm -rf $(SOFTHSM_TOKEN)

.PHONY: clean-container
clean-container:
	@echo "clean the container.."
	-docker rm -f fabric-ca-server orderer.example.com peer0.org1.example.com cli couchdb

.PHONY: clean-fabric-config
clean-fabric-config:
	@echo "clean fabric config.."
	-rm -rf ./config/* 
