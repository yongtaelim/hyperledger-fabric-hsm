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
# openssl x509 -in tlsca.org1.example.com-cert.pem -text


PROJECT_PATH?=$(shell printenv HOME)/hyperledger-fabric-hsm

PATH=$(shell printenv PATH):$(PROJECT_PATH)/bin
 
FABRIC_CA_CLIENT_HOME=$(PROJECT_PATH)/client/admin
FABRIC_CA_CLIENT_MSP=$(FABRIC_CA_CLIENT_HOME)/msp

FABRIC_CA_CLIENT_ROOT_HOME=$(PROJECT_PATH)/client/root/admin
FABRIC_CA_CLIENT_ROOT_MSP=$(FABRIC_CA_CLIENT_ROOT_HOME)/msp

FABRIC_CA_CLIENT_TLS_HOME=$(PROJECT_PATH)/client/tls/admin
FABRIC_CA_CLIENT_TLS_MSP=$(FABRIC_CA_CLIENT_TLS_HOME)/msp

SOFTHSM_TOKEN=$(PROJECT_PATH)/softhsm/tokens/*
# hardcording in config.yaml file
PEER_ORG=peerorg1
ORDERER_ORG=ordererorg

#certificate file CN 값에 따라 변경
TLS_CA_DOMAIN=tlsca.org1.example.com:8054
CATLS_DOMAIN=ca.org1.example.com:7054

PEER_MSP_PATH=$(PROJECT_PATH)/crypto-config/peerOrganizations/$(PEER_ORG)
PEER_ADMIN_MSP_PATH=$(PEER_MSP_PATH)/users/$(ID)peeradmin
PEER_ADMIN_TLS_MSP_PATH=$(PEER_MSP_PATH)/tlsca
PEER_USER_MSP_PATH=$(PEER_MSP_PATH)/users/$(ID)peeruser

ORDERER_MSP_PATH=$(PROJECT_PATH)/crypto-config/ordererOrganizations/$(ORDERER_ORG)
ORDERER_ADMIN_MSP_PATH=$(ORDERER_MSP_PATH)/users/$(ID)ordereradmin
ORDERER_ADMIN_TLS_MSP_PATH=$(ORDERER_MSP_PATH)/tlsca

CA_TLS_MSP_PATH=$(PROJECT_PATH)/crypto-config/catlsOrganizations
CATLS_ADMIN_MSP_PATH=$(CA_TLS_MSP_PATH)/ca
CA_TLS_ADMIN_MSP_PATH=$(CA_TLS_MSP_PATH)/tlsca

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
all: clean softhsm fabric-start

softhsm: softhsm-env softhsm-init-token softhsm-show-slots 

fabric-start: ca-start ca-enroll $(patsubst %,generate-%,$(MSPS)) $(patsubst %,generate-%,$(CONFIGS)) $(patsubst %,%-start,$(NODES)) $(patsubst %,channel-%,$(CHANNEL_INVOCATIONS))

#fabric-tls-start: catls-start catls-enroll generate-orderertls-admin ca-tls-start ca-tls-enroll generate-orderer-tls-admin
fabric-tls-start: catls-start catls-enroll generate-orderertls-admin generate-peertls-admin generate-peertls-user ca-tls-start ca-tls-enroll generate-orderer-tls-admin generate-peer-tls-admin

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

catls-start:	
	@echo "fabric ca(tls) server start..."
	@docker-compose -f docker/docker-compose-catls.yml up -d
	@echo "fabric ca(tls) server wait run time..."
	sleep 2

## 안씀
ca-root-start:
	@echo "fabric ca root server start..."
	@docker-compose -f docker/docker-compose-ca-root.yml up -d
	@echo "fabric ca root server wait run time..."
	sleep 2	

ca-tls-start:
	@echo "fabric ca tls server start..."
	@docker-compose -f docker/docker-compose-ca-tls.yml up -d
	@echo "fabric ca tls server wait run time..."
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

## 안씀
ca-root-enroll: 
	@echo "root admin enroll.."
	$(shell chmod +x bin/*)
	@fabric-ca-client enroll -u http://admin:adminpw@localhost:9054 --home ./client/root/admin	

ca-tls-enroll: 
	@echo "ca tls admin enroll.."
	$(shell chmod +x bin/*)
	fabric-ca-client enroll \
				-u https://admin:adminpw@$(TLS_CA_DOMAIN) \
				--enrollment.profile tls \
				--tls.certfiles $(CA_TLS_MSP_PATH)/tlsca/tlsca.org1.example.com-cert.pem \
				--home ./client/tls/admin		

catls-enroll: 
	@echo "ca(tls) admin enroll.."
	$(shell chmod +x bin/*)
	fabric-ca-client enroll \
				-u https://admin:adminpw@$(CATLS_DOMAIN) \
				--tls.certfiles $(CA_TLS_MSP_PATH)/ca/ca.org1.example.com-cert.pem \
				--home ./client/admin						

##안씀
generate-ca-tls-admin:
	@echo "ca tls admin register.."
	@fabric-ca-client register \
			--id.name $(ID)tlsadmin \
			--id.secret $(ID)tlsadminpw \
			--id.type client \
			--id.affiliation tlscaorg \
			--id.attrs '"hf.Registrar.Roles=client,orderer,peer,user"' \
			--id.attrs '"hf.Registrar.DelegateRoles=client,orderer,peer,user"' \
			--id.attrs hf.Registrar.Attributes="*" \
			--id.attrs hf.GenCRL=true \
			--id.attrs hf.Revoker=true \
			--id.attrs hf.AffiliationMgr=true \
			--id.attrs hf.IntermediateCA=true \
			--id.attrs admin=true:ecert \
			--home $(FABRIC_CA_CLIENT_ROOT_HOME)

	@echo "ca tls admin enroll.."
	@fabric-ca-client enroll \
			-u http://$(ID)tlsadmin:$(ID)tlsadminpw@localhost:9054 \
			-M $(CA_TLS_ADMIN_MSP_PATH)/msp \
			--home $(FABRIC_CA_CLIENT_ROOT_HOME)

	mv $(CA_TLS_ADMIN_MSP_PATH)/msp/keystore/* $(CA_TLS_ADMIN_MSP_PATH)/msp/keystore/server_sk

generate-orderertls-admin:
	@echo "orderer admin register.."
	fabric-ca-client register \
			--id.name $(ID)ordereradmin \
			--id.secret $(ID)ordereradminpw \
			--id.type client \
			--id.affiliation ordererorg \
			-u https://$(CATLS_DOMAIN) \
			--tls.certfiles $(CA_TLS_MSP_PATH)/ca/ca.org1.example.com-cert.pem \
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
	fabric-ca-client enroll \
			-u https://$(ID)ordereradmin:$(ID)ordereradminpw@$(CATLS_DOMAIN) \
			-M $(ORDERER_ADMIN_MSP_PATH)/msp \
			--tls.certfiles $(CA_TLS_MSP_PATH)/ca/ca.org1.example.com-cert.pem \
			--home $(FABRIC_CA_CLIENT_HOME)

	@echo "create orderer admin admincerts.."

	@echo mkdir -p $(ORDERER_ADMIN_MSP_PATH)/msp/admincerts
	@mkdir -p $(ORDERER_ADMIN_MSP_PATH)/msp/admincerts

	@echo "cp $(ORDERER_ADMIN_MSP_PATH)/msp/signcerts/cert.pem $(ORDERER_ADMIN_MSP_PATH)/msp/admincerts/."
	@cp $(ORDERER_ADMIN_MSP_PATH)/msp/signcerts/cert.pem $(ORDERER_ADMIN_MSP_PATH)/msp/admincerts/.

	@echo cp -r $(ORDERER_ADMIN_MSP_PATH)/msp $(ORDERER_MSP_PATH)/.
	@cp -r $(ORDERER_ADMIN_MSP_PATH)/msp $(ORDERER_MSP_PATH)/.

generate-peertls-admin: 		
	@echo "peer admin register.."
	fabric-ca-client register \
			--id.name $(ID)peeradmin \
			--id.secret $(ID)peeradminpw \
			--id.type client \
			--id.affiliation peerorg1 \
			-u https://$(CATLS_DOMAIN) \
			--tls.certfiles $(CA_TLS_MSP_PATH)/ca/ca.org1.example.com-cert.pem \
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
	fabric-ca-client enroll \
			-u https://$(ID)peeradmin:$(ID)peeradminpw@$(CATLS_DOMAIN) \
			-M $(PEER_ADMIN_MSP_PATH)/msp \
			--tls.certfiles $(CA_TLS_MSP_PATH)/ca/ca.org1.example.com-cert.pem \
			--home $(FABRIC_CA_CLIENT_HOME)

	@echo "create peer admin admincerts.."

	@echo mkdir -p $(PEER_ADMIN_MSP_PATH)/msp/admincerts
	@mkdir -p $(PEER_ADMIN_MSP_PATH)/msp/admincerts

	@echo cp $(PEER_ADMIN_MSP_PATH)/msp/signcerts/cert.pem $(PEER_ADMIN_MSP_PATH)/msp/admincerts/.
	@cp $(PEER_ADMIN_MSP_PATH)/msp/signcerts/cert.pem $(PEER_ADMIN_MSP_PATH)/msp/admincerts/.

	@echo cp -r $(PEER_ADMIN_MSP_PATH)/msp $(PEER_MSP_PATH)/.
	@cp -r $(PEER_ADMIN_MSP_PATH)/msp $(PEER_MSP_PATH)/.

generate-peertls-user:
	@echo "peer user register.."
	@cp $(FABRIC_CA_CLIENT_HOME)/fabric-ca-client-config.yaml $(PEER_ADMIN_MSP_PATH)/.

	@fabric-ca-client register \
			--id.name $(ID)peeruser \
			--id.secret $(ID)peeruserpw \
			--id.type peer \
			--id.affiliation peerorg1 \
			--id.attrs peer=true:ecert \
			-u https://$(CATLS_DOMAIN) \
			--tls.certfiles $(CA_TLS_MSP_PATH)/ca/ca.org1.example.com-cert.pem \
			--home $(PEER_ADMIN_MSP_PATH)

	@echo "peer user enroll.."
	@fabric-ca-client enroll \
			-u https://$(ID)peeruser:$(ID)peeruserpw@$(CATLS_DOMAIN) \
			--tls.certfiles $(CA_TLS_MSP_PATH)/ca/ca.org1.example.com-cert.pem \
			-M $(PEER_USER_MSP_PATH)/msp \
			--home $(PEER_ADMIN_MSP_PATH)

	@echo "create peer user admincerts.."

	@echo mkdir -p $(PEER_USER_MSP_PATH)/admincerts
	@mkdir -p $(PEER_USER_MSP_PATH)/admincerts

	@echo cp $(PEER_ADMIN_MSP_PATH)/msp/signcerts/cert.pem $(PEER_USER_MSP_PATH)/admincerts/.
	@cp $(PEER_ADMIN_MSP_PATH)/msp/signcerts/cert.pem $(PEER_USER_MSP_PATH)/admincerts/.

generate-orderer-tls-admin: 		
	@echo "orderer tls admin register.."
	fabric-ca-client register \
			-u https://$(TLS_CA_DOMAIN) \
			--tls.certfiles $(CA_TLS_MSP_PATH)/tlsca/tlsca.org1.example.com-cert.pem \
			--id.name $(ID)ordereradmintls \
			--id.secret $(ID)ordereradmintlspw \
			--id.type orderer \
			--id.affiliation ordererorg \
			--home $(FABRIC_CA_CLIENT_TLS_HOME)

	@echo "orderer tls admin enroll.."
	fabric-ca-client enroll \
			-u https://$(ID)ordereradmintls:$(ID)ordereradmintlspw@$(TLS_CA_DOMAIN) \
			-m orderer.example.com \
			--enrollment.profile tls \
			--tls.certfiles $(CA_TLS_MSP_PATH)/tlsca/tlsca.org1.example.com-cert.pem \
			-M $(ORDERER_ADMIN_TLS_MSP_PATH) \
			--home $(FABRIC_CA_CLIENT_TLS_HOME)

	@echo "create orderer admin tls.."
	@mkdir -p $(ORDERER_MSP_PATH)/tls

	@cp $(ORDERER_MSP_PATH)/tlsca/keystore/* $(ORDERER_MSP_PATH)/tls/server.key
	@cp $(ORDERER_MSP_PATH)/tlsca/signcerts/* $(ORDERER_MSP_PATH)/tls/server.crt
	@cp $(ORDERER_MSP_PATH)/tlsca/tlscacerts/* $(ORDERER_MSP_PATH)/tls/ca.crt

generate-peer-tls-admin: 		
	@echo "peer tls admin register.."
	fabric-ca-client register \
			-u https://$(TLS_CA_DOMAIN) \
			--tls.certfiles $(CA_TLS_MSP_PATH)/tlsca/tlsca.org1.example.com-cert.pem \
			--id.name $(ID)peeradmintls \
			--id.secret $(ID)peeradmintlspw \
			--id.type peer \
			--id.affiliation peerorg1 \
			--home $(FABRIC_CA_CLIENT_TLS_HOME)

	@echo "peer tls admin enroll.."
	fabric-ca-client enroll \
			-u https://$(ID)peeradmintls:$(ID)peeradmintlspw@$(TLS_CA_DOMAIN) \
			-m peer0.org1.example.com \
			--enrollment.profile tls \
			--tls.certfiles $(CA_TLS_MSP_PATH)/tlsca/tlsca.org1.example.com-cert.pem \
			-M $(PEER_ADMIN_TLS_MSP_PATH) \
			--home $(FABRIC_CA_CLIENT_TLS_HOME)

	@echo "create peer admin tls.."
	mkdir -p $(PEER_MSP_PATH)/tls

	cp $(PEER_MSP_PATH)/tlsca/keystore/* $(PEER_MSP_PATH)/tls/server.key
	cp $(PEER_MSP_PATH)/tlsca/signcerts/* $(PEER_MSP_PATH)/tls/server.crt
	cp $(PEER_MSP_PATH)/tlsca/tlscacerts/* $(PEER_MSP_PATH)/tls/ca.crt

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
	#-sudo rm -rf $(CA_TLS_MSP_PATH)
	-sudo rm -rf $(FABRIC_CA_CLIENT_MSP)
	-sudo rm -rf $(FABRIC_CA_CLIENT_ROOT_MSP)
	-sudo rm -rf $(FABRIC_CA_CLIENT_TLS_MSP)
	-sudo find docker/ca/ ! -name fabric-ca-server-config.yaml -delete
	-sudo find docker/ca-root/ ! -name fabric-ca-server-config.yaml -delete
	-sudo find docker/ca-tls/ ! -name fabric-ca-server-config.yaml -delete
 
clean-softhsm:
	@echo "clean softhsm tokens..."
	-sudo rm -rf $(SOFTHSM_TOKEN)

.PHONY: clean-container
clean-container:
	@echo "clean the container.."
	-docker rm -f fabric-ca-server fabric-ca-tls-server fabric-ca-root-server orderer.example.com peer0.org1.example.com cli couchdb

.PHONY: clean-fabric-config
clean-fabric-config:
	@echo "clean fabric config.."
	-rm -rf ./config/* 
