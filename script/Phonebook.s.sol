// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {Phonebook} from "../src/Phonebook.sol";

contract PhonebookScript is Script {
    Phonebook public phonebook;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // Deploy Phonebook contract
        // The deployer (msg.sender) will become the MNO
        phonebook = new Phonebook();

        console.log("Phonebook deployed at:", address(phonebook));
        console.log("MNO address:", phonebook.mnoAddress());

        vm.stopBroadcast();
    }
}

