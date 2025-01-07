# SpottedServiceManager

| File | Type | Proxy |
| -------- | -------- | -------- |
| `SpottedServiceManager.sol` | Singleton | UUPS proxy |

`SpottedServiceManager` is an Active Validator Set (AVS) service manager that enables cross-chain state verification through a quorum of operators. It inherits from `ECDSAServiceManagerBase` and implements additional functionality for state verification and dispute resolution.

## Core Components

### State Variables
```solidity
IStateDisputeResolver public immutable disputeResolver;    // Handles challenge resolution
```

### Access Control
```solidity
modifier onlyDisputeResolver() {
    if (msg.sender != address(disputeResolver)) {
        revert SpottedServiceManager__CallerNotDisputeResolver();
    }
    _;
}
```

## Key Functions

### Constructor & Initialization
```solidity
constructor(
    address _avsDirectory,
    address _stakeRegistry,
    address _rewardsCoordinator,
    address _delegationManager,
    address _disputeResolver
)
```
- Initializes base service manager components
- Sets immutable dispute resolver address
- Disables initializers for proxy pattern

```solidity
function initialize(
    address initialOwner,
    address initialRewardsInitiator,
    IPauserRegistry pauserRegistry
) external initializer
```
- Sets up initial contract state
- Initializes Ownable and Pausable features
- Configures rewards initiator and pauser registry

### Operator Management
```solidity
function registerOperatorToAVS(
    address operator,
    ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature
) external override(ECDSAServiceManagerBase, ISpottedServiceManager)
```
- Registers new operators to the AVS
- Requires stake registry authorization
- Validates operator signatures

```solidity
function deregisterOperatorFromAVS(
    address operator
) external override(ECDSAServiceManagerBase, ISpottedServiceManager)
```
- Removes operators from the AVS
- Only callable by stake registry
- Cleans up operator state

### Task Management
```solidity
function generateTaskId(
    address user,
    uint32 chainId,
    uint64 blockNumber,
    uint256 key,
    uint256 value,
    uint256 timestamp
) public pure returns (bytes32)
```
- Creates unique identifier for tasks
- Combines multiple parameters for uniqueness
- Used for tracking responses and challenges

## Integration Points

1. **With ECDSAServiceManagerBase**
   - Inherits core operator management
   - Extends base functionality
   - Maintains compatibility with EigenLayer

2. **With Dispute Resolution**
   - Direct integration with dispute resolver
   - Challenge handling capabilities
   - State verification support

3. **With Security Features**
   - Implements Pausable functionality
   - Upgradeable proxy pattern
   - Access control mechanisms

## Error Handling

```solidity
error SpottedServiceManager__CallerNotDisputeResolver()
```
- Ensures dispute resolution security
- Restricts sensitive operations
- Maintains system integrity