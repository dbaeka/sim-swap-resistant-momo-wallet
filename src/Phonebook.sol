// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Phonebook {
    address public mnoAddress; // The MNO (e.g., MTN Ghana)
    mapping(uint256 => address) public phoneToWallet;
    mapping(bytes32 => bool) public commits; // Stores hashed commitments
    mapping(bytes32 => uint256) public commitTimestamps; // Stores commitment timestamps

    uint256 public constant MIN_COMMIT_DELAY = 1 minutes; // Minimum time before reveal
    uint256 public constant MAX_COMMIT_WINDOW = 24 hours; // Maximum time to reveal

    event Commit(bytes32 indexed commitmentHash);
    event Registered(uint256 indexed phoneNumber, address indexed wallet);
    event WalletUpdated(uint256 indexed phoneNumber, address indexed oldWallet, address indexed newWallet);

    modifier onlyMNO() {
        require(msg.sender == mnoAddress, "Only MNO can register");
        _;
    }

    constructor() {
        mnoAddress = msg.sender;
    }

    // Commit: MNO submits a hash [keccak256(abi.encodePacked(phoneNumber, walletAddress, secretSalt))];
    function commit(bytes32 _commitmentHash) external onlyMNO {
        commits[_commitmentHash] = true;
        commitTimestamps[_commitmentHash] = block.timestamp;
        emit Commit(_commitmentHash);
    }

    // Reveal: MNO reveals the data to finalize registration
    function reveal(uint256 _phoneNumber, address _wallet, string memory _salt) external onlyMNO {
        require(_phoneNumber != 0, "Invalid phone number");
        require(_wallet != address(0), "Invalid wallet address");

        bytes32 generatedHash = keccak256(abi.encodePacked(_phoneNumber, _wallet, _salt));
        
        require(commits[generatedHash], "No matching commit found");

        uint256 commitTime = commitTimestamps[generatedHash];
        require(block.timestamp >= commitTime + MIN_COMMIT_DELAY, "Reveal too early");
        require(block.timestamp <= commitTime + MAX_COMMIT_WINDOW, "Reveal window expired");

        address oldWallet = phoneToWallet[_phoneNumber];

        delete commits[generatedHash];
        delete commitTimestamps[generatedHash];
        phoneToWallet[_phoneNumber] = _wallet;

        if (oldWallet == address(0)) {
            emit Registered(_phoneNumber, _wallet);
        } else {
            emit WalletUpdated(_phoneNumber, oldWallet, _wallet);
        }
    }

    // Helper to view address
    function getWallet(uint256 _phoneNumber) external view returns (address) {
        return phoneToWallet[_phoneNumber];
    }
}