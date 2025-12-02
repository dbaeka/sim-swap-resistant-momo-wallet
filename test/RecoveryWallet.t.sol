// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {RecoveryWallet} from "../src/RecoveryWallet.sol";

contract RecoveryWalletTest is Test {

    RecoveryWallet wallet;
    
    address owner;
    address guardianA;
    address guardianB;
    address newGuardian;
    address attacker;
    address newOwner;

    function setUp() public {
        owner = address(this);
        guardianA = makeAddr("guardianA");
        guardianB = makeAddr("guardianB");
        newGuardian = makeAddr("newGuardian");
        attacker = makeAddr("attacker");
        newOwner = makeAddr("newOwner");

        address[] memory guardians = new address[](2);
        guardians[0] = guardianA;
        guardians[1] = guardianB;
        
        wallet = new RecoveryWallet(owner, guardians, 2);
    }

    // Test 1: Verify Initial State
    function test_InitialConfig() public view {
        assertEq(wallet.owner(), owner, "Owner should be set correctly");
        assertEq(wallet.guardianCount(), 2, "Should start with 2 guardians");
        assertEq(wallet.guardianThreshold(), 2, "Threshold should be 2");
        assertEq(wallet.recoveryDelay(), 1 days, "Recovery delay should be 1 day");
    }

    // Test 2: Add a Guardian
    function test_AddGuardian() public {
        wallet.addGuardian(newGuardian);
        assertEq(wallet.guardianCount(), 3, "Count should increase to 3");
        assertTrue(wallet.isGuardian(newGuardian), "New address should be a guardian");
    }

    // Test 3: Remove a Guardian
    function test_RemoveGuardian() public {
        wallet.addGuardian(newGuardian);
        wallet.removeGuardian(newGuardian);
        assertEq(wallet.guardianCount(), 2, "Count should return to 2");
        assertFalse(wallet.isGuardian(newGuardian), "Address should no longer be guardian");
    }
    
    // Test 4: Verify Threshold Security 
    function test_ThresholdSecurity() public {
        vm.expectRevert("Cannot remove: threshold too high");
        wallet.removeGuardian(guardianA);
    }

    // Test 5: Verify nonce starts at 0
    function test_NonceReset() public view {
        uint256 nonceBefore = wallet.recoveryNonce();
        assertEq(nonceBefore, 0, "Nonce starts at 0");
    }

    // Test 6: Owner cannot be added as guardian
    function test_OwnerCannotBeGuardian() public {
        vm.expectRevert("Owner cannot be a guardian");
        wallet.addGuardian(owner);
    }

    // Test 7: Cannot initiate recovery with same owner
    function test_CannotRecoverToSameOwner() public {
        vm.prank(guardianA);
        vm.expectRevert("New owner must be different");
        wallet.initiateRecovery(owner);
    }

    // Test 8: Cannot initiate recovery when one is already active
    function test_CannotInitiateMultipleRecoveries() public {
        vm.prank(guardianA);
        wallet.initiateRecovery(newOwner);

        vm.prank(guardianB);
        vm.expectRevert("Recovery already in progress");
        wallet.initiateRecovery(makeAddr("anotherOwner"));
    }

    // Test 9: Change recovery delay
    function test_ChangeRecoveryDelay() public {
        uint256 newDelay = 2 days;
        wallet.changeRecoveryDelay(newDelay);
        assertEq(wallet.recoveryDelay(), newDelay, "Recovery delay should be updated");
    }

    // Test 10: Cannot set recovery delay to zero
    function test_CannotSetRecoveryDelayToZero() public {
        vm.expectRevert("Delay must be > 0");
        wallet.changeRecoveryDelay(0);
    }

    // Test 11: Cannot set recovery delay above maximum
    function test_CannotSetRecoveryDelayAboveMaximum() public {
        uint256 maxDelay = wallet.MAX_RECOVERY_DELAY();

        // This should succeed (at the limit)
        wallet.changeRecoveryDelay(maxDelay);
        assertEq(wallet.recoveryDelay(), maxDelay, "Should accept maximum delay");

        // This should fail (above the limit)
        vm.expectRevert("Delay exceeds maximum");
        wallet.changeRecoveryDelay(maxDelay + 1);
    }

    // Test 12: Full recovery flow
    function test_FullRecoveryFlow() public {
        // Initiate recovery
        vm.prank(guardianA);
        wallet.initiateRecovery(newOwner);

        // Approve recovery
        vm.prank(guardianB);
        wallet.approveRecovery();

        // Fast forward time
        vm.warp(block.timestamp + 1 days + 1);

        // Execute recovery
        wallet.executeRecovery();

        assertEq(wallet.owner(), newOwner, "Owner should be changed");
    }

    // Test 13: Cannot execute recovery before timelock
    function test_CannotExecuteBeforeTimelock() public {
        vm.prank(guardianA);
        wallet.initiateRecovery(newOwner);

        vm.prank(guardianB);
        wallet.approveRecovery();

        vm.expectRevert("Time lock active");
        wallet.executeRecovery();
    }

    // Test 14: Execute transfers value correctly
    function test_ExecuteTransfersValue() public {
        vm.deal(address(wallet), 1 ether);

        address payable recipient = payable(makeAddr("recipient"));
        bytes memory data = "";

        wallet.execute(recipient, 0.5 ether, data);

        assertEq(recipient.balance, 0.5 ether, "Recipient should receive ETH");
    }

    // Test 15: Reentrancy protection on execute
    function test_ReentrancyProtection() public {
        // Create a malicious contract that will be the owner of a new wallet
        address[] memory guardians = new address[](2);
        guardians[0] = guardianA;
        guardians[1] = guardianB;

        MaliciousReentrancy maliciousContract = new MaliciousReentrancy();
        RecoveryWallet vulnerableWallet = new RecoveryWallet(address(maliciousContract), guardians, 2);

        maliciousContract.setWallet(address(vulnerableWallet));
        vm.deal(address(vulnerableWallet), 2 ether);

        // Attempt reentrancy attack - the transaction should fail due to reentrancy guard
        vm.expectRevert("Transaction failed");
        maliciousContract.attack();
    }
}

contract MaliciousReentrancy {
    RecoveryWallet public wallet;

    function setWallet(address _wallet) external {
        wallet = RecoveryWallet(payable(_wallet));
    }

    function attack() external {
        // Call execute, which will send ETH to this contract and trigger receive()
        wallet.execute(payable(address(this)), 1 ether, "");
    }

    receive() external payable {
        // Attempt reentrancy - this should fail with "No reentrancy"
        wallet.execute(payable(address(this)), 0, "");
    }
}