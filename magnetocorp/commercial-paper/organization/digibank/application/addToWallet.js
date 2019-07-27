/*
 *  SPDX-License-Identifier: Apache-2.0
 */

'use strict';

// Bring key classes into scope, most importantly Fabric SDK network class
const fs = require('fs');
const { FileSystemWallet, X509WalletMixin } = require('fabric-network');
const path = require('path');

const fixtures = path.resolve(__dirname, '../../../../../fabric-paper');

// A wallet stores a collection of identities
const wallet = new FileSystemWallet('../identity/user/digibanduser/wallet');

async function main() {

    // Main try/catch block
    try {

        // Identity to credentials to be stored in the wallet
        const credPath = path.join(fixtures, '/crypto-config/peerOrganizations/DigiBank.papernet.com/users/Admin@DigiBank.papernet.com');
        const cert = fs.readFileSync(path.join(credPath, '/msp/signcerts/Admin@DigiBank.papernet.com-cert.pem')).toString();
        const key = fs.readFileSync(path.join(credPath, '/msp/keystore/key.pem')).toString();

        // Load credentials into wallet
        const identityLabel = 'Admin@DigiBank.papernet.com';
        const identity = X509WalletMixin.createIdentity('DigiBankMSP', cert, key);

        await wallet.import(identityLabel, identity);

    } catch (error) {
        console.log(`Error adding to wallet. ${error}`);
        console.log(error.stack);
    }
}

main().then(() => {
    console.log('done');
}).catch((e) => {
    console.log(e);
    console.log(e.stack);
    process.exit(-1);
});