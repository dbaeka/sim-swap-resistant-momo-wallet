// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {Phonebook} from "../src/Phonebook.sol";
import {RecoveryWallet} from "../src/RecoveryWallet.sol";

contract DeployAllScript is Script {
    Phonebook public phonebook;
    RecoveryWallet public wallet;

    function setUp() public {}

    function run() public {
        // Configuration for RecoveryWallet
        address owner = vm.envOr("WALLET_OWNER", msg.sender);

        address[] memory guardians = new address[](2);
        guardians[0] = vm.envOr("GUARDIAN_1", address(0x2345678901234567890123456789012345678901));
        guardians[1] = vm.envOr("GUARDIAN_2", address(0x3456789012345678901234567890123456789012));

        uint256 threshold = vm.envOr("GUARDIAN_THRESHOLD", uint256(2));

        console.log("=== Deploying All Contracts ===\n");

        vm.startBroadcast();

        // Deploy Phonebook
        phonebook = new Phonebook();
        console.log("1. Phonebook deployed at:", address(phonebook));
        console.log("   MNO address:", phonebook.mnoAddress());

        // Deploy RecoveryWallet
        wallet = new RecoveryWallet(owner, guardians, threshold);
        console.log("\n2. RecoveryWallet deployed at:", address(wallet));
        console.log("   Owner:", wallet.owner());
        console.log("   Guardian count:", wallet.guardianCount());
        console.log("   Guardian threshold:", wallet.guardianThreshold());
        console.log("   Recovery delay:", wallet.recoveryDelay(), "seconds");

        vm.stopBroadcast();

        console.log("\n=== Deployment Complete ===");
        console.log("\nNext steps:");
        console.log("1. Verify contracts on block explorer");
        console.log("2. Register phone number via Phonebook");
        console.log("3. Test guardian recovery flow");
    }
}

