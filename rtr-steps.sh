################################################################################################################
#Fabric
################################################################################################################
rm -rf crypto-config
rm -rf config/*.block config/*.tx 
rm -rf fabric-ca-server/ca-DigiBank/*
rm -rf fabric-ca-server/ca-MagnetoCorp/*


cryptogen generate --config=./crypto-config.yaml

configtxgen -profile MagnetoCorpGenesis -channelID mc-sys-channel -outputBlock ./config/magneto.genesis.block
configtxgen -profile DigiBankGenesis -channelID db-sys-channel -outputBlock ./config/digibank.genesis.block

export CHANNEL_NAME=papernet

configtxgen -profile PapernetChannel -outputCreateChannelTx ./config/papernetchannel.tx -channelID $CHANNEL_NAME

#DigiBank
export CHANNEL_NAME=digibankchannel

configtxgen -profile PapernetChannel -outputCreateChannelTx ./config/digibankchannel.tx -channelID $CHANNEL_NAME

export CHANNEL_NAME=papernet
echo $CHANNEL_NAME
configtxgen -profile PapernetChannel -outputAnchorPeersUpdate ./config/MagnetoCorpanchors.tx -channelID $CHANNEL_NAME -asOrg MagnetoCorpMSP
configtxgen -profile PapernetChannel -outputAnchorPeersUpdate ./config/DigiBankanchors.tx -channelID $CHANNEL_NAME -asOrg DigiBankMSP

docker-compose -f docker-compose-all.yaml up -d

configtxgen -inspectBlock ./config/digibank.genesis.block > logs/digibank.genesis.block.txt
configtxgen -inspectBlock ./config/magneto.genesis.block > logs/magneto.genesis.block.txt
configtxgen -inspectChannelCreateTx ./config/papernetchannel.tx > logs/papernetchannel.tx.txt

# configtxgen -inspectChannelCreateTx ./config/papernetchannel.tx > logs/papernetchannel.txt

#Rename Private keys
./remove-key.sh


################################################################################################################
# Start Magnetocorp
################################################################################################################
cd ~/fabric/fabric-paper-sdk/magnetocorp
configtxgen -printOrg DigiBankMSP > ../magnetocorp/config/channel/DigiBankMSP.json
docker-compose -f docker-compose-mcorp.yaml up -d
docker-compose -f docker-compose-cli.yaml up -d

docker exec -it cli.peer0.mgc bash

export ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/MagnetoCorp.com/orderers/orderer.MagnetoCorp.com/msp/tlscacerts/tlsca.MagnetoCorp.com-cert.pem
export CHANNEL_NAME=papernet
peer channel create -o orderer.MagnetoCorp.com:7050 -c $CHANNEL_NAME -f ./config/papernetchannel.tx --outputBlock ./config/papernet.block --tls --cafile $ORDERER_CA
#Join all Peers
peer channel join -b ./config/papernet.block
peer channel list

cd scripts
source peer2.mc.sh
peer channel join -b ../config/papernet.block

# Channel Anchor update MagnetoCorp
peer channel update -o orderer.MagnetoCorp.com:7050 -c $CHANNEL_NAME -f ./config/MagnetoCorpanchors.tx --tls --cafile $ORDERER_CA

################################################################################################################
# Add DigiBank org to Channels
################################################################################################################
docker exec -it cli.peer0.mgc bash

cd config/channel

# command saves the binary protobuf channel configuration block to config_block.pb
peer channel fetch config config_block.pb -o orderer.MagnetoCorp.com:7050 -c $CHANNEL_NAME --tls --cafile $ORDERER_CA

# decode config_block.pb channel configuration block into JSON format
configtxlator proto_decode --input config_block.pb --type common.Block | jq .data.data[0].payload.data.config > config.json

# append the DigiBankMSP configuration definition  to MagnetoCorp
jq -s '.[0] * {"channel_group":{"groups":{"Application":{"groups": {"DigiBankMSP":.[1]}}}}}' config.json DigiBankMSP.json > modified_config.json

# translate config.json back into a protobuf called config.pb:
configtxlator proto_encode --input config.json --type common.Config --output config.pb

# encode modified_config.json to modified_config.pb:
configtxlator proto_encode --input modified_config.json --type common.Config --output modified_config.pb

# use configtxlator to calculate the delta between these two config protobufs. This command will output a new protobuf binary named DigiBankMSP_update.pb:
configtxlator compute_update --channel_id $CHANNEL_NAME --original config.pb --updated modified_config.pb --output DigiBankMSP_update.pb

# decode DigiBankMSP_update.pb into editable JSON format and call it DigiBankMSP_update.json:
configtxlator proto_decode --input DigiBankMSP_update.pb --type common.ConfigUpdate | jq . > DigiBankMSP_update.json

# wrap in an envelope message
echo '{"payload":{"header":{"channel_header":{"channel_id":"papernet", "type":2}},"data":{"config_update":'$(cat DigiBankMSP_update.json)'}}}' | jq . > DigiBankMSP_update_in_envelope.json

# update object DigiBankMSP_update_in_envelope.pb: 
configtxlator proto_encode --input DigiBankMSP_update_in_envelope.json --type common.Envelope --output DigiBankMSP_update_in_envelope.pb

# org1MSP Signature
peer channel signconfigtx -f DigiBankMSP_update_in_envelope.pb

peer channel update -f DigiBankMSP_update_in_envelope.pb -c $CHANNEL_NAME -o orderer.MagnetoCorp.com:7050 --tls --cafile $ORDERER_CA

#verify New Block Creation
docker logs peer0.MagnetoCorp.com

# Bring up DigiBank Network#############################################################################
docker-compose -f docker-compose-digibank.yaml up -d
docker-compose -f docker-compose-cli.yaml up -d


# digi cli #######################################################################
docker exec -it cli.peer0.dbnk bash
export ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/magnetocorp/ordererOrganizations/MagnetoCorp.com/orderers/orderer.MagnetoCorp.com/msp/tlscacerts/tlsca.MagnetoCorp.com-cert.pem
export CHANNEL_NAME=papernet

peer channel fetch 0 papernet.block -o orderer.MagnetoCorp.com:7050 -c $CHANNEL_NAME --tls --cafile $ORDERER_CA

peer channel join -b papernet.block

peer channel list

# Update Anchor Peers########################################################################################
peer channel fetch config config_block.pb -o orderer.MagnetoCorp.com:7050 -c $CHANNEL_NAME --tls --cafile $ORDERER_CA

#Human Readable Format
configtxlator proto_decode --input config_block.pb --type common.Block | jq .data.data[0].payload.data.config > config.json

# Add Anchor Peer
jq '.channel_group.groups.Application.groups.DigiBankMSP.values += {"AnchorPeers":{"mod_policy": "Admins","value":{"anchor_peers": [{"host": "peer0.DigiBank.com","port": 17051}]},"version": "0"}}' config.json > modified_anchor_config.json
# jq '.channel_group.groups.Application.groups.MagnetoCorpMSP.values += {"AnchorPeers":{"mod_policy": "Admins","value":{"anchor_peers": [{"host": "peer0.MagnetoCorp.com","port": 7051}]},"version": "0"}}' config.json > modified_anchor_config.json

# Translate config.json back into protobuf format as config.pb
configtxlator proto_encode --input config.json --type common.Config --output config.pb

# Translate the modified_anchor_config.json into protobuf format as modified_anchor_config.pb
configtxlator proto_encode --input modified_anchor_config.json --type common.Config --output modified_anchor_config.pb

# Calculate the delta between the two protobuf formatted configurations.
configtxlator compute_update --channel_id $CHANNEL_NAME --original config.pb --updated modified_anchor_config.pb --output anchor_update.pb

# use the configtxlator command again to convert anchor_update.pb into anchor_update.json
configtxlator proto_decode --input anchor_update.pb --type common.ConfigUpdate | jq . > anchor_update.json

# wrap the update in an envelope message, restoring the previously stripped away header, 
# outputting it to anchor_update_in_envelope.json
echo '{"payload":{"header":{"channel_header":{"channel_id":"papernet", "type":2}},"data":{"config_update":'$(cat anchor_update.json)'}}}' | jq . > anchor_update_in_envelope.json

# convert it to a protobuf so it can be properly signed and submitted to the orderer for the update.
configtxlator proto_encode --input anchor_update_in_envelope.json --type common.Envelope --output anchor_update_in_envelope.pb

# use the peer channel update command as it will also sign off on the update as the Org3 admin before submitting it to the orderer.
peer channel update -f anchor_update_in_envelope.pb -c $CHANNEL_NAME -o orderer.MagnetoCorp.com:7050 --tls --cafile $ORDERER_CA

docker logs -f peer0.org1.example.com
[gossip.gossip] JoinChan -> INFO 0db Joining gossip network of channel mychannel with 3 organizations
[gossip.gossip] learnAnchorPeers -> INFO 0dd Learning about the configured anchor peers of Org2MSP for channel mychannel : [{peer0.org2.example.com 9051}]
[gossip.gossip] learnAnchorPeers -> INFO 0de Learning about the configured anchor peers of Org3MSP for channel mychannel : [{peer0.org3.example.com 11051}]
[gossip.gossip] learnAnchorPeers -> INFO 0df Learning about the configured anchor peers of Org1MSP for channel mychannel : [{peer0.org1.example.com 7051}]
[gossip.gossip] learnAnchorPeers -> INFO 0e0 Anchor peer with same endpoint, skipping connecting to myself
[committer.txvalidator] Validate -> INFO 0e1 [mychannel] Validated block [7] in 186ms

docker logs -f peer0.org3.example.com

#Chaincode ###
peer chaincode install -n mycc -v 1.0 -p github.com/chaincode/chaincode_example02/go/

peer chaincode list --installed

peer chaincode instantiate -o orderer.MagnetoCorp.com:7050 -C $CHANNEL_NAME -n mycc -v 1.0 -c '{"Args":["init","a","100","b","200"]}' --tls --cafile $ORDERER_CA -P "OR ('MagnetoCorpMSP.peer','DigiBankMSP.peer')"
peer chaincode list --instantiated -C $CHANNEL_NAME 

peer chaincode query -C $CHANNEL_NAME -n mycc -c '{"Args":["query","b"]}'

peer chaincode invoke -o orderer.MagnetoCorp.com:7050 -C $CHANNEL_NAME -n mycc -c '{"Args":["invoke","a","b","10"]}' --tls --cafile $ORDERER_CA


################################################################################################################
#Channel
################################################################################################################
cd ~/fabric/rtrfabs/fabric-paper/commercial-paper/organization/magnetocorp/configuration/cli
docker exec -it cli.peer0.mgc bash

docker exec -it cli.peer0.dbnk bash

orderer.DigiBank.com 7050
orderer.MagnetoCorp.com 7950

export CHANNEL_NAME=papernet
peer channel create -o orderer.MagnetoCorp.com:7050 -c $CHANNEL_NAME -f ./config/papernetchannel.tx --outputBlock ./config/papernet.block --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/MagnetoCorp.com/orderers/orderer.MagnetoCorp.com/msp/tlscacerts/tlsca.MagnetoCorp.com-cert.pem

# Digibank Channel
export CHANNEL_NAME=digibankchannel
peer channel create -o orderer.DigiBank.com:7050 -c $CHANNEL_NAME -f ./config/digibankchannel.tx --outputBlock ./config/digibankchannel.block --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/DigiBank.com/orderers/orderer.DigiBank.com/msp/tlscacerts/tlsca.DigiBank.com-cert.pem
peer channel join -b ./config/digibankchannel.block

peer channel list
peer channel getinfo -c $CHANNEL_NAME  #-> BlockChain Info →  Block Height Current Block Hash
peer channel fetch rtrchannel01.block -c $CHANNEL_NAME --orderer orderer.rupesh.com:7050

# Join channel on each peer
peer channel join -b ./config/papernet.block

source peer1.mc.sh
spurce peer2.mc.sh
peer channel join -b ./config/papernet.block


peer channel fetch newest -o orderer.papernet.com:7050 -c $CHANNEL_NAME
peer channel join -b $CHANNEL_NAME_newest.block


# Channel update DigiBank
export CHANNEL_NAME=papernet

peer channel update -o orderer.papernet.com:7050 -c $CHANNEL_NAME -f ./config/DigiBankMSPanchors.tx --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/papernet.com/orderers/orderer.papernet.com/msp/tlscacerts/tlsca.papernet.com-cert.pem

# Channel update MagnetoCorp
export CHANNEL_NAME=papernet

peer channel update -o orderer.papernet.com:7050 -c $CHANNEL_NAME -f ./config/MagnetoCorpMSPanchors.tx --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/papernet.com/orderers/orderer.papernet.com/msp/tlscacerts/tlsca.papernet.com-cert.pem


################################################################################################################
#Smart Contract
################################################################################################################
echo $ORDERER_CA && echo $CHANNEL_NAME
export CHANNEL_NAME=papernet
#Install on all peers
peer chaincode install -n papercontract -v 0 -p /opt/gopath/src/github.com/contract -l node

peer chaincode package ccpack.out -n mycc -l node -p
peer chaincode package ccpack.out -n papercontract -l node -p /opt/gopath/src/github.com/contract -v 1.0 -s -S
peer chaincode install ccpack.out

peer chaincode list --installed

peer chaincode instantiate -o orderer.MagnetoCorp.com:7050 -C $CHANNEL_NAME  -n papercontract -v 0 -l node -c '{"Args":["org.papernet.commercialpaper:instantiate"]}' --tls --cafile $ORDERER_CA  -P  "OR ('MagnetoCorpMSP.peer','DigiBankMSP.peer')"

peer chaincode instantiate -o orderer.MagnetoCorp.com:7050 -C $CHANNEL_NAME  -n bondpaper -v 1.0 -l node -c '{"Args":["org.papernet.commercialpaper:instantiate"]}' --tls --cafile $ORDERER_CA  -P  "OR ('MagnetoCorpMSP.peer','DigiBankMSP.peer')"


peer chaincode list --instantiated -C $CHANNEL_NAME 

node addToWallet.js
node issue.js
node buy.js
noode redeem

# Mc CLI
export ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/MagnetoCorp.com/orderers/orderer.MagnetoCorp.com/msp/tlscacerts/tlsca.MagnetoCorp.com-cert.pem
export CHANNEL_NAME=papernet

#digibank cli
export ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/magnetocorp/ordererOrganizations/MagnetoCorp.com/orderers/orderer.MagnetoCorp.com/msp/tlscacerts/tlsca.MagnetoCorp.com-cert.pem
export CHANNEL_NAME=papernet


cd ~/fabric/fabric-paper-sdk/digibank/commercial-paper/organization/digibank/application
cd ~/fabric/fabric-paper-sdk/magnetocorp/commercial-paper/organization/magnetocorp/application




Name: bondpaper, Version: 1.0, 
Path: /opt/gopath/src/github.com/contract, ID
5f1e27016288ac3d2920021be70b07ac1065fafa0f6c13d9590b76de8ed81b0a
5f1e27016288ac3d2920021be70b07ac1065fafa0f6c13d9590b76de8ed81b0a
5f1e27016288ac3d2920021be70b07ac1065fafa0f6c13d9590b76de8ed81b0a












peer chaincode instantiate -o orderer.papernet.com:7050 -C $CHANNEL_NAME -n rtrccex02 -v 1.0 -c '{"Args":["init","a","100","b","200"]}' --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/papernet.com/orderers/orderer.papernet.com/msp/tlscacerts/tlsca.papernet.com-cert.pem -P "OR ('MagnetoCorpMSP.peer','DigiBankMSP.peer')"

peer chaincode list --instantiated -C $CHANNEL_NAME 

peer chaincode invoke -o orderer.papernet.com:7050 -C $CHANNEL_NAME -n rtrccex02 -c '{"Args":["invoke","a","b","10"]}' --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/papernet.com/orderers/orderer.papernet.com/msp/tlscacerts/tlsca.papernet.com-cert.pem

peer chaincode query -C $CHANNEL_NAME -n rtrccex02 -c '{"Args":["query","a"]}' --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/papernet.com/orderers/orderer.papernet.com/msp/tlscacerts/tlsca.papernet.com-cert.pem 60s

peer chaincode query -C $CHANNEL_NAME -n rtrccex02 -c '{"Args":["query","b"]}'
peer chaincode query -C $CHANNEL_NAME -n rtrccex02 -c '{"Args":["query","a"]}'