// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Phonebook} from "../src/Phonebook.sol";

contract PhonebookTest is Test {

    Phonebook phonebook;
    
    address mno;
    uint256 phoneNumber = 233244123456; // +233 (Ghana) ...
    address walletAddr;
    string salt = "DelSecretSalt123";

    event Commit(bytes32 indexed commitmentHash);
    event Registered(uint256 indexed phoneNumber, address indexed wallet);
    event WalletUpdated(uint256 indexed phoneNumber, address indexed oldWallet, address indexed newWallet);

    function setUp() public {
        mno = address(this);
        walletAddr = makeAddr("wallet");
        phonebook = new Phonebook();
    }

    // Test 1: Verify MNO is set correctly
    function test_MNOIsSetCorrectly() public view {
        assertEq(phonebook.mnoAddress(), mno, "Test contract should be the MNO");
    }

    // Test 2: Test the Commit-Reveal Flow
    function test_CommitRevealRegistrationFlow() public {
        // Generate the Hash (Done by MNO backend)
        bytes32 secretHash = keccak256(abi.encodePacked(phoneNumber, walletAddr, salt));

        phonebook.commit(secretHash);
        assertTrue(phonebook.commits(secretHash), "Commitment should be stored");

        // Fast forward past MIN_COMMIT_DELAY
        vm.warp(block.timestamp + 2 minutes);

        phonebook.reveal(phoneNumber, walletAddr, salt);

        assertEq(phonebook.getWallet(phoneNumber), walletAddr, "Phone number should map to wallet");
    }

    // Test 3: Verify Commit is deleted after use
    function test_CommitCleanupAfterReveal() public {
        bytes32 secretHash = keccak256(abi.encodePacked(phoneNumber, walletAddr, salt));

        phonebook.commit(secretHash);

        // Fast forward past MIN_COMMIT_DELAY
        vm.warp(block.timestamp + 2 minutes);

        phonebook.reveal(phoneNumber, walletAddr, salt);

        assertFalse(phonebook.commits(secretHash), "Commit should be deleted after reveal");
    }

    // Test 4: Cannot reveal too early
    function test_CannotRevealTooEarly() public {
        bytes32 secretHash = keccak256(abi.encodePacked(phoneNumber, walletAddr, salt));

        phonebook.commit(secretHash);

        // Try to reveal immediately
        vm.expectRevert("Reveal too early");
        phonebook.reveal(phoneNumber, walletAddr, salt);
    }

    // Test 5: Cannot reveal after window expires
    function test_CannotRevealAfterWindowExpires() public {
        bytes32 secretHash = keccak256(abi.encodePacked(phoneNumber, walletAddr, salt));

        phonebook.commit(secretHash);

        // Fast forward past MAX_COMMIT_WINDOW
        vm.warp(block.timestamp + 25 hours);

        vm.expectRevert("Reveal window expired");
        phonebook.reveal(phoneNumber, walletAddr, salt);
    }

    // Test 6: Can update wallet address for existing phone number
    function test_UpdateWalletAddress() public {
        // Initial registration
        bytes32 secretHash1 = keccak256(abi.encodePacked(phoneNumber, walletAddr, salt));
        phonebook.commit(secretHash1);

        vm.warp(block.timestamp + 2 minutes);
        phonebook.reveal(phoneNumber, walletAddr, salt);

        assertEq(phonebook.getWallet(phoneNumber), walletAddr, "Initial wallet should be set");

        // Update to new wallet
        address newWallet = makeAddr("newWallet");
        string memory newSalt = "NewSalt456";
        bytes32 secretHash2 = keccak256(abi.encodePacked(phoneNumber, newWallet, newSalt));

        phonebook.commit(secretHash2);

        vm.warp(block.timestamp + 2 minutes);
        phonebook.reveal(phoneNumber, newWallet, newSalt);

        assertEq(phonebook.getWallet(phoneNumber), newWallet, "Wallet should be updated");
    }

    // Test 7: Only MNO can commit
    function test_OnlyMNOCanCommit() public {
        bytes32 secretHash = keccak256(abi.encodePacked(phoneNumber, walletAddr, salt));

        vm.prank(makeAddr("attacker"));
        vm.expectRevert("Only MNO can register");
        phonebook.commit(secretHash);
    }

    // Test 8: Only MNO can reveal
    function test_OnlyMNOCanReveal() public {
        bytes32 secretHash = keccak256(abi.encodePacked(phoneNumber, walletAddr, salt));

        phonebook.commit(secretHash);

        vm.warp(block.timestamp + 2 minutes);

        vm.prank(makeAddr("attacker"));
        vm.expectRevert("Only MNO can register");
        phonebook.reveal(phoneNumber, walletAddr, salt);
    }

    // Test 9: Cannot reveal without commit
    function test_CannotRevealWithoutCommit() public {
        vm.warp(block.timestamp + 2 minutes);

        vm.expectRevert("No matching commit found");
        phonebook.reveal(phoneNumber, walletAddr, salt);
    }

    // Test 10: Cannot reveal with wrong data
    function test_CannotRevealWithWrongData() public {
        bytes32 secretHash = keccak256(abi.encodePacked(phoneNumber, walletAddr, salt));

        phonebook.commit(secretHash);

        vm.warp(block.timestamp + 2 minutes);

        // Try to reveal with wrong salt
        vm.expectRevert("No matching commit found");
        phonebook.reveal(phoneNumber, walletAddr, "WrongSalt");
    }

    // Test 11: Events are emitted correctly
    function test_EventsEmittedCorrectly() public {
        bytes32 secretHash = keccak256(abi.encodePacked(phoneNumber, walletAddr, salt));

        // Expect Commit event
        vm.expectEmit(true, false, false, false);
        emit Commit(secretHash);
        phonebook.commit(secretHash);

        vm.warp(block.timestamp + 2 minutes);

        // Expect Registered event (first registration)
        vm.expectEmit(true, true, false, false);
        emit Registered(phoneNumber, walletAddr);
        phonebook.reveal(phoneNumber, walletAddr, salt);
    }

    // Test 12: WalletUpdated event emitted on update
    function test_WalletUpdatedEventEmitted() public {
        // Initial registration
        bytes32 secretHash1 = keccak256(abi.encodePacked(phoneNumber, walletAddr, salt));
        phonebook.commit(secretHash1);

        vm.warp(block.timestamp + 2 minutes);
        phonebook.reveal(phoneNumber, walletAddr, salt);

        // Update to new wallet
        address newWallet = makeAddr("newWallet");
        string memory newSalt = "NewSalt456";
        bytes32 secretHash2 = keccak256(abi.encodePacked(phoneNumber, newWallet, newSalt));

        phonebook.commit(secretHash2);

        vm.warp(block.timestamp + 2 minutes);

        // Expect WalletUpdated event
        vm.expectEmit(true, true, true, false);
        emit WalletUpdated(phoneNumber, walletAddr, newWallet);
        phonebook.reveal(phoneNumber, newWallet, newSalt);
    }

    // Test 13: Cannot register zero as a phone number
    function test_CannotRegisterZeroPhoneNumber() public {
        uint256 zeroPhoneNumber = 0;
        bytes32 secretHash = keccak256(abi.encodePacked(zeroPhoneNumber, walletAddr, salt));

        phonebook.commit(secretHash);

        vm.warp(block.timestamp + 2 minutes);

        vm.expectRevert("Invalid phone number");
        phonebook.reveal(zeroPhoneNumber, walletAddr, salt);
    }
}