/*
 *  SPDX-License-Identifier: Apache-2.0
 */

'use strict';

// Bring key classes into scope, most importantly Fabric SDK network class
const fs = require('fs');
const { FileSystemWallet, X509WalletMixin } = require('fabric-network');
const path = require('path');

const fixtures = path.resolve(__dirname, '../../../../../fabric-paper-sdk');

// A wallet stores a collection of identities
const wallet = new FileSystemWallet('../identity/user/magnetouser/wallet');

async function main() {

    // Main try/catch block
    try {

        // Identity to credentials to be stored in the wallet
        const credPath = path.join(fixtures, '/crypto-config/peerOrganizations/MagnetoCorp.com/users/User1@MagnetoCorp.com');
        const cert = fs.readFileSync(path.join(credPath, '/msp/signcerts/User1@MagnetoCorp.com-cert.pem')).toString();
        const key = fs.readFileSync(path.join(credPath, '/msp/keystore/key.pem')).toString();

        // Load credentials into wallet
        const identityLabel = 'User1@MagnetoCorp.com';
        const identity = X509WalletMixin.createIdentity('MagnetoCorpMSP', cert, key);

        await wallet.import(identityLabel, identity);

    } catch (error) {
        console.log(`Error adding to wallet. ${error}`);
        console.log(error.stack);
    }
}

main().then(() => {
    console.log('Add to Wallet done');
}).catch((e) => {
    console.log(e);
    console.log(e.stack);
    process.exit(-1);
});