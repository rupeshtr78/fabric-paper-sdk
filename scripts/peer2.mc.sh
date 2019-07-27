echo "========= Creating Env Variables peer2.MagnetoCorp.com=========== "
export CORE_PEER_ADDRESS=peer2.MagnetoCorp.com:9051
export CORE_PEER_LOCALMSPID=MagnetoCorpMSP
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_TLS_CERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/MagnetoCorp.com/peers/peer2.MagnetoCorp.com/tls/server.crt
export CORE_PEER_TLS_KEY_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/MagnetoCorp.com/peers/peer2.MagnetoCorp.com/tls/server.key
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/MagnetoCorp.com/peers/peer2.MagnetoCorp.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/MagnetoCorp.com/users/Admin@MagnetoCorp.com/msp
echo $CORE_PEER_ADDRESS
echo "========= End Variables peer2.MagnetoCorp.com=========== "