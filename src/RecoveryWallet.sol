// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract RecoveryWallet {
    address public owner;
    uint256 public guardianThreshold;
    mapping(address => bool) public isGuardian;
    uint256 public guardianCount;

    uint256 public recoveryNonce; 
    mapping(uint256 => mapping(address => bool)) public recoveryVotes;

    bool private locked;

    struct RecoveryRequest {
        address newOwner;
        uint256 approvalCount;
        uint256 initTime;
        bool active;
    }
    
    RecoveryRequest public activeRecovery;
    uint256 public recoveryDelay; // Time lock for recovery execution
    uint256 public constant MAX_RECOVERY_DELAY = 90 days; // Maximum 90-day time lock

    event Transfer(address indexed to, uint256 amount);
    event RecoveryInitiated(address indexed by, address newOwner, uint256 nonce);
    event RecoveryApproved(address indexed by, uint256 nonce);
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);

    event GuardianAdded(address indexed guardian);
    event GuardianRemoved(address indexed guardian);
    event ThresholdChanged(uint256 newThreshold);
    event RecoveryDelayChanged(uint256 newDelay);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyGuardian() {
        require(isGuardian[msg.sender], "Not a guardian");
        _;
    }

    modifier noActiveRecovery() {
        require(!activeRecovery.active, "Cannot change config during active recovery");
        _;
    }

    modifier nonReentrant() {
        require(!locked, "No reentrancy");
        locked = true;
        _;
        locked = false;
    }

    constructor(address _owner, address[] memory _guardians, uint256 _threshold) {
        owner = _owner;
        guardianThreshold = _threshold;
        recoveryDelay = 1 days; // Default 24-hour time lock

        for (uint256 i = 0; i < _guardians.length; i++) {
            require(_guardians[i] != address(0), "Invalid guardian address");
            require(!isGuardian[_guardians[i]], "Duplicate guardian");
            isGuardian[_guardians[i]] = true;
            guardianCount++;
        }
        
        require(guardianThreshold <= guardianCount, "Threshold too high");
        require(guardianThreshold > 0, "Threshold must be > 0");
    }

    // Execute: Allows the owner to send ETH or interact with other DApps
    function execute(address payable _to, uint256 _value, bytes calldata _data) external onlyOwner nonReentrant returns (bytes memory) {
        (bool success, bytes memory result) = _to.call{value: _value}(_data);
        require(success, "Transaction failed");
        emit Transfer(_to, _value);
        return result;
    }

    // InitiateRecovery: A Guardian starts the process
    function initiateRecovery(address _newOwner) external onlyGuardian {
        require(_newOwner != address(0), "Invalid new owner");
        require(_newOwner != owner, "New owner must be different");
        require(!activeRecovery.active, "Recovery already in progress");

        // Increment nonce to invalidate ALL old votes immediately.
        recoveryNonce++;
        
        RecoveryRequest storage r = activeRecovery;
        r.newOwner = _newOwner;
        r.approvalCount = 1;
        r.initTime = block.timestamp;
        r.active = true;

        recoveryVotes[recoveryNonce][msg.sender] = true;

        emit RecoveryInitiated(msg.sender, _newOwner, recoveryNonce);
    }

    // ApproveRecovery: Other Guardians vote
    function approveRecovery() external onlyGuardian {
        RecoveryRequest storage r = activeRecovery;
        require(r.active, "No active recovery");
        require(!recoveryVotes[recoveryNonce][msg.sender], "Already voted");
        
        recoveryVotes[recoveryNonce][msg.sender] = true;
        r.approvalCount++;

        emit RecoveryApproved(msg.sender, recoveryNonce);
    }

    // ExecuteRecovery: Execute the switch (After Threshold & Time Delay)
    function executeRecovery() external {
        RecoveryRequest storage r = activeRecovery;
        require(r.active, "No active recovery");
        require(r.approvalCount >= guardianThreshold, "Not enough approvals");
        require(block.timestamp >= r.initTime + recoveryDelay, "Time lock active");

        address oldOwner = owner;
        owner = r.newOwner;
        
        delete activeRecovery;
        
        emit OwnerChanged(oldOwner, owner);
    }

    // CancelRecovery: Cancel recovery
    function cancelRecovery() external onlyOwner {
        delete activeRecovery;
    }

    // AddGuardian: Add more guardians for recovery
    function addGuardian(address _guardian) external onlyOwner noActiveRecovery {
        require(_guardian != address(0), "Invalid guardian address");
        require(_guardian != owner, "Owner cannot be a guardian");
        require(!isGuardian[_guardian], "Already a guardian");
        isGuardian[_guardian] = true;
        guardianCount++;
        emit GuardianAdded(_guardian);
    }

    // RemoveGuardian: Remove a guardian so far as threshold is met
    function removeGuardian(address _guardian) external onlyOwner noActiveRecovery {
        require(isGuardian[_guardian], "Not a guardian");
        require(guardianCount - 1 >= guardianThreshold, "Cannot remove: threshold too high");
        
        isGuardian[_guardian] = false;
        guardianCount--;
        emit GuardianRemoved(_guardian);
    }

    // ChangeThreshold: Change threshold to a valid number
    function changeThreshold(uint256 _newThreshold) external onlyOwner noActiveRecovery {
        require(_newThreshold > 0 && _newThreshold <= guardianCount, "Invalid threshold");
        guardianThreshold = _newThreshold;
        emit ThresholdChanged(_newThreshold);
    }

    // ChangeRecoveryDelay: Change the recovery timelock period
    function changeRecoveryDelay(uint256 _newDelay) external onlyOwner noActiveRecovery {
        require(_newDelay > 0, "Delay must be > 0");
        require(_newDelay <= MAX_RECOVERY_DELAY, "Delay exceeds maximum");
        recoveryDelay = _newDelay;
        emit RecoveryDelayChanged(_newDelay);
    }

    receive() external payable {}
}