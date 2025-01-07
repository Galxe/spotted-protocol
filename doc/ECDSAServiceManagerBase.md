# ECDSAServiceManagerBase

| File | Type | Proxy |
| -------- | -------- | -------- |
| `ECDSAServiceManagerBase.sol` | Abstract Base Contract | UUPS proxy |

`ECDSAServiceManagerBase` is an abstract base contract that provides core infrastructure provided by EigenLayer for the AVS. It manages operator registration, stake tracking, and rewards distribution for ECDSA-based services.

## High-level Concepts

1. Operator Management
2. Rewards Distribution
3. AVS Metadata Management

## Core Components

### Immutable Contracts
```solidity
address public immutable stakeRegistry;        // Manages operator registration and stake
address public immutable avsDirectory;         // Stores AVS-related operator data
address internal immutable rewardsCoordinator; // Handles rewards distribution
address internal immutable delegationManager;  // Manages staker delegations
```

### State Variables
```solidity
address public rewardsInitiator;  // Authorized to create rewards submissions
```

## Access Control

The contract implements role-based access control:
- _StakeRegistry_: Can register/deregister operators
- _RewardsInitiator_: Can submit AVS rewards
- _Owner_: Can update AVS metadata and configurations

## Core Functions

### Operator Management
```solidity
function registerOperatorToAVS(
    address operator,
    ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature
) external onlyStakeRegistry
```
Registers an operator with the AVS:
- Validates operator signature
- Records registration in AVS directory
- Enables operator participation

```solidity
function deregisterOperatorFromAVS(
    address operator
) external onlyStakeRegistry
```
Removes an operator from the AVS:
- Cleans up operator records
- Updates AVS directory
- Disables operator participation

### Rewards Management
```solidity
function createAVSRewardsSubmission(
    IRewardsCoordinator.RewardsSubmission[] calldata rewardsSubmissions
) external onlyRewardsInitiator
```
Creates rewards submissions for operators:
- Validates submission data
- Forwards to rewards coordinator
- Updates reward distributions

### AVS Configuration
```solidity
function updateAVSMetadataURI(
    string memory _metadataURI
) external onlyOwner
```
Updates AVS metadata:
- Sets new metadata URI
- Updates AVS directory
- Maintains service information

## Integration Points

The contract integrates with several EigenLayer components:
1. **StakeRegistry**: For operator stake management
2. **AVSDirectory**: For operator service data
3. **RewardsCoordinator**: For rewards distribution
4. **DelegationManager**: For delegation management

## Events

```solidity
event OperatorRegistered(address indexed operator)
event OperatorDeregistered(address indexed operator)
event AVSMetadataURIUpdated(string newMetadataURI)
event RewardsInitiatorSet(address newRewardsInitiator)
```

## Usage

This base contract is inherited by SpottedServiceManager.