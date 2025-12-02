// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {RecoveryWallet} from "../src/RecoveryWallet.sol";

contract RecoveryWalletScript is Script {
    RecoveryWallet public wallet;

    function setUp() public {}

    function run() public {
        // IMPORTANT: Replace these with actual addresses before deploying
        address owner = vm.envOr("WALLET_OWNER", address(0x1234567890123456789012345678901234567890));

        // Guardian addresses - replace with real addresses
        address[] memory guardians = new address[](2);
        guardians[0] = vm.envOr("GUARDIAN_1", address(0x2345678901234567890123456789012345678901));
        guardians[1] = vm.envOr("GUARDIAN_2", address(0x3456789012345678901234567890123456789012));

        // Guardian threshold (number of guardians required for recovery)
        uint256 threshold = vm.envOr("GUARDIAN_THRESHOLD", uint256(2));

        console.log("Deploying RecoveryWallet with:");
        console.log("Owner:", owner);
        console.log("Guardian 1:", guardians[0]);
        console.log("Guardian 2:", guardians[1]);
        console.log("Threshold:", threshold);

        vm.startBroadcast();

        // Deploy RecoveryWallet contract
        wallet = new RecoveryWallet(owner, guardians, threshold);

        console.log("\n=== Deployment Successful ===");
        console.log("RecoveryWallet deployed at:", address(wallet));
        console.log("Owner:", wallet.owner());
        console.log("Guardian count:", wallet.guardianCount());
        console.log("Guardian threshold:", wallet.guardianThreshold());
        console.log("Recovery delay:", wallet.recoveryDelay(), "seconds");

        vm.stopBroadcast();
    }
}

