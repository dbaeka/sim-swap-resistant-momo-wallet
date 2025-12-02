# Sim Swap Resistant Mobile Money Wallet

A blockchain-based solution to protect mobile money wallets from SIM swap attacks using smart contracts on Ethereum.

## Problem Statement

SIM swap attacks are a major security threat for mobile money users, especially in Ghana, and largely Africa. Attackers
port victims' phone numbers to their own SIM cards, gaining access to SMS-based 2FA and mobile money accounts. This
project provides a blockchain-based solution that:

- Separates wallet control from phone number ownership
- Implements a guardian-based social recovery system
- Uses commit-reveal schemes for secure phone number registration
- Prevents single-point-of-failure recovery mechanisms

## Architecture

The solution consists of two main smart contracts:

### 1. RecoveryWallet

A smart contract wallet with guardian-based social recovery:

- **Owner**: The primary wallet controller
- **Guardians**: Trusted contacts who can help recover the wallet
- **Threshold**: Number of guardians required to approve recovery
- **Timelock**: Delay before recovery execution (default 24 hours)

### 2. Phonebook

A registry linking phone numbers to wallet addresses:

- **Commit-Reveal**: Uses a two-step process (commit, then reveal) to hide sensitive registration data until the reveal
  phase, preventing attackers from frontrunning phone number registrations.
- **Time-Bounded**: Enforces min/max windows for reveals
- **Updatable**: Allows wallet address changes with proper authorization
- **MNO-Controlled**: Only Mobile Network Operators can register mappings

## Security Features

### RecoveryWallet Security

- Reentrancy protection on execute function
- Guardian threshold enforcement
- Time-locked recovery execution
- Nonce-based vote invalidation
- Owner cannot be guardian (conflict of interest prevention)
- Cannot recover to same owner
- Cannot start multiple recoveries simultaneously
- Configurable recovery delay

### Phonebook Security

- Commit-reveal scheme prevents frontrunning
- Minimum commit delay (1 minute)
- Maximum reveal window (24 hours)
- MNO-only access control
- Support for wallet updates
- Event logging for transparency

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Git](https://git-scm.com/)

## Quick Start

### Installation

```bash
# Clone the repository
git clone https://github.com/dbaeka/sim-swap-resistant-momo-wallet
cd sim-swap-resistant-momo-wallet

# Install dependencies
forge install

# Build contracts
forge build
```

### Setup with Remix IDE

You can also work with this project using Remix IDE:

```bash
# Install remixd globally
npm install -g @remix-project/remixd

# Run remixd inside your Foundry project
remixd -s . --remix-ide https://remix.ethereum.org
```

Once remixd is running:
1. Open [Remix IDE](https://remix.ethereum.org)
2. Click on the "File Explorer" icon
3. Click "Connect to Localhost"
4. You should now see your project files in Remix

This allows you to edit, compile, and deploy contracts using Remix's visual interface while keeping your files in sync with your local Foundry project.

### Running Tests

```bash
# Run all tests
forge test

# Run with verbosity
forge test -vvv

# Run specific test file
forge test --match-contract RecoveryWalletTest

# Run with gas report
forge test --gas-report
```

### Test Coverage

```bash
# Generate coverage report
forge coverage

# Generate detailed coverage report
forge coverage --report lcov
```

## Project Structure

```
sim-swap-resistant-momo-wallet/
├── src/
│   ├── RecoveryWallet.sol    # Guardian-based wallet contract
│   └── Phonebook.sol           # Phone-to-wallet registry
├── test/
│   ├── RecoveryWallet.t.sol  # RecoveryWallet tests
│   └── Phonebook.t.sol       # Phonebook tests
├── script/
│   ├── RecoveryWallet.s.sol     # RecoveryWallet deployment
│   ├── Phonebook.s.sol          # Phonebook deployment
│   └── DeployAll.s.sol          # Deploy all contracts
└── README.md                  # This file
```

## Usage Examples

### Deploying Contracts

#### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) installed
- Private key or mnemonic for deployment
- RPC URL for target network (e.g., Sepolia etc.)
- ETH for gas fees on the target network

#### Environment Setup

Create a `.env` file in the project root:

```bash
# Network RPC URLs
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY

# Private key for deployment (DO NOT commit this!)
PRIVATE_KEY=your_private_key_here

# Optional: Etherscan API key for contract verification
ETHERSCAN_API_KEY=your_etherscan_api_key

# RecoveryWallet Configuration (Optional - defaults will be used if not set)
WALLET_OWNER=0x1234567890123456789012345678901234567890
GUARDIAN_1=0x2345678901234567890123456789012345678901
GUARDIAN_2=0x3456789012345678901234567890123456789012
GUARDIAN_THRESHOLD=2
```

#### Deployment Scripts

##### 1. Deploy Phonebook Only

```bash
# Local simulation (dry run)
forge script script/Phonebook.s.sol:PhonebookScript

# Deploy to Sepolia testnet
forge script script/Phonebook.s.sol:PhonebookScript \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --verify
```

##### 2. Deploy RecoveryWallet Only

**Before deploying**, you MUST set the environment variables for owner and guardians, or edit the script with real
addresses.

```bash
# Local simulation (dry run)
forge script script/RecoveryWallet.s.sol:RecoveryWalletScript

# Deploy to Sepolia testnet
forge script script/RecoveryWallet.s.sol:RecoveryWalletScript \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --verify
```

##### 3. Deploy All Contracts

Deploy both Phonebook and RecoveryWallet in a single transaction:

```bash
# Local simulation (dry run)
forge script script/DeployAll.s.sol:DeployAllScript

# Deploy to Sepolia testnet
forge script script/DeployAll.s.sol:DeployAllScript \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --verify
```

#### Deployment Flags Explained

- `--rpc-url`: The RPC endpoint for the target network
- `--private-key`: Your wallet's private key (use keystore for production)
- `--broadcast`: Actually send the transaction (omit for dry run)
- `--verify`: Automatically verify contract on Etherscan
- `-vvvv`: Verbose output for debugging

#### Using Keystores (Recommended for Production)

Instead of using raw private keys, use Foundry's keystore:

```bash
# Create a keystore
cast wallet import myKeystore --interactive

# Deploy using keystore
forge script script/DeployAll.s.sol:DeployAllScript \
    --rpc-url $SEPOLIA_RPC_URL \
    --account myKeystore \
    --sender 0xYourAddress \
    --broadcast \
    --verify
```

#### Post-Deployment Steps

##### For Phonebook

1. The deployer automatically becomes the MNO
2. To register a phone number:
   ```bash
   # 1. Commit hash
   cast send <PHONEBOOK_ADDRESS> \
       "commit(bytes32)" <COMMITMENT_HASH> \
       --rpc-url $SEPOLIA_RPC_URL \
       --private-key $PRIVATE_KEY
   
   # 2. Wait MIN_COMMIT_DELAY (1 minute)
   
   # 3. Reveal
   cast send <PHONEBOOK_ADDRESS> \
       "reveal(uint256,address,string)" <PHONE_NUMBER> <WALLET_ADDRESS> <SALT> \
       --rpc-url $SEPOLIA_RPC_URL \
       --private-key $PRIVATE_KEY
   ```

##### For RecoveryWallet

1. Verify guardian addresses are correct
2. Ensure guardians understand the recovery process
3. Test the recovery flow on testnet before mainnet deployment
4. Fund the wallet with ETH/tokens

#### Example Deployment Output

```
=== Deploying All Contracts ===

1. Phonebook deployed at: 0x1234567890abcdef1234567890abcdef12345678
   MNO address: 0xYourDeployerAddress

2. RecoveryWallet deployed at: 0xabcdef1234567890abcdef1234567890abcdef12
   Owner: 0xOwnerAddress
   Guardian count: 2
   Guardian threshold: 2
   Recovery delay: 86400 seconds

=== Deployment Complete ===

Next steps:
1. Verify contracts on block explorer
2. Register phone number via Phonebook
3. Test guardian recovery flow
```

## Configuration

### RecoveryWallet Parameters

- **guardianThreshold**: Number of guardians needed for recovery (default: based on guardian count)
- **recoveryDelay**: Time lock before recovery execution (default: 1 day)
- **guardians**: Array of trusted addresses

### Phonebook Parameters

- **MIN_COMMIT_DELAY**: Minimum time before reveal (1 minute)
- **MAX_COMMIT_WINDOW**: Maximum time to reveal (24 hours)
- **mnoAddress**: Mobile Network Operator address
