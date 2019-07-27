#!/bin/bash
echo "========= Creating Env Variables peer1.DigiBank.com=========== "
export CORE_PEER_ADDRESS=peer1.DigiBank.com:18051
export CORE_PEER_LOCALMSPID=DigiBankMSP
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_TLS_CERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/DigiBank.com/peers/peer1.DigiBank.com/tls/server.crt
export CORE_PEER_TLS_KEY_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/DigiBank.com/peers/peer1.DigiBank.com/tls/server.key
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/DigiBank.com/peers/peer1.DigiBank.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/DigiBank.com/users/Admin@DigiBank.com/msp
echo $CORE_PEER_ADDRESS
echo "Updated Env Variables peer1.DigiBank.com"