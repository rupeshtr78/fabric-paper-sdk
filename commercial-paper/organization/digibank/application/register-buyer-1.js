/*
 * SPDX-License-Identifier: Apache-2.0
 */

'use strict';

const { FileSystemWallet, Gateway, X509WalletMixin } = require('fabric-network');
const FabricCAServices = require('fabric-ca-client');
const fs = require('fs');
const path = require('path');
const yaml = require('js-yaml');

//const ccpPath = path.resolve(__dirname, '..', '..', 'fabric-paper', 'connection-org1.json');
//const ccpJSON = fs.readFileSync(ccpPath, 'utf8');
// const ccpJSON = fs.readFileSync("connection.json", 'utf8');
// const ccp = JSON.parse(ccpJSON);

const ccp = yaml.safeLoad(fs.readFileSync('../gateway/networkConnection.yaml', 'utf8'));

async function main() {
    try {

        // Create a new file system based wallet for managing identities.
        const walletPath = path.join(process.cwd(), 'wallet');
        const wallet = new FileSystemWallet(walletPath);
        console.log(`Wallet path: ${walletPath}`);

        // Check to see if we've already enrolled the user.
        const userExists = await wallet.exists('bondbuyer1@DigiBank.com');
        if (userExists) {
            console.log('An identity for the user "bondbuyer1@DigiBank.com" already exists in the wallet');
            return;
        }

        // Check to see if we've already enrolled the admin user.
        const adminExists = await wallet.exists('admin');
        if (!adminExists) {
            console.log('An identity for the admin user "Admin@DigiBank.com" does not exist in the wallet');
            console.log('Run the enrollAdmin.js application before retrying');
            return;
        }
		
		// Load connection profile; will be used to locate a gateway
		let connectionProfile = yaml.safeLoad(fs.readFileSync('../gateway/networkConnection.yaml', 'utf8'));

		// Set connection options; identity and wallet
		let connectionOptions = {
		  identity: 'admin',
		  wallet: wallet,
		  discovery: { enabled:true, asLocalhost: true }
		};

		// Connect to gateway using application specified parameters
		console.log('Connect to Fabric gateway.');
        const gateway = new Gateway();
		await gateway.connect(connectionProfile, connectionOptions);
		
        // Create a new gateway for connecting to our peer node.
        // const gateway = new Gateway();
        // await gateway.connect(ccp, { wallet, identity: 'admin', discovery: { enabled: false } });

        // Get the CA client object from the gateway for interacting with the CA.
		// Create a new CA client for interacting with the CA.
        const caURL = connectionProfile.certificateAuthorities['ca-DigiBank.com'].url;
        const ca = new FabricCAServices(caURL);
        // const ca = gateway.getClient().getCertificateAuthority();
        const adminIdentity = gateway.getCurrentIdentity();

        // Register the user, enroll the user, and import the new identity into the wallet.
        const secret = await ca.register({ affiliation: 'org1.department1', enrollmentID: 'bondbuyer1@DigiBank.com', role: 'client' }, adminIdentity);
        const enrollment = await ca.enroll({ enrollmentID: 'bondbuyer1@DigiBank.com', enrollmentSecret: secret });
        const userIdentity = X509WalletMixin.createIdentity('DigiBankMSP', enrollment.certificate, enrollment.key.toBytes());
        wallet.import('bondbuyer1@DigiBank.com', userIdentity);
        console.log('Successfully registered and enrolled admin user "bondbuyer1@DigiBank.com" and imported it into the wallet');

    } catch (error) {
        console.error(`Failed to register user : ${error}`);
        process.exit(1);
    }
}

main();
